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

    async def analyze_spending_patterns(self, transactions: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Analyze raw transaction payloads from mobile/desktop clients.
        Used by `/analyze/spending` for local-first analytics and subscription heuristics.
        """
        if not transactions:
            return {
                "total_income": 0.0,
                "total_expenses": 0.0,
                "net_savings": 0.0,
                "savings_rate": 0.0,
                "category_breakdown": {},
                "top_category": None,
                "monthly_data": {},
                "total_transactions": 0,
                "insights": ["Add transactions to unlock personalized insights."],
            }

        income_types = {"income", "credit", "deposit"}
        expense_types = {"expense", "debit"}

        total_income = 0.0
        total_expenses = 0.0
        category_totals = defaultdict(float)
        monthly_totals = defaultdict(lambda: {"income": 0.0, "expenses": 0.0, "savings": 0.0})

        for tx in transactions:
            try:
                amount = float(tx.get("amount", 0) or 0)
            except (TypeError, ValueError):
                amount = 0.0

            tx_type = str(tx.get("type", "expense") or "expense").strip().lower()
            category = str(tx.get("category", "Other") or "Other").strip() or "Other"

            date_raw = str(tx.get("date", "") or "").strip()
            month_key = None
            if date_raw:
                try:
                    parsed_date = datetime.fromisoformat(date_raw.replace("Z", "+00:00"))
                    month_key = parsed_date.strftime("%Y-%m")
                except ValueError:
                    # Keep analytics resilient even with loosely formatted dates.
                    month_key = date_raw[:7] if len(date_raw) >= 7 else None

            normalized_amount = abs(amount)

            if tx_type not in income_types and tx_type not in expense_types:
                tx_type = "income" if amount < 0 else "expense"

            if tx_type in income_types:
                total_income += normalized_amount
                if month_key:
                    monthly_totals[month_key]["income"] += normalized_amount
            else:
                total_expenses += normalized_amount
                category_totals[category] += normalized_amount
                if month_key:
                    monthly_totals[month_key]["expenses"] += normalized_amount

        net_savings = total_income - total_expenses
        savings_rate = (net_savings / total_income * 100) if total_income > 0 else 0.0

        for month, values in monthly_totals.items():
            values["savings"] = values["income"] - values["expenses"]
            values["income"] = round(values["income"], 2)
            values["expenses"] = round(values["expenses"], 2)
            values["savings"] = round(values["savings"], 2)

        category_breakdown = {
            category: round(total, 2)
            for category, total in sorted(category_totals.items(), key=lambda item: item[1], reverse=True)
        }

        top_category = None
        if category_breakdown and total_expenses > 0:
            top_name, top_amount = next(iter(category_breakdown.items()))
            top_category = {
                "category": top_name,
                "amount": top_amount,
                "percentage": round((top_amount / total_expenses) * 100, 2),
            }

        insights: List[str] = []
        if total_income <= 0 and total_expenses > 0:
            insights.append("No income transactions detected in this dataset.")
        if savings_rate < 10 and total_income > 0:
            insights.append("Savings rate is below 10%; review top spending categories.")
        if top_category:
            insights.append(
                f"Highest spending is in {top_category['category']} ({top_category['percentage']}%)."
            )
        if not insights:
            insights.append("Spending pattern looks balanced.")

        return {
            "total_income": round(total_income, 2),
            "total_expenses": round(total_expenses, 2),
            "net_savings": round(net_savings, 2),
            "savings_rate": round(savings_rate, 2),
            "category_breakdown": category_breakdown,
            "top_category": top_category,
            "monthly_data": dict(sorted(monthly_totals.items())),
            "total_transactions": len(transactions),
            "insights": insights,
        }

# Singleton
analytics_service = AnalyticsService()
