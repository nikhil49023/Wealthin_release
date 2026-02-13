"""
DPR Milestone Scoring Service
Calculates completeness and quality scores for DPR sections
"""

from typing import Dict, Any, List, Tuple
from datetime import datetime
import json


class DPRMilestoneScorer:
    """
    Scores DPR completeness and quality based on section-wise milestones
    """

    # Section weights (total = 100)
    SECTION_WEIGHTS = {
        "executive_summary": 15,
        "promoter_profile": 10,
        "market_analysis": 20,
        "technical_aspects": 10,
        "financial_projections": 20,
        "cost_of_project": 10,
        "profitability": 10,
        "risk_analysis": 3,
        "compliance": 2,
    }

    # Mandatory fields per section with point values
    SECTION_CRITERIA = {
        "executive_summary": {
            "business_name": 2,
            "nature_of_business": 2,
            "msme_category": 1,
            "project_cost": 3,
            "loan_required": 3,
            "promoter_contribution": 2,
            "expected_employment": 1,
            "projected_revenue_year1": 2,
            "break_even_months": 2,
            "dscr": 2,
        },
        "promoter_profile": {
            "promoter_name": 2,
            "qualification": 2,
            "experience_years": 2,
            "udyam_number": 2,
            "pan": 1,
            "gst_number": 1,
        },
        "market_analysis": {
            "product_description": 3,
            "target_market": 3,
            "tam": 3,
            "sam": 3,
            "som": 3,
            "competitors": 2,
            "competitive_advantage": 3,
        },
        "technical_aspects": {
            "production_process": 3,
            "technology_required": 2,
            "quality_standards": 2,
            "capacity": 2,
            "implementation_timeline": 1,
        },
        "financial_projections": {
            "year_1": 4,
            "year_2": 4,
            "year_3": 4,
            "year_4": 4,
            "year_5": 4,
        },
        "cost_of_project": {
            "land_building": 1,
            "plant_machinery": 2,
            "working_capital_margin": 2,
            "total_project_cost": 3,
            "term_loan": 2,
        },
        "profitability": {
            "dscr": 3,
            "current_ratio": 2,
            "break_even_point": 3,
            "payback_period": 2,
        },
        "risk_analysis": {
            "market_risks": 1,
            "operational_risks": 1,
            "mitigation_strategies": 1,
        },
        "compliance": {
            "business_registration": 1,
            "required_licenses": 1,
        },
    }

    def calculate_section_score(
        self, section_name: str, section_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Calculate completeness score for a single section
        
        Returns:
            {
                'section_name': str,
                'score': float (0-100),
                'weight': int,
                'weighted_score': float,
                'missing_fields': List[str],
                'status': str,
                'recommendation': str
            }
        """
        if section_name not in self.SECTION_CRITERIA:
            return {"error": f"Unknown section: {section_name}"}

        criteria = self.SECTION_CRITERIA[section_name]
        total_points = sum(criteria.values())
        earned_points = 0
        missing_fields = []

        for field, points in criteria.items():
            value = section_data.get(field)
            
            # Check if field has meaningful data
            if self._is_field_complete(value):
                earned_points += points
            else:
                missing_fields.append(field)

        # Calculate section score (0-100)
        score = (earned_points / total_points * 100) if total_points > 0 else 0
        
        # Calculate weighted contribution to overall DPR score
        weight = self.SECTION_WEIGHTS.get(section_name, 0)
        weighted_score = (score * weight) / 100

        # Determine status
        status = self._get_section_status(score)
        
        # Generate recommendation
        recommendation = self._get_section_recommendation(score, missing_fields)

        return {
            "section_name": section_name,
            "score": round(score, 1),
            "weight": weight,
            "weighted_score": round(weighted_score, 1),
            "earned_points": earned_points,
            "total_points": total_points,
            "missing_fields": missing_fields,
            "status": status,
            "recommendation": recommendation,
        }

    def calculate_overall_score(
        self, dpr_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Calculate overall DPR completeness score
        
        Returns:
            {
                'overall_score': float (0-100),
                'sections': List[section_scores],
                'completed_sections': int,
                'total_sections': int,
                'readiness': str,
                'next_steps': List[str]
            }
        """
        section_scores = []
        total_weighted_score = 0
        completed_sections = 0

        for section_name in self.SECTION_CRITERIA.keys():
            section_data = dpr_data.get(section_name, {})
            section_score = self.calculate_section_score(section_name, section_data)
            section_scores.append(section_score)
            
            total_weighted_score += section_score.get("weighted_score", 0)
            
            if section_score.get("score", 0) >= 70:
                completed_sections += 1

        overall_score = total_weighted_score
        total_sections = len(self.SECTION_CRITERIA)
        
        # Determine bank-readiness
        readiness = self._get_readiness_status(overall_score)
        
        # Generate next steps
        next_steps = self._get_next_steps(section_scores, overall_score)

        return {
            "overall_score": round(overall_score, 1),
            "sections": section_scores,
            "completed_sections": completed_sections,
            "total_sections": total_sections,
            "readiness": readiness,
            "next_steps": next_steps,
            "evaluated_at": datetime.now().isoformat(),
        }

    def _is_field_complete(self, value: Any) -> bool:
        """Check if a field has meaningful data"""
        if value is None:
            return False
        if isinstance(value, str):
            return len(value.strip()) > 0 and value.strip().lower() not in ["", "n/a", "na", "not applicable", "tbd", "to be determined"]
        if isinstance(value, (int, float)):
            return value > 0
        if isinstance(value, list):
            return len(value) > 0
        if isinstance(value, dict):
            # For nested dicts (like year_1, year_2), check if any field is filled
            return any(self._is_field_complete(v) for v in value.values())
        return True

    def _get_section_status(self, score: float) -> str:
        """Determine section completion status"""
        if score >= 90:
            return "Excellent"
        elif score >= 70:
            return "Complete"
        elif score >= 50:
            return "Needs Improvement"
        elif score >= 25:
            return "Incomplete"
        else:
            return "Not Started"

    def _get_section_recommendation(self, score: float, missing_fields: List[str]) -> str:
        """Generate recommendation for section"""
        if score >= 90:
            return "Section is bank-ready. No action needed."
        elif score >= 70:
            return f"Good progress. Consider adding: {', '.join(missing_fields[:3])}"
        elif score >= 50:
            return f"Add critical fields: {', '.join(missing_fields[:5])}"
        else:
            return f"Section needs completion. Focus on: {', '.join(missing_fields[:3])}"

    def _get_readiness_status(self, overall_score: float) -> str:
        """Determine overall bank-readiness"""
        if overall_score >= 85:
            return "Bank-Ready - Submit for loan approval"
        elif overall_score >= 70:
            return "Nearly Ready - Minor improvements needed"
        elif overall_score >= 50:
            return "Draft Stage - Significant work required"
        elif overall_score >= 25:
            return "Early Draft - Complete critical sections"
        else:
            return "Not Started - Begin with Executive Summary"

    def _get_next_steps(self, section_scores: List[Dict], overall_score: float) -> List[str]:
        """Generate prioritized next steps"""
        next_steps = []

        # Find incomplete high-weight sections
        incomplete_sections = [
            s for s in section_scores 
            if s.get("score", 0) < 70
        ]
        
        # Sort by weight (descending)
        incomplete_sections.sort(key=lambda s: s.get("weight", 0), reverse=True)

        if overall_score < 50:
            next_steps.append("Complete Executive Summary and Market Analysis (40% of total score)")
        
        if incomplete_sections:
            top_section = incomplete_sections[0]
            next_steps.append(
                f"Focus on {top_section['section_name'].replace('_', ' ').title()} "
                f"({top_section['weight']}% weight, currently {top_section['score']}% complete)"
            )

        if overall_score >= 70:
            next_steps.append("Review all sections for consistency")
            next_steps.append("Add financial assumptions and justifications")
            next_steps.append("Prepare supporting documents (licenses, quotes, etc.)")

        if not next_steps:
            next_steps.append("DPR is ready! Generate PDF and review before submission.")

        return next_steps[:5]  # Return top 5 steps


# Singleton instance
dpr_scorer = DPRMilestoneScorer()
