"""
Investment Calculator Service
Provides financial calculations for Indian investors:
- SIP (Systematic Investment Plan)
- FD (Fixed Deposit)
- EMI (Equated Monthly Installment)
- RD (Recurring Deposit)
- Lumpsum Investment
- CAGR (Compound Annual Growth Rate)
"""

from dataclasses import dataclass
from typing import Optional
import math


@dataclass
class SIPResult:
    monthly_investment: float
    duration_months: int
    expected_rate: float
    total_invested: float
    future_value: float
    wealth_gained: float


@dataclass
class FDResult:
    principal: float
    rate: float
    tenure_months: int
    maturity_amount: float
    interest_earned: float
    effective_annual_rate: float


@dataclass
class EMIResult:
    principal: float
    rate: float
    tenure_months: int
    emi: float
    total_payment: float
    total_interest: float
    amortization_schedule: list


@dataclass
class RDResult:
    monthly_deposit: float
    rate: float
    tenure_months: int
    maturity_amount: float
    total_deposited: float
    interest_earned: float


class InvestmentCalculator:
    """
    Financial calculators for common Indian investment instruments.
    """
    
    @staticmethod
    def calculate_sip(
        monthly_investment: float,
        expected_rate: float,  # Annual rate in percentage
        duration_months: int
    ) -> SIPResult:
        """
        Calculate SIP returns using compound interest formula.
        Formula: FV = P × ((1+r)^n - 1) / r × (1+r)
        Where:
        - P = Monthly investment
        - r = Monthly interest rate (annual rate / 12 / 100)
        - n = Number of months
        """
        monthly_rate = expected_rate / 12 / 100
        
        if monthly_rate == 0:
            future_value = monthly_investment * duration_months
        else:
            future_value = monthly_investment * (
                ((1 + monthly_rate) ** duration_months - 1) / monthly_rate
            ) * (1 + monthly_rate)
        
        total_invested = monthly_investment * duration_months
        wealth_gained = future_value - total_invested
        
        return SIPResult(
            monthly_investment=monthly_investment,
            duration_months=duration_months,
            expected_rate=expected_rate,
            total_invested=round(total_invested, 2),
            future_value=round(future_value, 2),
            wealth_gained=round(wealth_gained, 2)
        )
    
    @staticmethod
    def calculate_fd(
        principal: float,
        rate: float,  # Annual rate in percentage
        tenure_months: int,
        compounding: str = "quarterly"  # quarterly, monthly, yearly
    ) -> FDResult:
        """
        Calculate Fixed Deposit maturity amount with compound interest.
        Formula: A = P × (1 + r/n)^(n×t)
        Where:
        - P = Principal
        - r = Annual rate / 100
        - n = Compounding frequency per year
        - t = Time in years
        """
        compounding_freq = {
            "monthly": 12,
            "quarterly": 4,
            "half-yearly": 2,
            "yearly": 1
        }
        n = compounding_freq.get(compounding, 4)
        
        r = rate / 100
        t = tenure_months / 12
        
        maturity_amount = principal * ((1 + r/n) ** (n * t))
        interest_earned = maturity_amount - principal
        
        # Effective annual rate
        effective_rate = ((1 + r/n) ** n - 1) * 100
        
        return FDResult(
            principal=principal,
            rate=rate,
            tenure_months=tenure_months,
            maturity_amount=round(maturity_amount, 2),
            interest_earned=round(interest_earned, 2),
            effective_annual_rate=round(effective_rate, 2)
        )
    
    @staticmethod
    def calculate_emi(
        principal: float,
        rate: float,  # Annual rate in percentage
        tenure_months: int,
        include_amortization: bool = False
    ) -> EMIResult:
        """
        Calculate EMI using reducing balance method.
        Formula: EMI = P × r × (1+r)^n / ((1+r)^n - 1)
        Where:
        - P = Principal loan amount
        - r = Monthly interest rate
        - n = Loan tenure in months
        """
        monthly_rate = rate / 12 / 100
        
        if monthly_rate == 0:
            emi = principal / tenure_months
        else:
            emi = principal * monthly_rate * ((1 + monthly_rate) ** tenure_months) / \
                  (((1 + monthly_rate) ** tenure_months) - 1)
        
        total_payment = emi * tenure_months
        total_interest = total_payment - principal
        
        # Amortization schedule
        amortization = []
        if include_amortization:
            balance = principal
            for month in range(1, tenure_months + 1):
                interest_payment = balance * monthly_rate
                principal_payment = emi - interest_payment
                balance -= principal_payment
                amortization.append({
                    "month": month,
                    "emi": round(emi, 2),
                    "principal": round(principal_payment, 2),
                    "interest": round(interest_payment, 2),
                    "balance": round(max(0, balance), 2)
                })
        
        return EMIResult(
            principal=principal,
            rate=rate,
            tenure_months=tenure_months,
            emi=round(emi, 2),
            total_payment=round(total_payment, 2),
            total_interest=round(total_interest, 2),
            amortization_schedule=amortization
        )
    
    @staticmethod
    def calculate_rd(
        monthly_deposit: float,
        rate: float,  # Annual rate in percentage
        tenure_months: int
    ) -> RDResult:
        """
        Calculate RD maturity amount.
        Uses quarterly compounding as per Indian banks.
        """
        quarterly_rate = rate / 4 / 100
        n_quarters = tenure_months / 3
        
        # RD calculation with quarterly compounding
        maturity_amount = 0
        for month in range(tenure_months):
            remaining_quarters = (tenure_months - month) / 3
            amount = monthly_deposit * ((1 + quarterly_rate) ** remaining_quarters)
            maturity_amount += amount
        
        total_deposited = monthly_deposit * tenure_months
        interest_earned = maturity_amount - total_deposited
        
        return RDResult(
            monthly_deposit=monthly_deposit,
            rate=rate,
            tenure_months=tenure_months,
            maturity_amount=round(maturity_amount, 2),
            total_deposited=round(total_deposited, 2),
            interest_earned=round(interest_earned, 2)
        )
    
    @staticmethod
    def calculate_lumpsum(
        principal: float,
        rate: float,  # Annual rate in percentage
        duration_years: int
    ) -> dict:
        """
        Calculate lumpsum investment returns.
        Simple compound interest calculation.
        """
        r = rate / 100
        future_value = principal * ((1 + r) ** duration_years)
        returns = future_value - principal
        
        return {
            "principal": principal,
            "rate": rate,
            "duration_years": duration_years,
            "future_value": round(future_value, 2),
            "total_returns": round(returns, 2),
            "cagr": rate  # For lumpsum, CAGR equals the rate
        }
    
    @staticmethod
    def calculate_cagr(
        initial_value: float,
        final_value: float,
        years: float
    ) -> float:
        """
        Calculate Compound Annual Growth Rate.
        CAGR = (FV/PV)^(1/n) - 1
        """
        if initial_value <= 0 or years <= 0:
            return 0.0
        
        cagr = ((final_value / initial_value) ** (1 / years) - 1) * 100
        return round(cagr, 2)
    
    @staticmethod
    def calculate_goal_sip(
        target_amount: float,
        duration_months: int,
        expected_rate: float  # Annual rate in percentage
    ) -> float:
        """
        Reverse SIP calculation: How much to invest monthly to reach a goal.
        """
        monthly_rate = expected_rate / 12 / 100
        
        if monthly_rate == 0:
            return round(target_amount / duration_months, 2)
        
        # Reverse of SIP formula
        monthly_investment = target_amount / (
            (((1 + monthly_rate) ** duration_months - 1) / monthly_rate) * (1 + monthly_rate)
        )
        
        return round(monthly_investment, 2)


# Singleton instance
investment_calculator = InvestmentCalculator()
