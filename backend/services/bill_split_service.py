"""
WealthIn Bill Splitting Service
Smart bill splitting with group expense tracking and debt settlement optimization.
"""

import aiosqlite
from datetime import datetime
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
import os

PLANNING_DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'planning.db')

@dataclass
class BillItem:
    """Individual item from a bill"""
    description: str
    amount: float
    quantity: int = 1


@dataclass
class Settlement:
    """Settlement between two users"""
    from_user: str
    to_user: str
    amount: float


class BillSplitService:
    """Service for bill splitting and group expense management"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    async def initialize(self):
        """Initialize bill split tables"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            # Bill splits table
            await db.execute('''
                CREATE TABLE IF NOT EXISTS bill_splits (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    transaction_id INTEGER,
                    group_id INTEGER,
                    total_amount REAL NOT NULL,
                    split_method TEXT DEFAULT 'equal',
                    created_by TEXT NOT NULL,
                    description TEXT,
                    image_url TEXT,
                    created_at TEXT NOT NULL,
                    FOREIGN KEY (group_id) REFERENCES groups (id)
                )
            ''')
            
            # Split items (individual shares)
            await db.execute('''
                CREATE TABLE IF NOT EXISTS split_items (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    split_id INTEGER NOT NULL,
                    participant_id TEXT NOT NULL,
                    participant_name TEXT,
                    amount REAL NOT NULL,
                    settled BOOLEAN DEFAULT 0,
                    settled_at TEXT,
                    FOREIGN KEY (split_id) REFERENCES bill_splits (id)
                )
            ''')
            
            # Bill items (line items from OCR)
            await db.execute('''
                CREATE TABLE IF NOT EXISTS bill_items (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    split_id INTEGER NOT NULL,
                    description TEXT NOT NULL,
                    amount REAL NOT NULL,
                    quantity INTEGER DEFAULT 1,
                    assigned_to TEXT,
                    FOREIGN KEY (split_id) REFERENCES bill_splits (id)
                )
            ''')
            
            # Add nickname column to group_members if not exists
            await db.execute('''
                CREATE TABLE IF NOT EXISTS group_members_temp (
                    group_id INTEGER NOT NULL,
                    user_id TEXT NOT NULL,
                    role TEXT DEFAULT 'member',
                    nickname TEXT,
                    joined_at TEXT NOT NULL,
                    PRIMARY KEY (group_id, user_id)
                )
            ''')
            
            # Try to migrate data if group_members exists
            try:
                await db.execute('''
                    INSERT OR IGNORE INTO group_members_temp (group_id, user_id, role, joined_at)
                    SELECT group_id, user_id, role, joined_at FROM group_members
                ''')
                await db.execute('DROP TABLE IF EXISTS group_members')
                await db.execute('ALTER TABLE group_members_temp RENAME TO group_members')
            except:
                # Table might not exist yet or already has nickname
                await db.execute('DROP TABLE IF EXISTS group_members_temp')
            
            await db.execute('CREATE INDEX IF NOT EXISTS idx_bill_splits_group ON bill_splits(group_id)')
            await db.execute('CREATE INDEX IF NOT EXISTS idx_split_items_split ON split_items(split_id)')
            await db.execute('CREATE INDEX IF NOT EXISTS idx_split_items_participant ON split_items(participant_id)')
            await db.commit()
            
            print("✅ Bill Split Service initialized")
    
    async def create_split(
        self, 
        total_amount: float,
        split_method: str,
        participants: List[Dict[str, Any]],
        created_by: str,
        group_id: Optional[int] = None,
        description: Optional[str] = None,
        image_url: Optional[str] = None,
        items: Optional[List[BillItem]] = None
    ) -> Dict[str, Any]:
        """
        Create a bill split
        
        Args:
            total_amount: Total bill amount
            split_method: 'equal', 'by_item', 'percentage', 'custom'
            participants: List of {user_id, name, amount (for custom), percentage (for percentage)}
            created_by: User ID who created the split
            group_id: Optional group ID
            description: Bill description
            image_url: Bill image URL
            items: List of BillItem for itemized splits
        
        Returns:
            Dictionary with split details
        """
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            now = datetime.utcnow().isoformat()
            
            # Create bill split
            cursor = await db.execute('''
                INSERT INTO bill_splits 
                (transaction_id, group_id, total_amount, split_method, created_by, description, image_url, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (None, group_id, total_amount, split_method, created_by, description, image_url, now))
            
            split_id = cursor.lastrowid
            
            # Calculate shares based on method
            shares = await self._calculate_shares(
                split_method, 
                total_amount, 
                participants, 
                items
            )
            
            # Insert split items
            for share in shares:
                await db.execute('''
                    INSERT INTO split_items (split_id, participant_id, participant_name, amount, settled)
                    VALUES (?, ?, ?, ?, 0)
                ''', (split_id, share['user_id'], share.get('name'), share['amount']))
            
            # Insert bill items if provided
            if items:
                for item in items:
                    await db.execute('''
                        INSERT INTO bill_items (split_id, description, amount, quantity, assigned_to)
                        VALUES (?, ?, ?, ?, ?)
                    ''', (split_id, item.description, item.amount, item.quantity, item.get('assigned_to')))
            
            await db.commit()
            
            return {
                'split_id': split_id,
                'total_amount': total_amount,
                'split_method': split_method,
                'shares': shares,
                'created_at': now
            }
    
    async def _calculate_shares(
        self, 
        method: str, 
        total: float, 
        participants: List[Dict[str, Any]],
        items: Optional[List[BillItem]] = None
    ) -> List[Dict[str, Any]]:
        """Calculate individual shares based on split method"""
        
        if method == 'equal':
            # Equal split among all participants
            share_amount = total / len(participants)
            return [
                {
                    'user_id': p['user_id'],
                    'name': p.get('name', p['user_id']),
                    'amount': round(share_amount, 2)
                }
                for p in participants
            ]
        
        elif method == 'percentage':
            # Split by percentage
            return [
                {
                    'user_id': p['user_id'],
                    'name': p.get('name', p['user_id']),
                    'amount': round(total * p.get('percentage', 0) / 100, 2)
                }
                for p in participants
            ]
        
        elif method == 'custom':
            # Custom amounts specified by user
            return [
                {
                    'user_id': p['user_id'],
                    'name': p.get('name', p['user_id']),
                    'amount': round(p.get('amount', 0), 2)
                }
                for p in participants
            ]
        
        elif method == 'by_item':
            # Split by items assigned
            # This requires items to have 'assigned_to' field
            user_totals = {p['user_id']: 0.0 for p in participants}
            
            if items:
                for item in items:
                    assigned = item.get('assigned_to')
                    if assigned and assigned in user_totals:
                        user_totals[assigned] += item.amount * item.quantity
            
            return [
                {
                    'user_id': uid,
                    'name': next((p.get('name', uid) for p in participants if p['user_id'] == uid), uid),
                    'amount': round(amount, 2)
                }
                for uid, amount in user_totals.items()
            ]
        
        else:
            # Default to equal split
            return await self._calculate_shares('equal', total, participants, items)
    
    async def get_split(self, split_id: int) -> Optional[Dict[str, Any]]:
        """Get split details with items"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            
            # Get split
            cursor = await db.execute('SELECT * FROM bill_splits WHERE id = ?', (split_id,))
            split_row = await cursor.fetchone()
            
            if not split_row:
                return None
            
            split = dict(split_row)
            
            # Get split items
            cursor = await db.execute('SELECT * FROM split_items WHERE split_id = ?', (split_id,))
            items = [dict(row) for row in await cursor.fetchall()]
            
            # Get bill items
            cursor = await db.execute('SELECT * FROM bill_items WHERE split_id = ?', (split_id,))
            bill_items = [dict(row) for row in await cursor.fetchall()]
            
            split['items'] = items
            split['bill_items'] = bill_items
            
            return split
    
    async def get_group_splits(self, group_id: int, limit: int = 50) -> List[Dict[str, Any]]:
        """Get all splits for a group"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cursor = await db.execute('''
                SELECT * FROM bill_splits 
                WHERE group_id = ? 
                ORDER BY created_at DESC 
                LIMIT ?
            ''', (group_id, limit))
            
            return [dict(row) for row in await cursor.fetchall()]
    
    async def get_user_debts(self, user_id: str, group_id: Optional[int] = None) -> Dict[str, Any]:
        """
        Get all debts for a user (who owes them and whom they owe)
        
        Returns:
            {
                'owes_me': [{user_id, name, amount}],  # People who owe this user
                'i_owe': [{user_id, name, amount}],    # People this user owes
                'total_owed_to_me': float,
                'total_i_owe': float,
                'net_balance': float  # positive = they owe you, negative = you owe
            }
        """
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            
            # Build query
            query = '''
                SELECT 
                    bs.created_by as payer_id,
                    si.participant_id,
                    si.participant_name,
                    si.amount,
                    si.settled
                FROM bill_splits bs
                JOIN split_items si ON bs.id = si.split_id
                WHERE si.settled = 0
            '''
            
            params = []
            if group_id:
                query += ' AND bs.group_id = ?'
                params.append(group_id)
            
            cursor = await db.execute(query, params)
            all_splits = await cursor.fetchall()
            
            owes_me = {}  # {user_id: total_amount}
            i_owe = {}    # {user_id: total_amount}
            
            for row in all_splits:
                payer = row['payer_id']
                participant = row['participant_id']
                amount = row['amount']
                
                # If the user paid and someone else participated
                if payer == user_id and participant != user_id:
                    owes_me[participant] = owes_me.get(participant, 0) + amount
                
                # If someone else paid and the user participated
                elif payer != user_id and participant == user_id:
                    i_owe[payer] = i_owe.get(payer, 0) + amount
            
            # Calculate settlements (optimize to minimize transactions)
            settlements = self._optimize_settlements(owes_me, i_owe)
            
            total_owed_to_me = sum(owes_me.values())
            total_i_owe = sum(i_owe.values())
            
            return {
                'owes_me': [{'user_id': uid, 'amount': amt} for uid, amt in owes_me.items()],
                'i_owe': [{'user_id': uid, 'amount': amt} for uid, amt in i_owe.items()],
                'settlements': settlements,
                'total_owed_to_me': round(total_owed_to_me, 2),
                'total_i_owe': round(total_i_owe, 2),
                'net_balance': round(total_owed_to_me - total_i_owe, 2)
            }
    
    def _optimize_settlements(self, owes_me: Dict[str, float], i_owe: Dict[str, float]) -> List[Settlement]:
        """
        Optimize settlements to minimize number of transactions
        Uses debt simplification algorithm
        """
        # Net balances: positive = owed to me, negative = I owe
        balances = {}
        
        for user, amount in owes_me.items():
            balances[user] = balances.get(user, 0) + amount
        
        for user, amount in i_owe.items():
            balances[user] = balances.get(user, 0) - amount
        
        # Separate debtors and creditors
        debtors = [(user, -bal) for user, bal in balances.items() if bal < 0]  # People who owe
        creditors = [(user, bal) for user, bal in balances.items() if bal > 0]  # People who are owed
        
        debtors.sort(key=lambda x: x[1], reverse=True)
        creditors.sort(key=lambda x: x[1], reverse=True)
        
        settlements = []
        i, j = 0, 0
        
        while i < len(debtors) and j < len(creditors):
            debtor, debt = debtors[i]
            creditor, credit = creditors[j]
            
            # Settle the minimum of debt and credit
            settle_amount = min(debt, credit)
            
            settlements.append(Settlement(
                from_user=debtor,
                to_user=creditor,
                amount=round(settle_amount, 2)
            ))
            
            # Update balances
            debtors[i] = (debtor, debt - settle_amount)
            creditors[j] = (creditor, credit - settle_amount)
            
            # Move to next if fully settled
            if debtors[i][1] < 0.01:  # Small threshold for floating point
                i += 1
            if creditors[j][1] < 0.01:
                j += 1
        
        return settlements
    
    async def settle_debt(
        self, 
        from_user_id: str, 
        to_user_id: str, 
        amount: float,
        group_id: Optional[int] = None
    ) -> bool:
        """Mark debts as settled between two users"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            now = datetime.utcnow().isoformat()
            
            # Find all unsettled splits where from_user owes to_user
            query = '''
                UPDATE split_items 
                SET settled = 1, settled_at = ?
                WHERE split_id IN (
                    SELECT bs.id FROM bill_splits bs
                    WHERE bs.created_by = ?
                    {}
                )
                AND participant_id = ?
                AND settled = 0
            '''.format('AND bs.group_id = ?' if group_id else '')
            
            params = [now, to_user_id, from_user_id]
            if group_id:
                params.insert(2, group_id)
            
            await db.execute(query, params)
            await db.commit()
            
            return True
    
    async def delete_split(self, split_id: int, user_id: str) -> bool:
        """Delete a bill split (only creator can delete)"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            # Check if user is creator
            cursor = await db.execute(
                'SELECT created_by FROM bill_splits WHERE id = ?', 
                (split_id,)
            )
            row = await cursor.fetchone()
            
            if not row or row[0] != user_id:
                return False
            
            # Delete split items and bill items
            await db.execute('DELETE FROM split_items WHERE split_id = ?', (split_id,))
            await db.execute('DELETE FROM bill_items WHERE split_id = ?', (split_id,))
            await db.execute('DELETE FROM bill_splits WHERE id = ?', (split_id,))
            await db.commit()
            
            return True


# Singleton instance
bill_split_service = BillSplitService()
