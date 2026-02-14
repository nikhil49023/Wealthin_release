"""
WealthIn Investment Nudge Service
Provides RBI-compliant investment nudges with Insight Chips.
Zero-Legal-Risk: All nudges are informational only.
"""

from typing import Dict, Any, List, Optional
from dataclasses import dataclass
from datetime import datetime, timedelta
import os
import aiosqlite

# Database paths
TRANSACTIONS_DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'transactions.db')
PLANNING_DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'planning.db')


@dataclass
class InsightChip:
    """
    Explainability chip for investment nudges.
    Shows the 'why' behind each suggestion.
    """
    type: str          # 'surplus', 'yield', 'safety', 'goal', 'viksit'
    icon: str          # Material icon name
    label: str         # Display text
    value: str         # Value/percentage


@dataclass
class InvestmentNudge:
    """
    RBI-Compliant Investment Suggestion
    User must manually act - we never execute.
    """
    id: str
    title: str
    subtitle: str
    amount: float
    instrument: str      # 'RD', 'SGB', 'FD', 'liquid_fund', 'ppf'
    expected_yield: float
    action_text: str     # "Open SBI YONO" etc
    insight_chips: List[InsightChip]
    bank_deeplink: Optional[str] = None


class InvestmentNudgeService:
    """
    Investment Nudge Generator
    
    Generates contextual, explainable investment nudges
    based on user's spending patterns and surplus.
    
    RBI Compliance:
    - Information-only (no execution)
    - User directed to bank apps
    - Transparent risk disclosure
    """

    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    async def calculate_surplus(self, user_id: str) -> Dict[str, float]:
        """
        Calculate user's estimated investable surplus.
        Formula: Income - Fixed Expenses - Discretionary Buffer
        """
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            
            # Get last 30 days transactions
            cutoff = (datetime.utcnow() - timedelta(days=30)).isoformat()
            
            # Income
            cursor = await db.execute('''
                SELECT COALESCE(SUM(amount), 0) as total
                FROM transactions
                WHERE date >= ? AND LOWER(type) IN ('income', 'credit', 'deposit')
            ''', (cutoff,))
            income_row = await cursor.fetchone()
            income = income_row['total'] if income_row else 0
            
            # Expenses
            cursor = await db.execute('''
                SELECT COALESCE(SUM(amount), 0) as total
                FROM transactions
                WHERE date >= ? AND LOWER(type) IN ('expense', 'debit')
            ''', (cutoff,))
            expense_row = await cursor.fetchone()
            expenses = expense_row['total'] if expense_row else 0
            
            # Calculate surplus
            raw_surplus = income - expenses
            
            # Apply 20% buffer for discretionary spending
            buffer = raw_surplus * 0.20
            investable_surplus = max(0, raw_surplus - buffer)
            
            return {
                'income': income,
                'expenses': expenses,
                'raw_surplus': raw_surplus,
                'buffer': buffer,
                'investable_surplus': investable_surplus,
                'surplus_rate': (raw_surplus / income * 100) if income > 0 else 0
            }

    async def generate_nudges(self, user_id: str, limit: int = 3) -> List[InvestmentNudge]:
        """
        Generate personalized investment nudges with Insight Chips.
        """
        nudges = []
        surplus_data = await self.calculate_surplus(user_id)
        surplus = surplus_data['investable_surplus']
        surplus_rate = surplus_data['surplus_rate']
        
        if surplus <= 0:
            return []
        
        # ============ NUDGE 1: Recurring Deposit (Safe, Low barrier) ============
        if surplus >= 1000:
            rd_amount = min(surplus * 0.3, 10000)  # 30% of surplus, max 10K
            expected_yield = 6.5  # Approx RD rate
            
            nudges.append(InvestmentNudge(
                id='rd_auto',
                title='Start a Recurring Deposit',
                subtitle=f'Save ₹{rd_amount:,.0f}/month automatically',
                amount=rd_amount,
                instrument='RD',
                expected_yield=expected_yield,
                action_text='Open your Bank App',
                insight_chips=[
                    InsightChip(
                        type='surplus',
                        icon='trending_up',
                        label='Based on surplus',
                        value=f'{surplus_rate:.0f}%'
                    ),
                    InsightChip(
                        type='yield',
                        icon='percent',
                        label='Expected yield',
                        value=f'{expected_yield}%'
                    ),
                    InsightChip(
                        type='safety',
                        icon='verified_user',
                        label='Risk',
                        value='Low'
                    ),
                ],
            ))
        
        # ============ NUDGE 2: Sovereign Gold Bond (Viksit Bharat) ============
        if surplus >= 5000:
            sgb_amount = min(surplus * 0.2, 50000)  # 20% of surplus
            expected_yield = 8.0  # 2.5% interest + gold appreciation
            
            nudges.append(InvestmentNudge(
                id='sgb_sovereign',
                title='Invest in Sovereign Gold Bonds',
                subtitle=f'Contribute ₹{sgb_amount:,.0f} to Viksit Bharat',
                amount=sgb_amount,
                instrument='SGB',
                expected_yield=expected_yield,
                action_text='Check RBI Retail Direct',
                insight_chips=[
                    InsightChip(
                        type='viksit',
                        icon='stars',
                        label='Nation Building',
                        value='Sovereign'
                    ),
                    InsightChip(
                        type='yield',
                        icon='trending_up',
                        label='Est. return',
                        value=f'{expected_yield}%'
                    ),
                    InsightChip(
                        type='safety',
                        icon='shield',
                        label='Govt. backed',
                        value='Safe'
                    ),
                ],
            ))
        
        # ============ NUDGE 3: Liquid Fund (Emergency Fund) ============
        if surplus >= 2000:
            liquid_amount = min(surplus * 0.25, 20000)
            expected_yield = 5.5
            
            nudges.append(InvestmentNudge(
                id='liquid_emergency',
                title='Build Emergency Fund',
                subtitle=f'Park ₹{liquid_amount:,.0f} in Liquid Fund',
                amount=liquid_amount,
                instrument='liquid_fund',
                expected_yield=expected_yield,
                action_text='Check Mutual Fund Apps',
                insight_chips=[
                    InsightChip(
                        type='goal',
                        icon='savings',
                        label='Goal',
                        value='Emergency'
                    ),
                    InsightChip(
                        type='yield',
                        icon='account_balance',
                        label='Better than savings',
                        value=f'{expected_yield}%'
                    ),
                    InsightChip(
                        type='safety',
                        icon='lock_clock',
                        label='Instant withdraw',
                        value='T+0'
                    ),
                ],
            ))
        
        # ============ NUDGE 4: PPF (Tax Saving) ============
        if surplus >= 500:
            ppf_amount = min(surplus * 0.15, 12500)  # 1.5L yearly limit / 12
            expected_yield = 7.1
            
            nudges.append(InvestmentNudge(
                id='ppf_tax',
                title='Save Tax with PPF',
                subtitle=f'Invest ₹{ppf_amount:,.0f}/month (80C benefits)',
                amount=ppf_amount,
                instrument='ppf',
                expected_yield=expected_yield,
                action_text='Open Bank App',
                insight_chips=[
                    InsightChip(
                        type='tax',
                        icon='receipt_long',
                        label='Tax benefit',
                        value='80C'
                    ),
                    InsightChip(
                        type='yield',
                        icon='trending_up',
                        label='Tax-free return',
                        value=f'{expected_yield}%'
                    ),
                    InsightChip(
                        type='viksit',
                        icon='flag',
                        label='Contribution',
                        value='Nation'
                    ),
                ],
            ))
        
        return nudges[:limit]

    async def get_nudge_summary(self, user_id: str) -> Dict[str, Any]:
        """
        Get summary of nudges with surplus analysis.
        """
        surplus_data = await self.calculate_surplus(user_id)
        nudges = await self.generate_nudges(user_id)
        
        # Convert nudges to dict format
        nudge_dicts = []
        for nudge in nudges:
            nudge_dicts.append({
                'id': nudge.id,
                'title': nudge.title,
                'subtitle': nudge.subtitle,
                'amount': nudge.amount,
                'instrument': nudge.instrument,
                'expected_yield': nudge.expected_yield,
                'action_text': nudge.action_text,
                'insight_chips': [
                    {
                        'type': chip.type,
                        'icon': chip.icon,
                        'label': chip.label,
                        'value': chip.value
                    } for chip in nudge.insight_chips
                ]
            })
        
        return {
            'surplus_analysis': {
                'income': surplus_data['income'],
                'expenses': surplus_data['expenses'],
                'investable_surplus': surplus_data['investable_surplus'],
                'surplus_rate': surplus_data['surplus_rate'],
            },
            'nudges': nudge_dicts,
            'total_potential': sum(n.amount for n in nudges),
            'disclaimer': 'These are informational suggestions only. Please consult your financial advisor before investing.'
        }


# Singleton instance
investment_nudge_service = InvestmentNudgeService()
