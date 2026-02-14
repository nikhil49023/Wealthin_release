"""
WealthIn Vendor Payment Tracker Service
Track vendor/supplier payments, maintain vendor relationships, and manage credit terms.
Essential for MSME supply chain management.
"""

import aiosqlite
from datetime import datetime, date, timedelta
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, asdict
import os

PLANNING_DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'planning.db')


@dataclass
class Vendor:
    id: Optional[int]
    user_id: str
    vendor_name: str
    vendor_type: str  # 'supplier', 'contractor', 'utility', 'service'
    gstin: Optional[str]
    contact_person: Optional[str]
    email: Optional[str]
    phone: Optional[str]
    address: Optional[str]
    payment_terms: int  # Days (e.g., 30 for Net-30)
    credit_limit: float
    status: str  # 'active', 'blocked', 'inactive'
    created_at: str


@dataclass
class VendorPayment:
    id: Optional[int]
    user_id: str
    vendor_id: int
    bill_number: str
    bill_date: str
    due_date: str
    amount: float
    gst_amount: float
    total_amount: float
    payment_status: str  # 'pending', 'partial', 'paid'
    paid_amount: float
    payment_date: Optional[str]
    days_overdue: int
    notes: Optional[str]
    created_at: str


class VendorPaymentService:
    """Service for vendor payment tracking and management"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    async def initialize(self):
        """Initialize vendor payment tracking tables"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            # Vendors table
            await db.execute('''
                CREATE TABLE IF NOT EXISTS vendors (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    vendor_name TEXT NOT NULL,
                    vendor_type TEXT NOT NULL,
                    gstin TEXT,
                    contact_person TEXT,
                    email TEXT,
                    phone TEXT,
                    address TEXT,
                    payment_terms INTEGER DEFAULT 30,
                    credit_limit REAL DEFAULT 0,
                    status TEXT DEFAULT 'active',
                    created_at TEXT NOT NULL
                )
            ''')
            
            # Vendor payments/bills table
            await db.execute('''
                CREATE TABLE IF NOT EXISTS vendor_payments (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    vendor_id INTEGER NOT NULL,
                    bill_number TEXT NOT NULL,
                    bill_date TEXT NOT NULL,
                    due_date TEXT NOT NULL,
                    amount REAL NOT NULL,
                    gst_amount REAL DEFAULT 0,
                    total_amount REAL NOT NULL,
                    payment_status TEXT DEFAULT 'pending',
                    paid_amount REAL DEFAULT 0,
                    payment_date TEXT,
                    notes TEXT,
                    created_at TEXT NOT NULL,
                    FOREIGN KEY (vendor_id) REFERENCES vendors (id)
                )
            ''')
            
            # Payment history (for partial payments)
            await db.execute('''
                CREATE TABLE IF NOT EXISTS payment_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    vendor_payment_id INTEGER NOT NULL,
                    amount REAL NOT NULL,
                    payment_date TEXT NOT NULL,
                    payment_method TEXT,
                    reference_number TEXT,
                    notes TEXT,
                    created_at TEXT NOT NULL,
                    FOREIGN KEY (vendor_payment_id) REFERENCES vendor_payments (id)
                )
            ''')
            
            await db.execute('CREATE INDEX IF NOT EXISTS idx_vendors_user ON vendors(user_id)')
            await db.execute('CREATE INDEX IF NOT EXISTS idx_vendor_payments_user ON vendor_payments(user_id)')
            await db.execute('CREATE INDEX IF NOT EXISTS idx_vendor_payments_vendor ON vendor_payments(vendor_id)')
            await db.execute('CREATE INDEX IF NOT EXISTS idx_vendor_payments_status ON vendor_payments(payment_status)')
            await db.commit()
            
            print("✅ Vendor Payment Service initialized")
    
    # ==================== VENDOR MANAGEMENT ====================
    
    async def create_vendor(self, vendor: Vendor) -> Vendor:
        """Create a new vendor"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            now = datetime.utcnow().isoformat()
            cursor = await db.execute('''
                INSERT INTO vendors 
                (user_id, vendor_name, vendor_type, gstin, contact_person, email, phone,
                 address, payment_terms, credit_limit, status, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                vendor.user_id, vendor.vendor_name, vendor.vendor_type, vendor.gstin,
                vendor.contact_person, vendor.email, vendor.phone, vendor.address,
                vendor.payment_terms, vendor.credit_limit, vendor.status, now
            ))
            await db.commit()
            vendor.id = cursor.lastrowid
            vendor.created_at = now
            return vendor
    
    async def get_vendors(
        self,
        user_id: str,
        status: Optional[str] = 'active'
    ) -> List[Vendor]:
        """Get all vendors"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            
            query = 'SELECT * FROM vendors WHERE user_id = ?'
            params = [user_id]
            
            if status:
                query += ' AND status = ?'
                params.append(status)
            
            query += ' ORDER BY vendor_name'
            
            cursor = await db.execute(query, params)
            rows = await cursor.fetchall()
            return [Vendor(**dict(row)) for row in rows]
    
    async def get_vendor(self, vendor_id: int, user_id: str) -> Optional[Vendor]:
        """Get a specific vendor"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cursor = await db.execute(
                'SELECT * FROM vendors WHERE id = ? AND user_id = ?',
                (vendor_id, user_id)
            )
            row = await cursor.fetchone()
            return Vendor(**dict(row)) if row else None
    
    async def update_vendor_status(
        self,
        vendor_id: int,
        user_id: str,
        status: str
    ) -> bool:
        """Update vendor status (active/blocked/inactive)"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            await db.execute(
                'UPDATE vendors SET status = ? WHERE id = ? AND user_id = ?',
                (status, vendor_id, user_id)
            )
            await db.commit()
            return True
    
    # ==================== PAYMENT MANAGEMENT ====================
    
    async def record_vendor_bill(
        self,
        user_id: str,
        vendor_id: int,
        bill_number: str,
        bill_date: str,
        amount: float,
        gst_amount: float = 0,
        notes: Optional[str] = None
    ) -> Dict[str, Any]:
        """Record a new vendor bill"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            # Get vendor to determine payment terms
            vendor = await self.get_vendor(vendor_id, user_id)
            if not vendor:
                raise Exception("Vendor not found")
            
            # Calculate due date based on payment terms
            bill_dt = datetime.fromisoformat(bill_date).date()
            due_dt = bill_dt + timedelta(days=vendor.payment_terms)
            
            total_amount = amount + gst_amount
            now = datetime.utcnow().isoformat()
            
            cursor = await db.execute('''
                INSERT INTO vendor_payments
                (user_id, vendor_id, bill_number, bill_date, due_date, amount,
                 gst_amount, total_amount, payment_status, paid_amount, notes, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', 0, ?, ?)
            ''', (
                user_id, vendor_id, bill_number, bill_date, due_dt.isoformat(),
                amount, gst_amount, total_amount, notes, now
            ))
            await db.commit()
            
            return {
                'payment_id': cursor.lastrowid,
                'vendor_name': vendor.vendor_name,
                'bill_number': bill_number,
                'amount': total_amount,
                'due_date': due_dt.isoformat(),
                'payment_terms': f'Net-{vendor.payment_terms}'
            }
    
    async def make_payment(
        self,
        payment_id: int,
        user_id: str,
        amount: float,
        payment_date: Optional[str] = None,
        payment_method: Optional[str] = None,
        reference: Optional[str] = None,
        notes: Optional[str] = None
    ) -> bool:
        """Record a payment (full or partial)"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            # Get current payment status
            cursor = await db.execute('''
                SELECT total_amount, paid_amount
                FROM vendor_payments
                WHERE id = ? AND user_id = ?
            ''', (payment_id, user_id))
            
            row = await cursor.fetchone()
            if not row:
                return False
            
            total_amount, current_paid = row
            new_paid_amount = current_paid + amount
            
            # Determine new status
            if new_paid_amount >= total_amount:
                new_status = 'paid'
                new_paid_amount = total_amount  # Cap at total
            elif new_paid_amount > 0:
                new_status = 'partial'
            else:
                new_status = 'pending'
            
            payment_date = payment_date or date.today().isoformat()
            now = datetime.utcnow().isoformat()
            
            # Update payment record
            await db.execute('''
                UPDATE vendor_payments
                SET paid_amount = ?,
                    payment_status = ?,
                    payment_date = ?
                WHERE id = ?
            ''', (new_paid_amount, new_status, payment_date, payment_id))
            
            # Record in payment history
            await db.execute('''
                INSERT INTO payment_history
                (vendor_payment_id, amount, payment_date, payment_method, reference_number, notes, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (payment_id, amount, payment_date, payment_method, reference, notes, now))
            
            await db.commit()
            return True
    
    async def get_pending_payments(
        self,
        user_id: str,
        include_overdue_only: bool = False
    ) -> List[Dict[str, Any]]:
        """Get all pending vendor payments"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            
            query = '''
                SELECT 
                    vp.*,
                    v.vendor_name,
                    v.payment_terms,
                    julianday('now') - julianday(vp.due_date) as days_overdue
                FROM vendor_payments vp
                JOIN vendors v ON vp.vendor_id = v.id
                WHERE vp.user_id = ?
                AND vp.payment_status IN ('pending', 'partial')
            '''
            
            params = [user_id]
            
            if include_overdue_only:
                query += ' AND julianday("now") > julianday(vp.due_date)'
            
            query += ' ORDER BY vp.due_date ASC'
            
            cursor = await db.execute(query, params)
            payments = []
            
            for row in await cursor.fetchall():
                payment_dict = dict(row)
                payment_dict['days_overdue'] = max(0, int(payment_dict['days_overdue']))
                payments.append(payment_dict)
            
            return payments
    
    async def get_vendor_statement(
        self,
        vendor_id: int,
        user_id: str,
        from_date: Optional[str] = None,
        to_date: Optional[str] = None
    ) -> Dict[str, Any]:
        """Get complete vendor statement"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            
            # Get vendor details
            vendor = await self.get_vendor(vendor_id, user_id)
            if not vendor:
                return None
            
            # Build date filter
            date_filter = ''
            params = [vendor_id, user_id]
            
            if from_date:
                date_filter += ' AND bill_date >= ?'
                params.append(from_date)
            if to_date:
                date_filter += ' AND bill_date <= ?'
                params.append(to_date)
            
            # Get all payments
            cursor = await db.execute(f'''
                SELECT * FROM vendor_payments
                WHERE vendor_id = ? AND user_id = ?
                {date_filter}
                ORDER BY bill_date DESC
            ''', params)
            
            payments = [dict(row) for row in await cursor.fetchall()]
            
            # Calculate totals
            total_billed = sum(p['total_amount'] for p in payments)
            total_paid = sum(p['paid_amount'] for p in payments)
            total_pending = total_billed - total_paid
            
            # Get overdue count
            overdue_count = sum(
                1 for p in payments
                if p['payment_status'] != 'paid' and p['due_date'] < date.today().isoformat()
            )
            
            return {
                'vendor': asdict(vendor),
                'payments': payments,
                'summary': {
                    'total_billed': total_billed,
                    'total_paid': total_paid,
                    'total_pending': total_pending,
                    'payment_count': len(payments),
                    'overdue_count': overdue_count
                }
            }
    
    async def get_vendor_analytics(self, user_id: str) -> Dict[str, Any]:
        """Get vendor payment analytics"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            
            # Total pending by vendor
            cursor = await db.execute('''
                SELECT 
                    v.vendor_name,
                    SUM(vp.total_amount - vp.paid_amount) as pending_amount,
                    COUNT(*) as bill_count
                FROM vendor_payments vp
                JOIN vendors v ON vp.vendor_id = v.id
                WHERE vp.user_id = ?
                AND vp.payment_status IN ('pending', 'partial')
                GROUP BY vp.vendor_id
                ORDER BY pending_amount DESC
                LIMIT 10
            ''', (user_id,))
            
            top_vendors = [dict(row) for row in await cursor.fetchall()]
            
            # Overdue payments
            cursor = await db.execute('''
                SELECT COUNT(*) as count, SUM(total_amount - paid_amount) as amount
                FROM vendor_payments
                WHERE user_id = ?
                AND payment_status IN ('pending', 'partial')
                AND due_date < date('now')
            ''', (user_id,))
            
            overdue = dict(await cursor.fetchone())
            
            # Payment trends (last 6 months)
            cursor = await db.execute('''
                SELECT 
                    strftime('%Y-%m', bill_date) as month,
                    SUM(total_amount) as total
                FROM vendor_payments
                WHERE user_id = ?
                AND bill_date >= date('now', '-6 months')
                GROUP BY month
                ORDER BY month
            ''', (user_id,))
            
            monthly_trends = [dict(row) for row in await cursor.fetchall()]
            
            # Average payment delay
            cursor = await db.execute('''
                SELECT AVG(julianday(payment_date) - julianday(due_date)) as avg_delay
                FROM vendor_payments
                WHERE user_id = ?
                AND payment_status = 'paid'
                AND payment_date IS NOT NULL
            ''', (user_id,))
            
            avg_delay = await cursor.fetchone()
            avg_delay_days = int(avg_delay[0]) if avg_delay[0] else 0
            
            return {
                'top_vendors_by_pending': top_vendors,
                'overdue_summary': overdue,
                'monthly_trends': monthly_trends,
                'average_payment_delay_days': avg_delay_days
            }
    
    async def get_payment_calendar(
        self,
        user_id: str,
        days_ahead: int = 30
    ) -> List[Dict[str, Any]]:
        """Get upcoming payment due dates"""
        today = date.today()
        end_date = today + timedelta(days=days_ahead)
        
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            
            cursor = await db.execute('''
                SELECT 
                    vp.due_date,
                    vp.bill_number,
                    vp.total_amount - vp.paid_amount as pending_amount,
                    v.vendor_name
                FROM vendor_payments vp
                JOIN vendors v ON vp.vendor_id = v.id
                WHERE vp.user_id = ?
                AND vp.payment_status IN ('pending', 'partial')
                AND vp.due_date BETWEEN ? AND ?
                ORDER BY vp.due_date
            ''', (user_id, today.isoformat(), end_date.isoformat()))
            
            return [dict(row) for row in await cursor.fetchall()]


# Singleton instance
vendor_payment_service = VendorPaymentService()
