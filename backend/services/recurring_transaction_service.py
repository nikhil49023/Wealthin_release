from typing import List, Dict, Any, Optional
from collections import defaultdict
from datetime import datetime, timedelta
import math

class RecurringTransactionService:
    """
    Service to detect recurring transactions (subscriptions, bills, salary)
    based on historical transaction patterns.
    """

    def detect_recurring(self, transactions: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Analyze transactions to find recurring patterns.
        
        Algorithm:
        1. Group transactions by normalized description/merchant.
        2. accurate groups with >= 3 transactions.
        3. Calculate intervals between transactions.
        4. If intervals are consistent (low variance), mark as recurring.
        5. Predict next due date.
        """
        if not transactions:
            return []

        # 1. Group by Merchant/Description
        groups = defaultdict(list)
        for tx in transactions:
            # Normalize description: remove numbers, special chars, "payment to", etc.
            raw_desc = tx.get('merchant') or tx.get('description') or "Unknown"
            clean_desc = self._normalize_description(raw_desc)
            
            # Key usage: (clean_description, type) to separate income/expense
            key = (clean_desc, tx.get('type', 'expense'))
            groups[key].append(tx)

        recurring_items = []

        # 2. Analyze each group
        for (desc, tx_type), tx_list in groups.items():
            # Need at least 3 transactions to establish a reliable pattern
            # (Or 2 matches if they are exactly 30 days apart?)
            if len(tx_list) < 2: 
                continue

            # Sort by date
            tx_list.sort(key=lambda x: x.get('date', ''))
            
            # Calculate intervals
            dates = []
            amounts = []
            
            for tx in tx_list:
                try:
                    dt_str = tx.get('date')
                    # Handle multiple date formats if needed, assuming ISO for now
                    if dt_str:
                        dt = datetime.fromisoformat(dt_str.replace('Z', '+00:00'))
                        dates.append(dt)
                        amounts.append(float(tx.get('amount', 0)))
                except ValueError:
                    continue

            if len(dates) < 2:
                continue

            # Check Amount Consistency
            avg_amount = sum(amounts) / len(amounts)
            amount_variance = sum((a - avg_amount) ** 2 for a in amounts) / len(amounts)
            amount_std_dev = math.sqrt(amount_variance)
            
            # If amounts vary wildly (e.g. erratic spending at a grocery store), likely not a fixed subscription
            # But could be a variable bill (electricity).
            # We enforce stricter amount consistency for subscriptions.
            is_fixed_amount = amount_std_dev < (avg_amount * 0.1) # 10% tolerance

            # Check Inteval Consistency
            intervals = []
            for i in range(1, len(dates)):
                diff = (dates[i] - dates[i-1]).days
                intervals.append(diff)
            
            avg_interval = sum(intervals) / len(intervals)
            
            # Determine Frequency
            frequency = "variable"
            confidence = 0.0
            
            # Check for standard intervals with some jitter (±3 days)
            if 25 <= avg_interval <= 35:
                frequency = "monthly"
                confidence = 0.9 if self._is_consistent(intervals, 30, 5) else 0.6
            elif 6 <= avg_interval <= 8:
                frequency = "weekly"
                confidence = 0.9 if self._is_consistent(intervals, 7, 2) else 0.6
            elif 13 <= avg_interval <= 16:
                frequency = "bi-weekly"
                confidence = 0.8
            elif 350 <= avg_interval <= 380:
                frequency = "yearly"
                confidence = 0.9
            
            # If variable amount but consistent monthly date, likely a utility bill
            category = tx_list[0].get('category', 'Other')
            
            if frequency != "variable" and confidence > 0.5:
                # Predict Next Date
                last_date = dates[-1]
                next_date = last_date + timedelta(days=avg_interval)
                
                recurring_items.append({
                    "merchant": desc,
                    "amount": round(avg_amount, 2),
                    "type": tx_type,
                    "frequency": frequency,
                    "confidence": round(confidence, 2),
                    "category": category,
                    "next_due_date": next_date.isoformat(),
                    "last_paid_date": last_date.isoformat(),
                    "history_count": len(tx_list),
                    "is_fixed_amount": is_fixed_amount
                })

        # Sort by next due date
        recurring_items.sort(key=lambda x: x['next_due_date'])
        
        return recurring_items

    def _normalize_description(self, description: str) -> str:
        """Clean up description for grouping."""
        desc = description.lower()
        
        # Remove common prefixes/suffixes
        remove_words = ["payment to", "transfer to", "purchase at", "upi-", "pos-"]
        for word in remove_words:
            desc = desc.replace(word, "")
            
        # Remove numbers (often transaction IDs)
        # Simple cleanup - keep only letters and crucial spaces
        # Using a simplistic approach: merge if first 5-10 chars match? 
        # For now, just simplistic stripping
        return desc.strip().title()

    def _is_consistent(self, intervals: List[int], target: int, tolerance: int) -> bool:
        """Check if all intervals are within tolerance of target."""
        return all(abs(i - target) <= tolerance for i in intervals)

# Singleton
recurring_transaction_service = RecurringTransactionService()
