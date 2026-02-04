"""
WealthIn Python Sidecar - Enhanced Backend with Local Database
Handles: SQLite DB, LLM calls, Transaction import, Trend analysis
"""
import os
import json
import sqlite3
import hashlib
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any
from contextlib import contextmanager
from pathlib import Path

# Database path - stored in user's home directory
DB_DIR = Path.home() / '.wealthin'
DB_PATH = DB_DIR / 'wealthin.db'

def ensure_db_dir():
    """Ensure database directory exists"""
    DB_DIR.mkdir(parents=True, exist_ok=True)

@contextmanager
def get_db():
    """Context manager for database connections"""
    ensure_db_dir()
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        conn.close()

def init_database():
    """Initialize the SQLite database with all required tables"""
    ensure_db_dir()
    
    with get_db() as conn:
        cursor = conn.cursor()
        
        # Transactions table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS transactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                amount REAL NOT NULL,
                description TEXT NOT NULL,
                category TEXT DEFAULT 'Other',
                type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
                date TEXT NOT NULL,
                time TEXT,
                payment_method TEXT,
                notes TEXT,
                receipt_url TEXT,
                is_recurring INTEGER DEFAULT 0,
                source TEXT DEFAULT 'manual',
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Create indexes for faster queries
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions(user_id)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category)')
        
        # Trends table - stores analyzed spending patterns
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS trends (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                period TEXT NOT NULL,
                period_start TEXT NOT NULL,
                period_end TEXT NOT NULL,
                total_income REAL DEFAULT 0,
                total_expense REAL DEFAULT 0,
                net_savings REAL DEFAULT 0,
                savings_rate REAL DEFAULT 0,
                top_expense_category TEXT,
                top_expense_amount REAL DEFAULT 0,
                top_income_category TEXT,
                top_income_amount REAL DEFAULT 0,
                category_breakdown TEXT,
                insights TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(user_id, period, period_start)
            )
        ''')
        
        # Budgets table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS budgets (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                name TEXT NOT NULL,
                category TEXT NOT NULL,
                amount REAL NOT NULL,
                spent REAL DEFAULT 0,
                period TEXT DEFAULT 'monthly',
                icon TEXT DEFAULT 'wallet',
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Goals table
        cursor.execute('''
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
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Scheduled payments table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS scheduled_payments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                name TEXT NOT NULL,
                amount REAL NOT NULL,
                frequency TEXT NOT NULL,
                next_due TEXT NOT NULL,
                category TEXT,
                is_active INTEGER DEFAULT 1,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # AI conversation history (for context)
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS chat_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                timestamp TEXT DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # User preferences
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS user_preferences (
                user_id TEXT PRIMARY KEY,
                currency TEXT DEFAULT 'INR',
                language TEXT DEFAULT 'en',
                theme TEXT DEFAULT 'system',
                notifications INTEGER DEFAULT 1,
                ai_suggestions INTEGER DEFAULT 1,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        conn.commit()
        print(f"Database initialized at {DB_PATH}")

# ==================== TRANSACTION OPERATIONS ====================

def create_transaction(
    user_id: str,
    amount: float,
    description: str,
    category: str,
    type: str,
    date: str = None,
    time: str = None,
    payment_method: str = None,
    notes: str = None,
    source: str = 'manual'
) -> Dict[str, Any]:
    """Create a new transaction"""
    if date is None:
        date = datetime.now().strftime('%Y-%m-%d')
    
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO transactions 
            (user_id, amount, description, category, type, date, time, payment_method, notes, source)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (user_id, amount, description, category, type, date, time, payment_method, notes, source))
        
        transaction_id = cursor.lastrowid
        
        # Update budget spent if it's an expense
        if type == 'expense':
            cursor.execute('''
                UPDATE budgets 
                SET spent = spent + ?, updated_at = CURRENT_TIMESTAMP
                WHERE user_id = ? AND category = ?
            ''', (amount, user_id, category))
        
        return {
            'id': transaction_id,
            'user_id': user_id,
            'amount': amount,
            'description': description,
            'category': category,
            'type': type,
            'date': date,
            'time': time,
            'source': source
        }

