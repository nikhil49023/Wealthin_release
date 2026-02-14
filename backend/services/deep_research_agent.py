"""
Deep Research Agent - Agentic Loop for Comprehensive Financial Research
Implements the "Loop of Truth" architecture:
1. PLAN: Break query into sub-tasks (DAG)
2. EXECUTE: Search for each task via DuckDuckGo
3. BROWSE: Read full content from top URLs
4. REFLECT: Evaluate if data is sufficient
5. SYNTHESIZE: Generate comprehensive report

Integrates with Sarvam AI for planning/reflection and web_search_service for DDG.
"""

import json
import re
import logging
from typing import Dict, Any, List, Optional, Tuple
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum

# Configure logger
logger = logging.getLogger(__name__)

# Try importing optional dependencies
try:
    from bs4 import BeautifulSoup
    BS4_AVAILABLE = True
except ImportError:
    BS4_AVAILABLE = False
    logger.warning("BeautifulSoup not available. Content scraping will be limited.")

try:
    import urllib.request
    import urllib.error
    URLLIB_AVAILABLE = True
except ImportError:
    URLLIB_AVAILABLE = False


class ResearchPhase(Enum):
    """Current phase of the research loop"""
    PLANNING = "planning"
    SEARCHING = "searching"
    BROWSING = "browsing"
    REFLECTING = "reflecting"
    SYNTHESIZING = "synthesizing"
    COMPLETE = "complete"


@dataclass
class ResearchState:
    """Tracks the state of a deep research session"""
    query: str
    current_phase: ResearchPhase = ResearchPhase.PLANNING
    iteration: int = 0
    max_iterations: int = 3
    
    # Task DAG
    planned_tasks: List[str] = field(default_factory=list)
    completed_tasks: List[str] = field(default_factory=list)
    
    # Knowledge accumulation
    findings: List[Dict[str, Any]] = field(default_factory=list)
    sources: List[str] = field(default_factory=list)
    
    # Status updates for UI streaming
    status_log: List[str] = field(default_factory=list)
    
    # Final output
    final_report: Optional[str] = None
    
    def log_status(self, message: str):
        """Add a status message for UI display"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.status_log.append(f"[{timestamp}] {message}")
        logger.info(f"[DeepResearch] {message}")


class DeepResearchAgent:
    """
    Agentic Deep Research Agent
    
    Performs multi-step research with planning, execution, reflection loop.
    Designed for comprehensive financial analysis with RBI compliance.
    """
    
    def __init__(self, sarvam_service=None, web_search_service=None):
        """
        Initialize the agent with required services.
        
        Args:
            sarvam_service: Sarvam AI service for LLM calls
            web_search_service: DuckDuckGo search service
        """
        self.sarvam = sarvam_service
        self.web_search = web_search_service
        
        # Government domains for authoritative sources
        self.gov_domains = [
            "pib.gov.in",
            "india.gov.in",
            "rbi.org.in",
            "sebi.gov.in",
            "incometax.gov.in",
            "gst.gov.in",
        ]
    
    async def research(self, query: str, context: Optional[Dict] = None) -> Dict[str, Any]:
        """
        Main entry point for deep research.
        
        Args:
            query: User's research query
            context: Optional additional context (user data, preferences)
            
        Returns:
            Dict with 'report', 'sources', 'status_log'
        """
        state = ResearchState(query=query)
        state.log_status(f"🔍 Starting deep research: {query[:50]}...")
        
        try:
            # Phase 1: Planning
            state.current_phase = ResearchPhase.PLANNING
            state.log_status("[PLANNING] Breaking down query into research tasks...")
            await self._plan_research(state)
            
            # Iterative research loop
            while state.iteration < state.max_iterations:
                state.iteration += 1
                state.log_status(f"📊 Research iteration {state.iteration}/{state.max_iterations}")
                
                # Phase 2: Execute searches
                state.current_phase = ResearchPhase.SEARCHING
                await self._execute_searches(state)
                
                # Phase 3: Browse top results
                state.current_phase = ResearchPhase.BROWSING
                await self._browse_results(state)
                
                # Phase 4: Reflect on findings
                state.current_phase = ResearchPhase.REFLECTING
                is_complete, new_tasks = await self._reflect_on_findings(state)
                
                if is_complete:
                    state.log_status("✅ Research complete - sufficient data gathered")
                    break
                elif new_tasks:
                    state.log_status(f"🔄 Found gaps. Adding {len(new_tasks)} new tasks...")
                    state.planned_tasks.extend(new_tasks)
            
            # Phase 5: Synthesize final report
            state.current_phase = ResearchPhase.SYNTHESIZING
            state.log_status("[SYNTHESIZING] Generating comprehensive report...")
            await self._synthesize_report(state)
            
            state.current_phase = ResearchPhase.COMPLETE
            state.log_status("🎉 Deep research complete!")
            
            return {
                "report": state.final_report or "Research completed but no report generated.",
                "sources": list(set(state.sources)),
                "status_log": state.status_log,
                "iterations": state.iteration,
            }
            
        except Exception as e:
            logger.error(f"Deep research error: {e}")
            state.log_status(f"❌ Error during research: {str(e)}")
            return {
                "report": f"Research encountered an error: {str(e)}",
                "sources": state.sources,
                "status_log": state.status_log,
                "error": str(e),
            }
    
    async def _plan_research(self, state: ResearchState):
        """
        Break down the query into a DAG of research tasks.
        Uses Sarvam AI to generate sub-tasks.
        """
        planner_prompt = f"""You are a financial research planner. Break down this query into 3-5 specific search tasks.

