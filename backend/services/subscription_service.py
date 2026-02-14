"""
Subscription Detection Service for Wealthin

Implements pattern recognition for recurring payments using:
1. Merchant clustering by entity ID / name
2. Amount variance analysis (low variance = subscription)
3. Temporal frequency analysis (SD of time delta < 1.5 days = monthly sub)

This enables users to discover "silent drains" in their finances.
"""

import logging
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from collections import defaultdict
import statistics
import aiosqlite

from .database_service import TRANSACTIONS_DB_PATH

logger = logging.getLogger(__name__)


class SubscriptionService:
    """
    Detects recurring payments and subscriptions from transaction history.
    """

    # Thresholds for detection
    TIME_DELTA_SD_THRESHOLD = 3.0  # Max standard deviation in days for "regular" recurrence
    AMOUNT_VARIANCE_THRESHOLD = 0.1  # Max coefficient of variation for "fixed" amount (10%)
    MIN_OCCURRENCES = 2  # Minimum times a payment must appear to be considered recurring

    async def detect_subscriptions(self, user_id: str, months_back: int = 6) -> Dict[str, Any]:
        """
        Analyzes transaction history to find recurring payments.
        
        Returns:
            {
                "subscriptions": [...],  # Detected subscriptions
                "recurring_habits": [...],  # More variable recurring payments (coffee, etc)
                "total_monthly_cost": float,
                "annual_projection": float
            }
        """
        logger.info(f"Detecting subscriptions for user {user_id}, looking back {months_back} months")
        
        start_date = (datetime.now() - timedelta(days=months_back * 30)).strftime('%Y-%m-%d')
        
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            
            # Get all expense transactions grouped by merchant/description
            query = '''
                SELECT id, description, amount, date, category, merchant
                FROM transactions
                WHERE user_id = ? 
                  AND LOWER(type) IN ('expense', 'debit')
                  AND date >= ?
                ORDER BY description, date
            '''
            cursor = await db.execute(query, (user_id, start_date))
            rows = await cursor.fetchall()
            
            if not rows:
                return {
                    "subscriptions": [],
                    "recurring_habits": [],
                    "total_monthly_cost": 0.0,
                    "annual_projection": 0.0
                }
            
            # Group transactions by merchant/description for pattern analysis
            grouped = self._group_by_merchant(rows)
            
            subscriptions = []
            recurring_habits = []
            
            for merchant_key, transactions in grouped.items():
                if len(transactions) < self.MIN_OCCURRENCES:
                    continue
                
                pattern = self._analyze_pattern(transactions)
                
                if pattern['is_subscription']:
                    subscriptions.append({
                        'merchant': merchant_key,
                        'category': transactions[0]['category'],
                        'frequency': pattern['frequency'],
                        'average_amount': pattern['avg_amount'],
                        'last_charge': transactions[-1]['date'],
                        'next_expected': pattern['next_expected'],
                        'occurrences': len(transactions),
                        'confidence': pattern['confidence']
                    })
                elif pattern['is_recurring_habit']:
                    recurring_habits.append({
                        'merchant': merchant_key,
                        'category': transactions[0]['category'],
                        'frequency': pattern['frequency'],
                        'average_amount': pattern['avg_amount'],
                        'amount_variance': pattern['amount_cv'],
                        'occurrences': len(transactions)
                    })
            
            # Sort by monthly impact
            subscriptions.sort(key=lambda x: x['average_amount'], reverse=True)
            recurring_habits.sort(key=lambda x: x['average_amount'] * x['occurrences'], reverse=True)
            
            # Calculate totals
            monthly_sub_cost = sum(
                self._normalize_to_monthly(s['average_amount'], s['frequency']) 
                for s in subscriptions
            )
            
            return {
                "subscriptions": subscriptions,
                "recurring_habits": recurring_habits[:10],  # Top 10 habits
                "total_monthly_cost": round(monthly_sub_cost, 2),
                "annual_projection": round(monthly_sub_cost * 12, 2)
            }

    def _group_by_merchant(self, transactions: List) -> Dict[str, List[Dict]]:
        """
        Groups transactions by a normalized merchant key.
        Uses merchant field if available, otherwise normalizes description.
        """
        grouped = defaultdict(list)
        
        for tx in transactions:
            # Prefer merchant field, fall back to cleaned description
            merchant = tx['merchant'] if tx['merchant'] else tx['description']
            key = self._normalize_merchant_name(merchant)
            
            grouped[key].append({
                'id': tx['id'],
                'description': tx['description'],
                'amount': abs(float(tx['amount'])),
                'date': tx['date'],
                'category': tx['category'] or 'Other'
            })
        
        return grouped

    def _normalize_merchant_name(self, name: str) -> str:
        """
        Cleans and normalizes merchant names for better grouping.
        e.g., "NETFLIX.COM*123456" -> "netflix"
        """
        if not name:
            return "unknown"
        
        import re
        # Remove transaction IDs, numbers, special chars
        cleaned = re.sub(r'[*#\d]+', '', name.lower())
        cleaned = re.sub(r'[^\w\s]', '', cleaned)
        cleaned = cleaned.strip()
        
        # Common suffixes to remove
        for suffix in ['.com', 'com', 'inc', 'ltd', 'pvt', 'private', 'limited']:
            cleaned = cleaned.replace(suffix, '')
        
        return cleaned.strip() or "unknown"

    def _analyze_pattern(self, transactions: List[Dict]) -> Dict[str, Any]:
        """
        Analyzes a set of transactions from the same merchant to detect patterns.
        
        Returns pattern analysis including:
        - is_subscription: True if regular fixed-amount payment
        - is_recurring_habit: True if irregular but frequent
        - frequency: 'weekly', 'bi-weekly', 'monthly', 'quarterly', 'irregular'
        - confidence: 0-1 score
        """
        amounts = [tx['amount'] for tx in transactions]
        dates = [datetime.strptime(tx['date'][:10], '%Y-%m-%d') for tx in transactions]
        
        # Sort by date
        sorted_pairs = sorted(zip(dates, amounts), key=lambda x: x[0])
        dates = [p[0] for p in sorted_pairs]
        amounts = [p[1] for p in sorted_pairs]
        
        # Calculate time deltas between consecutive transactions
        if len(dates) >= 2:
            deltas = [(dates[i+1] - dates[i]).days for i in range(len(dates)-1)]
            avg_delta = statistics.mean(deltas)
            delta_sd = statistics.stdev(deltas) if len(deltas) > 1 else 0
        else:
            avg_delta = 30  # Assume monthly if only one occurrence
            delta_sd = 0
            deltas = []
        
        # Calculate amount statistics
        avg_amount = statistics.mean(amounts)
        amount_sd = statistics.stdev(amounts) if len(amounts) > 1 else 0
        amount_cv = (amount_sd / avg_amount) if avg_amount > 0 else 0  # Coefficient of variation
        
        # Determine frequency
        frequency = self._determine_frequency(avg_delta)
        
        # Subscription criteria:
        # 1. Low time delta variance (regular schedule)
        # 2. Low amount variance (fixed price)
        is_subscription = (
            delta_sd <= self.TIME_DELTA_SD_THRESHOLD and 
            amount_cv <= self.AMOUNT_VARIANCE_THRESHOLD and
            len(transactions) >= self.MIN_OCCURRENCES
        )
        
        # Recurring habit criteria:
        # Somewhat regular but with more variance
        is_recurring_habit = (
            not is_subscription and
            avg_delta <= 35 and  # At least monthly on average
            len(transactions) >= 3
        )
        
        # Calculate confidence score
        confidence = self._calculate_confidence(
            len(transactions), delta_sd, amount_cv, avg_delta
        )
        
        # Predict next expected date
        next_expected = None
        if dates and frequency != 'irregular':
            last_date = max(dates)
            next_expected = (last_date + timedelta(days=avg_delta)).strftime('%Y-%m-%d')
        
        return {
            'is_subscription': is_subscription,
            'is_recurring_habit': is_recurring_habit,
            'frequency': frequency,
            'avg_amount': round(avg_amount, 2),
            'amount_cv': round(amount_cv, 3),
            'time_delta_sd': round(delta_sd, 2),
            'avg_delta_days': round(avg_delta, 1),
            'next_expected': next_expected,
            'confidence': round(confidence, 2)
        }

    def _determine_frequency(self, avg_delta: float) -> str:
        """Determines the frequency label based on average days between payments."""
        if avg_delta <= 8:
            return 'weekly'
        elif avg_delta <= 16:
            return 'bi-weekly'
        elif avg_delta <= 35:
            return 'monthly'
        elif avg_delta <= 100:
            return 'quarterly'
        elif avg_delta <= 200:
            return 'semi-annual'
        elif avg_delta <= 400:
            return 'annual'
        else:
            return 'irregular'

    def _normalize_to_monthly(self, amount: float, frequency: str) -> float:
        """Converts an amount to its monthly equivalent based on frequency."""
        multipliers = {
            'weekly': 4.33,
            'bi-weekly': 2.17,
            'monthly': 1.0,
            'quarterly': 0.33,
            'semi-annual': 0.167,
            'annual': 0.083,
            'irregular': 1.0  # Assume monthly for irregular
        }
        return amount * multipliers.get(frequency, 1.0)

    def _calculate_confidence(
        self, 
        occurrences: int, 
        delta_sd: float, 
        amount_cv: float,
        avg_delta: float
    ) -> float:
        """
        Calculates a confidence score (0-1) for the subscription detection.
        
        Higher confidence with:
        - More occurrences
        - Lower time variance
        - Lower amount variance
        - Reasonable frequency (not too rare)
        """
        # Occurrence weight (more = better, caps at 12)
        occ_score = min(occurrences / 12, 1.0)
        
        # Time regularity (lower SD = better)
        time_score = max(0, 1 - (delta_sd / 10))
        
        # Amount consistency (lower CV = better)
        amount_score = max(0, 1 - (amount_cv / 0.5))
        
        # Frequency reasonableness (monthly-ish is best)
        freq_score = 1.0 if 20 <= avg_delta <= 40 else 0.8
        
        # Weighted average
        confidence = (
            occ_score * 0.3 + 
            time_score * 0.3 + 
            amount_score * 0.25 + 
            freq_score * 0.15
        )
        
        return min(confidence, 1.0)

    async def get_subscription_audit(self, user_id: str) -> Dict[str, Any]:
        """
        High-level audit of subscription spending.
        
        Returns insights for the user about their subscription "burden".
        """
        detection_result = await self.detect_subscriptions(user_id)
        
        subscriptions = detection_result['subscriptions']
        monthly_cost = detection_result['total_monthly_cost']
        
        # Categorize subscriptions
        by_category = defaultdict(lambda: {'count': 0, 'monthly_cost': 0})
        for sub in subscriptions:
            cat = sub['category']
            by_category[cat]['count'] += 1
            by_category[cat]['monthly_cost'] += self._normalize_to_monthly(
                sub['average_amount'], sub['frequency']
            )
        
        # Generate insights
        insights = []
        if monthly_cost > 5000:
            insights.append({
                'type': 'warning',
                'message': f'Your subscriptions cost ₹{monthly_cost:,.0f}/month. Consider auditing inactive services.'
            })
        
        if len(subscriptions) > 5:
            insights.append({
                'type': 'info',
                'message': f'You have {len(subscriptions)} active subscriptions. Some may overlap in functionality.'
            })
        
        # Find potentially forgotten subscriptions (high confidence, small amount)
        forgotten = [s for s in subscriptions if s['average_amount'] < 500 and s['confidence'] > 0.7]
        if forgotten:
            insights.append({
                'type': 'tip',
                'message': f'{len(forgotten)} small subscriptions (under ₹500) may be going unnoticed.'
            })
        
        return {
            'subscriptions': subscriptions,
            'by_category': dict(by_category),
            'total_monthly': round(monthly_cost, 2),
            'total_annual': round(monthly_cost * 12, 2),
            'insights': insights
        }


# Singleton instance
subscription_service = SubscriptionService()