def get_transactions(
    user_id: str,
    limit: int = 100,
    offset: int = 0,
    type: str = None,
    category: str = None,
    start_date: str = None,
    end_date: str = None
) -> List[Dict[str, Any]]:
    """Get transactions with optional filtering"""
    with get_db() as conn:
        cursor = conn.cursor()
        
        query = 'SELECT * FROM transactions WHERE user_id = ?'
        params = [user_id]
        
        if type:
            query += ' AND type = ?'
            params.append(type)
        
        if category:
            query += ' AND category = ?'
            params.append(category)
        
        if start_date:
            query += ' AND date >= ?'
            params.append(start_date)
        
        if end_date:
            query += ' AND date <= ?'
            params.append(end_date)
        
        query += ' ORDER BY date DESC, created_at DESC LIMIT ? OFFSET ?'
        params.extend([limit, offset])
        
        cursor.execute(query, params)
        rows = cursor.fetchall()
        
        return [dict(row) for row in rows]

def bulk_create_transactions(user_id: str, transactions: List[Dict[str, Any]], source: str = 'import') -> int:
    """Bulk insert transactions from import"""
    count = 0
    with get_db() as conn:
        cursor = conn.cursor()
        
        for t in transactions:
            try:
                cursor.execute('''
                    INSERT INTO transactions 
                    (user_id, amount, description, category, type, date, time, source)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    user_id,
                    t.get('amount', 0),
                    t.get('description', 'Unknown'),
                    t.get('category', 'Other'),
                    t.get('type', 'expense'),
                    t.get('date', datetime.now().strftime('%Y-%m-%d')),
                    t.get('time'),
                    source
                ))
                count += 1
            except Exception as e:
                print(f"Error inserting transaction: {e}")
                continue
        
        conn.commit()
    
    # Trigger trend analysis after bulk import
    analyze_trends(user_id)
    
    return count

def delete_transaction(user_id: str, transaction_id: int) -> bool:
    """Delete a transaction"""
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute(
            'DELETE FROM transactions WHERE id = ? AND user_id = ?',
            (transaction_id, user_id)
        )
        return cursor.rowcount > 0

# ==================== TREND ANALYSIS ====================

def analyze_trends(user_id: str, period: str = 'monthly') -> Dict[str, Any]:
    """Analyze spending trends and save to database"""
    with get_db() as conn:
        cursor = conn.cursor()
        
        # Determine date range based on period
        today = datetime.now()
        if period == 'weekly':
            start_date = (today - timedelta(days=7)).strftime('%Y-%m-%d')
        elif period == 'monthly':
            start_date = (today - timedelta(days=30)).strftime('%Y-%m-%d')
        elif period == 'quarterly':
            start_date = (today - timedelta(days=90)).strftime('%Y-%m-%d')
        else:  # yearly
            start_date = (today - timedelta(days=365)).strftime('%Y-%m-%d')
        
        end_date = today.strftime('%Y-%m-%d')
        
        # Get all transactions in period
        cursor.execute('''
            SELECT * FROM transactions 
            WHERE user_id = ? AND date >= ? AND date <= ?
        ''', (user_id, start_date, end_date))
        
        transactions = [dict(row) for row in cursor.fetchall()]
        
        if not transactions:
            return {
                'period': period,
                'total_income': 0,
                'total_expense': 0,
                'net_savings': 0,
                'savings_rate': 0,
                'insights': []
            }
        
        # Calculate totals
        total_income = sum(t['amount'] for t in transactions if t['type'] == 'income')
        total_expense = sum(t['amount'] for t in transactions if t['type'] == 'expense')
        net_savings = total_income - total_expense
        savings_rate = (net_savings / total_income * 100) if total_income > 0 else 0
        
        # Category breakdown
        expense_by_category = {}
        income_by_category = {}
        
        for t in transactions:
            cat = t.get('category', 'Other')
            if t['type'] == 'expense':
                expense_by_category[cat] = expense_by_category.get(cat, 0) + t['amount']
            else:
                income_by_category[cat] = income_by_category.get(cat, 0) + t['amount']
        
        # Find top categories
        top_expense_category = max(expense_by_category, key=expense_by_category.get) if expense_by_category else None
        top_expense_amount = expense_by_category.get(top_expense_category, 0) if top_expense_category else 0
        
        top_income_category = max(income_by_category, key=income_by_category.get) if income_by_category else None
        top_income_amount = income_by_category.get(top_income_category, 0) if top_income_category else 0
        
        # Generate insights
        insights = generate_spending_insights(
            total_income, total_expense, savings_rate,
            expense_by_category, income_by_category,
            transactions
        )
        
        # Save to trends table
        category_breakdown = json.dumps({
            'expense': expense_by_category,
            'income': income_by_category
        })
        
        cursor.execute('''
            INSERT OR REPLACE INTO trends 
            (user_id, period, period_start, period_end, total_income, total_expense,
             net_savings, savings_rate, top_expense_category, top_expense_amount,
             top_income_category, top_income_amount, category_breakdown, insights)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            user_id, period, start_date, end_date, total_income, total_expense,
            net_savings, round(savings_rate, 2), top_expense_category, top_expense_amount,
            top_income_category, top_income_amount, category_breakdown, json.dumps(insights)
        ))
        
        return {
            'period': period,
            'period_start': start_date,
            'period_end': end_date,
            'total_income': round(total_income, 2),
            'total_expense': round(total_expense, 2),
            'net_savings': round(net_savings, 2),
            'savings_rate': round(savings_rate, 2),
            'top_expense_category': top_expense_category,
            'top_expense_amount': round(top_expense_amount, 2),
            'top_income_category': top_income_category,
            'top_income_amount': round(top_income_amount, 2),
            'expense_breakdown': expense_by_category,
            'income_breakdown': income_by_category,
            'insights': insights,
            'transaction_count': len(transactions)
        }

