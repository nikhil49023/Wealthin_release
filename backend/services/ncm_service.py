"""
WealthIn NCM (National Contribution Milestone) Engine
Gamifies user's economic contribution with C+S+T score.
Aligns with RBI's FREE-AI Framework and Viksit Bharat 2047.
"""

import aiosqlite
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List
from dataclasses import dataclass
import os

# Database path
PLANNING_DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'planning.db')


@dataclass
class NCMScore:
    """
    National Contribution Milestone Score
    C = Consumption (Formalized Transactions)
    S = Savings (Structured Savings)
    T = Tax (Tax Contributions)
    """
    consumption_score: float  # Points from formalized transactions
    savings_score: float      # Points from structured savings
    tax_score: float          # Points from tax payments
    total_score: float
    milestone: str            # Current milestone name
    next_milestone: str       # Next milestone target
    progress_to_next: float   # 0-100%
    

# Milestone definitions (Viksit Bharat 2047 themed)
MILESTONES = [
    (0, "Citizen", "Starting your journey"),
    (100, "Contributor", "Making an impact"),
    (500, "Builder", "Building the nation"),
    (1000, "Catalyst", "Catalyzing growth"),
    (2500, "Patron", "Patronizing development"),
    (5000, "Sovereign Patron", "Champion of sovereign investments"),
    (10000, "Nation Builder", "Elite contributor to Viksit Bharat"),
]


