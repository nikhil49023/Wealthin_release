"""
WealthIn Database Service
SQLite database for persistent storage of financial data.
Uses aiosqlite for async operations.
"""

import aiosqlite
import json
from datetime import datetime, date, timedelta
from typing import Optional, List, Dict, Any
from dataclasses import dataclass, asdict
import os

# Database paths
TRANSACTIONS_DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'transactions.db')
PLANNING_DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'planning.db')

@dataclass
class Transaction:
    id: Optional[int]
    user_id: str
    amount: float
    description: str
    category: str
    type: str  # 'income', 'expense'
    date: str
    time: Optional[str] = None
    merchant: Optional[str] = None
    payment_method: Optional[str] = None
    notes: Optional[str] = None
    receipt_url: Optional[str] = None
    is_recurring: bool = False
    created_at: str = ""

# ... (Include other dataclasses: Budget, Goal, ScheduledPayment - same as before) ...
@dataclass
class Budget:
    id: Optional[int]
    user_id: str
    name: str
    amount: float
    spent: float
    icon: str
    category: str
    period: str  # 'monthly', 'weekly', 'yearly'
    start_date: str
    end_date: Optional[str]
    created_at: str
    updated_at: str


@dataclass
class Goal:
    id: Optional[int]
    user_id: str
    name: str
    target_amount: float
    current_amount: float
    deadline: Optional[str]
    status: str  # 'active', 'completed', 'paused'
    icon: str
    notes: Optional[str]
    created_at: str
    updated_at: str


@dataclass
class ScheduledPayment:
    id: Optional[int]
    user_id: str
    name: str
    amount: float
    category: str
    frequency: str  # 'daily', 'weekly', 'monthly', 'yearly'
    due_date: str
    next_due_date: str
    is_autopay: bool
    status: str  # 'active', 'paused', 'completed'
    reminder_days: int
    last_paid_date: Optional[str]
    notes: Optional[str]
    created_at: str
    updated_at: str

