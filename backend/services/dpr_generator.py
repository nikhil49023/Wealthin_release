"""
DPR Generator Service - Generates Bank-Ready Detailed Project Reports
Produces standardized PDFs from structured JSON data for MSME loan applications.
"""

import json
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, field
from datetime import datetime

# Try to import reportlab for PDF generation
try:
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch, cm
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
    from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_RIGHT
    REPORTLAB_AVAILABLE = True
except ImportError:
    REPORTLAB_AVAILABLE = False


@dataclass
class DPRSection:
    """Represents a section of the DPR."""
    title: str
    content: Dict[str, Any]
    section_number: str


class DPRGenerator:
    """
    Generates bank-ready Detailed Project Reports (DPRs) in standardized format.
    Follows RBI/MSME Ministry guidelines for project financing.
    """
    
    # Standard DPR sections as per banking norms
    DPR_STRUCTURE = {
        "executive_summary": "1. Executive Summary",
        "promoter_profile": "2. Promoter Profile & Background",
        "business_description": "3. Business Description & Market Analysis",
        "technical_aspects": "4. Technical Aspects & Production Process",
        "financial_projections": "5. Financial Projections",
        "cost_of_project": "6. Cost of Project & Means of Finance",
        "profitability": "7. Profitability & Break-Even Analysis",
        "risk_analysis": "8. Risk Analysis & Mitigation",
        "compliance": "9. Statutory Compliance & Approvals",
        "annexures": "10. Annexures",
    }
    
    def __init__(self):
        self.generated_reports: List[Dict] = []
    
    def generate_executive_summary(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Generate executive summary section."""
        return {
            "section_title": self.DPR_STRUCTURE["executive_summary"],
            "content": {
                "business_name": data.get("business_name", ""),
                "nature_of_business": data.get("nature_of_business", ""),
                "msme_category": data.get("msme_category", "Micro"),
                "project_cost": data.get("project_cost", 0),
                "loan_required": data.get("loan_required", 0),
                "promoter_contribution": data.get("promoter_contribution", 0),
                "expected_employment": data.get("expected_employment", 0),
                "projected_revenue_year1": data.get("projected_revenue_year1", 0),
                "break_even_months": data.get("break_even_months", 0),
                "dscr": data.get("dscr", 0),
            }
        }
    
    def generate_promoter_profile(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Generate promoter profile section."""
        return {
            "section_title": self.DPR_STRUCTURE["promoter_profile"],
            "content": {
                "promoter_name": data.get("promoter_name", ""),
                "qualification": data.get("qualification", ""),
                "experience_years": data.get("experience_years", 0),
                "udyam_number": data.get("udyam_number", ""),
                "pan": data.get("pan", ""),
                "aadhar": data.get("aadhar", ""),
                "gst_number": data.get("gst_number", ""),
                "address": data.get("address", ""),
                "contact": data.get("contact", ""),
            }
        }
    
    def generate_market_analysis(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Generate market analysis section with TAM/SAM/SOM."""
        return {
            "section_title": self.DPR_STRUCTURE["business_description"],
            "content": {
                "product_service_description": data.get("product_description", ""),
                "target_market": data.get("target_market", ""),
                "tam": data.get("tam", 0),
                "sam": data.get("sam", 0),
                "som": data.get("som", 0),
                "competitors": data.get("competitors", []),
                "competitive_advantage": data.get("competitive_advantage", ""),
                "pricing_strategy": data.get("pricing_strategy", ""),
                "marketing_plan": data.get("marketing_plan", ""),
            }
        }
    
    def generate_financial_projections(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Generate 5-year financial projections."""
        projections = []
        for year in range(1, 6):
            year_data = data.get(f"year_{year}", {})
            projections.append({
                "year": year,
                "revenue": year_data.get("revenue", 0),
                "operating_costs": year_data.get("operating_costs", 0),
                "gross_profit": year_data.get("gross_profit", 0),
                "depreciation": year_data.get("depreciation", 0),
                "interest": year_data.get("interest", 0),
                "net_profit": year_data.get("net_profit", 0),
                "cash_flow": year_data.get("cash_flow", 0),
            })
        
        return {
            "section_title": self.DPR_STRUCTURE["financial_projections"],
            "content": {
                "projections": projections,
                "assumptions": data.get("assumptions", []),
                "growth_rate": data.get("growth_rate", 15),
            }
        }
    
    def generate_cost_of_project(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Generate cost of project and means of finance."""
        return {
            "section_title": self.DPR_STRUCTURE["cost_of_project"],
            "content": {
                "land_building": data.get("land_building", 0),
                "plant_machinery": data.get("plant_machinery", 0),
                "furniture_fixtures": data.get("furniture_fixtures", 0),
                "preliminary_expenses": data.get("preliminary_expenses", 0),
                "working_capital_margin": data.get("working_capital_margin", 0),
                "contingency": data.get("contingency", 0),
                "total_project_cost": data.get("total_project_cost", 0),
                "means_of_finance": {
                    "term_loan": data.get("term_loan", 0),
                    "working_capital_loan": data.get("working_capital_loan", 0),
                    "subsidy": data.get("subsidy", 0),
                    "promoter_contribution": data.get("promoter_contribution", 0),
                },
            }
        }
    
    def generate_profitability_analysis(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Generate profitability and break-even analysis."""
        return {
            "section_title": self.DPR_STRUCTURE["profitability"],
            "content": {
                "dscr": data.get("dscr", 0),
                "dscr_status": "Bankable" if data.get("dscr", 0) >= 1.5 else "At Risk",
                "current_ratio": data.get("current_ratio", 0),
                "gross_profit_margin": data.get("gross_profit_margin", 0),
                "net_profit_margin": data.get("net_profit_margin", 0),
                "break_even_revenue": data.get("break_even_revenue", 0),
                "break_even_months": data.get("break_even_months", 0),
                "payback_period_years": data.get("payback_period_years", 0),
                "roe": data.get("roe", 0),
            }
        }
    
    def generate_compliance_section(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Generate statutory compliance section."""
        return {
            "section_title": self.DPR_STRUCTURE["compliance"],
            "content": {
                "udyam_registration": data.get("udyam_registration", "Applied"),
                "gst_registration": data.get("gst_registration", "Applied"),
                "trade_license": data.get("trade_license", "Pending"),
                "pollution_noc": data.get("pollution_noc", "Not Required"),
                "fire_noc": data.get("fire_noc", "Applied"),
                "labor_registration": data.get("labor_registration", "Will Apply"),
                "msme_schemes": data.get("msme_schemes", []),
            }
        }
    
    def compile_dpr(self, project_data: Dict[str, Any]) -> Dict[str, Any]:
        """Compile all sections into a complete DPR structure."""
        dpr = {
            "metadata": {
                "generated_on": datetime.now().isoformat(),
                "version": "1.0",
                "format": "Standardized Banking Format",
            },
            "sections": [
                self.generate_executive_summary(project_data.get("executive_summary", {})),
                self.generate_promoter_profile(project_data.get("promoter_profile", {})),
                self.generate_market_analysis(project_data.get("market_analysis", {})),
                self.generate_financial_projections(project_data.get("financial_projections", {})),
                self.generate_cost_of_project(project_data.get("cost_of_project", {})),
                self.generate_profitability_analysis(project_data.get("profitability", {})),
                self.generate_compliance_section(project_data.get("compliance", {})),
            ],
        }
        
        # Calculate completeness score
        total_fields = 0
        filled_fields = 0
        for section in dpr["sections"]:
            content = section.get("content", {})
            for key, value in content.items():
                if isinstance(value, dict):
                    for k, v in value.items():
                        total_fields += 1
                        if v:
                            filled_fields += 1
                else:
                    total_fields += 1
                    if value:
                        filled_fields += 1
        
        completeness = (filled_fields / total_fields * 100) if total_fields > 0 else 0
        dpr["metadata"]["completeness_pct"] = round(completeness, 1)
        dpr["metadata"]["status"] = "Ready for Submission" if completeness >= 80 else "Draft - Requires More Data"
        
        return dpr
    
    def generate_dpr_text(self, project_data: Dict[str, Any]) -> str:
        """Generate DPR as formatted text (fallback when reportlab not available)."""
        dpr = self.compile_dpr(project_data)
        
        lines = []
        lines.append("=" * 80)
        lines.append("DETAILED PROJECT REPORT (DPR)")
        lines.append("=" * 80)
        lines.append(f"Generated: {dpr['metadata']['generated_on']}")
        lines.append(f"Format: {dpr['metadata']['format']}")
        lines.append(f"Completeness: {dpr['metadata']['completeness_pct']}%")
        lines.append(f"Status: {dpr['metadata']['status']}")
        lines.append("=" * 80)
        lines.append("")
        
        for section in dpr["sections"]:
            lines.append("-" * 60)
            lines.append(section["section_title"])
            lines.append("-" * 60)
            
            content = section.get("content", {})
            for key, value in content.items():
                if isinstance(value, dict):
                    lines.append(f"\n  {key.replace('_', ' ').title()}:")
                    for k, v in value.items():
                        if isinstance(v, (int, float)) and v > 10000:
                            v = f"₹{v:,.0f}"
                        lines.append(f"    {k.replace('_', ' ').title()}: {v}")
                elif isinstance(value, list):
                    lines.append(f"\n  {key.replace('_', ' ').title()}:")
                    for item in value:
                        lines.append(f"    - {item}")
                else:
                    if isinstance(value, (int, float)) and value > 10000:
                        value = f"₹{value:,.0f}"
                    lines.append(f"  {key.replace('_', ' ').title()}: {value}")
            
            lines.append("")
        
        lines.append("=" * 80)
        lines.append("END OF DETAILED PROJECT REPORT")
        lines.append("=" * 80)
        
        return "\n".join(lines)


# Singleton instance
dpr_generator = DPRGenerator()


# ==================== TOOL API FUNCTIONS ====================

def generate_dpr(project_data: Dict[str, Any]) -> str:
    """Generate a complete DPR from project data."""
    dpr = dpr_generator.compile_dpr(project_data)
    return json.dumps({"success": True, "dpr": dpr})


def generate_dpr_text_report(project_data: Dict[str, Any]) -> str:
    """Generate DPR as formatted plain text."""
    text = dpr_generator.generate_dpr_text(project_data)
    return json.dumps({"success": True, "report_text": text})


def get_dpr_template() -> str:
    """Get empty DPR template with all required fields."""
    template = {
        "executive_summary": {
            "business_name": "",
            "nature_of_business": "",
            "msme_category": "Micro/Small/Medium",
            "project_cost": 0,
            "loan_required": 0,
            "promoter_contribution": 0,
            "expected_employment": 0,
            "projected_revenue_year1": 0,
            "break_even_months": 0,
            "dscr": 0,
        },
        "promoter_profile": {
            "promoter_name": "",
            "qualification": "",
            "experience_years": 0,
            "udyam_number": "UDYAM-XX-00-0000000",
            "pan": "",
            "gst_number": "",
            "address": "",
            "contact": "",
        },
        "market_analysis": {
            "product_description": "",
            "target_market": "",
            "tam": 0,
            "sam": 0,
            "som": 0,
            "competitors": [],
            "competitive_advantage": "",
            "pricing_strategy": "",
            "marketing_plan": "",
        },
        "financial_projections": {
            "year_1": {"revenue": 0, "operating_costs": 0, "gross_profit": 0, "net_profit": 0},
            "year_2": {"revenue": 0, "operating_costs": 0, "gross_profit": 0, "net_profit": 0},
            "year_3": {"revenue": 0, "operating_costs": 0, "gross_profit": 0, "net_profit": 0},
            "year_4": {"revenue": 0, "operating_costs": 0, "gross_profit": 0, "net_profit": 0},
            "year_5": {"revenue": 0, "operating_costs": 0, "gross_profit": 0, "net_profit": 0},
            "assumptions": [],
            "growth_rate": 15,
        },
        "cost_of_project": {
            "land_building": 0,
            "plant_machinery": 0,
            "furniture_fixtures": 0,
            "preliminary_expenses": 0,
            "working_capital_margin": 0,
            "contingency": 0,
            "total_project_cost": 0,
            "term_loan": 0,
            "working_capital_loan": 0,
            "subsidy": 0,
            "promoter_contribution": 0,
        },
        "profitability": {
            "dscr": 0,
            "current_ratio": 0,
            "gross_profit_margin": 0,
            "net_profit_margin": 0,
            "break_even_revenue": 0,
            "break_even_months": 0,
            "payback_period_years": 0,
            "roe": 0,
        },
        "compliance": {
            "udyam_registration": "Applied/Obtained",
            "gst_registration": "Applied/Obtained",
            "trade_license": "Pending/Obtained",
            "pollution_noc": "Required/Not Required/Applied",
            "fire_noc": "Required/Not Required/Applied",
            "msme_schemes": ["PMEGP", "Stand-Up India", "Mudra", "ZED"],
        },
    }
    
    return json.dumps({
        "success": True,
        "template": template,
        "sections": list(dpr_generator.DPR_STRUCTURE.keys()),
        "instructions": "Fill in the template and call generate_dpr() with the completed data.",
    })
