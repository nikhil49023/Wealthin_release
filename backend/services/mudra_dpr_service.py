"""
Mudra-Compliant DPR Financial Engine
Pure Python deterministic calculations for PMMY/Mudra Loan DPR generation.
No AI dependency -- all math is computed locally.

Mudra Categories:
- SHISHU: Loans up to ₹50,000
- KISHORE: Loans from ₹50,001 to ₹5,00,000
- TARUN: Loans from ₹5,00,001 to ₹10,00,000
"""

import math
import json
from enum import Enum
from dataclasses import dataclass, field, asdict
from typing import Dict, Any, List, Optional, Tuple


# ==================== ENUMS & DATACLASSES ====================

class MudraCategory(str, Enum):
    SHISHU = "shishu"
    KISHORE = "kishore"
    TARUN = "tarun"


@dataclass
class MudraDPRInput:
    """All user inputs required to generate a Mudra-compliant DPR."""
    # Promoter details
    promoter_name: str = ""
    qualification: str = ""
    experience_years: int = 0
    life_skills: List[str] = field(default_factory=list)
    city: str = ""
    state: str = ""

    # Business details
    business_name: str = ""
    nature_of_business: str = ""
    product_or_service: str = ""
    target_customers: str = ""
    constitution: str = "Proprietorship"  # Proprietorship, Partnership, LLP, Pvt Ltd

    # Production & pricing
    selling_price_per_unit: float = 0.0
    units_at_full_capacity: float = 0.0  # per month
    raw_material_cost_per_unit: float = 0.0

    # Capital expenditure (fixed assets)
    fixed_assets: List[Dict[str, Any]] = field(default_factory=list)
    # Each item: {"name": str, "amount": float, "life_years": int}

    # Operating expenses (monthly)
    monthly_rent: float = 0.0
    monthly_wages: float = 0.0
    monthly_utilities: float = 0.0
    monthly_other_expenses: float = 0.0
    working_capital_months: int = 3

    # Finance & projections
    promoter_contribution_pct: float = 10.0  # percentage
    interest_rate: float = 12.0  # annual
    tenure_months: int = 60
    capacity_utilization_y1: float = 60.0  # percentage
    capacity_utilization_y2: float = 75.0
    capacity_utilization_y3: float = 85.0
    capacity_utilization_y4: float = 90.0
    capacity_utilization_y5: float = 95.0

    # Inflation/growth
    cost_inflation_rate: float = 5.0  # annual percentage
    tax_rate: float = 25.0  # percentage

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class ProjectedPnLYear:
    """Projected P&L for a single year."""
    year: int
    capacity_utilization: float
    units_produced: float
    revenue: float
    raw_material_cost: float
    rent: float
    wages: float
    utilities: float
    other_expenses: float
    total_operating_cost: float
    ebitda: float
    depreciation: float
    interest: float
    pbt: float  # Profit Before Tax
    tax: float
    pat: float  # Profit After Tax

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class ProjectedBalanceSheetYear:
    """Projected Balance Sheet for a single year."""
    year: int
    # Assets
    gross_fixed_assets: float
    accumulated_depreciation: float
    net_fixed_assets: float
    current_assets: float  # working capital + cash
    total_assets: float
    # Liabilities
    loan_outstanding: float
    promoter_equity: float
    retained_earnings: float
    total_liabilities: float

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class MudraDPROutput:
    """All computed results for a Mudra DPR."""
    mudra_category: str
    mudra_category_label: str

    # Project cost breakdown
    total_fixed_assets: float
    working_capital: float
    preliminary_expenses: float
    contingency: float
    total_project_cost: float

    # Means of finance
    promoter_contribution: float
    loan_amount: float
    emi: float

    # Projections
    projected_pnl: List[Dict[str, Any]]
    projected_balance_sheet: List[Dict[str, Any]]

    # Key ratios
    dscr_per_year: List[Dict[str, Any]]  # [{year, dscr, status}]
    average_dscr: float
    irr: float
    break_even_units: float
    break_even_revenue: float
    break_even_month: int

    # Summary
    is_bankable: bool
    recommendation: str

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