class DatabaseService:
    """Singleton database service for WealthIn (Multi-DB Architecture)"""
    
    _instance = None
    _initialized = False
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    async def initialize(self):
        """Initialize databases and create tables"""
        if self._initialized:
            return
            
        # Initialize Transactions DB
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            await db.execute('''
                CREATE TABLE IF NOT EXISTS transactions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    amount REAL NOT NULL,
                    description TEXT NOT NULL,
                    category TEXT NOT NULL,
                    type TEXT NOT NULL,
                    date TEXT NOT NULL,
                    time TEXT,
                    merchant TEXT,
                    payment_method TEXT,
                    notes TEXT,
                    receipt_url TEXT,
                    is_recurring INTEGER DEFAULT 0,
                    created_at TEXT NOT NULL
                )
            ''')
            # Trends Calculation Cache Table (optional, but good for performance)
            await db.execute('''
                 CREATE TABLE IF NOT EXISTS daily_trends (
                    user_id TEXT NOT NULL,
                    date TEXT NOT NULL,
                    total_spent REAL DEFAULT 0,
                    total_income REAL DEFAULT 0,
                    PRIMARY KEY (user_id, date)
                 )
            ''')
            
            await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions(user_id)')
            await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)')
            await db.commit()
            print(f"✅ Transactions DB initialized at {TRANSACTIONS_DB_PATH}")

        # Initialize Planning DB (Budgets, Goals, Scheduled Payments)
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            await db.execute('''
                CREATE TABLE IF NOT EXISTS budgets (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    amount REAL NOT NULL,
                    spent REAL DEFAULT 0,
                    icon TEXT DEFAULT 'wallet',
                    category TEXT NOT NULL,
                    period TEXT DEFAULT 'monthly',
                    start_date TEXT NOT NULL,
                    end_date TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
            ''')
            
            await db.execute('''
                CREATE TABLE IF NOT EXISTS goals (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    target_amount REAL NOT NULL,
                    current_amount REAL DEFAULT 0,
                    deadline TEXT,
                    status TEXT DEFAULT 'active',
                    icon TEXT DEFAULT 'flag',
                    notes TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
            ''')
            
            await db.execute('''
                CREATE TABLE IF NOT EXISTS scheduled_payments (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    amount REAL NOT NULL,
                    category TEXT NOT NULL,
                    frequency TEXT DEFAULT 'monthly',
                    due_date TEXT NOT NULL,
                    next_due_date TEXT NOT NULL,
                    is_autopay INTEGER DEFAULT 0,
                    status TEXT DEFAULT 'active',
                    reminder_days INTEGER DEFAULT 3,
                    last_paid_date TEXT,
                    notes TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    -- Debt Management Fields (Phase 3)
                    payment_type TEXT DEFAULT 'regular',  -- 'regular', 'loan', 'emi'
                    interest_rate REAL DEFAULT 0,
                    total_tenure INTEGER DEFAULT 0,
                    principal_outstanding REAL DEFAULT 0,
                    total_interest_paid REAL DEFAULT 0,
                    total_principal_paid REAL DEFAULT 0
                )
            ''')
            
            await db.execute('CREATE INDEX IF NOT EXISTS idx_budgets_user ON budgets(user_id)')
            await db.execute('CREATE INDEX IF NOT EXISTS idx_goals_user ON goals(user_id)')
            await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_user ON scheduled_payments(user_id)')
            await db.commit()
            print(f"✅ Planning DB initialized at {PLANNING_DB_PATH}")
            
        self._initialized = True

    # ==================== TRANSACTION OPERATIONS (transactions.db) ====================
    
    async def create_transaction(self, transaction: Transaction) -> Transaction:
        """Create a new transaction"""
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            now = datetime.utcnow().isoformat()
            cursor = await db.execute('''
                INSERT INTO transactions (user_id, amount, description, category, type, date, time, merchant, payment_method, notes, receipt_url, is_recurring, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (transaction.user_id, transaction.amount, transaction.description, transaction.category, transaction.type, transaction.date, transaction.time, transaction.merchant, transaction.payment_method, transaction.notes, transaction.receipt_url, 1 if transaction.is_recurring else 0, now))
            await db.commit()
            transaction.id = cursor.lastrowid
            transaction.created_at = now
            
            # Update budget spent if expense (Cross-DB operation)
            if transaction.type == 'expense':
                await self.update_budget_spent(transaction.user_id, transaction.category, transaction.amount)
            
            return transaction
    
    async def get_transactions(self, user_id: str, limit: int = 50, offset: int = 0, 
                               category: Optional[str] = None, type: Optional[str] = None,
                               start_date: Optional[str] = None, end_date: Optional[str] = None) -> List[Transaction]:
        """Get transactions with filtering"""
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            
            query = 'SELECT * FROM transactions WHERE user_id = ?'
            params = [user_id]
            
            if category:
                query += ' AND category = ?'
                params.append(category)
            if type:
                query += ' AND type = ?'
                params.append(type)
            if start_date:
                query += ' AND date >= ?'
                params.append(start_date)
            if end_date:
                query += ' AND date <= ?'
                params.append(end_date)
            
            query += ' ORDER BY date DESC, time DESC, created_at DESC LIMIT ? OFFSET ?'
            params.extend([limit, offset])
            
            cursor = await db.execute(query, params)
            rows = await cursor.fetchall()
            return [Transaction(**{**dict(row), 'is_recurring': bool(row['is_recurring'])}) for row in rows]
            
    async def get_transaction(self, transaction_id: int, user_id: str) -> Optional[Transaction]:
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cursor = await db.execute('SELECT * FROM transactions WHERE id = ? AND user_id = ?', (transaction_id, user_id))
            row = await cursor.fetchone()
            return Transaction(**{**dict(row), 'is_recurring': bool(row['is_recurring'])}) if row else None

    async def update_transaction(self, transaction_id: int, user_id: str, updates: Dict[str, Any]) -> Optional[Transaction]:
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            if 'is_recurring' in updates:
                updates['is_recurring'] = 1 if updates['is_recurring'] else 0
            
            set_clause = ', '.join(f'{k} = ?' for k in updates.keys())
            values = list(updates.values()) + [transaction_id, user_id]
            
            await db.execute(f'UPDATE transactions SET {set_clause} WHERE id = ? AND user_id = ?', values)
            await db.commit()
            return await self.get_transaction(transaction_id, user_id)

    async def delete_transaction(self, transaction_id: int, user_id: str) -> bool:
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            cursor = await db.execute('DELETE FROM transactions WHERE id = ? AND user_id = ?', (transaction_id, user_id))
            await db.commit()
            return cursor.rowcount > 0

    async def get_spending_summary(self, user_id: str, start_date: str, end_date: str) -> Dict[str, Any]:
        """Get spending summary from transactions.db"""
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            cursor = await db.execute('''
                SELECT COALESCE(SUM(amount), 0) FROM transactions 
                WHERE user_id = ? AND type = 'income' AND date BETWEEN ? AND ?
            ''', (user_id, start_date, end_date))
            income = (await cursor.fetchone())[0]
            
            cursor = await db.execute('''
                SELECT COALESCE(SUM(amount), 0) FROM transactions 
                WHERE user_id = ? AND type = 'expense' AND date BETWEEN ? AND ?
            ''', (user_id, start_date, end_date))
            expenses = (await cursor.fetchone())[0]
            
            cursor = await db.execute('''
                SELECT category, SUM(amount) as total FROM transactions 
                WHERE user_id = ? AND type = 'expense' AND date BETWEEN ? AND ?
                GROUP BY category ORDER BY total DESC
            ''', (user_id, start_date, end_date))
            by_category = {row[0]: row[1] for row in await cursor.fetchall()}
            
            return {
                'total_income': income,
                'total_expenses': expenses,
                'net': income - expenses,
                'savings_rate': ((income - expenses) / income * 100) if income > 0 else 0,
                'by_category': by_category
            }


    # ==================== BUDGET & GOAL OPERATIONS (planning.db) ====================
    
    async def create_budget(self, budget: Budget) -> Budget:
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            now = datetime.utcnow().isoformat()
            cursor = await db.execute('''
                INSERT INTO budgets (user_id, name, amount, spent, icon, category, period, start_date, end_date, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (budget.user_id, budget.name, budget.amount, budget.spent, budget.icon, budget.category, budget.period, budget.start_date, budget.end_date, now, now))
            await db.commit()
            budget.id = cursor.lastrowid
            budget.created_at = now
            budget.updated_at = now
            return budget
            
    async def get_budgets(self, user_id: str) -> List[Budget]:
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cursor = await db.execute('SELECT * FROM budgets WHERE user_id = ? ORDER BY created_at DESC', (user_id,))
            rows = await cursor.fetchall()
            return [Budget(**dict(row)) for row in rows]

    async def get_budget(self, budget_id: int, user_id: str) -> Optional[Budget]:
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cursor = await db.execute('SELECT * FROM budgets WHERE id = ? AND user_id = ?', (budget_id, user_id))
            row = await cursor.fetchone()
            return Budget(**dict(row)) if row else None

    async def update_budget(self, budget_id: int, user_id: str, updates: Dict[str, Any]) -> Optional[Budget]:
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            updates['updated_at'] = datetime.utcnow().isoformat()
            set_clause = ', '.join(f'{k} = ?' for k in updates.keys())
            values = list(updates.values()) + [budget_id, user_id]
            await db.execute(f'UPDATE budgets SET {set_clause} WHERE id = ? AND user_id = ?', values)
            await db.commit()
            return await self.get_budget(budget_id, user_id)

    async def delete_budget(self, budget_id: int, user_id: str) -> bool:
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            cursor = await db.execute('DELETE FROM budgets WHERE id = ? AND user_id = ?', (budget_id, user_id))
            await db.commit()
            return cursor.rowcount > 0

    async def update_budget_spent(self, user_id: str, category: str, amount: float):
        """Update spent amount for a budget category (in planning.db)"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            await db.execute('''
                UPDATE budgets 
                SET spent = spent + ?, updated_at = ?
                WHERE user_id = ? AND category = ?
            ''', (amount, datetime.utcnow().isoformat(), user_id, category))
            await db.commit()

    # --- Goals ---
    async def create_goal(self, goal: Goal) -> Goal:
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            now = datetime.utcnow().isoformat()
            cursor = await db.execute('''
                INSERT INTO goals (user_id, name, target_amount, current_amount, deadline, status, icon, notes, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (goal.user_id, goal.name, goal.target_amount, goal.current_amount, goal.deadline, goal.status, goal.icon, goal.notes, now, now))
            await db.commit()
            goal.id = cursor.lastrowid
            goal.created_at = now
            goal.updated_at = now
            return goal

    async def get_goals(self, user_id: str) -> List[Goal]:
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cursor = await db.execute('SELECT * FROM goals WHERE user_id = ? ORDER BY created_at DESC', (user_id,))
            rows = await cursor.fetchall()
            return [Goal(**dict(row)) for row in rows]

    async def get_goal(self, goal_id: int, user_id: str) -> Optional[Goal]:
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cursor = await db.execute('SELECT * FROM goals WHERE id = ? AND user_id = ?', (goal_id, user_id))
            row = await cursor.fetchone()
            return Goal(**dict(row)) if row else None

    async def update_goal(self, goal_id: int, user_id: str, updates: Dict[str, Any]) -> Optional[Goal]:
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            updates['updated_at'] = datetime.utcnow().isoformat()
            set_clause = ', '.join(f'{k} = ?' for k in updates.keys())
            values = list(updates.values()) + [goal_id, user_id]
            await db.execute(f'UPDATE goals SET {set_clause} WHERE id = ? AND user_id = ?', values)
            await db.commit()
            return await self.get_goal(goal_id, user_id)

    async def add_funds_to_goal(self, goal_id: int, user_id: str, amount: float) -> Optional[Goal]:
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            now = datetime.utcnow().isoformat()
            await db.execute('''
                UPDATE goals 
                SET current_amount = current_amount + ?, updated_at = ?,
                    status = CASE WHEN current_amount + ? >= target_amount THEN 'completed' ELSE status END
                WHERE id = ? AND user_id = ?
            ''', (amount, now, amount, goal_id, user_id))
            await db.commit()
            return await self.get_goal(goal_id, user_id)

    async def delete_goal(self, goal_id: int, user_id: str) -> bool:
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            cursor = await db.execute('DELETE FROM goals WHERE id = ? AND user_id = ?', (goal_id, user_id))
            await db.commit()
            return cursor.rowcount > 0

    # --- Scheduled Payments ---
    async def create_scheduled_payment(self, payment: ScheduledPayment) -> ScheduledPayment:
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            now = datetime.utcnow().isoformat()
            cursor = await db.execute('''
                INSERT INTO scheduled_payments (user_id, name, amount, category, frequency, due_date, next_due_date, is_autopay, status, reminder_days, last_paid_date, notes, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (payment.user_id, payment.name, payment.amount, payment.category, payment.frequency, payment.due_date, payment.next_due_date, 1 if payment.is_autopay else 0, payment.status, payment.reminder_days, payment.last_paid_date, payment.notes, now, now))
            await db.commit()
            payment.id = cursor.lastrowid
            payment.created_at = now
            payment.updated_at = now
            return payment

    async def get_scheduled_payments(self, user_id: str, status: Optional[str] = None) -> List[ScheduledPayment]:
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            query = 'SELECT * FROM scheduled_payments WHERE user_id = ?'
            params = [user_id]
            if status:
                query += ' AND status = ?'
                params.append(status)
            query += ' ORDER BY next_due_date ASC'
            cursor = await db.execute(query, params)
            rows = await cursor.fetchall()
            return [ScheduledPayment(**{**dict(row), 'is_autopay': bool(row['is_autopay'])}) for row in rows]

    async def get_scheduled_payment(self, payment_id: int, user_id: str) -> Optional[ScheduledPayment]:
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cursor = await db.execute('SELECT * FROM scheduled_payments WHERE id = ? AND user_id = ?', (payment_id, user_id))
            row = await cursor.fetchone()
            return ScheduledPayment(**{**dict(row), 'is_autopay': bool(row['is_autopay'])}) if row else None

    async def update_scheduled_payment(self, payment_id: int, user_id: str, updates: Dict[str, Any]) -> Optional[ScheduledPayment]:
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            updates['updated_at'] = datetime.utcnow().isoformat()
            if 'is_autopay' in updates:
                updates['is_autopay'] = 1 if updates['is_autopay'] else 0
            
            set_clause = ', '.join(f'{k} = ?' for k in updates.keys())
            values = list(updates.values()) + [payment_id, user_id]
            await db.execute(f'UPDATE scheduled_payments SET {set_clause} WHERE id = ? AND user_id = ?', values)
            await db.commit()
            return await self.get_scheduled_payment(payment_id, user_id)

    async def mark_payment_paid(self, payment_id: int, user_id: str) -> Optional[ScheduledPayment]:
        """
        Mark a scheduled payment as paid.
        For loan/EMI payments, calculates principal/interest split (reducing balance method).
        """
        payment = await self.get_scheduled_payment(payment_id, user_id)
        if not payment:
            return None
        
        from dateutil.relativedelta import relativedelta
        current_due = datetime.fromisoformat(payment.next_due_date)
        
        if payment.frequency == 'daily':
            next_due = current_due + relativedelta(days=1)
        elif payment.frequency == 'weekly':
            next_due = current_due + relativedelta(weeks=1)
        elif payment.frequency == 'monthly':
            next_due = current_due + relativedelta(months=1)
        elif payment.frequency == 'yearly':
            next_due = current_due + relativedelta(years=1)
        else:
            next_due = current_due + relativedelta(months=1)
        
        updates = {
            'last_paid_date': datetime.utcnow().isoformat(),
            'next_due_date': next_due.isoformat()
        }
        
        # EMI Split Calculation (for loan/emi type payments)
        interest_component = 0.0
        principal_component = payment.amount
        
        # Check if this is a loan payment with interest
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            cursor = await db.execute(
                'SELECT payment_type, interest_rate, principal_outstanding, total_interest_paid, total_principal_paid '
                'FROM scheduled_payments WHERE id = ?', 
                (payment_id,)
            )
            row = await cursor.fetchone()
            
            if row and row[0] in ('loan', 'emi') and row[1] and row[1] > 0:
                # Existing loan data
                interest_rate = row[1]  # Annual rate
                principal_outstanding = row[2] if row[2] else payment.amount * 12  # Estimate if not set
                total_interest_paid = row[3] if row[3] else 0
                total_principal_paid = row[4] if row[4] else 0
                
                # Calculate monthly interest (Reducing Balance Method)
                monthly_rate = interest_rate / 12 / 100
                interest_component = principal_outstanding * monthly_rate
                principal_component = payment.amount - interest_component
                
                # Ensure principal component is not negative
                if principal_component < 0:
                    principal_component = 0
                    interest_component = payment.amount
                
                # Update outstanding principal and totals
                new_outstanding = max(0, principal_outstanding - principal_component)
                
                updates['principal_outstanding'] = new_outstanding
                updates['total_interest_paid'] = total_interest_paid + interest_component
                updates['total_principal_paid'] = total_principal_paid + principal_component
                
                # If loan is paid off, mark as completed
                if new_outstanding <= 0:
                    updates['status'] = 'completed'
        
        # Create transaction for this payment
        description = f"Payment: {payment.name}"
        notes = f"Scheduled payment"
        
        # Add EMI split info to transaction description if loan
        if interest_component > 0:
            description = f"EMI: {payment.name}"
            notes = f"Principal: ₹{principal_component:.0f} | Interest: ₹{interest_component:.0f}"
        
        transaction = Transaction(
            id=None,
            user_id=user_id,
            amount=payment.amount,
            description=description,
            category=payment.category,
            type='expense',
            date=datetime.utcnow().date().isoformat(),
            time=datetime.utcnow().strftime("%H:%M"),
            payment_method="Scheduled",
            notes=notes,
            receipt_url=None,
            is_recurring=True,
            created_at=''
        )
        await self.create_transaction(transaction)
        
        return await self.update_scheduled_payment(payment_id, user_id, updates)

    async def delete_scheduled_payment(self, payment_id: int, user_id: str) -> bool:
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            cursor = await db.execute('DELETE FROM scheduled_payments WHERE id = ? AND user_id = ?', (payment_id, user_id))
            await db.commit()
            return cursor.rowcount > 0

    async def get_upcoming_payments(self, user_id: str, days: int = 7) -> List[ScheduledPayment]:
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            from_date = datetime.utcnow().date().isoformat()
            to_date = (datetime.utcnow().date() + timedelta(days=days)).isoformat()
            cursor = await db.execute('''
                SELECT * FROM scheduled_payments 
                WHERE user_id = ? AND status = 'active' AND next_due_date BETWEEN ? AND ?
                ORDER BY next_due_date ASC
            ''', (user_id, from_date, to_date))
            rows = await cursor.fetchall()
            return [ScheduledPayment(**{**dict(row), 'is_autopay': bool(row['is_autopay'])}) for row in rows]

    async def get_debt_snowball_data(self, user_id: str) -> Dict[str, Any]:
        """
        Get debt payment data for Debt Snowball visualization.
        Returns all loans with their payment progress and schedule.
        """
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cursor = await db.execute('''
                SELECT id, name, amount, category, interest_rate, total_tenure,
                       principal_outstanding, total_interest_paid, total_principal_paid,
                       status, created_at
                FROM scheduled_payments 
                WHERE user_id = ? AND payment_type IN ('loan', 'emi')
                ORDER BY principal_outstanding DESC
            ''', (user_id,))
            rows = await cursor.fetchall()
            
            loans = []
            total_outstanding = 0
            total_interest_paid = 0
            total_principal_paid = 0
            
            for row in rows:
                loan = dict(row)
                outstanding = loan.get('principal_outstanding', 0) or 0
                interest_paid = loan.get('total_interest_paid', 0) or 0
                principal_paid = loan.get('total_principal_paid', 0) or 0
                
                # Calculate original loan amount
                original_amount = outstanding + principal_paid
                
                # Calculate progress
                progress = (principal_paid / original_amount * 100) if original_amount > 0 else 0
                
                loans.append({
                    'id': loan['id'],
                    'name': loan['name'],
                    'emi_amount': loan['amount'],
                    'interest_rate': loan.get('interest_rate', 0),
                    'original_amount': original_amount,
                    'outstanding': outstanding,
                    'interest_paid': interest_paid,
                    'principal_paid': principal_paid,
                    'progress': progress,
                    'status': loan.get('status', 'active'),
                })
                
                total_outstanding += outstanding
                total_interest_paid += interest_paid
                total_principal_paid += principal_paid
            
            return {
                'loans': loans,
                'summary': {
                    'total_loans': len(loans),
                    'total_outstanding': total_outstanding,
                    'total_interest_paid': total_interest_paid,
                    'total_principal_paid': total_principal_paid,
                    'overall_progress': (total_principal_paid / (total_outstanding + total_principal_paid) * 100) 
                        if (total_outstanding + total_principal_paid) > 0 else 0
                }
            }

    async def get_cashflow_data(self, user_id: str, start_date: str, end_date: str) -> List[Dict[str, Any]]:
        """Get daily cashflow data for the specified date range"""
        async with aiosqlite.connect(TRANSACTIONS_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            
            # Ensure dates are just YYYY-MM-DD for the query if stored as TEXT without time in some cases
            # But since we fixed end_date to include time, we should treat them as strings
            
            cursor = await db.execute('''
                SELECT date, 
                       SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as income,
                       SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as expense
                FROM transactions 
                WHERE user_id = ? AND date BETWEEN ? AND ?
                GROUP BY date
                ORDER BY date ASC
            ''', (user_id, start_date, end_date))
            
            rows = await cursor.fetchall()
            
            # Fill in gaps and calculate running balance
            cashflow = []
            
            # get initial balance (before start date)
            cursor = await db.execute('''
                SELECT SUM(CASE WHEN type = 'income' THEN amount ELSE -amount END) 
                FROM transactions 
                WHERE user_id = ? AND date < ?
            ''', (user_id, start_date))
            initial_balance_row = await cursor.fetchone()
            running_balance = initial_balance_row[0] if initial_balance_row and initial_balance_row[0] else 0
            
            # Generate date range logic
            from datetime import datetime as dt
            
            # Parse YYYY-MM-DD or ISO
            try:
                s_dt = dt.fromisoformat(start_date.split('T')[0])
                e_dt = dt.fromisoformat(end_date.split('T')[0])
                days_diff = (e_dt - s_dt).days
                
                for i in range(days_diff + 1):
                    curr_date = (s_dt + timedelta(days=i)).isoformat().split('T')[0]
                    # We might need to match partial dates if DB has full ISO. 
                    # But the GROUP BY date above suggests DB usually stores YYYY-MM-DD or we grouped by full string.
                    # If DB has mix, the grouping might be split. 
                    # For now assume mostly standard dates.
                    
                    # Find matching row manually if needed, or use the map
                    # Since keys in data_map depend on the DB 'date' column value.
                    
                    # NOTE: A better approach for the loop is to iterate the rows returned, 
                    # but to fill gaps we need the range. 
                    # If DB dates have time, data_map keys have time. curr_date does not.
                    # Simplification: Just list the rows returned for now to avoid zero-filling mismatch.
                    pass
            except:
                pass

            # Simpler approach: Just return the rows + running balance calculation
            # Reset running balance and re-calculate strictly from sorted rows? 
            # No, we need the initial balance.
            
            cashflow = []
            
            # Re-iterate rows to apply running balance
            running_balance_curr = running_balance
            
            for row in rows:
                income = row['income']
                expense = row['expense']
                running_balance_curr += (income - expense)
                cashflow.append({
                    'date': row['date'],
                    'income': income,
                    'expense': expense,
                    'balance': running_balance_curr
                })
                
            return cashflow

    async def get_dashboard_data(self, user_id: str, start_date: str = None, end_date: str = None) -> Dict[str, Any]:
        """Get aggregated dashboard data"""
        from datetime import timedelta
        
        if not start_date or not end_date:
            today = datetime.utcnow().date()
            start_date = today.replace(day=1).isoformat()
            end_date = f"{today.isoformat()}T23:59:59"
        
        summary = await self.get_spending_summary(user_id, start_date, end_date)
        budgets = await self.get_budgets(user_id)
        total_budget = sum(b.amount for b in budgets)
        total_spent = sum(b.spent for b in budgets)
        goals = await self.get_goals(user_id)
        active_goals = [g for g in goals if g.status == 'active']
        upcoming = await self.get_upcoming_payments(user_id, 7)
        transactions = await self.get_transactions(user_id, limit=5)
        cashflow = await self.get_cashflow_data(user_id, start_date, end_date)
        
        return {
            'total_income': summary['total_income'],
            'total_expense': summary['total_expenses'],
            'balance': summary['net'],
            'savings_rate': summary['savings_rate'],
            'summary': summary,
            'budgets': {
                'total': total_budget,
                'spent': total_spent,
                'remaining': total_budget - total_spent,
                'count': len(budgets)
            },
            'goals': {
                'active_count': len(active_goals),
                'total_target': sum(g.target_amount for g in active_goals),
                'total_saved': sum(g.current_amount for g in active_goals)
            },
            'upcoming_payments': [
                {'name': p.name, 'amount': p.amount, 'due_date': p.next_due_date}
                for p in upcoming[:3]
            ],
            'recent_transactions': [
                {'description': t.description, 'amount': t.amount, 'type': t.type, 'date': t.date}
                for t in transactions
            ],
            'cashflow_data': cashflow
        }


# Singleton instance
database_service = DatabaseService()
