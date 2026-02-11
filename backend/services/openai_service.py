from openai import OpenAI
from typing import List, Dict, Optional
import os
from dotenv import load_dotenv
from .lightweight_rag import rag  # Use lightweight RAG
import logging
import json

load_dotenv()
logger = logging.getLogger(__name__)

class OpenAIService:
    """OpenAI service with lightweight RAG integration"""
    
    def __init__(self):
        self.api_key = os.getenv("OPENAI_API_KEY")
        self.client = None
        if self.api_key:
            self.client = OpenAI(api_key=self.api_key)
        else:
            logger.warning("OPENAI_API_KEY not found. OpenAI service will not work.")
            
        self.rag = rag
        
        # System prompt
        self.system_prompt = """You are an expert Chartered Accountant (CA) and financial advisor specializing in Indian taxation, investments, and financial planning.

You have comprehensive knowledge of:
- Income Tax Act 1961 and all recent amendments
- GST framework and compliance requirements
- Section-wise deductions (80C, 80D, 80G, 80TTA, etc.)
- Old vs New tax regime comparison for FY 2024-25
- ITR form selection (ITR-1 to ITR-7)
- Tax-saving instruments (ELSS, PPF, NPS, SCSS, etc.)

Current Financial Year: 2024-25
Assessment Year: 2025-26

Always cite specific sections and add disclaimer: "This is AI-generated guidance. Consult a CA for personalized advice."
"""
    
    def chat_with_rag(
        self,
        user_query: str,
        conversation_history: List[Dict] = None,
        model: str = "gpt-4o-mini",
        use_rag: bool = True,
        max_tokens: int = 1000
    ) -> Dict:
        """
        Generate response with lightweight RAG context.
        """
        if not self.client:
            return {
                "response": "OpenAI API key is missing. Please configure it in .env file.",
                "sources": [],
                "model_used": "none",
                "tokens_used": 0
            }

        messages = [{"role": "system", "content": self.system_prompt}]
        
        if conversation_history:
            # Filter out metadata if present in history to keep context clean
            clean_history = []
            for msg in conversation_history:
                clean_history.append({
                    "role": msg.get("role"),
                    "content": msg.get("content")
                })
            messages.extend(clean_history)
        
        # Retrieve RAG context (fast TF-IDF search)
        rag_context = ""
        sources = []
        
        if use_rag:
            try:
                # Use hybrid search for best results
                contexts = self.rag.hybrid_search(user_query, top_k=3)
                
                if contexts:
                    rag_context = "\n\n**Relevant Knowledge Base:**\n"
                    for ctx in contexts:
                        rag_context += f"\n[{ctx['title']}]\n{ctx['content']}\n"
                        sources.append(ctx.get('doc_id', 'kb'))
                    
                    rag_context += "\nUse the above information to provide accurate, India-specific advice.\n"
            except Exception as e:
                logger.error(f"RAG search error: {e}")
        
        # Construct message
        enhanced_query = f"{rag_context}\n**User Question:** {user_query}" if rag_context else user_query
        messages.append({"role": "user", "content": enhanced_query})
        
        # Call OpenAI
        try:
            response = self.client.chat.completions.create(
                model=model,
                messages=messages,
                max_tokens=max_tokens,
                temperature=0.7
            )
            
            answer = response.choices[0].message.content
            tokens_used = response.usage.total_tokens
            
            return {
                "response": answer,
                "sources": list(set(sources)),
                "model_used": model,
                "tokens_used": tokens_used
            }
        
        except Exception as e:
            logger.error(f"OpenAI error: {e}")
            return {
                "response": f"Error: {str(e)}",
                "sources": [],
                "model_used": model,
                "tokens_used": 0
            }
    
    def generate_dpr(
        self,
        business_idea: str,
        user_data: Dict,
        market_research: str = None
    ) -> str:
        """
        Generate Detailed Project Report (DPR) using GPT-4o.
        This is a heavy reasoning task.
        """
        if not self.client:
            return "OpenAI API key is missing."

        prompt = f"""Generate a comprehensive Detailed Project Report (DPR) for the following business idea:

**Business Idea:** {business_idea}

**User Context:**
- Location: {user_data.get('location', 'India')}
- Investment Capacity: ₹{user_data.get('investment', 'Not specified')}
- Industry Experience: {user_data.get('experience', 'Not specified')}

**Market Research:**
{market_research or 'No external research provided'}

**DPR Structure Required:**
1. Executive Summary
2. Business Description & Objectives
3. Market Analysis (TAM, SAM, SOM)
4. Product/Service Details
5. Marketing & Sales Strategy
6. Operational Plan
7. Management Team Structure
8. Financial Projections (5 years)
   - Revenue Forecast
   - Break-even Analysis
   - Cash Flow Statement
   - Profit & Loss
9. Risk Analysis & Mitigation
10. Funding Requirements
11. Implementation Timeline
12. Appendices

Make it bank-ready and suitable for loan applications or investor pitches.
Include specific numbers, calculations, and India-centric insights."""

        try:
            response = self.client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": "You are a business consultant specializing in creating Detailed Project Reports (DPRs) for Indian businesses."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=4000,
                temperature=0.8
            )
            return response.choices[0].message.content
        except Exception as e:
            logger.error(f"Error generating DPR: {e}")
            return f"Failed to generate DPR: {str(e)}"

    # ==================== MUDRA DPR NARRATIVES ====================

    # Section-specific system prompts for Mudra DPR narrative generation
    MUDRA_SECTION_PROMPTS = {
        "promoter_profile": (
            "You are writing the Promoter Profile section of a Mudra Loan DPR. "
            "Translate the promoter's life skills and experience into professional strengths "
            "that demonstrate capability to run the proposed business. Highlight relevant "
            "qualifications, domain knowledge, and entrepreneurial aptitude. "
            "Write in third person, formal tone suitable for a bank loan application."
        ),
        "business_description": (
            "You are writing the Business Description section of a Mudra Loan DPR. "
            "Describe the business model, products/services, target market, and competitive "
            "advantage. Include India-specific market context and growth potential. "
            "Keep it factual and concise, suitable for bank review."
        ),
        "market_analysis": (
            "You are writing the Market Analysis section of a Mudra Loan DPR. "
            "Provide market size context, demand drivers, competition landscape, and "
            "the applicant's positioning. Use India-specific data points where possible. "
            "Focus on local/regional market dynamics relevant to MSMEs."
        ),
        "technical_aspects": (
            "You are writing the Technical/Production Process section of a Mudra Loan DPR. "
            "Describe the production or service delivery process, equipment/machinery needed, "
            "capacity planning, and quality control measures. Be specific and practical."
        ),
        "financial_projections": (
            "You are writing a narrative summary of the Financial Projections section of a "
            "Mudra Loan DPR. The actual numbers are computed deterministically and provided "
            "to you. Write a concise interpretation of the projections, highlighting key "
            "trends, profitability trajectory, and debt serviceability. Do NOT invent numbers; "
            "only reference the data provided."
        ),
        "risk_analysis": (
            "You are writing the Risk Analysis & Mitigation section of a Mudra Loan DPR. "
            "Identify 3-5 key risks (market, operational, financial, regulatory) and provide "
            "practical mitigation strategies. Be realistic but constructive."
        ),
        "executive_summary": (
            "You are writing the Executive Summary of a Mudra Loan DPR. "
            "Summarize the business proposal, key financial highlights (DSCR, IRR, break-even), "
            "Mudra category, and loan request in 2-3 concise paragraphs. "
            "This is the first thing the bank officer reads -- make it compelling."
        ),
    }

    def generate_mudra_dpr_narrative(
        self,
        section_key: str,
        calculated_data: Dict,
        user_inputs: Dict,
    ) -> str:
        """
        Generate AI narrative for a specific DPR section.
        Financial numbers come from the deterministic engine (calculated_data);
        AI adds context, interpretation, and professional language.
        """
        if not self.client:
            return f"[{section_key}] OpenAI API key not configured. Narrative unavailable."

        section_prompt = self.MUDRA_SECTION_PROMPTS.get(
            section_key,
            "You are writing a section of a Mudra Loan DPR for an Indian MSME. "
            "Write in formal, bank-ready language."
        )

        # Build context from user inputs and calculated data
        mudra_category = calculated_data.get("mudra_category_label", "Unknown")
        total_cost = calculated_data.get("total_project_cost", 0)
        loan_amount = calculated_data.get("loan_amount", 0)
        avg_dscr = calculated_data.get("average_dscr", 0)
        irr = calculated_data.get("irr", 0)

        user_prompt = f"""Generate the **{section_key.replace('_', ' ').title()}** section for this Mudra Loan DPR.

**Mudra Category:** {mudra_category}
**Total Project Cost:** ₹{total_cost:,.0f}
**Loan Amount:** ₹{loan_amount:,.0f}
**Average DSCR:** {avg_dscr}
**IRR:** {irr}%

**Promoter Details:**
- Name: {user_inputs.get('promoter_name', 'N/A')}
- Qualification: {user_inputs.get('qualification', 'N/A')}
- Experience: {user_inputs.get('experience_years', 0)} years
- Life Skills: {', '.join(user_inputs.get('life_skills', []))}
- Location: {user_inputs.get('city', '')}, {user_inputs.get('state', '')}

**Business Details:**
- Name: {user_inputs.get('business_name', 'N/A')}
- Nature: {user_inputs.get('nature_of_business', 'N/A')}
- Product/Service: {user_inputs.get('product_or_service', 'N/A')}
- Target Customers: {user_inputs.get('target_customers', 'N/A')}
- Constitution: {user_inputs.get('constitution', 'Proprietorship')}

**Financial Highlights (computed):**
{json.dumps({k: v for k, v in calculated_data.items() if k in ['break_even_month', 'break_even_revenue', 'emi', 'is_bankable', 'recommendation', 'dscr_per_year']}, indent=2, default=str)}

Write 2-4 paragraphs. Be specific, professional, and bank-ready. Do not invent financial numbers beyond what is provided."""

        try:
            response = self.client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": section_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                max_tokens=1000,
                temperature=0.7,
            )
            return response.choices[0].message.content
        except Exception as e:
            logger.error(f"Error generating Mudra DPR narrative for {section_key}: {e}")
            return f"[{section_key}] Narrative generation failed: {str(e)}"


openai_service = OpenAIService()
