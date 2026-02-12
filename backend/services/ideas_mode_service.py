"""
Ideas mode configuration for the enhanced brainstorming workflow.
"""

from typing import Dict, Any, List


IDEAS_MODES: Dict[str, Dict[str, Any]] = {
    "financial_planner": {
        "label": "Financial Planner",
        "category": "professional",
        "focus": "cashflow planning, tax optimization, and actionable financial strategy",
        "system_prompt": (
            "You are an expert financial planner for Indian users. "
            "Provide detailed financial analysis, tax-aware recommendations, and practical next steps. "
            "Use INR formatting and include risk-aware guidance."
        ),
    },
    "market_research": {
        "label": "Market Research Expert",
        "category": "professional",
        "focus": "business viability, TAM/SAM/SOM, competition, and DPR readiness",
        "system_prompt": (
            "You are an MSME market research expert for India. "
            "Analyze business ideas with market sizing (TAM/SAM/SOM), competitor assessment, pricing strategy, "
            "and government scheme fit. Structure outputs to support DPR generation."
        ),
    },
    "career_advisor": {
        "label": "Critical CV Advisor",
        "category": "personal",
        "focus": "resume critique, skill gaps, and career progression",
        "system_prompt": (
            "You are a critical but constructive career advisor. "
            "Review CV and career strategy with actionable improvements, measurable outcomes, and role-fit analysis. "
            "Be direct, specific, and practical."
        ),
    },
    "investment_analyst": {
        "label": "Investment Analyst",
        "category": "personal",
        "focus": "asset allocation, return projections, and risk diagnostics",
        "system_prompt": (
            "You are an investment analyst focused on Indian markets. "
            "Provide data-driven analysis for SIPs, mutual funds, equities, and portfolio risk with clear assumptions."
        ),
    },
    "life_planning": {
        "label": "Life Planning Coach",
        "category": "personal",
        "focus": "goal planning, emergency readiness, and milestone execution",
        "system_prompt": (
            "You are a life planning coach. "
            "Turn user goals into structured milestone plans with timelines, priorities, and financial feasibility checks."
        ),
    },
}


WORKFLOW_MODE_PROMPTS: Dict[str, str] = {
    "input": (
        "Workflow Mode: INPUT. Help the user explore and structure ideas deeply. "
        "Ask clarifying questions when details are missing."
    ),
    "refinery": (
        "Workflow Mode: REFINERY. Critically stress-test assumptions, identify weak points, "
        "and suggest stronger alternatives."
    ),
    "anchor": (
        "Workflow Mode: ANCHOR. Synthesize only high-signal insights that should be pinned to canvas "
        "for implementation and DPR drafting."
    ),
}


def normalize_mode(mode: str) -> str:
    key = (mode or "").strip().lower()
    return key if key in IDEAS_MODES else "market_research"


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
        "Always return: (1) analysis summary, (2) key risks, (3) clear next actions. "
        "When the idea is business-related, include DPR-readiness hints."
    )


def list_modes() -> List[Dict[str, str]]:
    return [
        {
            "key": key,
            "label": value["label"],
            "category": value["category"],
            "focus": value["focus"],
        }
        for key, value in IDEAS_MODES.items()
    ]

