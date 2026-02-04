import aiosqlite
import logging
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from collections import defaultdict
import pandas as pd
from .database_service import TRANSACTIONS_DB_PATH, database_service

logger = logging.getLogger(__name__)

class AnalyticsService:
    """
    Service for Trend Analysis and Data Aggregation.
    """
    
    async def refresh_daily_trends(self, user_id: str):
        """
        Re-calculates daily income/expense totals from the transactions table
        and populates the daily_trends cache table.
        """
        logger.info(f"Refreshing daily trends for user {user_id}")
        
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            # Clear existing trends for user to ensure fresh calc
            await db.execute("DELETE FROM daily_trends WHERE user_id = ?", (user_id,))
            
            # Aggregate per day
            # Group by date
            query = '''
                SELECT date, type, SUM(amount) 
                FROM transactions 
                WHERE user_id = ? 
                GROUP BY date, type
            '''
            cursor = await db.execute(query, (user_id,))
            rows = await cursor.fetchall()
            
            # Process in memory to merge income/expense per day
            daily_data = defaultdict(lambda: {"income": 0.0, "expense": 0.0})
            
            for date_str, tx_type, amount in rows:
                if tx_type == 'income':
                    daily_data[date_str]['income'] += amount
                elif tx_type == 'expense':
                    daily_data[date_str]['expense'] += amount
            
            # Bulk Insert
            if daily_data:
                insert_query = '''
                    INSERT INTO daily_trends (user_id, date, total_spent, total_income)
                    VALUES (?, ?, ?, ?)
                '''
                data_to_insert = [
                    (user_id, date, vals['expense'], vals['income'])
                    for date, vals in daily_data.items()
                ]
                
                await db.executemany(insert_query, data_to_insert)
                await db.commit()
                logger.info(f"Updated daily trends for {len(data_to_insert)} days")

    async def get_monthly_trends(self, user_id: str, months: int = 6) -> List[Dict[str, Any]]:
        """
        Get monthly spending/income trends for the last N months.
        Returns list sorted by Month.
        """
        # Ensure trends are updated (optional, could be async job)
        # await self.refresh_daily_trends(user_id) 
        
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            # We can aggregate from proper transactions table for accuracy
            # SQLite doesn't have great date functions, usually use strftime
            query = '''
                SELECT strftime('%Y-%m', date) as month, type, SUM(amount)
                FROM transactions
                WHERE user_id = ?
                GROUP BY month, type
                ORDER BY month DESC
                LIMIT ?
            '''
            # Limit needs to be higher because we split by type
            cursor = await db.execute(query, (user_id, months * 3)) 
            rows = await cursor.fetchall()
            
            monthly_data = defaultdict(lambda: {"month": "", "income": 0.0, "expense": 0.0, "savings": 0.0})
            
            for month, tx_type, amount in rows:
                if not month: continue
                monthly_data[month]["month"] = month
                if tx_type == 'income':
                    monthly_data[month]['income'] = amount
                else:
                    monthly_data[month]['expense'] = amount
            
            # Calculate savings
            results = []
            for m in monthly_data.values():
                m['savings'] = m['income'] - m['expense']
                results.append(m)
                
            return sorted(results, key=lambda x: x['month'])

    async def get_category_analysis(self, user_id: str, month: str = None) -> Dict[str, Any]:
        """
        Get category breakdown for a specific month (YYYY-MM) or all time.
        """
        start_date = f"{month}-01" if month else "2000-01-01"
        end_date = f"{month}-31" if month else "2099-12-31"
        
        summary = await database_service.get_spending_summary(user_id, start_date, end_date)
        return summary['by_category']

    async def predict_next_month_expenses(self, user_id: str) -> float:
        """
        Simple moving average prediction for next month's total expenses.
        """
        trends = await self.get_monthly_trends(user_id, months=3)
        if not trends:
            return 0.0
            
        total_expenses = sum(t['expense'] for t in trends)
        avg = total_expenses / len(trends)
        return round(avg, 2)

# Singleton
analytics_service = AnalyticsService()