Query: {state.query}

Return ONLY a JSON array of search queries, e.g.:
["Latest Q3 results for Reliance Industries", "Green Hydrogen Mission India subsidies 2024", "RBI guidelines on investment in renewable sector"]

Focus on:
1. Company financials if mentioned (earnings, P/E, revenue)
2. Government policies/subsidies
3. RBI guidelines and compliance
4. Market analysis and competitors
5. Recent news and developments

Return ONLY the JSON array, no other text:"""

        try:
            if self.sarvam and self.sarvam.is_configured:
                response = await self.sarvam.chat_async(planner_prompt)
                # Parse JSON from response
                tasks = self._extract_json_array(response)
                if tasks:
                    state.planned_tasks = tasks
                    state.log_status(f"📋 Planned {len(tasks)} research tasks")
                    for i, task in enumerate(tasks, 1):
                        state.log_status(f"   {i}. {task[:60]}...")
                    return
            
            # Fallback: Simple task extraction
            state.planned_tasks = [
                state.query,
                f"{state.query} RBI guidelines",
                f"{state.query} India news 2024",
            ]
            state.log_status(f"📋 Generated {len(state.planned_tasks)} fallback tasks")
            
        except Exception as e:
            logger.error(f"Planning error: {e}")
            state.planned_tasks = [state.query]
    
    async def _execute_searches(self, state: ResearchState):
        """Execute DDG searches for pending tasks."""
        for task in state.planned_tasks:
            if task in state.completed_tasks:
                continue
            
            state.log_status(f"[SEARCHING] DuckDuckGo: \"{task[:40]}...\"")
            
            try:
                if self.web_search and self.web_search.is_available:
                    results = await self.web_search.search_async(task, max_results=3)
                    
                    for result in results:
                        state.findings.append({
                            "task": task,
                            "title": result.get("title", ""),
                            "snippet": result.get("snippet", ""),
                            "url": result.get("url", ""),
                            "source": "ddg_search",
                        })
                        if result.get("url"):
                            state.sources.append(result["url"])
                    
                    state.log_status(f"   Found {len(results)} results")
                else:
                    state.log_status("   ⚠️ Search service unavailable")
                    
                state.completed_tasks.append(task)
                
            except Exception as e:
                logger.error(f"Search error for '{task}': {e}")
                state.log_status(f"   ❌ Search failed: {str(e)[:30]}")
    
    async def _browse_results(self, state: ResearchState):
        """Browse top URLs to extract full content."""
        urls_to_browse = []
        
        # Collect unique URLs (prioritize gov domains)
        for finding in state.findings:
            url = finding.get("url")
            if url and url not in urls_to_browse:
                # Prioritize government sources
                is_gov = any(domain in url for domain in self.gov_domains)
                if is_gov or len(urls_to_browse) < 4:
                    urls_to_browse.append(url)
        
        # Browse top 2 per iteration
        for url in urls_to_browse[:2]:
            state.log_status(f"[BROWSING] Reading: {self._truncate_url(url)}")
            
            try:
                content = await self._fetch_page_content(url)
                if content:
                    # Add to findings
                    state.findings.append({
                        "url": url,
                        "content": content[:3000],  # Limit content size
                        "source": "full_browse",
                    })
                    state.log_status(f"   ✅ Extracted {len(content)} chars")
                else:
                    state.log_status(f"   ⚠️ Could not extract content")
                    
            except Exception as e:
                logger.error(f"Browse error for {url}: {e}")
                state.log_status(f"   ❌ Failed: {str(e)[:30]}")
    
    async def _fetch_page_content(self, url: str) -> Optional[str]:
        """Fetch and extract main text content from a URL."""
        if not URLLIB_AVAILABLE:
            return None
            
        try:
            req = urllib.request.Request(
                url,
                headers={
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
                }
            )
            with urllib.request.urlopen(req, timeout=10) as response:
                html = response.read().decode("utf-8", errors="ignore")
                
                if BS4_AVAILABLE:
                    soup = BeautifulSoup(html, "html.parser")
                    
                    # Remove script and style elements
                    for script in soup(["script", "style", "nav", "footer", "header", "aside"]):
                        script.decompose()
                    
                    # Extract main content
                    main = soup.find("main") or soup.find("article") or soup.find("body")
                    if main:
                        text = main.get_text(separator="\n", strip=True)
                        # Clean up whitespace
                        text = re.sub(r'\n\s*\n', '\n\n', text)
                        return text[:5000]
                else:
                    # Basic text extraction without BeautifulSoup
                    text = re.sub(r'<[^>]+>', ' ', html)
                    text = re.sub(r'\s+', ' ', text)
                    return text[:3000]
                    
        except Exception as e:
            logger.error(f"Fetch error: {e}")
            return None
    
    async def _reflect_on_findings(self, state: ResearchState) -> Tuple[bool, List[str]]:
        """
        Reflect on gathered data. Determine if research is complete or needs more.
        
        Returns:
            Tuple of (is_complete, new_tasks_if_incomplete)
        """
        state.log_status("[REFLECTING] Evaluating research completeness...")
        
        # Prepare summary of findings
        findings_summary = "\n".join([
            f"- {f.get('title', f.get('url', 'Unknown'))}: {f.get('snippet', f.get('content', ''))[:100]}"
            for f in state.findings[:10]
        ])
        
        reflection_prompt = f"""You are a research quality evaluator. Analyze if we have enough information to answer this query.