def generate_spending_insights(
    total_income: float,
    total_expense: float,
    savings_rate: float,
    expense_by_category: Dict[str, float],
    income_by_category: Dict[str, float],
    transactions: List[Dict[str, Any]]
) -> List[Dict[str, Any]]:
    """Generate actionable insights from spending data"""
    insights = []
    
    # Insight 1: Savings rate analysis
    if savings_rate >= 30:
        insights.append({
            'type': 'positive',
            'title': 'Excellent Savings Rate',
            'description': f'You\'re saving {savings_rate:.1f}% of your income, well above the recommended 20%.',
            'recommendation': 'Consider investing surplus in mutual funds or high-yield savings.'
        })
    elif savings_rate >= 20:
        insights.append({
            'type': 'neutral',
            'title': 'Good Savings Rate',
            'description': f'Your savings rate of {savings_rate:.1f}% meets the recommended benchmark.',
            'recommendation': 'Try to increase savings by 5% for faster wealth building.'
        })
    elif savings_rate >= 10:
        insights.append({
            'type': 'warning',
            'title': 'Low Savings Rate',
            'description': f'At {savings_rate:.1f}%, your savings are below the recommended 20%.',
            'recommendation': 'Review discretionary spending and set up automatic savings.'
        })
    else:
        insights.append({
            'type': 'alert',
            'title': 'Critical: Very Low Savings',
            'description': f'Your savings rate of {savings_rate:.1f}% needs immediate attention.',
            'recommendation': 'Create a budget and cut non-essential expenses urgently.'
        })
    
    # Insight 2: Top spending category
    if expense_by_category:
        top_cat = max(expense_by_category, key=expense_by_category.get)
        top_amount = expense_by_category[top_cat]
        pct_of_expense = (top_amount / total_expense * 100) if total_expense > 0 else 0
        
        insights.append({
            'type': 'info',
            'title': f'Top Spending: {top_cat}',
            'description': f'₹{top_amount:,.0f} ({pct_of_expense:.1f}% of total expenses)',
            'recommendation': f'Review your {top_cat} expenses for potential savings.'
        })
    
    # Insight 3: Minimum and maximum transactions
    if transactions:
        expense_transactions = [t for t in transactions if t['type'] == 'expense']
        if expense_transactions:
            min_expense = min(expense_transactions, key=lambda x: x['amount'])
            max_expense = max(expense_transactions, key=lambda x: x['amount'])
            
            insights.append({
                'type': 'stat',
                'title': 'Expense Range',
                'description': f'Min: ₹{min_expense["amount"]:,.0f} | Max: ₹{max_expense["amount"]:,.0f}',
                'min_amount': min_expense['amount'],
                'max_amount': max_expense['amount'],
                'min_description': min_expense['description'],
                'max_description': max_expense['description']
            })
    
    # Insight 4: Daily average
    if total_expense > 0 and transactions:
        # Calculate unique days
        unique_days = len(set(t['date'] for t in transactions if t['type'] == 'expense'))
        daily_avg = total_expense / max(unique_days, 1)
        
        insights.append({
            'type': 'stat',
            'title': 'Daily Spending Average',
            'description': f'₹{daily_avg:,.0f} per day on average',
            'recommendation': 'Set a daily spending limit to stay on track.'
        })
    
    return insights

