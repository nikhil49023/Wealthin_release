from dataclasses import dataclass
from typing import Dict, Any, Optional
import math

class FinancialCalculator:
    """
    Utility class for performing complex financial calculations.
    """

    @staticmethod
    def calculate_savings_rate(income: float, expenses: float) -> float:
        """
        Calculate savings rate percentage.
        Formula: ((Income - Expenses) / Income) * 100
        """
        if income <= 0:
            return 0.0
        return ((income - expenses) / income) * 100

    @staticmethod
    def calculate_runway(current_savings: float, monthly_expenses: float) -> float:
        """
        Calculate financial runway in months.
        Formula: Current Savings / Monthly Expenses
        """
        if monthly_expenses <= 0:
            return float('inf')  # Infinite runway if no expenses
        return current_savings / monthly_expenses

    @staticmethod
    def calculate_compound_interest(
        principal: float, 
        annual_rate: float, 
        years: int, 
        monthly_contribution: float = 0
    ) -> Dict[str, float]:
        """
        Calculate compound interest including monthly contributions.
        Returns: { 'total_amount': float, 'interest_earned': float, 'total_contributed': float }
        """
        r = annual_rate / 100
        n = 12  # Compounded monthly
        t = years
        
        # Future value of principal
        future_value_principal = principal * (1 + r/n)**(n*t)
        
        # Future value of monthly contributions
        # FV = PMT * (((1 + r/n)^(n*t) - 1) / (r/n))
        if r > 0:
            future_value_contributions = monthly_contribution * (((1 + r/n)**(n*t) - 1) / (r/n))
        else:
            future_value_contributions = monthly_contribution * n * t
            
        total_amount = future_value_principal + future_value_contributions
        total_contributed = principal + (monthly_contribution * n * t)
        interest_earned = total_amount - total_contributed
        
        return {
            "total_amount": round(total_amount, 2),
            "interest_earned": round(interest_earned, 2),
            "total_contributed": round(total_contributed, 2)
        }

    @staticmethod
    def calculate_per_capita_income(total_income: float, family_size: int) -> float:
        """
        Calculate Per Capita Income (Income per family member).
        """
        if family_size <= 0:
            return 0.0
        return total_income / family_size

    @staticmethod
    def calculate_loan_emi(principal: float, annual_rate: float, tenure_years: float) -> float:
        """
        Calculate Monthly EMI for a loan.
        Formula: E = P * r * (1+r)^n / ((1+r)^n - 1)
        """
        if principal <= 0 or tenure_years <= 0:
            return 0.0
        if annual_rate <= 0:
            return principal / (tenure_years * 12)
            
        r = annual_rate / (12 * 100)  # Monthly rate
        n = tenure_years * 12         # Total months
        
        emi = principal * r * ((1 + r)**n) / (((1 + r)**n) - 1)
        return round(emi, 2)

    @staticmethod
    def calculate_fire_number(annual_expenses: float, withdrawal_rate: float = 4.0) -> float:
        """
        Calculate FIRE (Financial Independence, Retire Early) number.
        Target corpus needed to sustain annual expenses indefinitely.
        Formula: Annual Expenses * (100 / Withdrawal Rate) (Default 25x rule)
        """
        if withdrawal_rate <= 0:
            return float('inf')
        return annual_expenses * (100 / withdrawal_rate)

    @staticmethod
    def calculate_emergency_fund_status(
        current_savings: float, 
        monthly_expenses: float, 
        target_months: int = 6
    ) -> Dict[str, Any]:
        """
        Evaluate Emergency Fund status.
        """
        target_amount = monthly_expenses * target_months
        if target_amount == 0:
             return {"status": "Complete", "percentage": 100, "shortfall": 0}
             
        percent_complete = (current_savings / target_amount) * 100
        shortfall = max(0, target_amount - current_savings)
        
        status = "Critical"
        if percent_complete >= 100:
            status = "Excellent"
        elif percent_complete >= 80:
            status = "Good"
        elif percent_complete >= 50:
            status = "Fair"
        elif percent_complete >= 20:
            status = "Poor"
            
        return {
            "target_amount": target_amount,
            "current_amount": current_savings,
            "shortfall": shortfall,
            "percentage": round(percent_complete, 1),
            "health_status": status,
            "months_covered": round(current_savings / monthly_expenses, 1) if monthly_expenses > 0 else 0
        }
