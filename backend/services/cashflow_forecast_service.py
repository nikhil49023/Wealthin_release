"""
WealthIn Cash Flow Forecasting Service (30-90 Days)
Predicts business cash flow based on invoices, bills, recurring expenses, and historical patterns.
Critical for MSME survival and runway calculations.
"""

import aiosqlite
from datetime import datetime, timedelta, date
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
import os

TRANSACTIONS_DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'transactions.db')
PLANNING_DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'planning.db')


@dataclass
class CashFlowProjection:
    """Single day cash flow projection"""
    date: str
    opening_balance: float
    income: float
    expenses: float
    closing_balance: float
    notes: List[str]


class CashFlowForecastService:
    """Service for business cash flow forecasting"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    async def forecast_cash_flow(
        self,
        user_id: str,
        days_ahead: int = 90,
        starting_balance: Optional[float] = None
    ) -> List[Dict[str, Any]]:
        """
        Forecast cash flow for the next N days
        
        Algorithm:
        1. Start with current balance (or provided)
        2. Add scheduled income (invoices, salaries)
        3. Subtract scheduled expenses (EMIs, bills, vendor payments)
        4. Subtract predicted variable expenses (based on historical average)
        5. Calculate runway (days until balance goes negative)
        
        Returns:
            List of daily projections with opening/closing balances
        """
        today = date.today()
        
        # Get starting balance
        if starting_balance is None:
            starting_balance = await self._get_current_balance(user_id)
        
        # Get scheduled income and expenses
        scheduled_income = await self._get_scheduled_income(user_id, days_ahead)
        scheduled_expenses = await self._get_scheduled_expenses(user_id, days_ahead)
        
        # Get average daily variable expenses
        daily_variable = await self._get_average_daily_expenses(user_id)
        
        # Build daily projections
        projections = []
        running_balance = starting_balance
        
        for day_offset in range(days_ahead + 1):
            current_date = today + timedelta(days=day_offset)
            date_str = current_date.isoformat()
            
            opening_balance = running_balance
            
            # Get scheduled income for this day
            day_income = sum(
                item['amount'] for item in scheduled_income
                if item['date'] == date_str
            )
            
            # Get scheduled expenses for this day
            day_expenses = sum(
                item['amount'] for item in scheduled_expenses
                if item['date'] == date_str
            )
            
            # Add variable expenses (every day)
            day_expenses += daily_variable
            
            # Calculate closing balance
            closing_balance = opening_balance + day_income - day_expenses
            
            # Generate notes for this day
            notes = []
            if day_income > 0:
                income_items = [
                    item for item in scheduled_income
                    if item['date'] == date_str
                ]
                for item in income_items:
                    notes.append(f"💰 Expected: {item['description']} - ₹{item['amount']:,.0f}")
            
            if day_expenses > daily_variable:
                expense_items = [
                    item for item in scheduled_expenses
                    if item['date'] == date_str
                ]
                for item in expense_items:
                    notes.append(f"💸 Due: {item['description']} - ₹{item['amount']:,.0f}")
            
            if closing_balance < 0 and opening_balance >= 0:
                notes.append("⚠️ ALERT: Cash balance will go negative!")
            
            projections.append({
                'date': date_str,
                'opening_balance': round(opening_balance, 2),
                'income': round(day_income, 2),
                'expenses': round(day_expenses, 2),
                'closing_balance': round(closing_balance, 2),
                'notes': notes
            })
            
            running_balance = closing_balance
        
        return projections
    
    async def calculate_runway(self, user_id: str) -> Dict[str, Any]:
        """
        Calculate business runway (months until cash runs out)
        
        Returns:
            {
                'current_balance': float,
                'monthly_burn_rate': float,
                'runway_months': float,
                'runway_days': int,
                'zero_balance_date': str,
                'status': str,
                'recommendation': str
            }
        """
        # Get current balance
        current_balance = await self._get_current_balance(user_id)
        
        # Calculate monthly burn rate (avg expenses - avg income)
        burn_rate = await self._calculate_monthly_burn_rate(user_id)
        
        # Calculate runway
        if burn_rate <= 0:
            # Positive cash flow - not burning
            return {
                'current_balance': current_balance,
                'monthly_burn_rate': burn_rate,
                'runway_months': float('inf'),
                'runway_days': -1,
                'zero_balance_date': None,
                'status': 'healthy',
                'recommendation': '✅ Positive cash flow! No runway concerns.'
            }
        
        runway_months = current_balance / burn_rate
        runway_days = int(runway_months * 30)
        
        zero_date = (date.today() + timedelta(days=runway_days)).isoformat()
        
        # Determine status and recommendation
        if runway_months < 1:
            status = 'critical'
            recommendation = f'🚨 CRITICAL: Only {runway_days} days of runway! Urgent action needed.'
        elif runway_months < 3:
            status = 'warning'
            recommendation = f'⚠️ WARNING: {runway_months:.1f} months runway. Start reducing costs or increasing revenue.'
        elif runway_months < 6:
            status = 'caution'
            recommendation = f'⚡ CAUTION: {runway_months:.1f} months runway. Monitor closely.'
        else:
            status = 'healthy'
            recommendation = f'✅ HEALTHY: {runway_months:.1f} months runway.'
        
        return {
            'current_balance': round(current_balance, 2),
            'monthly_burn_rate': round(burn_rate, 2),
            'runway_months': round(runway_months, 2),
            'runway_days': runway_days,
            'zero_balance_date': zero_date,
            'status': status,
            'recommendation': recommendation
        }
    
    async def simulate_delayed_payment(
        self,
        user_id: str,
        invoice_amount: float,
        original_date: str,
        delay_days: int
    ) -> Dict[str, Any]:
        """
        What-if scenario: How does delayed invoice payment affect cash flow?
        
        Returns:
            Comparison of original vs delayed scenario
        """
        # Get base forecast
        base_forecast = await self.forecast_cash_flow(user_id, days_ahead=90)
        
        # Find the impact date
        original_dt = datetime.fromisoformat(original_date).date()
        new_dt = original_dt + timedelta(days=delay_days)
        
        # Calculate impact
        affected_days = []
        for projection in base_forecast:
            proj_date = datetime.fromisoformat(projection['date']).date()
            
            if original_dt <= proj_date < new_dt:
                # Days where money was expected but not received
                affected_days.append({
                    'date': projection['date'],
                    'expected_balance': projection['closing_balance'],
                    'actual_balance': projection['closing_balance'] - invoice_amount,
                    'shortfall': invoice_amount
                })
        
        # Check if any day goes negative
        will_go_negative = any(
            day['actual_balance'] < 0 for day in affected_days
        )
        
        return {
            'invoice_amount': invoice_amount,
            'delay_days': delay_days,
            'original_date': original_date,
            'new_date': new_dt.isoformat(),
            'affected_days_count': len(affected_days),
            'will_go_negative': will_go_negative,
            'affected_days': affected_days[:7],  # Show first week
            'recommendation': (
                f'⚠️ {delay_days}-day delay will cause negative balance!'
                if will_go_negative
                else f'✓ {delay_days}-day delay is manageable'
            )
        }
    
    async def get_upcoming_cash_crunch(
        self,
        user_id: str,
        days_ahead: int = 90
    ) -> List[Dict[str, Any]]:
        """
        Identify upcoming dates where cash balance might be critically low
        
        Returns:
            List of dates with low balance warnings
        """
        forecast = await self.forecast_cash_flow(user_id, days_ahead)
        
        # Get current balance to set threshold
        current_balance = forecast[0]['opening_balance']
        critical_threshold = current_balance * 0.2  # 20% of current
        
        warnings = []
        for projection in forecast:
            if projection['closing_balance'] < critical_threshold:
                severity = 'critical' if projection['closing_balance'] < 0 else 'warning'
                
                warnings.append({
                    'date': projection['date'],
                    'balance': projection['closing_balance'],
                    'severity': severity,
                    'notes': projection['notes']
                })
        
        return warnings
    
    # ==================== HELPER METHODS ====================
    
    async def _get_current_balance(self, user_id: str) -> float:
        """Calculate current balance from transactions"""
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            cursor = await db.execute('''
                SELECT 
                    SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) -
                    SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as balance
                FROM transactions
                WHERE user_id = ?
            ''', (user_id,))
            
            result = await cursor.fetchone()
            return result[0] if result[0] else 0.0
    
    async def _get_scheduled_income(
        self,
        user_id: str,
        days_ahead: int
    ) -> List[Dict[str, Any]]:
        """Get scheduled income (invoices, expected payments)"""
        today = date.today()
        end_date = today + timedelta(days=days_ahead)
        
        scheduled = []
        
        # Get unpaid invoices from GST module
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            try:
                cursor = await db.execute('''
                    SELECT invoice_number, total_amount, due_date
                    FROM invoices
                    WHERE user_id = ?
                    AND payment_status = 'unpaid'
                    AND due_date BETWEEN ? AND ?
                    ORDER BY due_date
                ''', (user_id, today.isoformat(), end_date.isoformat()))
                
                for row in await cursor.fetchall():
                    scheduled.append({
                        'date': row[2],
                        'description': f'Invoice {row[0]}',
                        'amount': row[1],
                        'type': 'invoice'
                    })
            except:
                # Invoices table might not exist yet
                pass
        
        # Get salary/recurring income from scheduled payments
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            cursor = await db.execute('''
                SELECT name, amount, next_due_date, frequency
                FROM scheduled_payments
                WHERE user_id = ?
                AND status = 'active'
                AND payment_type = 'regular'
                AND category = 'Salary'
            ''', (user_id,))
            
            for row in await cursor.fetchall():
                # Project future occurrences
                current_date = datetime.fromisoformat(row[2]).date()
                frequency = row[3]
                
                while current_date <= end_date:
                    if current_date >= today:
                        scheduled.append({
                            'date': current_date.isoformat(),
                            'description': row[0],
                            'amount': row[1],
                            'type': 'salary'
                        })
                    
                    # Increment based on frequency
                    if frequency == 'monthly':
                        current_date = current_date + timedelta(days=30)
                    elif frequency == 'weekly':
                        current_date = current_date + timedelta(days=7)
                    elif frequency == 'daily':
                        current_date = current_date + timedelta(days=1)
                    else:
                        break
        
        return scheduled
    
    async def _get_scheduled_expenses(
        self,
        user_id: str,
        days_ahead: int
    ) -> List[Dict[str, Any]]:
        """Get scheduled expenses (EMIs, rent, bills)"""
        today = date.today()
        end_date = today + timedelta(days=days_ahead)
        
        scheduled = []
        
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            cursor = await db.execute('''
                SELECT name, amount, next_due_date, frequency, category
                FROM scheduled_payments
                WHERE user_id = ?
                AND status = 'active'
                AND payment_type IN ('regular', 'loan', 'emi')
                AND category != 'Salary'
            ''', (user_id,))
            
            for row in await cursor.fetchall():
                current_date = datetime.fromisoformat(row[2]).date()
                frequency = row[3]
                
                while current_date <= end_date:
                    if current_date >= today:
                        scheduled.append({
                            'date': current_date.isoformat(),
                            'description': row[0],
                            'amount': row[1],
                            'type': row[4]
                        })
                    
                    # Increment based on frequency
                    if frequency == 'monthly':
                        current_date = current_date + timedelta(days=30)
                    elif frequency == 'weekly':
                        current_date = current_date + timedelta(days=7)
                    elif frequency == 'daily':
                        current_date = current_date + timedelta(days=1)
                    else:
                        break
        
        return scheduled
    
    async def _get_average_daily_expenses(self, user_id: str) -> float:
        """Calculate average daily non-recurring expenses"""
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            # Get last 90 days average
            lookback = (date.today() - timedelta(days=90)).isoformat()
            
            cursor = await db.execute('''
                SELECT AVG(daily_total) as avg_daily
                FROM (
                    SELECT date, SUM(amount) as daily_total
                    FROM transactions
                    WHERE user_id = ?
                    AND type = 'expense'
                    AND date >= ?
                    AND is_recurring = 0
                    GROUP BY date
                )
            ''', (user_id, lookback))
            
            result = await cursor.fetchone()
            return result[0] if result[0] else 0.0
    
    async def _calculate_monthly_burn_rate(self, user_id: str) -> float:
        """Calculate average monthly burn rate (expenses - income)"""
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            # Get last 3 months
            lookback = (date.today() - timedelta(days=90)).isoformat()
            
            cursor = await db.execute('''
                SELECT 
                    SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as expenses,
                    SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as income
                FROM transactions
                WHERE user_id = ?
                AND date >= ?
            ''', (user_id, lookback))
            
            result = await cursor.fetchone()
            
            if result:
                total_expenses = result[0] or 0
                total_income = result[1] or 0
                
                # Monthly average
                monthly_expenses = (total_expenses / 90) * 30
                monthly_income = (total_income / 90) * 30
                
                return monthly_expenses - monthly_income
            
            return 0.0


# Singleton instance
cashflow_forecast_service = CashFlowForecastService()
