"""
WealthIn Expense Forecasting Service
Predictive spending alerts and budget forecasting based on historical patterns.
"""

import aiosqlite
from datetime import datetime, timedelta, date
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
import statistics
import os

TRANSACTIONS_DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'transactions.db')
PLANNING_DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'planning.db')


@dataclass
class ForecastResult:
    """Forecast result for a period"""
    period: str
    projected_spending: float
    budget_limit: float
    confidence: float
    is_over_budget: bool
    variance_percent: float


@dataclass
class AnomalyAlert:
    """Spending anomaly detection"""
    category: str
    current_spending: float
    average_spending: float
    deviation_percent: float
    severity: str  # 'low', 'medium', 'high'


class ExpenseForecastService:
    """Service for expense forecasting and budget alerts"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    async def forecast_month_end(
        self, 
        user_id: str, 
        category: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Forecast month-end spending based on current trends
        
        Returns:
            {
                'projected_total': float,
                'current_spending': float,
                'days_elapsed': int,
                'days_remaining': int,
                'daily_average': float,
                'budget_limit': float,
                'over_budget_by': float,
                'confidence_level': float,
                'recommendation': str
            }
        """
        today = date.today()
        month_start = today.replace(day=1)
        
        # Calculate days in month
        if today.month == 12:
            next_month = today.replace(year=today.year + 1, month=1, day=1)
        else:
            next_month = today.replace(month=today.month + 1, day=1)
        
        days_in_month = (next_month - month_start).days
        days_elapsed = (today - month_start).days + 1
        days_remaining = days_in_month - days_elapsed
        
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            # Get spending so far this month
            query = '''
                SELECT COALESCE(SUM(amount), 0) as total
                FROM transactions 
                WHERE user_id = ? 
                AND type = 'expense' 
                AND date >= ?
                AND date <= ?
            '''
            params = [user_id, month_start.isoformat(), today.isoformat()]
            
            if category:
                query += ' AND category = ?'
                params.append(category)
            
            cursor = await db.execute(query, params)
            current_spending = (await cursor.fetchone())[0]
            
            # Calculate daily average (using weighted average)
            # Give more weight to recent days
            daily_totals = await self._get_daily_spending(
                user_id, 
                month_start.isoformat(), 
                today.isoformat(),
                category
            )
            
            if len(daily_totals) > 0:
                # Weighted average (more recent days have higher weight)
                weights = list(range(1, len(daily_totals) + 1))
                daily_average = sum(
                    amount * weight 
                    for amount, weight in zip(daily_totals, weights)
                ) / sum(weights)
            else:
                daily_average = 0
            
            # Project to month end
            projected_total = current_spending + (daily_average * days_remaining)
            
            # Get budget for comparison
            budget_limit = 0
            async with aiosqlite.connect(PLANNING_DB_PATH) as budget_db:
                budget_query = 'SELECT COALESCE(SUM(amount), 0) FROM budgets WHERE user_id = ? AND period = "monthly"'
                budget_params = [user_id]
                
                if category:
                    budget_query += ' AND category = ?'
                    budget_params.append(category)
                
                cursor = await budget_db.execute(budget_query, budget_params)
                budget_limit = (await cursor.fetchone())[0]
            
            # Calculate confidence (higher with more data points)
            confidence_level = min(0.95, 0.3 + (len(daily_totals) / days_in_month) * 0.65)
            
            # Determine recommendation
            over_budget_by = projected_total - budget_limit if budget_limit > 0 else 0
            
            if budget_limit > 0:
                if projected_total > budget_limit:
                    recommendation = f"⚠️ Projected to exceed budget by ₹{over_budget_by:,.0f}. Consider reducing spending."
                elif projected_total > budget_limit * 0.9:
                    recommendation = "⚡ On track to reach 90%+ of budget. Monitor closely."
                else:
                    remaining = budget_limit - projected_total
                    recommendation = f"✅ On track! Projected to stay ₹{remaining:,.0f} under budget."
            else:
                recommendation = "💡 Set a budget to get personalized recommendations."
            
            return {
                'projected_total': round(projected_total, 2),
                'current_spending': round(current_spending, 2),
                'days_elapsed': days_elapsed,
                'days_remaining': days_remaining,
                'daily_average': round(daily_average, 2),
                'budget_limit': round(budget_limit, 2),
                'over_budget_by': round(over_budget_by, 2) if over_budget_by > 0 else 0,
                'confidence_level': round(confidence_level, 2),
                'recommendation': recommendation,
                'category': category or 'All'
            }
    
    async def _get_daily_spending(
        self, 
        user_id: str, 
        start_date: str, 
        end_date: str,
        category: Optional[str] = None
    ) -> List[float]:
        """Get daily spending amounts as a list"""
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            query = '''
                SELECT date, SUM(amount) as total
                FROM transactions 
                WHERE user_id = ? 
                AND type = 'expense'
                AND date BETWEEN ? AND ?
            '''
            params = [user_id, start_date, end_date]
            
            if category:
                query += ' AND category = ?'
                params.append(category)
            
            query += ' GROUP BY date ORDER BY date ASC'
            
            cursor = await db.execute(query, params)
            rows = await cursor.fetchall()
            
            return [row[1] for row in rows]
    
    async def detect_anomalies(
        self, 
        user_id: str, 
        lookback_days: int = 30,
        threshold_std_dev: float = 2.0
    ) -> List[AnomalyAlert]:
        """
        Detect spending anomalies (unusual spending patterns)
        
        Args:
            user_id: User ID
            lookback_days: Number of days to analyze
            threshold_std_dev: Number of standard deviations for anomaly (default 2.0)
        
        Returns:
            List of anomaly alerts
        """
        today = date.today()
        lookback_start = today - timedelta(days=lookback_days)
        week_start = today - timedelta(days=7)
        
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            # Get spending by category for last week
            cursor = await db.execute('''
                SELECT category, SUM(amount) as total
                FROM transactions 
                WHERE user_id = ? 
                AND type = 'expense'
                AND date >= ?
                GROUP BY category
            ''', (user_id, week_start.isoformat()))
            
            current_week_spending = {row[0]: row[1] for row in await cursor.fetchall()}
            
            # Get historical average by category
            cursor = await db.execute('''
                SELECT category, AVG(weekly_total) as avg_weekly
                FROM (
                    SELECT 
                        category,
                        strftime('%Y-%W', date) as week,
                        SUM(amount) as weekly_total
                    FROM transactions 
                    WHERE user_id = ? 
                    AND type = 'expense'
                    AND date >= ?
                    GROUP BY category, week
                )
                GROUP BY category
            ''', (user_id, lookback_start.isoformat()))
            
            historical_avg = {row[0]: row[1] for row in await cursor.fetchall()}
            
            # Get standard deviation for each category
            anomalies = []
            
            for category, current_amount in current_week_spending.items():
                if category not in historical_avg:
                    continue
                
                avg = historical_avg[category]
                
                # Simple anomaly detection (can be enhanced with proper std dev calculation)
                if avg > 0:
                    deviation_percent = ((current_amount - avg) / avg) * 100
                    
                    # Determine severity
                    if abs(deviation_percent) > 100:
                        severity = 'high'
                    elif abs(deviation_percent) > 50:
                        severity = 'medium'
                    else:
                        severity = 'low'
                    
                    # Flag if spending is significantly higher
                    if deviation_percent > 50:  # 50% or more above average
                        anomalies.append(AnomalyAlert(
                            category=category,
                            current_spending=current_amount,
                            average_spending=avg,
                            deviation_percent=deviation_percent,
                            severity=severity
                        ))
            
            return anomalies
    
    async def generate_weekly_digest(self, user_id: str) -> Dict[str, Any]:
        """
        Generate weekly spending digest
        
        Returns:
            {
                'week_total': float,
                'previous_week_total': float,
                'change_percent': float,
                'top_categories': [{category, amount, percent_of_total}],
                'anomalies': [AnomalyAlert],
                'insights': [str]
            }
        """
        today = date.today()
        week_start = today - timedelta(days=7)
        prev_week_start = today - timedelta(days=14)
        
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            # Current week spending
            cursor = await db.execute('''
                SELECT COALESCE(SUM(amount), 0)
                FROM transactions 
                WHERE user_id = ? 
                AND type = 'expense'
                AND date >= ?
            ''', (user_id, week_start.isoformat()))
            week_total = (await cursor.fetchone())[0]
            
            # Previous week spending
            cursor = await db.execute('''
                SELECT COALESCE(SUM(amount), 0)
                FROM transactions 
                WHERE user_id = ? 
                AND type = 'expense'
                AND date >= ?
                AND date < ?
            ''', (user_id, prev_week_start.isoformat(), week_start.isoformat()))
            prev_week_total = (await cursor.fetchone())[0]
            
            # Calculate change
            if prev_week_total > 0:
                change_percent = ((week_total - prev_week_total) / prev_week_total) * 100
            else:
                change_percent = 0
            
            # Top categories this week
            cursor = await db.execute('''
                SELECT category, SUM(amount) as total
                FROM transactions 
                WHERE user_id = ? 
                AND type = 'expense'
                AND date >= ?
                GROUP BY category
                ORDER BY total DESC
                LIMIT 5
            ''', (user_id, week_start.isoformat()))
            
            category_rows = await cursor.fetchall()
            top_categories = [
                {
                    'category': row[0],
                    'amount': row[1],
                    'percent_of_total': (row[1] / week_total * 100) if week_total > 0 else 0
                }
                for row in category_rows
            ]
            
            # Detect anomalies
            anomalies = await self.detect_anomalies(user_id, lookback_days=30)
            
            # Generate insights
            insights = []
            
            if change_percent > 20:
                insights.append(f"📈 Spending increased {change_percent:+.0f}% from last week")
            elif change_percent < -20:
                insights.append(f"📉 Great! Spending decreased {abs(change_percent):.0f}% from last week")
            
            if len(top_categories) > 0:
                top_cat = top_categories[0]
                insights.append(f"💰 {top_cat['category']} was your biggest expense (₹{top_cat['amount']:,.0f})")
            
            if len(anomalies) > 0:
                high_anomalies = [a for a in anomalies if a.severity == 'high']
                if high_anomalies:
                    insights.append(f"⚠️ Unusual spike in {high_anomalies[0].category} spending")
            
            return {
                'week_total': round(week_total, 2),
                'previous_week_total': round(prev_week_total, 2),
                'change_percent': round(change_percent, 2),
                'top_categories': top_categories,
                'anomalies': [
                    {
                        'category': a.category,
                        'current_spending': a.current_spending,
                        'average_spending': a.average_spending,
                        'deviation_percent': a.deviation_percent,
                        'severity': a.severity
                    }
                    for a in anomalies
                ],
                'insights': insights
            }
    
    async def get_category_forecast(
        self, 
        user_id: str, 
        days_ahead: int = 30
    ) -> List[Dict[str, Any]]:
        """
        Forecast spending by category for the next N days
        
        Returns:
            List of {category, projected_amount, confidence}
        """
        today = date.today()
        lookback_start = today - timedelta(days=90)  # Use 90 days of history
        
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            # Get daily average by category
            cursor = await db.execute('''
                SELECT category, AVG(daily_total) as daily_avg
                FROM (
                    SELECT category, date, SUM(amount) as daily_total
                    FROM transactions 
                    WHERE user_id = ? 
                    AND type = 'expense'
                    AND date >= ?
                    GROUP BY category, date
                )
                GROUP BY category
            ''', (user_id, lookback_start.isoformat()))
            
            category_avgs = await cursor.fetchall()
            
            forecasts = []
            for category, daily_avg in category_avgs:
                projected = daily_avg * days_ahead
                
                # Calculate confidence based on consistency
                # (simplified - could be enhanced with actual variance calculation)
                confidence = 0.7  # Default confidence
                
                forecasts.append({
                    'category': category,
                    'projected_amount': round(projected, 2),
                    'daily_average': round(daily_avg, 2),
                    'confidence': confidence
                })
            
            return sorted(forecasts, key=lambda x: x['projected_amount'], reverse=True)


# Singleton instance
forecast_service = ExpenseForecastService()
