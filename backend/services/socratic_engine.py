"""
Socratic Inquiry Engine - Implements 6-Type Questioning Framework
Guides MSME entrepreneurs through structured thinking for DPR preparation.

The 6 Socratic Question Types:
1. Clarification - Refine vague terminology
2. Probing Assumptions - Challenge entrenched beliefs
3. Probing Reasons/Evidence - "5 Whys" technique
4. Viewpoints/Perspectives - "Outside-in" thinking
5. Implications/Consequences - Ripple effect analysis
6. Meta-Questions - Questions about the questioning process
"""

import json
import random
from typing import Dict, Any, List, Optional
from enum import Enum
from dataclasses import dataclass, field
from datetime import datetime


class QuestionType(Enum):
    CLARIFICATION = "clarification"
    PROBING_ASSUMPTIONS = "probing_assumptions"
    PROBING_EVIDENCE = "probing_evidence"
    VIEWPOINTS = "viewpoints"
    IMPLICATIONS = "implications"
    META = "meta"


@dataclass
class SocraticQuestion:
    """Represents a single Socratic question."""
    question_type: QuestionType
    question: str
    context: str
    follow_up_hints: List[str] = field(default_factory=list)
    priority: int = 1  # 1=high, 5=low


class InquiryEngine:
    """
    Socratic Inquiry Engine for MSME brainstorming.
    Generates structured questions to help entrepreneurs think deeply about their business.
    """
    
    # Question templates per type
    TEMPLATES = {
        QuestionType.CLARIFICATION: [
            "What specific metrics define '{aspect}' in the context of your business?",
            "When you say '{aspect}', what exactly do you mean by that?",
            "Could you clarify what success looks like for '{aspect}'?",
            "How would you measure '{aspect}' in concrete terms?",
            "Can you give an example of what '{aspect}' looks like in practice?",
        ],
        QuestionType.PROBING_ASSUMPTIONS: [
            "What evidence leads you to believe that {assumption}?",
            "Have you considered what happens if {assumption} turns out to be wrong?",
            "Why do you assume {assumption}? What's the basis for this?",
            "Is it possible that {assumption} is an industry myth rather than fact?",
            "What would change your mind about {assumption}?",
        ],
        QuestionType.PROBING_EVIDENCE: [
            "Why is {factor} important to your business model?",
            "What's the root cause behind {factor}?",
            "Why do you think {factor} will work in your specific market?",
            "What data or research supports your claim about {factor}?",
            "Can you trace {factor} back to a fundamental customer need?",
        ],
        QuestionType.VIEWPOINTS: [
            "How would a large-scale competitor respond to your entry into {market}?",
            "What would a skeptical investor ask about {aspect}?",
            "How might a potential customer view {aspect}?",
            "What would a regulatory body think about {aspect}?",
            "How would your approach look from a supplier's perspective?",
        ],
        QuestionType.IMPLICATIONS: [
            "What are the financial ramifications if {scenario} happens?",
            "If {factor} fails, what's your Plan B?",
            "How would a 30-day disruption in {area} affect your operations?",
            "What are the long-term implications of {decision}?",
            "If successful, how would {aspect} scale to 10x the current volume?",
        ],
        QuestionType.META: [
            "Why is it important to define {aspect} at this stage of planning?",
            "Are we asking the right questions about {topic}?",
            "What question haven't we asked yet that we should?",
            "Is {aspect} really relevant to bank loan approval?",
            "How does clarifying {topic} help strengthen your DPR?",
        ],
    }
    
    # DPR Section-specific question prompts
    DPR_SECTIONS = {
        "market_analysis": {
            "key_aspects": ["TAM/SAM/SOM", "target customer", "competitive landscape", "pricing strategy"],
            "priority_types": [QuestionType.PROBING_EVIDENCE, QuestionType.VIEWPOINTS],
        },
        "technical_viability": {
            "key_aspects": ["production process", "machinery requirements", "raw materials", "capacity"],
            "priority_types": [QuestionType.CLARIFICATION, QuestionType.IMPLICATIONS],
        },
        "financial_projections": {
            "key_aspects": ["revenue assumptions", "cost structure", "break-even", "DSCR"],
            "priority_types": [QuestionType.PROBING_ASSUMPTIONS, QuestionType.PROBING_EVIDENCE],
        },
        "compliance": {
            "key_aspects": ["MSME registration", "GST", "environmental clearances", "labor laws"],
            "priority_types": [QuestionType.CLARIFICATION, QuestionType.IMPLICATIONS],
        },
        "risk_mitigation": {
            "key_aspects": ["supply chain risks", "market risks", "operational risks", "financial risks"],
            "priority_types": [QuestionType.IMPLICATIONS, QuestionType.VIEWPOINTS],
        },
    }
    
    def __init__(self):
        self.session_history: List[Dict[str, Any]] = []
        self.covered_types: set = set()
        self.current_section: Optional[str] = None
    
    def start_session(self, business_idea: str, initial_section: str = "market_analysis") -> Dict[str, Any]:
        """Start a new brainstorming session."""
        self.session_history = []
        self.covered_types = set()
        self.current_section = initial_section
        
        # Generate initial clarification question
        initial_question = self.generate_question(
            question_type=QuestionType.CLARIFICATION,
            context=business_idea,
            aspect="your business idea"
        )
        
        return {
            "session_started": True,
            "business_idea": business_idea,
            "current_section": initial_section,
            "initial_question": initial_question,
            "sections_to_cover": list(self.DPR_SECTIONS.keys()),
            "guidance": "Let's explore your business idea systematically. I'll ask questions to help you think through each aspect."
        }
    
    def generate_question(
        self,
        question_type: QuestionType,
        context: str,
        aspect: str = "",
        assumption: str = "",
        factor: str = "",
        scenario: str = "",
        decision: str = "",
        area: str = "",
        market: str = "",
        topic: str = "",
    ) -> SocraticQuestion:
        """Generate a question of the specified type."""
        templates = self.TEMPLATES.get(question_type, [])
        if not templates:
            templates = ["Could you elaborate on '{aspect}'?"]
        
        template = random.choice(templates)
        
        # Fill in template variables
        question_text = template.format(
            aspect=aspect or context[:50],
            assumption=assumption or f"customers want {aspect}",
            factor=factor or aspect,
            scenario=scenario or f"{aspect} doesn't work as planned",
            decision=decision or f"investing in {aspect}",
            area=area or aspect,
            market=market or "the market",
            topic=topic or aspect,
        )
        
        # Generate follow-up hints
        follow_up_hints = self._generate_follow_up_hints(question_type, aspect)
        
        question = SocraticQuestion(
            question_type=question_type,
            question=question_text,
            context=context,
            follow_up_hints=follow_up_hints,
        )
        
        # Track in session
        self.session_history.append({
            "type": question_type.value,
            "question": question_text,
            "timestamp": datetime.now().isoformat(),
        })
        self.covered_types.add(question_type)
        
        return question
    
    def _generate_follow_up_hints(self, question_type: QuestionType, aspect: str) -> List[str]:
        """Generate helpful hints for the user."""
        hints = {
            QuestionType.CLARIFICATION: [
                "Be specific with numbers and metrics",
                "Think about how this would appear in your DPR",
            ],
            QuestionType.PROBING_ASSUMPTIONS: [
                "Consider if you have data to back this up",
                "Think about what industry reports say",
            ],
            QuestionType.PROBING_EVIDENCE: [
                "Cite sources if you have them",
                "Consider primary vs secondary research",
            ],
            QuestionType.VIEWPOINTS: [
                "Think from the bank's perspective",
                "Consider what competitors would do",
            ],
            QuestionType.IMPLICATIONS: [
                "Calculate potential financial impact",
                "Think about contingency plans",
            ],
            QuestionType.META: [
                "Reflect on the overall DPR structure",
                "Consider what sections need more depth",
            ],
        }
        return hints.get(question_type, [])
    
    def process_response(self, user_response: str, current_aspect: str) -> Dict[str, Any]:
        """Process user response and generate next appropriate question."""
        # Analyze response quality (simplified)
        response_quality = self._assess_response_quality(user_response)
        
        # Determine next question type based on coverage and response
        next_type = self._determine_next_type(response_quality)
        
        # Generate next question
        next_question = self.generate_question(
            question_type=next_type,
            context=user_response,
            aspect=current_aspect,
        )
        
        return {
            "response_quality": response_quality,
            "next_question": {
                "type": next_question.question_type.value,
                "question": next_question.question,
                "hints": next_question.follow_up_hints,
            },
            "covered_types": [t.value for t in self.covered_types],
            "session_progress": len(self.session_history),
        }
    
    def _assess_response_quality(self, response: str) -> Dict[str, Any]:
        """Assess the quality of user's response."""
        word_count = len(response.split())
        has_numbers = any(char.isdigit() for char in response)
        is_detailed = word_count > 30
        
        score = 0
        feedback = []
        
        if word_count < 10:
            feedback.append("Response is quite brief. Consider adding more detail.")
        else:
            score += 25
        
        if has_numbers:
            score += 25
            feedback.append("Good use of specific data/numbers.")
        else:
            feedback.append("Consider adding specific metrics or numbers.")
        
        if is_detailed:
            score += 25
        
        if "because" in response.lower() or "since" in response.lower():
            score += 25
            feedback.append("Good reasoning provided.")
        
        return {
            "score": min(score, 100),
            "word_count": word_count,
            "has_specifics": has_numbers,
            "feedback": feedback,
        }
    
    def _determine_next_type(self, response_quality: Dict) -> QuestionType:
        """Determine the next question type based on response and coverage."""
        # If response lacks specifics, probe for evidence
        if not response_quality.get("has_specifics"):
            return QuestionType.PROBING_EVIDENCE
        
        # Ensure all types get covered
        all_types = set(QuestionType)
        uncovered = all_types - self.covered_types
        
        if uncovered:
            # Prioritize based on current section
            section_info = self.DPR_SECTIONS.get(self.current_section, {})
            priority_types = section_info.get("priority_types", [])
            
            for ptype in priority_types:
                if ptype in uncovered:
                    return ptype
            
            return random.choice(list(uncovered))
        
        # All covered, cycle through
        return random.choice(list(QuestionType))
    
    def advance_section(self) -> Dict[str, Any]:
        """Move to the next DPR section."""
        sections = list(self.DPR_SECTIONS.keys())
        
        if self.current_section in sections:
            current_idx = sections.index(self.current_section)
            if current_idx < len(sections) - 1:
                self.current_section = sections[current_idx + 1]
                self.covered_types = set()  # Reset for new section
                
                section_info = self.DPR_SECTIONS[self.current_section]
                
                return {
                    "new_section": self.current_section,
                    "key_aspects": section_info["key_aspects"],
                    "message": f"Great progress! Let's now explore {self.current_section.replace('_', ' ').title()}.",
                    "completed": False,
                }
        
        return {
            "completed": True,
            "message": "All DPR sections have been covered. Your brainstorming session is complete!",
            "sections_covered": sections,
        }
    
    def get_session_summary(self) -> Dict[str, Any]:
        """Get summary of the current brainstorming session."""
        type_counts = {}
        for entry in self.session_history:
            qtype = entry["type"]
            type_counts[qtype] = type_counts.get(qtype, 0) + 1
        
        return {
            "total_questions": len(self.session_history),
            "question_type_distribution": type_counts,
            "sections_explored": self.current_section,
            "covered_question_types": [t.value for t in self.covered_types],
            "session_history": self.session_history[-10:],  # Last 10 questions
        }


