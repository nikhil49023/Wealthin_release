"""
WealthIn MongoDB Service
NoSQL database for analysis data, milestones, DPR documents, and idea evaluations.
Uses motor (async MongoDB driver) for non-blocking operations.
Falls back to in-memory storage if MongoDB is not available.
"""

import os
import logging
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# Try to import motor, fall back to dict-based storage
try:
    from motor.motor_asyncio import AsyncIOMotorClient
    HAS_MOTOR = True
except ImportError:
    HAS_MOTOR = False
    logger.warning("motor not installed - using in-memory fallback for NoSQL storage")

MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017")
MONGO_DB_NAME = os.getenv("MONGO_DB_NAME", "wealthin")


class MongoService:
    """
    MongoDB service for storing analysis snapshots, milestones,
    idea evaluations, DPR documents, and financial metrics history.
    """

    _instance = None
    _initialized = False

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        self._client = None
        self._db = None
        # In-memory fallback stores
        self._memory_store: Dict[str, List[Dict]] = {
            "analysis_snapshots": [],
            "milestones": [],
            "idea_evaluations": [],
            "dpr_documents": [],
            "financial_metrics": [],
            "budget_auto_sync": [],
            "mudra_dprs": [],
        }

    async def initialize(self):
        """Initialize MongoDB connection"""
        if self._initialized:
            return

        if HAS_MOTOR:
            try:
                self._client = AsyncIOMotorClient(MONGO_URI, serverSelectionTimeoutMS=3000)
                # Test connection
                await self._client.admin.command("ping")
                self._db = self._client[MONGO_DB_NAME]

                # Create indexes
                await self._db.analysis_snapshots.create_index([("user_id", 1), ("created_at", -1)])
                await self._db.milestones.create_index([("user_id", 1), ("achieved", 1)])
                await self._db.idea_evaluations.create_index([("user_id", 1), ("created_at", -1)])
                await self._db.dpr_documents.create_index([("user_id", 1), ("created_at", -1)])
                await self._db.financial_metrics.create_index([("user_id", 1), ("month", -1)])
                await self._db.budget_auto_sync.create_index([("user_id", 1)])
                await self._db.mudra_dprs.create_index([("user_id", 1), ("created_at", -1)])

                logger.info(f"✅ MongoDB connected: {MONGO_URI}/{MONGO_DB_NAME}")
                self._initialized = True
                return
            except Exception as e:
                logger.warning(f"MongoDB connection failed: {e} - using in-memory fallback")
                self._client = None
                self._db = None

        logger.info("Using in-memory NoSQL storage (no MongoDB)")
        self._initialized = True

    @property
    def is_mongo_available(self) -> bool:
        return self._db is not None

    # ==================== ANALYSIS SNAPSHOTS ====================

    async def save_analysis_snapshot(self, user_id: str, analysis_data: Dict[str, Any]) -> str:
        """Save a point-in-time analysis snapshot"""
        doc = {
            "user_id": user_id,
            "created_at": datetime.utcnow().isoformat(),
            "total_income": analysis_data.get("total_income", 0),
            "total_expense": analysis_data.get("total_expense", 0),
            "savings_rate": analysis_data.get("savings_rate", 0),
            "health_score": analysis_data.get("health_score", 0),
            "category_breakdown": analysis_data.get("category_breakdown", {}),
            "insights": analysis_data.get("insights", []),
            "milestones_achieved": analysis_data.get("milestones_achieved", []),
            "month": datetime.utcnow().strftime("%Y-%m"),
        }

        if self._db:
            result = await self._db.analysis_snapshots.insert_one(doc)
            return str(result.inserted_id)
        else:
            doc["_id"] = f"snap_{len(self._memory_store['analysis_snapshots'])}"
            self._memory_store["analysis_snapshots"].append(doc)
            return doc["_id"]

    async def get_analysis_history(self, user_id: str, months: int = 6) -> List[Dict]:
        """Get analysis snapshots for trend comparison"""
        cutoff = (datetime.utcnow() - timedelta(days=months * 30)).isoformat()

        if self._db:
            cursor = self._db.analysis_snapshots.find(
                {"user_id": user_id, "created_at": {"$gte": cutoff}},
                {"_id": 0}
            ).sort("created_at", -1)
            return await cursor.to_list(length=100)
        else:
            return [
                s for s in self._memory_store["analysis_snapshots"]
                if s["user_id"] == user_id and s.get("created_at", "") >= cutoff
            ]

    # ==================== MILESTONES (GAMIFICATION) ====================

    async def get_milestones(self, user_id: str) -> List[Dict]:
        """Get all milestones for a user"""
        if self._db:
            cursor = self._db.milestones.find(
                {"user_id": user_id}, {"_id": 0}
            ).sort("order", 1)
            return await cursor.to_list(length=50)
        else:
            return [m for m in self._memory_store["milestones"] if m["user_id"] == user_id]

    async def check_and_award_milestones(self, user_id: str, metrics: Dict[str, Any]) -> List[Dict]:
        """Check metrics against milestone criteria and award new ones"""
        existing = await self.get_milestones(user_id)
        achieved_ids = {m["milestone_id"] for m in existing if m.get("achieved")}

        # Define milestones
        milestones_definitions = [
            {"milestone_id": "first_transaction", "title": "First Step", "description": "Added your first transaction",
             "icon": "🎯", "xp": 10, "order": 1,
             "check": lambda m: m.get("transaction_count", 0) >= 1},
            {"milestone_id": "budget_creator", "title": "Budget Master", "description": "Created your first budget",
             "icon": "📊", "xp": 15, "order": 2,
             "check": lambda m: m.get("budget_count", 0) >= 1},
            {"milestone_id": "savings_10", "title": "Saver Initiate", "description": "Achieved 10% savings rate",
             "icon": "💰", "xp": 25, "order": 3,
             "check": lambda m: m.get("savings_rate", 0) >= 10},
            {"milestone_id": "savings_20", "title": "Smart Saver", "description": "Achieved 20% savings rate",
             "icon": "🏆", "xp": 50, "order": 4,
             "check": lambda m: m.get("savings_rate", 0) >= 20},
            {"milestone_id": "savings_30", "title": "Savings Champion", "description": "Achieved 30% savings rate",
             "icon": "👑", "xp": 100, "order": 5,
             "check": lambda m: m.get("savings_rate", 0) >= 30},
            {"milestone_id": "health_50", "title": "Financially Fit", "description": "Health score above 50",
             "icon": "💪", "xp": 30, "order": 6,
             "check": lambda m: m.get("health_score", 0) >= 50},
            {"milestone_id": "health_75", "title": "Financial Pro", "description": "Health score above 75",
             "icon": "🌟", "xp": 75, "order": 7,
             "check": lambda m: m.get("health_score", 0) >= 75},
            {"milestone_id": "health_90", "title": "Finance Legend", "description": "Health score above 90",
             "icon": "🔥", "xp": 150, "order": 8,
             "check": lambda m: m.get("health_score", 0) >= 90},
            {"milestone_id": "expense_tracker_50", "title": "Tracker Pro", "description": "Tracked 50+ transactions",
             "icon": "📝", "xp": 40, "order": 9,
             "check": lambda m: m.get("transaction_count", 0) >= 50},
            {"milestone_id": "expense_tracker_200", "title": "Data Driven", "description": "Tracked 200+ transactions",
             "icon": "📈", "xp": 80, "order": 10,
             "check": lambda m: m.get("transaction_count", 0) >= 200},
            {"milestone_id": "under_budget", "title": "Budget Hero", "description": "Stayed under budget for a month",
             "icon": "🛡️", "xp": 60, "order": 11,
             "check": lambda m: m.get("under_budget_months", 0) >= 1},
            {"milestone_id": "goal_achieved", "title": "Goal Crusher", "description": "Completed a savings goal",
             "icon": "🎯", "xp": 100, "order": 12,
             "check": lambda m: m.get("goals_completed", 0) >= 1},
            {"milestone_id": "streak_7", "title": "Week Warrior", "description": "7-day activity streak",
             "icon": "⚡", "xp": 20, "order": 13,
             "check": lambda m: m.get("current_streak", 0) >= 7},
            {"milestone_id": "streak_30", "title": "Month Master", "description": "30-day activity streak",
             "icon": "🔥", "xp": 75, "order": 14,
             "check": lambda m: m.get("current_streak", 0) >= 30},
        ]

        newly_achieved = []
        for mdef in milestones_definitions:
            mid = mdef["milestone_id"]
            if mid not in achieved_ids and mdef["check"](metrics):
                doc = {
                    "user_id": user_id,
                    "milestone_id": mid,
                    "title": mdef["title"],
                    "description": mdef["description"],
                    "icon": mdef["icon"],
                    "xp": mdef["xp"],
                    "order": mdef["order"],
                    "achieved": True,
                    "achieved_at": datetime.utcnow().isoformat(),
                }
                if self._db:
                    await self._db.milestones.insert_one(doc)
                else:
                    self._memory_store["milestones"].append(doc)
                newly_achieved.append(doc)

            elif mid not in achieved_ids:
                # Store as unachieved for progress display
                pass

        return newly_achieved

    async def get_user_xp(self, user_id: str) -> Dict[str, Any]:
        """Get total XP and level for gamification"""
        milestones = await self.get_milestones(user_id)
        total_xp = sum(m.get("xp", 0) for m in milestones if m.get("achieved"))
        # Level calculation: every 100 XP = 1 level
        level = total_xp // 100 + 1
        xp_in_level = total_xp % 100
        return {
            "total_xp": total_xp,
            "level": level,
            "xp_in_current_level": xp_in_level,
            "xp_to_next_level": 100 - xp_in_level,
            "milestones_achieved": len([m for m in milestones if m.get("achieved")]),
            "total_milestones": 14,
        }

    async def get_last_analysis_date(self, user_id: str) -> Optional[datetime]:
        """Get the date of the last analysis snapshot for cooldown check"""
        try:
            if self._db:
                result = await self._db.analysis_snapshots.find_one(
                    {"user_id": user_id},
                    sort=[("created_at", -1)]  # Most recent first
                )
                if result and "created_at" in result:
                    return datetime.fromisoformat(result["created_at"])
            else:
                # In-memory fallback
                user_snapshots = [
                    s for s in self._memory_store["analysis_snapshots"]
                    if s.get("user_id") == user_id
                ]
                if user_snapshots:
                    # Sort by created_at descending
                    user_snapshots.sort(
                        key=lambda x: x.get("created_at", ""),
                        reverse=True
                    )
                    return datetime.fromisoformat(user_snapshots[0]["created_at"])
        except Exception as e:
            logger.error(f"Error getting last analysis date: {e}")
        return None

    async def can_analyze_now(self, user_id: str, cooldown_days: int = 7) -> Dict[str, Any]:
        """Check if user can run analysis based on cooldown period"""
        last_analysis = await self.get_last_analysis_date(user_id)

        if last_analysis is None:
            # No previous analysis, can analyze now
            return {
                "can_analyze": True,
                "last_analysis_date": None,
                "next_analysis_date": None,
                "days_remaining": 0,
                "hours_remaining": 0,
            }

        now = datetime.utcnow()
        time_since_last = now - last_analysis
        cooldown_delta = timedelta(days=cooldown_days)

        if time_since_last >= cooldown_delta:
            # Cooldown period has passed
            return {
                "can_analyze": True,
                "last_analysis_date": last_analysis.isoformat(),
                "next_analysis_date": None,
                "days_remaining": 0,
                "hours_remaining": 0,
            }
        else:
            # Still in cooldown
            time_remaining = cooldown_delta - time_since_last
            next_analysis_date = last_analysis + cooldown_delta
            return {
                "can_analyze": False,
                "last_analysis_date": last_analysis.isoformat(),
                "next_analysis_date": next_analysis_date.isoformat(),
                "days_remaining": time_remaining.days,
                "hours_remaining": time_remaining.seconds // 3600,
            }

    # ==================== IDEA EVALUATIONS ====================

    async def save_idea_evaluation(self, user_id: str, evaluation: Dict[str, Any]) -> str:
        """Save an OpenAI-powered idea evaluation"""
        doc = {
            "user_id": user_id,
            "created_at": datetime.utcnow().isoformat(),
            "idea": evaluation.get("idea", ""),
            "score": evaluation.get("score", 0),
            "viability": evaluation.get("viability", ""),
            "market_analysis": evaluation.get("market_analysis", ""),
            "financial_projection": evaluation.get("financial_projection", {}),
            "strengths": evaluation.get("strengths", []),
            "weaknesses": evaluation.get("weaknesses", []),
            "recommendations": evaluation.get("recommendations", []),
            "competitive_landscape": evaluation.get("competitive_landscape", ""),
            "risk_assessment": evaluation.get("risk_assessment", ""),
        }

        if self._db:
            result = await self._db.idea_evaluations.insert_one(doc)
            return str(result.inserted_id)
        else:
            doc["_id"] = f"idea_{len(self._memory_store['idea_evaluations'])}"
            self._memory_store["idea_evaluations"].append(doc)
            return doc["_id"]

    async def get_idea_evaluations(self, user_id: str, limit: int = 10) -> List[Dict]:
        """Get saved idea evaluations"""
        if self._db:
            cursor = self._db.idea_evaluations.find(
                {"user_id": user_id}, {"_id": 0}
            ).sort("created_at", -1).limit(limit)
            return await cursor.to_list(length=limit)
        else:
            evals = [e for e in self._memory_store["idea_evaluations"] if e["user_id"] == user_id]
            return sorted(evals, key=lambda x: x.get("created_at", ""), reverse=True)[:limit]

    # ==================== DPR DOCUMENTS ====================

    async def save_dpr(self, user_id: str, dpr_data: Dict[str, Any]) -> str:
        """Save a generated DPR document"""
        doc = {
            "user_id": user_id,
            "created_at": datetime.utcnow().isoformat(),
            "business_idea": dpr_data.get("business_idea", ""),
            "sections": dpr_data.get("sections", {}),
            "completeness": dpr_data.get("completeness", 0),
            "status": dpr_data.get("status", "draft"),
            "research_data": dpr_data.get("research_data", {}),
            "financial_projections": dpr_data.get("financial_projections", {}),
        }

        if self._db:
            result = await self._db.dpr_documents.insert_one(doc)
            return str(result.inserted_id)
        else:
            doc["_id"] = f"dpr_{len(self._memory_store['dpr_documents'])}"
            self._memory_store["dpr_documents"].append(doc)
            return doc["_id"]

    async def get_dprs(self, user_id: str, limit: int = 10) -> List[Dict]:
        """Get saved DPR documents"""
        if self._db:
            cursor = self._db.dpr_documents.find(
                {"user_id": user_id}, {"_id": 0}
            ).sort("created_at", -1).limit(limit)
            return await cursor.to_list(length=limit)
        else:
            dprs = [d for d in self._memory_store["dpr_documents"] if d["user_id"] == user_id]
            return sorted(dprs, key=lambda x: x.get("created_at", ""), reverse=True)[:limit]

    # ==================== MUDRA DPR DOCUMENTS ====================

    async def save_mudra_dpr(self, user_id: str, dpr_data: Dict[str, Any]) -> str:
        """Save a Mudra-compliant DPR with calculated financials."""
        doc = {
            "user_id": user_id,
            "created_at": datetime.utcnow().isoformat(),
            "business_name": dpr_data.get("business_name", ""),
            "mudra_category": dpr_data.get("mudra_category", ""),
            "total_project_cost": dpr_data.get("total_project_cost", 0),
            "loan_amount": dpr_data.get("loan_amount", 0),
            "average_dscr": dpr_data.get("average_dscr", 0),
            "irr": dpr_data.get("irr", 0),
            "is_bankable": dpr_data.get("is_bankable", False),
            "inputs": dpr_data.get("inputs", {}),
            "output": dpr_data.get("output", {}),
            "narratives": dpr_data.get("narratives", {}),
            "status": dpr_data.get("status", "draft"),
        }

        if self._db:
            result = await self._db.mudra_dprs.insert_one(doc)
            return str(result.inserted_id)
        else:
            doc["_id"] = f"mdpr_{len(self._memory_store['mudra_dprs'])}"
            self._memory_store["mudra_dprs"].append(doc)
            return doc["_id"]

    async def get_mudra_dprs(self, user_id: str, limit: int = 10) -> List[Dict]:
        """Get saved Mudra DPR documents for a user."""
        if self._db:
            cursor = self._db.mudra_dprs.find(
                {"user_id": user_id}, {"_id": 0}
            ).sort("created_at", -1).limit(limit)
            return await cursor.to_list(length=limit)
        else:
            dprs = [d for d in self._memory_store["mudra_dprs"] if d["user_id"] == user_id]
            return sorted(dprs, key=lambda x: x.get("created_at", ""), reverse=True)[:limit]

    # ==================== FINANCIAL METRICS HISTORY ====================

    async def save_monthly_metrics(self, user_id: str, metrics: Dict[str, Any]) -> str:
        """Save monthly financial metrics for historical tracking"""
        month = metrics.get("month", datetime.utcnow().strftime("%Y-%m"))
        doc = {
            "user_id": user_id,
            "month": month,
            "updated_at": datetime.utcnow().isoformat(),
            "income": metrics.get("income", 0),
            "expense": metrics.get("expense", 0),
            "savings": metrics.get("savings", 0),
            "savings_rate": metrics.get("savings_rate", 0),
            "health_score": metrics.get("health_score", 0),
            "top_category": metrics.get("top_category", ""),
            "budget_adherence": metrics.get("budget_adherence", 0),
            "transaction_count": metrics.get("transaction_count", 0),
        }

        if self._db:
            # Upsert by user_id + month
            await self._db.financial_metrics.update_one(
                {"user_id": user_id, "month": month},
                {"$set": doc},
                upsert=True
            )
            return month
        else:
            # Replace or append
            store = self._memory_store["financial_metrics"]
            for i, existing in enumerate(store):
                if existing["user_id"] == user_id and existing["month"] == month:
                    store[i] = doc
                    return month
            store.append(doc)
            return month

    async def get_metrics_history(self, user_id: str, months: int = 12) -> List[Dict]:
        """Get monthly metrics history for trend analysis"""
        if self._db:
            cursor = self._db.financial_metrics.find(
                {"user_id": user_id}, {"_id": 0}
            ).sort("month", -1).limit(months)
            return await cursor.to_list(length=months)
        else:
            metrics = [m for m in self._memory_store["financial_metrics"] if m["user_id"] == user_id]
            return sorted(metrics, key=lambda x: x.get("month", ""), reverse=True)[:months]


# Singleton instance
mongo_service = MongoService()