# ==================== CORE ENGINE ====================

class MudraDPREngine:
    """
    Deterministic financial math engine for Mudra-compliant DPRs.
    All calculations are pure Python -- zero AI dependency.
    """

    CATEGORY_LABELS = {
        MudraCategory.SHISHU: "Shishu (up to ₹50,000)",
        MudraCategory.KISHORE: "Kishore (₹50,001 - ₹5,00,000)",
        MudraCategory.TARUN: "Tarun (₹5,00,001 - ₹10,00,000)",
    }

    # Static cluster data for industrial area suggestions
    CLUSTER_DATA: Dict[str, List[Dict[str, str]]] = {
        "maharashtra": [
            {"name": "Pune IT Park", "type": "IT/Services", "city": "Pune"},
            {"name": "MIDC Ambernath", "type": "Manufacturing", "city": "Thane"},
            {"name": "Nashik Food Park", "type": "Food Processing", "city": "Nashik"},
            {"name": "Aurangabad Industrial Area", "type": "Auto Components", "city": "Aurangabad"},
        ],
        "karnataka": [
            {"name": "Peenya Industrial Area", "type": "Manufacturing", "city": "Bengaluru"},
            {"name": "Electronic City", "type": "IT/Services", "city": "Bengaluru"},
            {"name": "Hubli-Dharwad SEZ", "type": "Mixed", "city": "Hubli"},
        ],
        "tamil_nadu": [
            {"name": "SIPCOT Hosur", "type": "Auto/Manufacturing", "city": "Hosur"},
            {"name": "Tidel Park", "type": "IT/Services", "city": "Chennai"},
            {"name": "Coimbatore Industrial Estate", "type": "Textile/Engineering", "city": "Coimbatore"},
        ],
        "gujarat": [
            {"name": "Sanand Industrial Area", "type": "Auto/Manufacturing", "city": "Ahmedabad"},
            {"name": "Mundra SEZ", "type": "Export/Logistics", "city": "Kutch"},
            {"name": "GIDC Vadodara", "type": "Chemical/Pharma", "city": "Vadodara"},
        ],
        "delhi": [
            {"name": "Okhla Industrial Area", "type": "Manufacturing", "city": "Delhi"},
            {"name": "Narela Industrial Area", "type": "Mixed", "city": "Delhi"},
        ],
        "uttar_pradesh": [
            {"name": "Noida SEZ", "type": "IT/Manufacturing", "city": "Noida"},
            {"name": "Greater Noida Industrial Area", "type": "Mixed", "city": "Greater Noida"},
        ],
        "rajasthan": [
            {"name": "Sitapura Industrial Area", "type": "IT/Manufacturing", "city": "Jaipur"},
            {"name": "Bhiwadi Industrial Area", "type": "Manufacturing", "city": "Bhiwadi"},
        ],
        "telangana": [
            {"name": "HITEC City", "type": "IT/Services", "city": "Hyderabad"},
            {"name": "Patancheru Industrial Area", "type": "Pharma/Chemical", "city": "Hyderabad"},
        ],
        "west_bengal": [
            {"name": "Salt Lake Sector V", "type": "IT/Services", "city": "Kolkata"},
            {"name": "Falta SEZ", "type": "Export/Manufacturing", "city": "South 24 Parganas"},
        ],
        "kerala": [
            {"name": "Infopark Kochi", "type": "IT/Services", "city": "Kochi"},
            {"name": "Technopark", "type": "IT/Services", "city": "Thiruvananthapuram"},
        ],
    }

    # ---- Classification ----

    @staticmethod
    def classify_mudra_category(total_project_cost: float) -> MudraCategory:
        """Classify into Mudra category based on total project cost."""
        if total_project_cost <= 50000:
            return MudraCategory.SHISHU
        elif total_project_cost <= 500000:
            return MudraCategory.KISHORE
        else:
            return MudraCategory.TARUN

    # ---- Project Cost ----

    @staticmethod
    def calculate_project_cost(inputs: MudraDPRInput) -> Dict[str, float]:
        """Calculate total project cost breakdown."""
        total_fixed = sum(item.get("amount", 0) for item in inputs.fixed_assets)

        monthly_opex = (
            inputs.monthly_rent
            + inputs.monthly_wages
            + inputs.monthly_utilities
            + inputs.monthly_other_expenses
            + (inputs.raw_material_cost_per_unit * inputs.units_at_full_capacity * (inputs.capacity_utilization_y1 / 100))
        )
        working_capital = monthly_opex * inputs.working_capital_months

        subtotal = total_fixed + working_capital
        preliminary = subtotal * 0.05
        contingency = subtotal * 0.05
        total = subtotal + preliminary + contingency

        return {
            "total_fixed_assets": round(total_fixed, 2),
            "working_capital": round(working_capital, 2),
            "preliminary_expenses": round(preliminary, 2),
            "contingency": round(contingency, 2),
            "total_project_cost": round(total, 2),
        }

    # ---- Means of Finance ----

    @staticmethod
    def calculate_means_of_finance(
        total_cost: float, promoter_pct: float
    ) -> Dict[str, float]:
        """Calculate loan vs promoter contribution split."""
        promoter = total_cost * (promoter_pct / 100)
        loan = total_cost - promoter
        return {
            "promoter_contribution": round(promoter, 2),
            "loan_amount": round(loan, 2),
        }

    # ---- EMI ----

    @staticmethod
    def calculate_emi(
        principal: float, annual_rate: float, tenure_months: int
    ) -> float:
        """Reducing balance EMI calculation."""
        if principal <= 0 or tenure_months <= 0:
            return 0.0
        if annual_rate <= 0:
            return round(principal / tenure_months, 2)

        monthly_rate = annual_rate / 12 / 100
        emi = (
            principal
            * monthly_rate
            * ((1 + monthly_rate) ** tenure_months)
            / (((1 + monthly_rate) ** tenure_months) - 1)
        )
        return round(emi, 2)

    # ---- Loan Amortization Helpers ----

    @staticmethod
    def _loan_schedule(
        principal: float, annual_rate: float, tenure_months: int
    ) -> List[Dict[str, float]]:
        """Generate year-wise loan outstanding, interest, and principal repayment."""
        if principal <= 0 or tenure_months <= 0:
            return [{"year": y, "opening": 0, "interest": 0, "principal_repaid": 0, "closing": 0} for y in range(1, 6)]

        monthly_rate = annual_rate / 12 / 100 if annual_rate > 0 else 0
        emi = MudraDPREngine.calculate_emi(principal, annual_rate, tenure_months)
        balance = principal
        schedule = []

        for year in range(1, 6):
            opening = balance
            year_interest = 0.0
            year_principal = 0.0
            for _ in range(12):
                if balance <= 0:
                    break
                interest_part = balance * monthly_rate
                principal_part = min(emi - interest_part, balance)
                balance -= principal_part
                year_interest += interest_part
                year_principal += principal_part

            schedule.append({
                "year": year,
                "opening": round(opening, 2),
                "interest": round(year_interest, 2),
                "principal_repaid": round(year_principal, 2),
                "closing": round(max(0, balance), 2),
            })

        return schedule

    # ---- Depreciation ----

    @staticmethod
    def _calculate_depreciation(fixed_assets: List[Dict[str, Any]]) -> List[float]:
        """Calculate straight-line depreciation for 5 years."""
        yearly = [0.0] * 5
        for asset in fixed_assets:
            amount = asset.get("amount", 0)
            life = asset.get("life_years", 10)
            if life <= 0:
                life = 10
            annual_dep = amount / life
            for y in range(5):
                yearly[y] += annual_dep
        return [round(d, 2) for d in yearly]

    # ---- Projected P&L ----

    def generate_projected_pnl(
        self, inputs: MudraDPRInput, loan_schedule: List[Dict], years: int = 5
    ) -> List[ProjectedPnLYear]:
        """Generate 5-year projected P&L statement."""
        utilizations = [
            inputs.capacity_utilization_y1,
            inputs.capacity_utilization_y2,
            inputs.capacity_utilization_y3,
            inputs.capacity_utilization_y4,
            inputs.capacity_utilization_y5,
        ]
        depreciation_yearly = self._calculate_depreciation(inputs.fixed_assets)
        inflation = inputs.cost_inflation_rate / 100

        results = []
        for y in range(years):
            util = utilizations[y] / 100
            inflation_factor = (1 + inflation) ** y

            units = inputs.units_at_full_capacity * 12 * util
            revenue = units * inputs.selling_price_per_unit

            rm_cost = units * inputs.raw_material_cost_per_unit * inflation_factor
            rent = inputs.monthly_rent * 12 * inflation_factor
            wages = inputs.monthly_wages * 12 * inflation_factor
            utilities = inputs.monthly_utilities * 12 * inflation_factor
            other = inputs.monthly_other_expenses * 12 * inflation_factor
            total_opex = rm_cost + rent + wages + utilities + other

            ebitda = revenue - total_opex
            dep = depreciation_yearly[y]
            interest = loan_schedule[y]["interest"]
            pbt = ebitda - dep - interest
            tax = max(0, pbt * (inputs.tax_rate / 100))
            pat = pbt - tax

            results.append(ProjectedPnLYear(
                year=y + 1,
                capacity_utilization=utilizations[y],
                units_produced=round(units, 0),
                revenue=round(revenue, 2),
                raw_material_cost=round(rm_cost, 2),
                rent=round(rent, 2),
                wages=round(wages, 2),
                utilities=round(utilities, 2),
                other_expenses=round(other, 2),
                total_operating_cost=round(total_opex, 2),
                ebitda=round(ebitda, 2),
                depreciation=round(dep, 2),
                interest=round(interest, 2),
                pbt=round(pbt, 2),
                tax=round(tax, 2),
                pat=round(pat, 2),
            ))

        return results

    # ---- Projected Balance Sheet ----

    def generate_projected_balance_sheet(
        self,
        inputs: MudraDPRInput,
        pnl_data: List[ProjectedPnLYear],
        loan_schedule: List[Dict],
        project_cost: Dict[str, float],
        means: Dict[str, float],
        years: int = 5,
    ) -> List[ProjectedBalanceSheetYear]:
        """Generate 5-year projected balance sheet."""
        gross_fixed = project_cost["total_fixed_assets"]
        promoter_equity = means["promoter_contribution"]
        results = []
        cumulative_depreciation = 0.0
        cumulative_retained = 0.0

        for y in range(years):
            cumulative_depreciation += pnl_data[y].depreciation
            cumulative_retained += pnl_data[y].pat
            net_fixed = gross_fixed - cumulative_depreciation

            # Current assets: working capital + accumulated cash surplus
            current_assets = project_cost["working_capital"] + max(0, cumulative_retained)
            total_assets = net_fixed + current_assets

            loan_out = loan_schedule[y]["closing"]
            total_liabilities = loan_out + promoter_equity + cumulative_retained

            results.append(ProjectedBalanceSheetYear(
                year=y + 1,
                gross_fixed_assets=round(gross_fixed, 2),
                accumulated_depreciation=round(cumulative_depreciation, 2),
                net_fixed_assets=round(net_fixed, 2),
                current_assets=round(current_assets, 2),
                total_assets=round(total_assets, 2),
                loan_outstanding=round(loan_out, 2),
                promoter_equity=round(promoter_equity, 2),
                retained_earnings=round(cumulative_retained, 2),
                total_liabilities=round(total_liabilities, 2),
            ))

        return results

    # ---- DSCR ----

    @staticmethod
    def calculate_dscr(
        pat: float, depreciation: float, interest: float,
        principal_repaid: float
    ) -> float:
        """
        DSCR = (PAT + Depreciation + Interest) / (Principal Repaid + Interest)
        Standard Mudra/bank formula.
        """
        numerator = pat + depreciation + interest
        denominator = principal_repaid + interest
        if denominator <= 0:
            return float('inf') if numerator > 0 else 0.0
        return round(numerator / denominator, 2)

    # ---- IRR ----

    @staticmethod
    def calculate_irr(
        initial_investment: float, cash_flows: List[float], max_iter: int = 200, tol: float = 1e-7
    ) -> float:
        """
        IRR via Newton-Raphson method.
        cash_flows: list of annual net cash flows (PAT + Depreciation) for years 1-5.
        """
        if initial_investment <= 0:
            return 0.0

        flows = [-initial_investment] + cash_flows

        # Initial guess
        r = 0.1
        for _ in range(max_iter):
            npv = sum(f / ((1 + r) ** t) for t, f in enumerate(flows))
            dnpv = sum(-t * f / ((1 + r) ** (t + 1)) for t, f in enumerate(flows))
            if abs(dnpv) < 1e-12:
                break
            r_new = r - npv / dnpv
            if abs(r_new - r) < tol:
                r = r_new
                break
            r = r_new

        return round(r * 100, 2)

    # ---- Break-Even ----

    @staticmethod
    def calculate_break_even(
        fixed_costs_annual: float,
        selling_price_per_unit: float,
        variable_cost_per_unit: float,
        monthly_production_capacity: float,
    ) -> Dict[str, Any]:
        """Calculate break-even in units, revenue, and months."""
        contribution = selling_price_per_unit - variable_cost_per_unit
        if contribution <= 0:
            return {
                "break_even_units": float('inf'),
                "break_even_revenue": float('inf'),
                "break_even_month": 999,
                "status": "Not achievable - variable cost exceeds selling price",
            }

        be_units = fixed_costs_annual / contribution
        be_revenue = be_units * selling_price_per_unit

        # Months to break even based on monthly capacity
        if monthly_production_capacity > 0:
            be_months = math.ceil(be_units / monthly_production_capacity)
        else:
            be_months = 999

        return {
            "break_even_units": round(be_units, 0),
            "break_even_revenue": round(be_revenue, 2),
            "break_even_month": be_months,
            "status": "Achievable",
        }

    # ---- What-If Simulation ----

    def whatif_simulate(
        self, inputs: MudraDPRInput, overrides: Dict[str, Any]
    ) -> "MudraDPROutput":
        """Recalculate DPR with parameter overrides."""
        # Create modified inputs
        modified = MudraDPRInput(**inputs.to_dict())
        for key, value in overrides.items():
            if hasattr(modified, key):
                setattr(modified, key, value)
        return self.generate_full_dpr(modified)

    # ---- DSCR Slider Data ----

    def dscr_slider_data(
        self,
        inputs: MudraDPRInput,
        variable: str,
        min_val: float,
        max_val: float,
        steps: int = 20,
    ) -> List[Dict[str, Any]]:
        """Generate data series for real-time DSCR charting."""
        step_size = (max_val - min_val) / steps if steps > 0 else 0
        results = []

        for i in range(steps + 1):
            val = min_val + i * step_size
            override = {variable: val}
            output = self.whatif_simulate(inputs, override)
            results.append({
                "value": round(val, 2),
                "average_dscr": output.average_dscr,
                "irr": output.irr,
                "is_bankable": output.is_bankable,
            })

        return results

    # ---- Cluster Suggestions ----

    def suggest_cluster(
        self, city: str, state: str, business_type: str
    ) -> List[Dict[str, str]]:
        """Static lookup of industrial clusters/SEZs by state."""
        state_key = state.lower().replace(" ", "_")
        clusters = self.CLUSTER_DATA.get(state_key, [])

        if not clusters:
            return [{"name": "No specific cluster data available", "type": "General", "city": city}]

        # Filter by city if matches, otherwise return all for state
        city_lower = city.lower()
        city_matches = [c for c in clusters if c["city"].lower() == city_lower]
        return city_matches if city_matches else clusters

    # ---- Full DPR Orchestrator ----

    def generate_full_dpr(self, inputs: MudraDPRInput) -> MudraDPROutput:
        """Orchestrator: compute all financial data for a Mudra DPR."""
        # 1. Project cost
        project_cost = self.calculate_project_cost(inputs)
        total_cost = project_cost["total_project_cost"]

        # 2. Mudra category
        category = self.classify_mudra_category(total_cost)

        # 3. Means of finance
        means = self.calculate_means_of_finance(total_cost, inputs.promoter_contribution_pct)

        # 4. EMI
        emi = self.calculate_emi(means["loan_amount"], inputs.interest_rate, inputs.tenure_months)

        # 5. Loan schedule
        loan_schedule = self._loan_schedule(means["loan_amount"], inputs.interest_rate, inputs.tenure_months)

        # 6. P&L
        pnl = self.generate_projected_pnl(inputs, loan_schedule)

        # 7. Balance sheet
        bs = self.generate_projected_balance_sheet(inputs, pnl, loan_schedule, project_cost, means)

        # 8. DSCR per year
        dscr_data = []
        for y in range(5):
            dscr_val = self.calculate_dscr(
                pat=pnl[y].pat,
                depreciation=pnl[y].depreciation,
                interest=pnl[y].interest,
                principal_repaid=loan_schedule[y]["principal_repaid"],
            )
            status = "Excellent" if dscr_val >= 2.0 else "Good" if dscr_val >= 1.5 else "Marginal" if dscr_val >= 1.25 else "Poor"
            dscr_data.append({"year": y + 1, "dscr": dscr_val, "status": status})

        finite_dscrs = [d["dscr"] for d in dscr_data if d["dscr"] != float('inf')]
        avg_dscr = round(sum(finite_dscrs) / len(finite_dscrs), 2) if finite_dscrs else 0.0

        # 9. IRR
        cash_flows = [pnl[y].pat + pnl[y].depreciation for y in range(5)]
        irr = self.calculate_irr(total_cost, cash_flows)

        # 10. Break-even
        # Fixed costs = rent + wages + utilities + other + depreciation + interest (year 1)
        y1_fixed = (
            pnl[0].rent + pnl[0].wages + pnl[0].utilities
            + pnl[0].other_expenses + pnl[0].depreciation + pnl[0].interest
        )
        be = self.calculate_break_even(
            fixed_costs_annual=y1_fixed,
            selling_price_per_unit=inputs.selling_price_per_unit,
            variable_cost_per_unit=inputs.raw_material_cost_per_unit,
            monthly_production_capacity=inputs.units_at_full_capacity * (inputs.capacity_utilization_y1 / 100),
        )

        # 11. Bankability assessment
        is_bankable = avg_dscr >= 1.5
        if avg_dscr >= 2.0:
            recommendation = "Strong financials. Likely approval with standard terms."
        elif avg_dscr >= 1.5:
            recommendation = "Acceptable. May proceed with standard documentation."
        elif avg_dscr >= 1.25:
            recommendation = "Marginal. Consider additional collateral or reduced loan amount."
        elif avg_dscr >= 1.0:
            recommendation = "Risky. Suggest reducing loan amount by 20-30%."
        else:
            recommendation = "Not viable. Cash flow insufficient for debt service."

        return MudraDPROutput(
            mudra_category=category.value,
            mudra_category_label=self.CATEGORY_LABELS[category],
            total_fixed_assets=project_cost["total_fixed_assets"],
            working_capital=project_cost["working_capital"],
            preliminary_expenses=project_cost["preliminary_expenses"],
            contingency=project_cost["contingency"],
            total_project_cost=total_cost,
            promoter_contribution=means["promoter_contribution"],
            loan_amount=means["loan_amount"],
            emi=emi,
            projected_pnl=[p.to_dict() for p in pnl],
            projected_balance_sheet=[b.to_dict() for b in bs],
            dscr_per_year=dscr_data,
            average_dscr=avg_dscr,
            irr=irr,
            break_even_units=be["break_even_units"],
            break_even_revenue=be["break_even_revenue"],
            break_even_month=be["break_even_month"],
            is_bankable=is_bankable,
            recommendation=recommendation,
        )


# Singleton
mudra_engine = MudraDPREngine()
