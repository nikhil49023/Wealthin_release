"""
OpenAI Brainstorming Service for WealthIn
Uses GPT-4o with web search tool for interactive business ideation.
"""

import os
import json
import logging
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, asdict
from datetime import datetime

try:
    from openai import AsyncOpenAI
    _HAS_OPENAI = True
except ImportError:
    _HAS_OPENAI = False
    AsyncOpenAI = None

from .web_search_service import web_search_service, SearchResult

logger = logging.getLogger(__name__)


@dataclass
class BrainstormMessage:
    role: str  # 'user', 'assistant', 'system'
    content: str
    timestamp: str = ""
    sources: List[Dict] = None
    
    def __post_init__(self):
        if not self.timestamp:
            self.timestamp = datetime.utcnow().isoformat()
        if self.sources is None:
            self.sources = []


class OpenAIBrainstormService:
    """
    Interactive brainstorming service powered by OpenAI GPT-4o.
    Supports web search, thinking hats (personas), and reverse brainstorming.

    Psychological Framework:
    - Input (Chat): Free association, raw thoughts
    - Refinery (Critique): Reverse brainstorming, find flaws
    - Anchor (Canvas): Survivors, externalized memory
    """

    # Default persona
    SYSTEM_PROMPT_NEUTRAL = """You are WealthIn AI, a business consultant specializing in Indian markets.

Your role is to help entrepreneurs with:
- Business idea validation and refinement
- Market analysis and competitor research
- Financial planning and budgeting strategies
- Government schemes (PMEGP, MUDRA, Startup India)
- Legal and compliance guidance for Indian businesses

Guidelines:
1. Always provide actionable advice with specific next steps
2. Include clickable markdown links when referencing resources: [Title](URL)
3. Format currency in Indian Rupees (₹) with lakhs/crores notation
4. Reference current government schemes and benefits when applicable
5. End responses with 1-2 follow-up questions to deepen the conversation
6. Keep responses concise but comprehensive (max 400 words)
7. Use bullet points and headers for readability

When web search results are provided, integrate them naturally with proper attribution."""

    # Thinking Hats - Different personas for cognitive debiasing
    PERSONAS = {
        "neutral": SYSTEM_PROMPT_NEUTRAL,

        "cynical_vc": """You are a cynical venture capitalist with 20 years of experience. You've seen thousands of pitches fail.

Your mission: FIND EVERY REASON THIS IDEA MIGHT FAIL.

### BRUTAL REALITY CHECKS (Use These Frameworks):

**1. The "Death Spiral" Test**
- Cash runway: How many months until they're broke?
- Burn rate vs revenue: When does the math actually work?
- CAC payback period: Can they afford to acquire customers?

**2. The "Why Now?" Challenge**
- If this is such a great idea, why hasn't someone with more money already done it?
- What changed in the market that makes this possible NOW?
- Or is this just a me-too with no defensibility?

**3. The "Founder Reality Check"**
- Do they have domain expertise or just watched a YouTube video?
- Have they talked to 100 potential customers or just their mom?
- Can they actually execute or just pitch well?

**4. The "Unit Economics Murder"**
- Calculate real CAC (not Instagram hopes and dreams)
- What's realistic LTV? (Hint: It's probably 1/3 of what they think)
- Gross margin after REAL costs (not optimistic BS)

**5. The "Competition Crusher"**
- Who else is doing this? (Spoiler: Someone is)
- Why won't incumbents just copy this in 6 months?
- What moat exists? (Spoiler: "First mover" is NOT a moat)

**6. The "India Reality"**
- Payment collection in India is HARD (90-day payment cycles kill MSMEs)
- GST compliance nightmare (will they even understand tax filing?)
- Distribution in India = relationship-based, not tech-based

### YOUR OUTPUT FORMAT:

**⚠️ CRITICAL RISK #1: [Title]** (Severity: HIGH/MEDIUM/LOW)
- What's broken: [Specific flaw with data]
- Real example: [Similar startup that failed, with link if possible]
- Financial impact: ₹ calculations showing why this kills them
- Why this matters: [Consequence if not fixed]

**⚠️ CRITICAL RISK #2: [Title]**
[Same format]

**⚠️ CRITICAL RISK #3: [Title]**
[Same format]

---
**📊 FINANCIAL REALITY CHECK:**
- Realistic CAC: ₹[X] (not their assumption)
- Break-even point: [X] customers at ₹[Y] each
- Time to profitability: [X] months (probably never)
- Burn rate: ₹[X]/month with current assumptions

---
**SURVIVORS:**
IF they fix these issues, the idea might work:
- [Specific action item 1]
- [Specific action item 2]
- [Specific action item 3]

**VERDICT:** Fund / Pass / Maybe (with major pivots)

---
Be brutally honest. Use concrete examples. Show the math. Make them cry a little (it's for their own good).
Format currency in ₹ lakhs/crores. Include clickable links when possible.
""",

        "enthusiastic_entrepreneur": """You are an enthusiastic, creative entrepreneur who sees opportunity everywhere.

Your mission: FIND CREATIVE SOLUTIONS AND OPPORTUNITIES.

Focus on:
- Innovative pivots and unexpected markets
- Creative bootstrapping strategies
- Unconventional marketing channels for Indian markets
- How to turn weaknesses into strengths
- Inspiring success stories of similar Indian startups

Be optimistic but practical. Show how constraints breed creativity.
Format in ₹ with lakhs/crores. Include clickable links to success stories.
End with: "Here are 3 creative approaches you might not have considered:"
""",

        "risk_manager": """You are a risk management consultant focused on Indian business compliance and financial safety.

Your mission: IDENTIFY LEGAL, FINANCIAL, AND OPERATIONAL RISKS.

Focus on:
- GST, ITR, and regulatory compliance requirements
- Insurance and liability protection needs
- Labor law and employee-related risks in India
- Financial controls to prevent cash flow disasters
- Contingency planning for common failure modes

Be systematic and thorough. Use checklists.
Format in ₹ with lakhs/crores. Include links to government portals.
End with: "Critical compliance checklist you must complete:"
""",

        "customer_advocate": """You are a customer experience expert who champions the end user.

Your mission: EVALUATE FROM THE CUSTOMER'S PERSPECTIVE.

Focus on:
- Why would a customer actually choose this over alternatives?
- What pain points are truly being solved?
- Is the value proposition clear and compelling?
- Customer acquisition: where do you find these people?
- Retention: why would they come back?

Be empathetic and user-focused. Challenge founder assumptions.
Include behavioral psychology insights for Indian markets.
End with: "3 customer-centric questions to answer before launch:"
""",

        "financial_analyst": """You are a financial analyst specializing in Indian MSME businesses.

Your mission: RUN THE NUMBERS AND VALIDATE FINANCIAL VIABILITY.

Focus on:
- Break-even analysis with realistic assumptions
- Unit economics: CAC, LTV, gross margin
- Cash flow projections for first 12 months
- Burn rate and runway calculations
- Funding requirements and capital efficiency

Be data-driven. Show calculations in ₹ lakhs/crores.
Use conservative estimates. Include links to financial tools.
End with: "Financial reality check - 3 metrics you must hit:"
""",

        "systems_thinker": """You are a systems thinking expert who sees the big picture.

Your mission: MAP THE ECOSYSTEM AND IDENTIFY LEVERAGE POINTS.

Focus on:
- Network effects and feedback loops
- Dependencies and bottlenecks in the business model
- Scalability constraints and growth limits
- Strategic partnerships and ecosystem players
- Long-term sustainability and moats

Think holistically about the Indian business ecosystem.
Use frameworks (Porter's 5 Forces, Value Chain, etc.)
End with: "3 strategic leverage points for exponential growth:"
"""
    }

    def __init__(self):
        self.client = None
        self.model = "gpt-4o"
        self._initialized = False
        
    async def initialize(self):
        """Initialize OpenAI client with API key."""
        if self._initialized:
            return
            
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            logger.warning("OPENAI_API_KEY not found in environment")
            return
            
        if _HAS_OPENAI:
            self.client = AsyncOpenAI(api_key=api_key)
            self._initialized = True
            logger.info("OpenAI Brainstorm Service initialized")
        else:
            logger.warning("OpenAI package not installed")
    
    @property
    def is_available(self) -> bool:
        return self._initialized and self.client is not None
    
    async def brainstorm(
        self,
        user_message: str,
        conversation_history: List[Dict] = None,
        enable_web_search: bool = True,
        search_category: str = "general",
        persona: str = "neutral"
    ) -> BrainstormMessage:
        """
        Generate a brainstorming response with optional web search augmentation.

        Args:
            user_message: The user's question or prompt
            conversation_history: Previous messages for context
            enable_web_search: Whether to search web for current data
            search_category: Category for web search (general, schemes, stocks, etc.)
            persona: Thinking hat persona (neutral, cynical_vc, enthusiastic_entrepreneur, etc.)

        Returns:
            BrainstormMessage with response and sources
        """
        if not self.is_available:
            return BrainstormMessage(
                role="assistant",
                content="AI service is not available. Please check API configuration.",
                sources=[]
            )

        # Get persona system prompt
        system_prompt = self.PERSONAS.get(persona, self.PERSONAS["neutral"])

        # Build messages
        messages = [{"role": "system", "content": system_prompt}]
        
        # Add conversation history
        if conversation_history:
            for msg in conversation_history[-10:]:  # Last 10 messages for context
                messages.append({
                    "role": msg.get("role", "user"),
                    "content": msg.get("content", "")
                })
        
        # Web search augmentation
        sources = []
        search_context = ""
        
        if enable_web_search and web_search_service.is_available:
            try:
                results = await web_search_service.search_finance_news(
                    user_message,
                    limit=5,
                    category=search_category
                )
                
                if results:
                    sources = [asdict(r) for r in results]
                    search_context = self._format_search_results(results)
                    
            except Exception as e:
                logger.error(f"Web search failed: {e}")
        
        # Build final user message with search context
        final_message = user_message
        if search_context:
            final_message = f"""User Query: {user_message}

Web Search Results (use to provide current, accurate information):
{search_context}

Please provide a helpful response integrating the above information where relevant. Include clickable links using markdown format."""
        
        messages.append({"role": "user", "content": final_message})
        
        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                max_tokens=800,
                temperature=0.7,
            )
            
            content = response.choices[0].message.content or ""
            
            return BrainstormMessage(
                role="assistant",
                content=content,
                sources=sources
            )
            
        except Exception as e:
            logger.error(f"OpenAI API error: {e}")
            return BrainstormMessage(
                role="assistant",
                content=f"I encountered an error processing your request. Please try again.\n\nError: {str(e)}",
                sources=[]
            )
    
    def _format_search_results(self, results: List[SearchResult]) -> str:
        """Format search results for inclusion in prompt."""
        formatted = []
        for i, r in enumerate(results, 1):
            entry = f"{i}. [{r.title}]({r.url})\n   {r.snippet[:200]}..."
            if r.price_display:
                entry += f"\n   Price: {r.price_display}"
            formatted.append(entry)
        return "\n\n".join(formatted)
    
    async def generate_business_ideas(
        self,
        industry: str,
        budget: float,
        location: str = "India"
    ) -> BrainstormMessage:
        """Generate business ideas based on criteria."""
        prompt = f"""Generate 3 innovative business ideas for:
- Industry: {industry}
- Budget: ₹{budget:,.0f}
- Location: {location}

For each idea, provide:
1. Business concept (2-3 sentences)
2. Initial investment breakdown
3. Expected monthly revenue range
4. Key challenges and solutions
5. Relevant government schemes"""
        
        return await self.brainstorm(prompt, enable_web_search=True, search_category="schemes")
    
    async def analyze_competitor(self, business_type: str, region: str = "India") -> BrainstormMessage:
        """Analyze competitors in a given market."""
        prompt = f"Analyze the competitive landscape for {business_type} businesses in {region}. Include major players, market share estimates, and opportunities for differentiation."
        return await self.brainstorm(prompt, enable_web_search=True, search_category="general")

    async def reverse_brainstorm(
        self,
        ideas: List[str],
        conversation_history: List[Dict] = None
    ) -> BrainstormMessage:
        """
        REFINERY STAGE: Critique ideas to find weak points.

        Psychology: Your brain is better at spotting flaws than creating perfection.
        By attacking ideas, you generate "defensive" features that are more innovative.

        Args:
            ideas: List of ideas to critique (from chat history)
            conversation_history: Full conversation for context

        Returns:
            BrainstormMessage with critique and identified weaknesses
        """
        if not ideas:
            return BrainstormMessage(
                role="assistant",
                content="No ideas to critique. Start by brainstorming some concepts first!",
                sources=[]
            )

        ideas_text = "\n".join([f"• {idea}" for idea in ideas])

        critique_prompt = f"""You are now in CRITIQUE MODE (Reverse Brainstorming).

Ideas to critique:
{ideas_text}

Your mission: Identify the 3 weakest links that would make a user delete the app or a customer abandon the business.

For each weakness:
1. What specific problem or flaw did you spot?
2. Why is this a critical issue (with data/examples)?
3. How severe is the risk (High/Medium/Low)?
4. What would happen if this isn't fixed?

Be brutally honest. Attack assumptions. Find the holes.

End with: "SURVIVORS: Which ideas can withstand this critique if the weaknesses are addressed?"
"""

        return await self.brainstorm(
            critique_prompt,
            conversation_history=conversation_history,
            enable_web_search=False,  # No web search for critique
            persona="cynical_vc"  # Use cynical VC persona for critique
        )

    async def extract_canvas_candidates(
        self,
        conversation_history: List[Dict]
    ) -> Dict[str, Any]:
        """
        ANCHOR STAGE: Extract ideas that survived critique for canvas.

        Returns ideas formatted for canvas display with categories.
        """
        if not conversation_history or len(conversation_history) < 2:
            return {"ideas": [], "message": "No conversation history to extract from."}

        # Build summary of conversation
        history_summary = "\n\n".join([
            f"{msg.get('role', 'user').upper()}: {msg.get('content', '')[:300]}"
            for msg in conversation_history[-10:]
        ])

        extract_prompt = f"""Based on this conversation:

{history_summary}

Extract the KEY IDEAS that survived critique and should be pinned to the canvas.

For each idea, provide:
1. Title (5-10 words, actionable)
2. Category (feature/risk/opportunity/insight)
3. Summary (2-3 sentences)
4. Priority (High/Medium/Low)

Return ONLY ideas that are:
- Concrete and actionable
- Have withstood criticism
- Are worth remembering/developing further

Format as JSON:
[
  {{
    "title": "...",
    "category": "feature|risk|opportunity|insight",
    "content": "...",
    "priority": "high|medium|low"
  }}
]
"""

        response = await self.brainstorm(
            extract_prompt,
            conversation_history=None,  # Don't include history again
            enable_web_search=False,
            persona="systems_thinker"  # Use systems thinker for synthesis
        )

        # Try to parse JSON from response
        try:
            import re
            content = response.content
            # Extract JSON block
            json_match = re.search(r'```json\s*(\[.*?\])\s*```', content, re.DOTALL)
            if json_match:
                ideas = json.loads(json_match.group(1))
            else:
                # Try to find JSON array directly
                json_match = re.search(r'(\[.*\])', content, re.DOTALL)
                if json_match:
                    ideas = json.loads(json_match.group(1))
                else:
                    ideas = []

            return {"ideas": ideas, "message": "Extracted canvas candidates from conversation."}

        except Exception as e:
            logger.error(f"Failed to parse canvas candidates: {e}")
            return {"ideas": [], "message": response.content}


# Singleton instance
openai_brainstorm_service = OpenAIBrainstormService()