Original Query: {state.query}

Findings Summary:
{findings_summary}

Evaluate:
1. Do we have specific financial data (numbers, metrics)?
2. Do we have RBI/regulatory compliance information?
3. Do we have recent news/updates?
4. Are there any gaps in the research?

Response format (JSON only):
{{"is_complete": true/false, "missing_topics": ["topic1", "topic2"], "confidence": 0.0-1.0}}

Return ONLY the JSON:"""

        try:
            if self.sarvam and self.sarvam.is_configured:
                response = await self.sarvam.chat_async(reflection_prompt)
                result = self._extract_json_object(response)
                
                if result:
                    is_complete = result.get("is_complete", False)
                    confidence = result.get("confidence", 0.5)
                    missing = result.get("missing_topics", [])
                    
                    state.log_status(f"   Confidence: {confidence*100:.0f}% | Complete: {is_complete}")
                    
                    if is_complete or confidence > 0.8:
                        return True, []
                    
                    # Generate new search queries for missing topics
                    new_tasks = [f"{topic} India 2024" for topic in missing[:2]]
                    return False, new_tasks
            
            # Fallback: Consider complete after gathering some data
            return len(state.findings) >= 5, []
            
        except Exception as e:
            logger.error(f"Reflection error: {e}")
            return len(state.findings) >= 3, []
    
    async def _synthesize_report(self, state: ResearchState):
        """Generate the final research report."""
        state.log_status("[SYNTHESIZING] Compiling research report...")
        
        # Compile all findings
        all_content = []
        for finding in state.findings:
            if finding.get("content"):
                all_content.append(finding["content"][:1000])
            elif finding.get("snippet"):
                all_content.append(finding["snippet"])
        
        findings_text = "\n\n".join(all_content[:10])
        sources_text = "\n".join([f"- {s}" for s in list(set(state.sources))[:10]])
        
        synthesis_prompt = f"""You are a financial research analyst. Create a comprehensive report based on the research findings.

Original Query: {state.query}

Research Findings:
{findings_text[:4000]}

