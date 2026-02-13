"""
Ideas mode configuration for the enhanced brainstorming workflow.
Consolidated into 3 core modes for clarity and better UX.
"""

from typing import Dict, Any, List


# CONSOLIDATED MODES (3 Core Modes)
IDEAS_MODES: Dict[str, Dict[str, Any]] = {
    "strategic_planner": {
        "label": "Strategic Planner",
        "icon": "🎯",
        "category": "business",
        "focus": "business strategy, market analysis, competitive positioning, DPR readiness",
        "capabilities": [
            "Market sizing (TAM/SAM/SOM)",
            "Competitive analysis",
            "Business model validation",
            "Go-to-market strategy",
            "DPR section generation"
        ],
        "system_prompt": (
            "You are a Strategic Business Planner specializing in Indian MSMEs and startups. "
            "Your expertise includes:\n"
            "- Market research and sizing (TAM/SAM/SOM)\n"
            "- Competitive landscape analysis\n"
            "- Business model design and validation\n"
            "- Government scheme alignment (Mudra, PMEGP, etc.)\n"
            "- DPR-ready outputs for bank loan applications\n\n"
            "Provide structured, actionable insights with:\n"
            "1. Data-backed analysis\n"
            "2. Risk assessment\n"
            "3. Clear next steps\n"
            "4. DPR-compatible sections when relevant\n\n"
            "Use INR formatting and Indian market context."
        ),
    },
    "financial_architect": {
        "label": "Financial Architect",
        "icon": "💰",
        "category": "finance",
        "focus": "financial projections, budgeting, tax optimization, funding strategies",
        "capabilities": [
            "Cash flow forecasting",
            "5-year financial projections",
            "Budget planning & optimization",
            "Tax strategy (Indian tax laws)",
            "Funding & loan structuring"
        ],
        "system_prompt": (
            "You are a Financial Architect for Indian businesses and individuals. "
            "Your expertise includes:\n"
            "- Financial modeling and 5-year projections\n"
            "- Cash flow management and forecasting\n"
            "- Tax optimization under Indian tax laws\n"
            "- Funding strategies (equity, debt, grants)\n"
            "- Budget planning and cost optimization\n\n"
            "Provide:\n"
            "1. Detailed financial breakdowns\n"
            "2. Risk-aware projections with assumptions\n"
            "3. Tax-efficient recommendations\n"
            "4. Actionable financial roadmaps\n\n"
            "Always use INR and Indian financial context. "
            "Include profitability metrics (DSCR, break-even, ROI) when relevant."
        ),
    },
    "execution_coach": {
        "label": "Execution Coach",
        "icon": "🚀",
        "category": "implementation",
        "focus": "implementation planning, milestone tracking, risk mitigation, progress monitoring",
        "capabilities": [
            "Milestone planning & timelines",
            "Risk identification & mitigation",
            "Resource allocation",
            "Progress tracking frameworks",
            "Execution roadmaps"
        ],
        "system_prompt": (
            "You are an Execution Coach focused on turning plans into reality. "
            "Your expertise includes:\n"
            "- Breaking down goals into actionable milestones\n"
            "- Creating realistic timelines with dependencies\n"
            "- Risk identification and mitigation strategies\n"
            "- Resource allocation and optimization\n"
            "- Progress tracking and KPI definition\n\n"
            "Provide:\n"
            "1. Clear milestone-based roadmaps\n"
            "2. Risk matrix with mitigation plans\n"
            "3. Resource requirements\n"
            "4. Success metrics and KPIs\n\n"
            "Be practical, specific, and accountability-focused. "
            "Structure outputs for easy progress tracking."
        ),
    },
}

# LEGACY MODES (Mapped to new modes for backward compatibility)
LEGACY_MODE_MAPPING = {
    "market_research": "strategic_planner",
    "financial_planner": "financial_architect",
    "investment_analyst": "financial_architect",
    "career_advisor": "execution_coach",
    "life_planning": "execution_coach",
}


WORKFLOW_MODE_PROMPTS: Dict[str, str] = {
    "input": (
        "Workflow Mode: INPUT. Help the user explore and structure ideas deeply. "
        "Ask clarifying questions when details are missing. "
        "Guide them toward comprehensive inputs for better analysis."
    ),
    "refinery": (
        "Workflow Mode: REFINERY. Critically stress-test assumptions, identify weak points, "
        "challenge optimistic projections, and suggest stronger alternatives. "
        "Be constructive but rigorous in finding gaps and risks."
    ),
    "anchor": (
        "Workflow Mode: ANCHOR. Synthesize only high-signal, actionable insights. "
        "Create pin-worthy content for canvas implementation and DPR drafting. "
        "Focus on concrete takeaways, not verbose analysis."
    ),
}


def normalize_mode(mode: str) -> str:
    """Normalize mode key, handling legacy modes"""
    key = (mode or "").strip().lower()
    
    # Check if it's a legacy mode
    if key in LEGACY_MODE_MAPPING:
        return LEGACY_MODE_MAPPING[key]
    
    # Return mode if valid, else default to strategic_planner
    return key if key in IDEAS_MODES else "strategic_planner"


def normalize_workflow_mode(workflow_mode: str) -> str:
    key = (workflow_mode or "").strip().lower()
    return key if key in WORKFLOW_MODE_PROMPTS else "input"


def get_system_prompt(mode: str, workflow_mode: str = "input") -> str:
    mode_key = normalize_mode(mode)
    workflow_key = normalize_workflow_mode(workflow_mode)
    mode_config = IDEAS_MODES[mode_key]
    return (
        f"{mode_config['system_prompt']}\n\n"
        f"{WORKFLOW_MODE_PROMPTS[workflow_key]}\n\n"
        "Response Structure:\n"
        "1. **Analysis Summary**: Key findings and insights\n"
        "2. **Risks & Challenges**: What could go wrong\n"
        "3. **Next Actions**: Concrete, prioritized steps\n"
        "4. **DPR Hints** (if business-related): Which DPR sections this addresses\n\n"
        "Keep responses focused, actionable, and structured for canvas pinning."
    )


def list_modes() -> List[Dict[str, Any]]:
    """List all available modes with metadata"""
    return [
        {
            "key": key,
            "label": value["label"],
            "icon": value["icon"],
            "category": value["category"],
            "focus": value["focus"],
            "capabilities": value["capabilities"],
        }
        for key, value in IDEAS_MODES.items()
    ]


def get_mode_description(mode: str) -> str:
    """Get detailed description of a mode"""
    mode_key = normalize_mode(mode)
    mode_config = IDEAS_MODES[mode_key]
    
    capabilities = "\n".join([f"  • {cap}" for cap in mode_config["capabilities"]])
    
    return (
        f"**{mode_config['label']}** {mode_config['icon']}\n"
        f"Focus: {mode_config['focus']}\n\n"
        f"Capabilities:\n{capabilities}"
    )


