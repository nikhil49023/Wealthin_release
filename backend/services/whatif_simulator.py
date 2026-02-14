"""
What-If Scenario Simulator - Sensitivity Analysis for MSME DPR
Performs DSCR sensitivity, best/worst case scenarios, and financial projections.
"""

import json
from typing import Dict, Any, List, Optional, Tuple
from dataclasses import dataclass, field


@dataclass
class ScenarioResult:
    """Result of a single scenario simulation."""
    scenario_name: str
    dscr: float
    npv: float
    break_even_months: int
    cash_runway_months: int
    risk_level: str  # "LOW", "MEDIUM", "HIGH", "CRITICAL"
    key_metrics: Dict[str, Any] = field(default_factory=dict)


class WhatIfSimulator:
    """
    Scenario simulator for MSME financial planning.
    Performs sensitivity analysis for bank loan applications.
    """
    
    # DSCR risk thresholds
    DSCR_THRESHOLDS = {
        "LOW": 2.0,       # >= 2.0 = Low risk
        "MEDIUM": 1.5,    # >= 1.5 = Medium risk
        "HIGH": 1.25,     # >= 1.25 = High risk
        "CRITICAL": 0,    # < 1.25 = Critical
    }
    
    def calculate_dscr(
        self,
        annual_revenue: float,
        operating_costs: float,
        annual_interest: float,
        annual_principal: float,
        tax_rate: float = 0.25,
    ) -> float:
        """Calculate DSCR from financial inputs."""
        ebitda = annual_revenue - operating_costs
        net_income = ebitda * (1 - tax_rate)
        debt_service = annual_interest + annual_principal
        
        if debt_service == 0:
            return float('inf')
        
        return net_income / debt_service
    
    def _get_risk_level(self, dscr: float) -> str:
        """Get risk level based on DSCR."""
        if dscr >= self.DSCR_THRESHOLDS["LOW"]:
            return "LOW"
        elif dscr >= self.DSCR_THRESHOLDS["MEDIUM"]:
            return "MEDIUM"
        elif dscr >= self.DSCR_THRESHOLDS["HIGH"]:
            return "HIGH"
        else:
            return "CRITICAL"
    
    def sensitivity_analysis(
        self,
        base_revenue: float,
        base_costs: float,
        loan_amount: float,
        interest_rate: float,
        loan_tenure_years: int,
        variables: Optional[List[str]] = None,
        variation_pct: float = 20.0,
    ) -> Dict[str, Any]:
        """
        Perform sensitivity analysis on key variables.
        
        Args:
            base_revenue: Annual revenue in INR
            base_costs: Annual operating costs in INR
            loan_amount: Total loan amount in INR
            interest_rate: Annual interest rate (e.g., 12 for 12%)
            loan_tenure_years: Loan repayment period in years
            variables: Variables to analyze (revenue, costs, interest)
            variation_pct: Percentage variation for sensitivity (default 20%)
        """
        if variables is None:
            variables = ["revenue", "costs", "interest"]
        
        # Calculate base case
        annual_interest = loan_amount * (interest_rate / 100)
        annual_principal = loan_amount / loan_tenure_years
        
        base_dscr = self.calculate_dscr(
            base_revenue, base_costs, annual_interest, annual_principal
        )
        
        results = {
            "base_case": {
                "dscr": round(base_dscr, 2),
                "risk_level": self._get_risk_level(base_dscr),
                "revenue": base_revenue,
                "costs": base_costs,
                "annual_debt_service": annual_interest + annual_principal,
            },
            "sensitivity": {},
        }
        
        # Analyze each variable
        for var in variables:
            sensitivity_data = []
            
            for pct in [-variation_pct, -variation_pct/2, 0, variation_pct/2, variation_pct]:
                factor = 1 + (pct / 100)
                
                if var == "revenue":
                    test_revenue = base_revenue * factor
                    test_costs = base_costs
                    test_interest = annual_interest
                elif var == "costs":
                    test_revenue = base_revenue
                    test_costs = base_costs * factor
                    test_interest = annual_interest
                else:  # interest
                    test_revenue = base_revenue
                    test_costs = base_costs
                    test_interest = annual_interest * factor
                
                dscr = self.calculate_dscr(
                    test_revenue, test_costs, test_interest, annual_principal
                )
                
                sensitivity_data.append({
                    "variation_pct": pct,
                    "dscr": round(dscr, 2),
                    "risk_level": self._get_risk_level(dscr),
                    "bankable": dscr >= 1.5,
                })
            
            results["sensitivity"][var] = sensitivity_data
        
        # Find break-even revenue for DSCR = 1.5
        target_dscr = 1.5
        target_ebitda = target_dscr * (annual_interest + annual_principal) / 0.75  # After-tax
        break_even_revenue = target_ebitda + base_costs
        
        results["break_even"] = {
            "minimum_revenue_for_dscr_1_5": round(break_even_revenue, 2),
            "margin_from_base": round(((base_revenue / break_even_revenue) - 1) * 100, 1),
            "interpretation": "Revenue can drop by this % before DSCR falls below 1.5",
        }
        
        return results
    
    def scenario_comparison(
        self,
        base_revenue: float,
        base_costs: float,
        loan_amount: float,
        interest_rate: float,
        loan_tenure_years: int,
    ) -> Dict[str, Any]:
        """
        Compare best/base/worst case scenarios.
        """
        annual_interest = loan_amount * (interest_rate / 100)
        annual_principal = loan_amount / loan_tenure_years
        
        scenarios = {
            "optimistic": {
                "revenue_factor": 1.25,
                "cost_factor": 0.90,
                "description": "25% higher revenue, 10% lower costs",
            },
            "base": {
                "revenue_factor": 1.0,
                "cost_factor": 1.0,
                "description": "As per DPR projections",
            },
            "conservative": {
                "revenue_factor": 0.85,
                "cost_factor": 1.10,
                "description": "15% lower revenue, 10% higher costs",
            },
            "worst_case": {
                "revenue_factor": 0.70,
                "cost_factor": 1.20,
                "description": "30% lower revenue, 20% higher costs",
            },
        }
        
        results = {}
        
        for name, params in scenarios.items():
            revenue = base_revenue * params["revenue_factor"]
            costs = base_costs * params["cost_factor"]
            
            dscr = self.calculate_dscr(
                revenue, costs, annual_interest, annual_principal
            )
            
            ebitda = revenue - costs
            net_margin = (ebitda / revenue) * 100 if revenue > 0 else 0
            
            results[name] = {
                "description": params["description"],
                "revenue": round(revenue, 2),
                "costs": round(costs, 2),
                "ebitda": round(ebitda, 2),
                "net_margin_pct": round(net_margin, 1),
                "dscr": round(dscr, 2),
                "risk_level": self._get_risk_level(dscr),
                "bankable": dscr >= 1.5,
                "recommendation": self._get_scenario_recommendation(dscr),
            }
        
        return results
    
    def _get_scenario_recommendation(self, dscr: float) -> str:
        """Get recommendation based on DSCR."""
        if dscr >= 2.0:
            return "Strong position. Likely approval with standard terms."
        elif dscr >= 1.5:
            return "Acceptable. May proceed with standard documentation."
        elif dscr >= 1.25:
            return "Marginal. Consider additional collateral or reduced loan amount."
        elif dscr >= 1.0:
            return "Risky. Suggest reducing loan amount by 20-30%."
        else:
            return "Not viable. Cash flow insufficient for debt service."
    
    def cash_runway_analysis(
        self,
        initial_cash: float,
        monthly_revenue: float,
        monthly_costs: float,
        monthly_debt_service: float,
        growth_rate_pct: float = 5.0,  # Monthly revenue growth
    ) -> Dict[str, Any]:
        """
        Analyze cash runway under different scenarios.
        """
        scenarios = []
        
        # Scenario: Normal operations
        cash = initial_cash
        month = 0
        normal_runway = 0
        cash_history = [cash]
        
        while month < 36 and cash > 0:
            month += 1
            revenue = monthly_revenue * ((1 + growth_rate_pct/100) ** month)
            cash_flow = revenue - monthly_costs - monthly_debt_service
            cash += cash_flow
            cash_history.append(round(cash, 2))
            if cash > 0:
                normal_runway = month
        
        # Scenario: 50% revenue drop for 3 months
        cash = initial_cash
        month = 0
        stress_runway = 0
        
        while month < 36 and cash > 0:
            month += 1
            if month <= 3:
                revenue = monthly_revenue * 0.5
            else:
                revenue = monthly_revenue * ((1 + growth_rate_pct/100) ** (month - 3))
            cash_flow = revenue - monthly_costs - monthly_debt_service
            cash += cash_flow
            if cash > 0:
                stress_runway = month
        
        return {
            "normal_scenario": {
                "runway_months": normal_runway,
                "cash_history_first_12": cash_history[:13],
                "interpretation": f"Business can sustain for {normal_runway} months under normal operations",
            },
            "stress_scenario": {
                "runway_months": stress_runway,
                "scenario": "50% revenue drop for first 3 months",
                "interpretation": f"Under stress, business survives {stress_runway} months",
            },
            "recommendation": self._get_runway_recommendation(normal_runway, stress_runway),
        }
    
    def _get_runway_recommendation(self, normal: int, stress: int) -> str:
        """Get recommendation based on runway analysis."""
        if stress >= 12:
            return "Strong cash position. Business can weather significant stress."
        elif stress >= 6:
            return "Adequate buffer. Consider building 3 months additional reserves."
        elif stress >= 3:
            return "Tight margins. Recommend increasing initial working capital."
        else:
            return "High risk. Working capital is insufficient for debt servicing."


