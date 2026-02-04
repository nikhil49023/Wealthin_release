from typing import List, Dict, Any, Optional, Tuple
from collections import defaultdict
from dataclasses import dataclass

class TrendsService:
    """
    Analyzes transaction patterns to provide AI context.
    Does NOT store trend data in a database; calculates on-the-fly.
    """
    
    @dataclass
    class TrendContext:
        ai_context: str
        top_income_sources: List[Tuple[str, float]]
        top_expense_sources: List[Tuple[str, float]]
        total_income: float
        total_spent: float
        savings_rate: float
        top_spending_category: str
    
    async def analyze_transactions(
        self, 
        transactions: List[Dict[str, Any]], 
        user_id: str, 
        period_days: int = 30
    ) -> TrendContext:
        """
        Analyze recent transactions to identify major income/expense sources.
        """
        if not transactions:
            return self.TrendContext(
                ai_context="No recent transactions found.",
                top_income_sources=[],
                top_expense_sources=[],
                total_income=0,
                total_spent=0,
                savings_rate=0,
                top_spending_category="None"
            )
            
        income_map = defaultdict(float)
        expense_map = defaultdict(float)
        
        total_income = 0
        total_expense = 0
        
        for tx in transactions:
            amount = float(tx.get('amount', 0))
            desc = tx.get('merchant') or tx.get('description') or "Unknown"
            category = tx.get('category', 'Other')
            tx_type = tx.get('type')
            
            # Use Merchant Name if available, else Description
            source_name = desc.strip()
            # Clean up common prefixes
            if source_name.lower().startswith("paid to "):
                source_name = source_name[8:]
            elif source_name.lower().startswith("received from "):
                source_name = source_name[14:]

            if tx_type == 'income':
                income_map[source_name] += amount
                total_income += amount
            else:
                expense_map[source_name] += amount
                total_expense += amount
                
        # Sort and get Top 5
        sorted_income = sorted(income_map.items(), key=lambda x: x[1], reverse=True)[:5]
        sorted_expense = sorted(expense_map.items(), key=lambda x: x[1], reverse=True)[:5]
        
        # Build AI Context String
        context_str = f"Financial Snapshot (Last {period_days} Days):\n"
        context_str += f"Total Income: ₹{total_income:,.0f} | Total Spent: ₹{total_expense:,.0f}\n\n"
        
        if sorted_income:
            context_str += "Major Income Sources:\n"
            for source, amt in sorted_income:
                context_str += f"- {source}: ₹{amt:,.0f}\n"
        
        if sorted_expense:
            context_str += "\nMajor Expenses:\n"
            for source, amt in sorted_expense:
                context_str += f"- {source}: ₹{amt:,.0f}\n"

        # Category Analysis
        category_map = defaultdict(float)
        for tx in transactions:
            if tx.get('type') == 'expense':
                category_map[tx.get('category', 'Other')] += float(tx.get('amount', 0))
        
        sorted_categories = sorted(category_map.items(), key=lambda x: x[1], reverse=True)
        top_cat = sorted_categories[0][0] if sorted_categories else "None"
        
        if sorted_categories:
            context_str += "\nSpending by Category:\n"
            for cat, amt in sorted_categories:
                context_str += f"- {cat}: ₹{amt:,.0f}\n"

        # Highlight Priority Categories
        priority_cats = ['Medical', 'Education', 'Legal']
        context_str += "\nPriority Spending Alert:\n"
        has_priority = False
        for cat in priority_cats:
            if category_map.get(cat, 0) > 0:
                context_str += f"⚠️ {cat}: ₹{category_map[cat]:,.0f}\n"
                has_priority = True
        
        if not has_priority:
            context_str += "None detected this period.\n"

        savings_rate = 0.0
        if total_income > 0:
            savings_rate = ((total_income - total_expense) / total_income) * 100

        return self.TrendContext(
            ai_context=context_str,
            top_income_sources=sorted_income,
            top_expense_sources=sorted_expense,
            total_income=total_income,
            total_spent=total_expense,
            savings_rate=round(savings_rate, 1),
            top_spending_category=top_cat
        )

# Singleton
trends_service = TrendsService()