Create a well-structured report with:
1. **Executive Summary** (2-3 sentences)
2. **Key Findings** (bullet points with specific data/numbers)
3. **RBI/Regulatory Compliance** (if applicable)
4. **Market Analysis** (trends, opportunities, risks)
5. **Recommendations** (actionable insights)

Use markdown formatting. Include specific numbers and dates where available.
Always cite sources in [brackets].

Sources:
{sources_text}

Generate the report:"""

        try:
            if self.sarvam and self.sarvam.is_configured:
                report = await self.sarvam.chat_async(synthesis_prompt)
                state.final_report = report
                state.log_status("   ✅ Report generated")
                return
            
            # Fallback report
            state.final_report = f"""# Research Report: {state.query}

## Summary
Completed {state.iteration} research iterations, analyzing {len(state.findings)} sources.

## Key Findings
{chr(10).join([f"- {f.get('title', 'Finding')}: {f.get('snippet', '')[:100]}" for f in state.findings[:5]])}

## Sources
{sources_text}

*Note: This is a basic report. Enable Sarvam AI for comprehensive analysis.*
"""
            
        except Exception as e:
            logger.error(f"Synthesis error: {e}")
            state.final_report = f"Error generating report: {str(e)}"
    
    # =========== SPECIALIZED TOOLS ===========
    
    async def government_search(self, query: str) -> List[Dict[str, Any]]:
        """
        GovTool: Search specifically on government domains.
        Appends site filters for authoritative sources.
        """
        site_queries = []
        for domain in self.gov_domains[:3]:
            site_queries.append(f"{query} site:{domain}")
        
        results = []
        for site_query in site_queries:
            if self.web_search:
                try:
                    r = await self.web_search.search_async(site_query, max_results=2)
                    results.extend(r)
                except:
                    pass
        
        return results
    
    async def stock_analysis(self, symbol: str) -> Dict[str, Any]:
        """
        StockTool: Get stock data using yfinance (if available).
        Returns P/E, latest price, 52-week range.
        """
        try:
            import yfinance as yf
            
            # Add .NS for NSE stocks if not present
            if not symbol.endswith(('.NS', '.BO')):
                symbol = f"{symbol}.NS"
            
            stock = yf.Ticker(symbol)
            info = stock.info
            
            return {
                "symbol": symbol,
                "name": info.get("longName", symbol),
                "price": info.get("currentPrice"),
                "pe_ratio": info.get("trailingPE"),
                "market_cap": info.get("marketCap"),
                "52_week_high": info.get("fiftyTwoWeekHigh"),
                "52_week_low": info.get("fiftyTwoWeekLow"),
                "sector": info.get("sector"),
                "success": True,
            }
        except ImportError:
            return {"error": "yfinance not installed", "success": False}
        except Exception as e:
            return {"error": str(e), "success": False}
    
    # =========== UTILITY METHODS ===========
    
    def _extract_json_array(self, text: str) -> List[str]:
        """Extract JSON array from text."""
        try:
            # Find JSON array in text
            match = re.search(r'\[.*?\]', text, re.DOTALL)
            if match:
                return json.loads(match.group())
        except:
            pass
        return []
    
    def _extract_json_object(self, text: str) -> Optional[Dict]:
        """Extract JSON object from text."""
        try:
            match = re.search(r'\{.*?\}', text, re.DOTALL)
            if match:
                return json.loads(match.group())
        except:
            pass
        return None
    
    def _truncate_url(self, url: str, max_len: int = 40) -> str:
        """Truncate URL for display."""
        if len(url) <= max_len:
            return url
        return url[:max_len-3] + "..."


# ==================== MSME SPECIALIZED AGENTS ====================

class MSMEComplianceAgent:
    """
    Agent for checking MSME scheme eligibility and compliance requirements.
    Covers: PMEGP, ZED, Stand-Up India, Mudra, RAMP, and updated MSME classifications.
    """
    
    # MSME Classification Limits (2025-26 Budget)
    CLASSIFICATION = {
        "micro": {"investment_limit": 2_50_00_000, "turnover_limit": 10_00_00_000},  # ₹2.5 Cr / ₹10 Cr
        "small": {"investment_limit": 25_00_00_000, "turnover_limit": 100_00_00_000},  # ₹25 Cr / ₹100 Cr
        "medium": {"investment_limit": 125_00_00_000, "turnover_limit": 500_00_00_000},  # ₹125 Cr / ₹500 Cr
    }
    
    # Scheme Database
    SCHEMES = {
        "PMEGP": {
            "full_name": "Prime Minister's Employment Generation Programme",
            "max_project_cost_manufacturing": 50_00_000,  # ₹50 Lakh
            "max_project_cost_service": 20_00_000,  # ₹20 Lakh
            "subsidy_general_urban": 0.15,  # 15%
            "subsidy_general_rural": 0.25,  # 25%
            "subsidy_special_urban": 0.25,  # 25% for SC/ST/Women/Minorities
            "subsidy_special_rural": 0.35,  # 35%
            "min_education": "VIII pass for > ₹10 Lakh projects",
            "exclusions": ["Land cost", "Existing units"],
            "implementing_agency": "KVIC, KVIB, DIC",
        },
        "Mudra": {
            "full_name": "Micro Units Development & Refinance Agency",
            "categories": {
                "Shishu": {"max_amount": 50_000},
                "Kishor": {"max_amount": 5_00_000},
                "Tarun": {"max_amount": 10_00_000},
            },
            "collateral_free": True,
            "target": "Non-corporate, non-farm small/micro enterprises",
        },
        "Stand-Up India": {
            "full_name": "Stand-Up India Scheme",
            "target": "SC/ST and Women entrepreneurs",
            "loan_range": (10_00_000, 1_00_00_000),  # ₹10 Lakh - ₹1 Cr
            "repayment_period_years": 7,
            "moratorium_months": 18,
            "project_type": "Greenfield (first-time ventures) only",
            "sectors": ["Manufacturing", "Services", "Agri-allied"],
        },
        "ZED": {
            "full_name": "Zero Defect Zero Effect Certification",
            "certification_levels": ["Bronze", "Silver", "Gold"],
            "subsidy_normal": 0.80,  # 80% subsidy on certification cost
            "subsidy_women_owned": 1.00,  # 100% for women-owned MSMEs
            "tech_upgradation_support": 3_00_000,  # Up to ₹3 Lakh
            "benefits": ["Quality improvement", "Eco-friendly production", "Export readiness"],
        },
        "RAMP": {
            "full_name": "Raising and Accelerating MSME Performance",
            "backed_by": "World Bank",
            "focus_areas": ["Technology upgradation", "Innovation", "Digitization", "Greening"],
            "special_focus": "Women-owned MSEs",
        },
    }
    
    def classify_msme(self, investment: float, turnover: float) -> Dict[str, Any]:
        """
        Classify an enterprise based on investment and turnover.
        
        Args:
            investment: Investment in plant & machinery (INR)
            turnover: Annual turnover (INR)
        """
        for category, limits in self.CLASSIFICATION.items():
            if investment <= limits["investment_limit"] and turnover <= limits["turnover_limit"]:
                return {
                    "category": category.capitalize(),
                    "investment_limit": limits["investment_limit"],
                    "turnover_limit": limits["turnover_limit"],
                    "valid": True,
                }
        return {"category": "Not MSME", "valid": False, "reason": "Exceeds Medium enterprise limits"}
    
    def check_pmegp_eligibility(
        self,
        project_cost: float,
        sector: str,  # "manufacturing" or "service"
        location: str,  # "urban" or "rural"
        category: str,  # "general" or "special" (SC/ST/Women/Minority)
        education: str = "VIII pass",
        is_existing_unit: bool = False,
    ) -> Dict[str, Any]:
        """Check eligibility for PMEGP scheme."""
        scheme = self.SCHEMES["PMEGP"]
        issues = []
        
        # Check project cost limit
        max_cost = scheme["max_project_cost_manufacturing"] if sector == "manufacturing" else scheme["max_project_cost_service"]
        if project_cost > max_cost:
            issues.append(f"Project cost ₹{project_cost/100000:.1f}L exceeds limit ₹{max_cost/100000:.0f}L")
        
        if is_existing_unit:
            issues.append("PMEGP is only for new units, not existing businesses")
        
        # Calculate subsidy
        if location == "rural":
            subsidy_rate = scheme["subsidy_special_rural"] if category == "special" else scheme["subsidy_general_rural"]
        else:
            subsidy_rate = scheme["subsidy_special_urban"] if category == "special" else scheme["subsidy_general_urban"]
        
        subsidy_amount = project_cost * subsidy_rate
        own_contribution = project_cost * (0.05 if category == "special" else 0.10)
        bank_loan = project_cost - subsidy_amount - own_contribution
        
        return {
            "eligible": len(issues) == 0,
            "issues": issues,
            "subsidy_rate": f"{subsidy_rate*100:.0f}%",
            "subsidy_amount": subsidy_amount,
            "own_contribution": own_contribution,
            "bank_loan_required": bank_loan,
            "implementing_agency": scheme["implementing_agency"],
        }
    
    def check_standup_india_eligibility(
        self,
        loan_amount: float,
        applicant_category: str,  # "sc", "st", "woman"
        is_greenfield: bool,
        sector: str,
    ) -> Dict[str, Any]:
        """Check eligibility for Stand-Up India scheme."""
        scheme = self.SCHEMES["Stand-Up India"]
        issues = []
        
        if applicant_category not in ["sc", "st", "woman"]:
            issues.append("Stand-Up India is only for SC/ST and Women entrepreneurs")
        
        if not is_greenfield:
            issues.append("Only greenfield (first-time) ventures are eligible")
        
        min_loan, max_loan = scheme["loan_range"]
        if loan_amount < min_loan or loan_amount > max_loan:
            issues.append(f"Loan must be between ₹10 Lakh and ₹1 Crore")
        
        if sector not in ["manufacturing", "services", "agri-allied"]:
            issues.append(f"Sector '{sector}' may not be eligible")
        
        return {
            "eligible": len(issues) == 0,
            "issues": issues,
            "repayment_period": f"{scheme['repayment_period_years']} years",
            "moratorium": f"{scheme['moratorium_months']} months",
            "composite_loan": "Yes (term loan + working capital)",
        }
    
    def get_scheme_summary(self, scheme_name: str) -> Dict[str, Any]:
        """Get detailed information about a specific scheme."""
        scheme_name_upper = scheme_name.upper()
        if scheme_name_upper in self.SCHEMES:
            return {"found": True, "scheme": self.SCHEMES[scheme_name_upper]}
        return {"found": False, "available_schemes": list(self.SCHEMES.keys())}


class MSMEFinancialAnalyst:
    """
    Agent for calculating CMA-standard financial ratios for bank loan applications.
    Calculates: DSCR, Current Ratio, Quick Ratio, and projected cash flows.
    """
    
    def calculate_dscr(
        self,
        net_operating_income: float,
        annual_interest: float,
        annual_principal: float,
    ) -> Dict[str, Any]:
        """
        Calculate Debt Service Coverage Ratio.
        
        DSCR = Net Operating Income / (Interest + Principal)
        Banks typically require DSCR >= 1.5
        """
        total_debt_service = annual_interest + annual_principal
        if total_debt_service == 0:
            return {"dscr": float('inf'), "status": "No debt obligations", "bankable": True}
        
        dscr = net_operating_income / total_debt_service
        
        if dscr >= 2.0:
            status = "Excellent - Strong debt repayment capacity"
            bankable = True
        elif dscr >= 1.5:
            status = "Good - Meets typical bank requirements"
            bankable = True
        elif dscr >= 1.25:
            status = "Marginal - May require additional collateral"
            bankable = True
        elif dscr >= 1.0:
            status = "Weak - High risk of default"
            bankable = False
        else:
            status = "Critical - Insufficient cash flow for debt service"
            bankable = False
        
        return {
            "dscr": round(dscr, 2),
            "status": status,
            "bankable": bankable,
            "net_operating_income": net_operating_income,
            "total_debt_service": total_debt_service,
            "minimum_recommended": 1.5,
        }
    
    def calculate_current_ratio(
        self,
        current_assets: float,
        current_liabilities: float,
    ) -> Dict[str, Any]:
        """
        Calculate Current Ratio for liquidity assessment.
        
        Current Ratio = Current Assets / Current Liabilities
        Banks prefer >= 1.33 (1.33:1)
        """
        if current_liabilities == 0:
            return {"current_ratio": float('inf'), "status": "No current liabilities"}
        
        ratio = current_assets / current_liabilities
        
        if ratio >= 2.0:
            status = "Very Strong - Excellent liquidity"
        elif ratio >= 1.5:
            status = "Strong - Good liquidity position"
        elif ratio >= 1.33:
            status = "Acceptable - Meets minimum bank standards"
        elif ratio >= 1.0:
            status = "Weak - May struggle with short-term obligations"
        else:
            status = "Critical - Negative working capital"
        
        return {
            "current_ratio": round(ratio, 2),
            "status": status,
            "recommended_minimum": 1.33,
        }
    
    def calculate_quick_ratio(
        self,
        current_assets: float,
        inventory: float,
        current_liabilities: float,
    ) -> Dict[str, Any]:
        """
        Calculate Quick Ratio (Acid Test).
        
        Quick Ratio = (Current Assets - Inventory) / Current Liabilities
        """
        if current_liabilities == 0:
            return {"quick_ratio": float('inf'), "status": "No current liabilities"}
        
        ratio = (current_assets - inventory) / current_liabilities
        
        if ratio >= 1.0:
            status = "Strong - Can meet obligations without selling inventory"
        elif ratio >= 0.75:
            status = "Acceptable - Adequate quick liquidity"
        else:
            status = "Weak - May need to liquidate inventory for obligations"
        
        return {"quick_ratio": round(ratio, 2), "status": status}
    
    def calculate_tam_sam_som(
        self,
        total_potential_customers: int,
        average_revenue_per_user: float,
        geographic_accessibility_pct: float,
        feature_accessibility_pct: float,
        operational_capacity_pct: float,
        competitive_edge_pct: float,
    ) -> Dict[str, Any]:
        """
        Calculate TAM/SAM/SOM market sizing.
        
        TAM = Total Addressable Market
        SAM = Serviceable Addressable Market
        SOM = Serviceable Obtainable Market
        """
        tam = total_potential_customers * average_revenue_per_user
        
        # SAM = TAM × (Geographic + Feature Accessibility %)
        sam = tam * (geographic_accessibility_pct / 100) * (feature_accessibility_pct / 100)
        
        # SOM = SAM × Operational Capacity × Competitive Edge
        som = sam * (operational_capacity_pct / 100) * (competitive_edge_pct / 100)
        
        return {
            "TAM": {
                "value": round(tam, 2),
                "description": "Total potential revenue if 100% market share achieved",
            },
            "SAM": {
                "value": round(sam, 2),
                "description": "Segment reachable with current products/geography",
            },
            "SOM": {
                "value": round(som, 2),
                "description": "Practical market share capturable in short term",
            },
            "methodology": "Bottom-up calculation",
        }
    
    def project_cash_flow(
        self,
        initial_investment: float,
        annual_revenues: List[float],
        annual_costs: List[float],
        discount_rate: float = 0.12,  # 12% default
    ) -> Dict[str, Any]:
        """
        Project cash flows and calculate NPV/IRR for project viability.
        """
        if len(annual_revenues) != len(annual_costs):
            return {"error": "Revenue and cost arrays must be same length"}
        
        # Calculate annual cash flows
        cash_flows = [-initial_investment]
        for revenue, cost in zip(annual_revenues, annual_costs):
            cash_flows.append(revenue - cost)
        
        # Calculate NPV
        npv = 0
        for t, cf in enumerate(cash_flows):
            npv += cf / ((1 + discount_rate) ** t)
        
        # Simple payback period
        cumulative = 0
        payback_years = None
        for t, cf in enumerate(cash_flows):
            cumulative += cf
            if cumulative >= 0 and payback_years is None:
                payback_years = t
        
        return {
            "cash_flows": cash_flows,
            "npv": round(npv, 2),
            "npv_positive": npv > 0,
            "discount_rate": f"{discount_rate*100:.0f}%",
            "payback_period_years": payback_years,
            "recommendation": "Viable" if npv > 0 else "Not Recommended",
        }


# Singleton instances
msme_compliance_agent = MSMEComplianceAgent()
msme_financial_analyst = MSMEFinancialAnalyst()


# Singleton instance (lazy initialization)
_deep_research_agent: Optional[DeepResearchAgent] = None

def get_deep_research_agent() -> DeepResearchAgent:
    """Get or create the singleton DeepResearchAgent instance."""
    global _deep_research_agent
    if _deep_research_agent is None:
        # Import services here to avoid circular imports
        from .sarvam_service import sarvam_service
        from .web_search_service import web_search_service
        _deep_research_agent = DeepResearchAgent(
            sarvam_service=sarvam_service,
            web_search_service=web_search_service,
        )
    return _deep_research_agent