def get_trends(user_id: str, period: str = 'monthly') -> Dict[str, Any]:
    """Get cached trends or recalculate if stale"""
    with get_db() as conn:
        cursor = conn.cursor()
        
        # Check for recent trends
        cursor.execute('''
            SELECT * FROM trends 
            WHERE user_id = ? AND period = ?
            ORDER BY created_at DESC LIMIT 1
        ''', (user_id, period))
        
        row = cursor.fetchone()
        
        if row:
            trend = dict(row)
            # Parse JSON fields
            if trend.get('category_breakdown'):
                trend['category_breakdown'] = json.loads(trend['category_breakdown'])
            if trend.get('insights'):
                trend['insights'] = json.loads(trend['insights'])
            return trend
    
    # No cached trends, recalculate
    return analyze_trends(user_id, period)

# ==================== DASHBOARD DATA ====================

def get_dashboard_data(user_id: str) -> Dict[str, Any]:
    """Get comprehensive dashboard data from real transactions"""
    with get_db() as conn:
        cursor = conn.cursor()
        
        # Current month range
        today = datetime.now()
        month_start = today.replace(day=1).strftime('%Y-%m-%d')
        month_end = today.strftime('%Y-%m-%d')
        
        # This month's totals
        cursor.execute('''
            SELECT 
                COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as total_income,
                COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as total_expense
            FROM transactions 
            WHERE user_id = ? AND date >= ? AND date <= ?
        ''', (user_id, month_start, month_end))
        
        row = cursor.fetchone()
        total_income = row['total_income'] if row else 0
        total_expense = row['total_expense'] if row else 0
        net_savings = total_income - total_expense
        savings_rate = (net_savings / total_income * 100) if total_income > 0 else 0
        
        # Previous month comparison
        prev_month_start = (today.replace(day=1) - timedelta(days=1)).replace(day=1).strftime('%Y-%m-%d')
        prev_month_end = (today.replace(day=1) - timedelta(days=1)).strftime('%Y-%m-%d')
        
        cursor.execute('''
            SELECT 
                COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as prev_income,
                COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as prev_expense
            FROM transactions 
            WHERE user_id = ? AND date >= ? AND date <= ?
        ''', (user_id, prev_month_start, prev_month_end))
        
        prev_row = cursor.fetchone()
        prev_income = prev_row['prev_income'] if prev_row else 0
        prev_expense = prev_row['prev_expense'] if prev_row else 0
        
        # Calculate changes
        income_change = ((total_income - prev_income) / prev_income * 100) if prev_income > 0 else 0
        expense_change = ((total_expense - prev_expense) / prev_expense * 100) if prev_expense > 0 else 0
        
        # Recent transactions
        cursor.execute('''
            SELECT * FROM transactions 
            WHERE user_id = ? 
            ORDER BY date DESC, created_at DESC 
            LIMIT 10
        ''', (user_id,))
        
        recent_transactions = [dict(row) for row in cursor.fetchall()]
        
        # Category breakdown for chart
        cursor.execute('''
            SELECT category, SUM(amount) as total
            FROM transactions 
            WHERE user_id = ? AND type = 'expense' AND date >= ? AND date <= ?
            GROUP BY category
            ORDER BY total DESC
        ''', (user_id, month_start, month_end))
        
        expense_breakdown = [{'category': row['category'], 'amount': row['total']} 
                           for row in cursor.fetchall()]
        
        # Cashflow data (last 7 days)
        cashflow_data = []
        for i in range(6, -1, -1):
            day = today - timedelta(days=i)
            day_str = day.strftime('%Y-%m-%d')
            
            cursor.execute('''
                SELECT 
                    COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as income,
                    COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as expense
                FROM transactions 
                WHERE user_id = ? AND date = ?
            ''', (user_id, day_str))
            
            day_row = cursor.fetchone()
            cashflow_data.append({
                'date': day_str,
                'day': day.strftime('%a'),
                'income': day_row['income'] if day_row else 0,
                'expense': day_row['expense'] if day_row else 0
            })
        
        return {
            'total_income': round(total_income, 2),
            'total_expense': round(total_expense, 2),
            'net_savings': round(net_savings, 2),
            'savings_rate': round(savings_rate, 1),
            'income_change': round(income_change, 1),
            'expense_change': round(expense_change, 1),
            'recent_transactions': recent_transactions,
            'expense_breakdown': expense_breakdown,
            'cashflow_data': cashflow_data,
            'has_data': len(recent_transactions) > 0
        }