# Singleton instance
simulator = WhatIfSimulator()


# ==================== TOOL API FUNCTIONS ====================

def run_sensitivity_analysis(
    base_revenue: float,
    base_costs: float,
    loan_amount: float,
    interest_rate: float = 12.0,
    loan_tenure_years: int = 5,
    variation_pct: float = 20.0,
) -> str:
    """Run DSCR sensitivity analysis."""
    result = simulator.sensitivity_analysis(
        base_revenue=base_revenue,
        base_costs=base_costs,
        loan_amount=loan_amount,
        interest_rate=interest_rate,
        loan_tenure_years=loan_tenure_years,
        variation_pct=variation_pct,
    )
    return json.dumps({"success": True, **result})


def run_scenario_comparison(
    base_revenue: float,
    base_costs: float,
    loan_amount: float,
    interest_rate: float = 12.0,
    loan_tenure_years: int = 5,
) -> str:
    """Compare best/base/worst case scenarios."""
    result = simulator.scenario_comparison(
        base_revenue=base_revenue,
        base_costs=base_costs,
        loan_amount=loan_amount,
        interest_rate=interest_rate,
        loan_tenure_years=loan_tenure_years,
    )
    return json.dumps({"success": True, "scenarios": result})


def run_cash_runway_analysis(
    initial_cash: float,
    monthly_revenue: float,
    monthly_costs: float,
    monthly_debt_service: float,
    growth_rate_pct: float = 5.0,
) -> str:
    """Analyze cash runway under normal and stress scenarios."""
    result = simulator.cash_runway_analysis(
        initial_cash=initial_cash,
        monthly_revenue=monthly_revenue,
        monthly_costs=monthly_costs,
        monthly_debt_service=monthly_debt_service,
        growth_rate_pct=growth_rate_pct,
    )
    return json.dumps({"success": True, **result})