# Singleton instance
inquiry_engine = InquiryEngine()


# ==================== TOOL API FUNCTIONS ====================

def generate_socratic_question(
    business_idea: str,
    aspect: str,
    question_type: str = "clarification",
    current_section: str = "market_analysis",
) -> str:
    """Generate a Socratic question for brainstorming."""
    try:
        qtype = QuestionType(question_type.lower())
    except ValueError:
        qtype = QuestionType.CLARIFICATION
    
    inquiry_engine.current_section = current_section
    question = inquiry_engine.generate_question(
        question_type=qtype,
        context=business_idea,
        aspect=aspect,
    )
    
    return json.dumps({
        "success": True,
        "question_type": question.question_type.value,
        "question": question.question,
        "hints": question.follow_up_hints,
        "context": question.context[:100] + "..." if len(question.context) > 100 else question.context,
    })


def start_brainstorming_session(business_idea: str, section: str = "market_analysis") -> str:
    """Start a new Socratic brainstorming session."""
    result = inquiry_engine.start_session(business_idea, section)
    
    # Convert SocraticQuestion to dict
    initial_q = result["initial_question"]
    result["initial_question"] = {
        "type": initial_q.question_type.value,
        "question": initial_q.question,
        "hints": initial_q.follow_up_hints,
    }
    
    return json.dumps({"success": True, **result})


def process_brainstorm_response(user_response: str, current_aspect: str) -> str:
    """Process user response and get next Socratic question."""
    result = inquiry_engine.process_response(user_response, current_aspect)
    return json.dumps({"success": True, **result})


def get_brainstorm_summary() -> str:
    """Get summary of current brainstorming session."""
    result = inquiry_engine.get_session_summary()
    return json.dumps({"success": True, **result})