class NCMService:
    """
    National Contribution Milestone Engine
    
    Scoring Logic:
    - Consumption (C): ₹1000 formalized = 1 point
    - Savings (S): ₹1000 saved = 1.5 points (bonus for structured savings)
    - Tax (T): ₹1000 GST/Income Tax = 2 points
    - Sovereign Bonus: Sovereign Bonds = 3x multiplier
    """

    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    async def initialize(self):
        """Create NCM tracking table if not exists."""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            await db.execute('''
                CREATE TABLE IF NOT EXISTS ncm_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    date TEXT NOT NULL,
                    consumption_total REAL DEFAULT 0,
                    savings_total REAL DEFAULT 0,
                    tax_total REAL DEFAULT 0,
                    sovereign_investments REAL DEFAULT 0,
                    points_earned REAL DEFAULT 0,
                    created_at TEXT NOT NULL
                )
            ''')
            await db.execute('CREATE INDEX IF NOT EXISTS idx_ncm_user ON ncm_history(user_id)')
            await db.commit()
            print("✅ NCM Engine initialized")

    async def calculate_score(self, user_id: str) -> NCMScore:
        """
        Calculate the user's current NCM score.
        """
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            
            # Get totals from history
            cursor = await db.execute('''
                SELECT 
                    COALESCE(SUM(consumption_total), 0) as c_total,
                    COALESCE(SUM(savings_total), 0) as s_total,
                    COALESCE(SUM(tax_total), 0) as t_total,
                    COALESCE(SUM(sovereign_investments), 0) as sov_total
                FROM ncm_history
                WHERE user_id = ?
            ''', (user_id,))
            row = await cursor.fetchone()
            
            c_total = row['c_total'] if row else 0
            s_total = row['s_total'] if row else 0
            t_total = row['t_total'] if row else 0
            sov_total = row['sov_total'] if row else 0
            
            # Calculate points
            c_points = c_total / 1000  # ₹1000 = 1 point
            s_points = s_total / 1000 * 1.5  # ₹1000 = 1.5 points
            t_points = t_total / 1000 * 2  # ₹1000 = 2 points
            sov_bonus = sov_total / 1000 * 3  # Sovereign = 3x
            
            total_points = c_points + s_points + t_points + sov_bonus
            
            # Determine milestone
            current_milestone = MILESTONES[0]
            next_milestone = MILESTONES[1] if len(MILESTONES) > 1 else None
            
            for i, (threshold, name, desc) in enumerate(MILESTONES):
                if total_points >= threshold:
                    current_milestone = (threshold, name, desc)
                    if i + 1 < len(MILESTONES):
                        next_milestone = MILESTONES[i + 1]
                    else:
                        next_milestone = None
            
            # Calculate progress to next
            progress = 0.0
            if next_milestone:
                current_threshold = current_milestone[0]
                next_threshold = next_milestone[0]
                if next_threshold > current_threshold:
                    progress = ((total_points - current_threshold) / (next_threshold - current_threshold)) * 100
                    progress = min(max(progress, 0), 100)
            else:
                progress = 100.0
            
            return NCMScore(
                consumption_score=c_points,
                savings_score=s_points,
                tax_score=t_points,
                total_score=total_points,
                milestone=current_milestone[1],
                next_milestone=next_milestone[1] if next_milestone else "Maximum",
                progress_to_next=progress
            )

    async def record_contribution(
        self,
        user_id: str,
        consumption: float = 0,
        savings: float = 0,
        tax: float = 0,
        sovereign: float = 0
    ) -> Dict[str, Any]:
        """
        Record a contribution to the NCM ledger.
        Called when transactions are processed.
        """
        now = datetime.utcnow()
        date_str = now.date().isoformat()
        
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            # Check if entry exists for today
            cursor = await db.execute('''
                SELECT id FROM ncm_history 
                WHERE user_id = ? AND date = ?
            ''', (user_id, date_str))
            existing = await cursor.fetchone()
            
            if existing:
                # Update existing
                await db.execute('''
                    UPDATE ncm_history 
                    SET consumption_total = consumption_total + ?,
                        savings_total = savings_total + ?,
                        tax_total = tax_total + ?,
                        sovereign_investments = sovereign_investments + ?
                    WHERE user_id = ? AND date = ?
                ''', (consumption, savings, tax, sovereign, user_id, date_str))
            else:
                # Create new
                await db.execute('''
                    INSERT INTO ncm_history 
                    (user_id, date, consumption_total, savings_total, tax_total, sovereign_investments, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (user_id, date_str, consumption, savings, tax, sovereign, now.isoformat()))
            
            await db.commit()
        
        # Return updated score
        score = await self.calculate_score(user_id)
        return {
            'success': True,
            'score': score.total_score,
            'milestone': score.milestone,
            'added': {
                'consumption': consumption,
                'savings': savings,
                'tax': tax,
                'sovereign': sovereign
            }
        }

    async def get_insight(self, user_id: str) -> Dict[str, Any]:
        """
        Generate NCM insight for the user (Viksit Bharat themed).
        """
        score = await self.calculate_score(user_id)
        
        # Format amounts
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            cursor = await db.execute('''
                SELECT COALESCE(SUM(consumption_total + savings_total + tax_total + sovereign_investments), 0)
                FROM ncm_history WHERE user_id = ?
            ''', (user_id,))
            row = await cursor.fetchone()
            total_formalized = row[0] if row else 0
        
        # Generate insight message
        if total_formalized >= 100000:
            insight = f"You've formalized ₹{total_formalized/1000:.0f}K this year. You're {score.progress_to_next:.0f}% closer to becoming a '{score.next_milestone}'!"
        elif total_formalized >= 50000:
            insight = f"Great progress! ₹{total_formalized/1000:.0f}K formalized. Keep building towards Viksit Bharat 2047!"
        elif total_formalized > 0:
            insight = f"You've started your journey! ₹{total_formalized/1000:.1f}K formalized so far."
        else:
            insight = "Start your contribution journey! Every transaction moves India forward."
        
        return {
            'score': score.total_score,
            'milestone': score.milestone,
            'next_milestone': score.next_milestone,
            'progress': score.progress_to_next,
            'insight': insight,
            'total_formalized': total_formalized,
            'breakdown': {
                'consumption': score.consumption_score,
                'savings': score.savings_score,
                'tax': score.tax_score
            }
        }


# Singleton instance
ncm_service = NCMService()
