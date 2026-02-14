"""
WealthIn Financial Health Engine
Calculates a 4-pillar financial health score (0-100).
"""

import aiosqlite
import json
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, asdict
import os

# Database paths
TRANSACTIONS_DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'transactions.db')
PLANNING_DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'planning.db')


@dataclass
class HealthScore:
    total_score: float
    grade: str  # 'Excellent', 'Good', 'Fair', 'Poor', 'Critical'
    savings_score: float
    debt_score: float
    liquidity_score: float
    investment_score: float
    insights: List[str]
    metrics: Dict[str, Any]


class FinancialHealthService:
    """
    Financial Health Scoring Engine
    
    Weights:
    - Savings Rate (30%)
    - Debt-to-Income (30%)
    - Liquidity Ratio (20%)
    - Investment Diversity (20%)
    """

    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    async def calculate_health_score(self, user_id: str, force_refresh: bool = False) -> HealthScore:
        """
        Calculate comprehensive financial health score.
        Uses cache if available and fresh (< 24 hours). Set force_refresh=True to bypass cache.
        """
        # Check cache first
        if not force_refresh:
            cached = await self._get_cached_score(user_id)
            if cached:
                return cached
        
        metrics = await self._calculate_metrics(user_id)
        
        # 1. Savings Score (30%)
        # Target: 20% savings rate = 100 points
        savings_rate = metrics['savings_rate']
        savings_score = min(savings_rate / 20 * 100, 100) * 0.30
        
        # 2. Debt Score (30%)
        # Target: < 30% DTI = 100 points. > 60% DTI = 0 points.
        dti = metrics['debt_to_income']
        if dti <= 30:
            debt_raw_score = 100
        elif dti >= 60:
            debt_raw_score = 0
        else:
            debt_raw_score = 100 - ((dti - 30) / 30 * 100)
        debt_score = debt_raw_score * 0.30
        
        # 3. Liquidity Score (20%)
        # Target: 6 months expenses = 100 points
        liquidity_months = metrics['liquidity_ratio']
        liquidity_score = min(liquidity_months / 6 * 100, 100) * 0.20
        
        # 4. Investment Score (20%)
        # Based on diversity and active SIPs
        investment_raw_score = metrics['investment_diversity_score']
        investment_score = investment_raw_score * 0.20
        
        total_score = savings_score + debt_score + liquidity_score + investment_score
        
        # Determine Grade
        if total_score >= 80: grade = 'Excellent'
        elif total_score >= 60: grade = 'Good'
        elif total_score >= 40: grade = 'Fair'
        elif total_score >= 20: grade = 'Poor'
        else: grade = 'Critical'
        
        # Generate Insights
        insights = []
        if savings_rate < 10:
            insights.append("Low Savings Rate: Try the 50/30/20 rule to boost savings.")
        if dti > 40:
            insights.append("High Debt Usage: Consider the debt snowball method to reduce interest.")
        if liquidity_months < 3:
            insights.append("Low Liquidity: Build an emergency fund for at least 3 months.")
        if investment_raw_score < 50:
            insights.append("Lack of Diversity: Explore varied asset classes like SGB or Mutual Funds.")
            
        score = HealthScore(
            total_score=total_score,
            grade=grade,
            savings_score=savings_score,
            debt_score=debt_score,
            liquidity_score=liquidity_score,
            investment_score=investment_score,
            insights=insights,
            metrics=metrics
        )
        
        # Save to cache
        await self._save_cached_score(user_id, score)
        
        return score

    async def _get_cached_score(self, user_id: str) -> Optional[HealthScore]:
        """Retrieve cached score if it exists and is less than 24 hours old."""
        try:
            async with aiosqlite.connect(PLANNING_DB_PATH) as db:
                db.row_factory = aiosqlite.Row
                cursor = await db.execute(
                    'SELECT score_data, created_at FROM financial_health_cache WHERE user_id = ?',
                    (user_id,)
                )
                row = await cursor.fetchone()
                if row:
                    created_at = datetime.fromisoformat(row['created_at'])
                    if datetime.utcnow() - created_at < timedelta(hours=24):
                        data = json.loads(row['score_data'])
                        return HealthScore(**data)
        except Exception as e:
            print(f"Cache read error: {e}")
        return None

    async def _save_cached_score(self, user_id: str, score: HealthScore):
        """Save or update cached score."""
        try:
            async with aiosqlite.connect(PLANNING_DB_PATH) as db:
                now = datetime.utcnow().isoformat()
                score_json = json.dumps(asdict(score))
                await db.execute(
                    '''INSERT OR REPLACE INTO financial_health_cache (user_id, score_data, created_at)
                       VALUES (?, ?, ?)''',
                    (user_id, score_json, now)
                )
                await db.commit()
        except Exception as e:
            print(f"Cache write error: {e}")

    async def _calculate_metrics(self, user_id: str) -> Dict[str, Any]:
        """Fetch raw metrics from database with optimized single query."""
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            db.row_factory = aiosqlite.Row

            # Last 3 months average for stable metrics
            cutoff = (datetime.utcnow() - timedelta(days=90)).isoformat()

            # OPTIMIZED: Single query using CTEs and CASE aggregations
            cursor = await db.execute('''
                WITH metrics AS (
                    SELECT
                        -- 90-day metrics
                        SUM(CASE WHEN type='income' AND date >= ? THEN amount ELSE 0 END) as income_90d,
                        SUM(CASE WHEN type='expense' AND date >= ? THEN amount ELSE 0 END) as expense_90d,
                        SUM(CASE WHEN date >= ? AND (description LIKE '%invest%' OR category='Investment')
                            THEN amount ELSE 0 END) as investments_90d,
                        SUM(CASE WHEN date >= ? AND (category='Loan' OR description LIKE '%EMI%')
                            THEN amount ELSE 0 END) as debt_payments_90d,
                        -- Lifetime net worth
                        SUM(CASE WHEN type='income' THEN amount ELSE -amount END) as net_worth
                    FROM transactions
                    WHERE user_id = ?
                ),
                diversity AS (
                    SELECT COUNT(DISTINCT category) as asset_classes
                    FROM transactions
                    WHERE user_id = ? AND type='expense'
                        AND category IN ('Investment', 'Stocks', 'Mutual Fund', 'Gold', 'Real Estate')
                )
                SELECT
                    m.income_90d,
                    m.expense_90d,
                    m.investments_90d,
                    m.debt_payments_90d,
                    m.net_worth,
                    d.asset_classes
                FROM metrics m, diversity d
            ''', (cutoff, cutoff, cutoff, cutoff, user_id, user_id))

            row = await cursor.fetchone()

            # Extract values with fallbacks
            total_income = row['income_90d'] if row and row['income_90d'] else 1  # Avoid div/0
            total_expense = row['expense_90d'] if row and row['expense_90d'] else 0
            total_investments = row['investments_90d'] if row and row['investments_90d'] else 0
            total_debt_payments = row['debt_payments_90d'] if row and row['debt_payments_90d'] else 0
            liquid_assets = row['net_worth'] if row and row['net_worth'] else 0
            asset_classes = row['asset_classes'] if row and row['asset_classes'] else 0

            # Calculate monthly averages (90 days = ~3 months)
            monthly_income = total_income / 3
            monthly_expense = total_expense / 3
            monthly_debt = total_debt_payments / 3

            # Calculate ratios
            savings_rate = ((total_income - total_expense) / total_income) * 100 if total_income > 0 else 0
            dti = (monthly_debt / monthly_income * 100) if monthly_income > 0 else 0
            liquidity_ratio = liquid_assets / monthly_expense if monthly_expense > 0 else 0
            diversity_score = min(asset_classes * 25, 100)  # 4 classes = 100%

            return {
                'savings_rate': max(0, savings_rate),
                'debt_to_income': dti,
                'liquidity_ratio': liquidity_ratio,
                'investment_diversity_score': diversity_score,
                'monthly_income': monthly_income,
                'monthly_expense': monthly_expense
            }


# Singleton instance
financial_health_service = FinancialHealthService()