# ==================== BUDGET OPERATIONS ====================

def create_budget(user_id: str, name: str, category: str, amount: float, period: str = 'monthly', icon: str = 'wallet') -> Dict[str, Any]:
    """Create a new budget"""
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO budgets (user_id, name, category, amount, period, icon)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (user_id, name, category, amount, period, icon))
        
        return {
            'id': cursor.lastrowid,
            'user_id': user_id,
            'name': name,
            'category': category,
            'amount': amount,
            'spent': 0,
            'period': period,
            'icon': icon
        }

def get_budgets(user_id: str) -> List[Dict[str, Any]]:
    """Get all budgets for a user"""
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM budgets WHERE user_id = ?', (user_id,))
        return [dict(row) for row in cursor.fetchall()]

def update_budget(user_id: str, budget_id: int, **kwargs) -> bool:
    """Update a budget"""
    if not kwargs:
        return False
    
    with get_db() as conn:
        cursor = conn.cursor()
        
        updates = ', '.join(f'{k} = ?' for k in kwargs.keys())
        values = list(kwargs.values()) + [user_id, budget_id]
        
        cursor.execute(f'''
            UPDATE budgets 
            SET {updates}, updated_at = CURRENT_TIMESTAMP
            WHERE user_id = ? AND id = ?
        ''', values)
        
        return cursor.rowcount > 0

def delete_budget(user_id: str, budget_id: int) -> bool:
    """Delete a budget"""
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('DELETE FROM budgets WHERE user_id = ? AND id = ?', (user_id, budget_id))
        return cursor.rowcount > 0

# ==================== GOAL OPERATIONS ====================

