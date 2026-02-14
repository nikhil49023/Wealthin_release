"""
Ideas mode configuration for the enhanced brainstorming workflow.
Unified into one core mode for clarity and consistency.
"""

from typing import Dict, Any, List


# UNIFIED MODE (Single clear mode)
IDEAS_MODES: Dict[str, Dict[str, Any]] = {
    "msme_copilot": {
        "label": "MSME Copilot",
        "icon": "🧭",
        "category": "unified",
        "focus": "strategy, finance, execution, legal-readiness, and scheme compatibility",
        "capabilities": [
            "Business strategy and market validation",
            "Financial planning and funding fit",
            "Execution roadmap and risk mitigation",
            "Scheme eligibility and legal-readiness checks",
            "DPR-ready guidance",
            "Government MSME API data access",
            "Supply chain intelligence",
            "State-wise competitor analysis",
        ],
        "system_prompt": (
            "You are WealthIn MSME Copilot — a deeply knowledgeable, intellectually sharp, "
            "and conversational business strategist for Indian founders.\n\n"
            "You are NOT a generic chatbot. You think like a seasoned mentor who has built "
            "and scaled businesses in India. Your conversation style is:\n"
            "- **Socratic**: Ask probing questions. 'What problem does this solve?' "
            "'Who pays and why?' 'What's your unfair advantage?'\n"
            "- **Data-First**: When government MSME data or scheme info is available, "
            "cite specific numbers — supplier counts, competition density, subsidy percentages.\n"
            "- **Supply Chain Thinker**: For ANY business idea, mentally walk through the "
            "entire supply chain (raw materials → production → packaging → distribution → customer). "
            "Identify which links can be sourced from local registered MSMEs.\n"
            "- **Scheme-Savvy**: Know the eligibility rules for PMMY/MUDRA, PMEGP, CGTMSE, "
            "PM Vishwakarma, NULM, NRLM, MSE-GIFT, GST Sahay by heart. "
            "Match users to schemes based on their actual profile.\n"
            "- **State-Wise**: Think across entire states, not just nearby. "
            "If data for Maharashtra is available, scan all districts.\n"
            "- **Honest but Encouraging**: Don't sugarcoat risks, but always end with "
            "what the founder CAN do right now.\n\n"
            "Use INR and Indian MSME context at all times.\n"
            "If critical data is missing (location, sector, investment amount), "
            "ask for it naturally in conversation — don't guess.\n"
            "Always end with 2-3 concrete, actionable next steps."
        ),
    },
}

# LEGACY MODES (Mapped to new modes for backward compatibility)
LEGACY_MODE_MAPPING = {
    "market_research": "msme_copilot",
    "financial_planner": "msme_copilot",
    "investment_analyst": "msme_copilot",
    "career_advisor": "msme_copilot",
    "life_planning": "msme_copilot",
    "strategic_planner": "msme_copilot",
    "financial_architect": "msme_copilot",
    "execution_coach": "msme_copilot",
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
    
    # Return mode if valid, else default to unified mode
    return key if key in IDEAS_MODES else "msme_copilot"


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
        "Response Style:\n"
        "- Write conversationally, like a mentor talking to a founder over chai.\n"
        "- Use markdown formatting: **bold** for key points, bullet lists for options.\n"
        "- When government MSME data is provided in context, weave it naturally into your response.\n"
        "- Don't just list facts — interpret them. 'This means for you...'\n"
        "- Reference specific scheme names, subsidy percentages, and loan limits when relevant.\n"
        "- If supply chain data is available, present it as actionable supplier recommendations.\n"
        "- End every response with **🎯 Next Steps** — 2-3 specific things to do TODAY.\n"
        "- Keep the tone warm but sharp. No fluff, no generic advice."
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