def create_goal(user_id: str, name: str, target_amount: float, deadline: str = None, icon: str = 'flag', notes: str = None) -> Dict[str, Any]:
    """Create a new savings goal"""
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO goals (user_id, name, target_amount, deadline, icon, notes)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (user_id, name, target_amount, deadline, icon, notes))
        
        return {
            'id': cursor.lastrowid,
            'user_id': user_id,
            'name': name,
            'target_amount': target_amount,
            'current_amount': 0,
            'deadline': deadline,
            'status': 'active',
            'icon': icon,
            'notes': notes
        }

def get_goals(user_id: str) -> List[Dict[str, Any]]:
    """Get all goals for a user"""
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM goals WHERE user_id = ?', (user_id,))
        return [dict(row) for row in cursor.fetchall()]

def add_funds_to_goal(user_id: str, goal_id: int, amount: float) -> Dict[str, Any]:
    """Add funds to a goal"""
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE goals 
            SET current_amount = current_amount + ?, updated_at = CURRENT_TIMESTAMP
            WHERE user_id = ? AND id = ?
        ''', (amount, user_id, goal_id))
        
        cursor.execute('SELECT * FROM goals WHERE id = ?', (goal_id,))
        row = cursor.fetchone()
        return dict(row) if row else None

# ==================== AI CONTEXT FOR PERSONALIZATION ====================

def get_ai_context(user_id: str) -> Dict[str, Any]:
    """Get user's financial context for AI personalization"""
    with get_db() as conn:
        cursor = conn.cursor()
        
        # Get recent trends
        trends = get_trends(user_id, 'monthly')
        
        # Get budgets
        cursor.execute('SELECT * FROM budgets WHERE user_id = ?', (user_id,))
        budgets = [dict(row) for row in cursor.fetchall()]
        
        # Get goals
        cursor.execute('SELECT * FROM goals WHERE user_id = ? AND status = "active"', (user_id,))
        goals = [dict(row) for row in cursor.fetchall()]
        
        # Get transaction count
        cursor.execute('SELECT COUNT(*) as count FROM transactions WHERE user_id = ?', (user_id,))
        transaction_count = cursor.fetchone()['count']
        
        # Recent transaction summary
        cursor.execute('''
            SELECT category, type, COUNT(*) as count, SUM(amount) as total
            FROM transactions 
            WHERE user_id = ? AND date >= date('now', '-30 days')
            GROUP BY category, type
            ORDER BY total DESC
            LIMIT 10
        ''', (user_id,))
        
        category_summary = [dict(row) for row in cursor.fetchall()]
        
        return {
            'total_transactions': transaction_count,
            'monthly_income': trends.get('total_income', 0),
            'monthly_expense': trends.get('total_expense', 0),
            'savings_rate': trends.get('savings_rate', 0),
            'top_expense_category': trends.get('top_expense_category'),
            'budgets': budgets,
            'active_goals': goals,
            'category_summary': category_summary,
            'insights': trends.get('insights', [])
        }

def save_chat_message(user_id: str, role: str, content: str):
    """Save chat message for context"""
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO chat_history (user_id, role, content)
            VALUES (?, ?, ?)
        ''', (user_id, role, content))
        
        # Keep only last 50 messages per user
        cursor.execute('''
            DELETE FROM chat_history 
            WHERE user_id = ? AND id NOT IN (
                SELECT id FROM chat_history WHERE user_id = ? 
                ORDER BY timestamp DESC LIMIT 50
            )
        ''', (user_id, user_id))

def get_chat_history(user_id: str, limit: int = 10) -> List[Dict[str, Any]]:
    """Get recent chat history for context"""
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT role, content, timestamp 
            FROM chat_history 
            WHERE user_id = ?
            ORDER BY timestamp DESC
            LIMIT ?
        ''', (user_id, limit))
        
        return [dict(row) for row in cursor.fetchall()][::-1]  # Reverse for chronological order

# Initialize database on import
init_database()
