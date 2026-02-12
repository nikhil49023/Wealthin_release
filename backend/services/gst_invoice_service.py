"""
WealthIn GST Invoice Generator Service
Professional GST-compliant invoice generation for MSME businesses.
Supports CGST+SGST (intra-state) and IGST (inter-state) calculations.
"""

import aiosqlite
from datetime import datetime, date
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, asdict
import os
import json
from io import BytesIO

# For PDF generation
try:
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.units import inch
    from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_CENTER, TA_RIGHT
    PDF_AVAILABLE = True
except ImportError:
    PDF_AVAILABLE = False
    print("⚠️ reportlab not installed. PDF generation will be disabled.")

PLANNING_DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'planning.db')

# GST Rates in India
GST_RATES = {
    'nil': 0.0,
    '0.25': 0.25,
    '3': 3.0,
    '5': 5.0,
    '12': 12.0,
    '18': 18.0,
    '28': 28.0,
}

# Common HSN Codes (sample - can be expanded)
HSN_CODES = {
    'software': '998314',
    'consulting': '998313',
    'food_grains': '1006',
    'textiles': '6302',
    'electronics': '8517',
    'furniture': '9403',
    'stationery': '4820',
    'medical': '3004',
    'chemicals': '3824',
    'machinery': '8479',
}


@dataclass
class Customer:
    id: Optional[int]
    user_id: str
    business_name: str
    gstin: str
    state_code: str
    address: str
    email: Optional[str]
    phone: Optional[str]
    created_at: str


@dataclass
class InvoiceItem:
    description: str
    hsn_code: str
    quantity: float
    rate: float
    gst_rate: float
    
    @property
    def taxable_value(self) -> float:
        return self.quantity * self.rate
    
    @property
    def gst_amount(self) -> float:
        return self.taxable_value * (self.gst_rate / 100)
    
    @property
    def total_value(self) -> float:
        return self.taxable_value + self.gst_amount


class GSTInvoiceService:
    """Service for GST invoice generation and customer management"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    async def initialize(self):
        """Initialize GST invoice tables"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            # Customers table
            await db.execute('''
                CREATE TABLE IF NOT EXISTS customers (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    business_name TEXT NOT NULL,
                    gstin TEXT UNIQUE,
                    state_code TEXT NOT NULL,
                    address TEXT NOT NULL,
                    email TEXT,
                    phone TEXT,
                    created_at TEXT NOT NULL
                )
            ''')
            
            # Invoices table
            await db.execute('''
                CREATE TABLE IF NOT EXISTS invoices (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    invoice_number TEXT UNIQUE NOT NULL,
                    customer_id INTEGER NOT NULL,
                    invoice_date TEXT NOT NULL,
                    due_date TEXT,
                    place_of_supply TEXT NOT NULL,
                    taxable_amount REAL NOT NULL,
                    cgst REAL DEFAULT 0,
                    sgst REAL DEFAULT 0,
                    igst REAL DEFAULT 0,
                    cess REAL DEFAULT 0,
                    total_amount REAL NOT NULL,
                    status TEXT DEFAULT 'draft',
                    payment_status TEXT DEFAULT 'unpaid',
                    notes TEXT,
                    created_at TEXT NOT NULL,
                    FOREIGN KEY (customer_id) REFERENCES customers (id)
                )
            ''')
            
            # Invoice items table
            await db.execute('''
                CREATE TABLE IF NOT EXISTS invoice_items (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    invoice_id INTEGER NOT NULL,
                    description TEXT NOT NULL,
                    hsn_code TEXT NOT NULL,
                    quantity REAL NOT NULL,
                    rate REAL NOT NULL,
                    gst_rate REAL NOT NULL,
                    taxable_value REAL NOT NULL,
                    gst_amount REAL NOT NULL,
                    total_value REAL NOT NULL,
                    FOREIGN KEY (invoice_id) REFERENCES invoices (id)
                )
            ''')
            
            # Business profile table (for invoice header)
            await db.execute('''
                CREATE TABLE IF NOT EXISTS business_profile (
                    user_id TEXT PRIMARY KEY,
                    business_name TEXT NOT NULL,
                    gstin TEXT NOT NULL,
                    state_code TEXT NOT NULL,
                    address TEXT NOT NULL,
                    email TEXT,
                    phone TEXT,
                    logo_url TEXT,
                    invoice_prefix TEXT DEFAULT 'INV',
                    next_invoice_number INTEGER DEFAULT 1,
                    bank_name TEXT,
                    bank_account TEXT,
                    bank_ifsc TEXT,
                    updated_at TEXT NOT NULL
                )
            ''')
            
            await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_user ON invoices(user_id)')
            await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices(customer_id)')
            await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_user ON customers(user_id)')
            await db.commit()
            
            print("✅ GST Invoice Service initialized")
    
    # ==================== CUSTOMER MANAGEMENT ====================
    
    async def create_customer(self, customer: Customer) -> Customer:
        """Create a new customer"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            now = datetime.utcnow().isoformat()
            cursor = await db.execute('''
                INSERT INTO customers (user_id, business_name, gstin, state_code, address, email, phone, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (customer.user_id, customer.business_name, customer.gstin, customer.state_code,
                  customer.address, customer.email, customer.phone, now))
            await db.commit()
            customer.id = cursor.lastrowid
            customer.created_at = now
            return customer
    
    async def get_customers(self, user_id: str) -> List[Customer]:
        """Get all customers for a user"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cursor = await db.execute(
                'SELECT * FROM customers WHERE user_id = ? ORDER BY business_name',
                (user_id,)
            )
            rows = await cursor.fetchall()
            return [Customer(**dict(row)) for row in rows]
    
    async def get_customer(self, customer_id: int, user_id: str) -> Optional[Customer]:
        """Get a specific customer"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cursor = await db.execute(
                'SELECT * FROM customers WHERE id = ? AND user_id = ?',
                (customer_id, user_id)
            )
            row = await cursor.fetchone()
            return Customer(**dict(row)) if row else None
    
    # ==================== BUSINESS PROFILE ====================
    
    async def set_business_profile(self, user_id: str, profile: Dict[str, Any]) -> bool:
        """Set or update business profile for invoice generation"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            now = datetime.utcnow().isoformat()
            await db.execute('''
                INSERT OR REPLACE INTO business_profile 
                (user_id, business_name, gstin, state_code, address, email, phone, 
                 logo_url, invoice_prefix, bank_name, bank_account, bank_ifsc, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                user_id,
                profile.get('business_name'),
                profile.get('gstin'),
                profile.get('state_code'),
                profile.get('address'),
                profile.get('email'),
                profile.get('phone'),
                profile.get('logo_url'),
                profile.get('invoice_prefix', 'INV'),
                profile.get('bank_name'),
                profile.get('bank_account'),
                profile.get('bank_ifsc'),
                now
            ))
            await db.commit()
            return True
    
    async def get_business_profile(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get business profile"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cursor = await db.execute(
                'SELECT * FROM business_profile WHERE user_id = ?',
                (user_id,)
            )
            row = await cursor.fetchone()
            return dict(row) if row else None
    
    # ==================== INVOICE GENERATION ====================
    
    def calculate_gst(
        self,
        items: List[InvoiceItem],
        seller_state: str,
        buyer_state: str
    ) -> Dict[str, float]:
        """
        Calculate GST amounts based on state codes
        CGST + SGST (intra-state) or IGST (inter-state)
        """
        taxable_amount = sum(item.taxable_value for item in items)
        total_gst = sum(item.gst_amount for item in items)
        
        is_intra_state = seller_state == buyer_state
        
        if is_intra_state:
            # CGST + SGST (split equally)
            cgst = total_gst / 2
            sgst = total_gst / 2
            igst = 0
        else:
            # IGST (inter-state)
            cgst = 0
            sgst = 0
            igst = total_gst
        
        return {
            'taxable_amount': taxable_amount,
            'cgst': cgst,
            'sgst': sgst,
            'igst': igst,
            'cess': 0,  # Can be added for specific items
            'total_amount': taxable_amount + total_gst
        }
    
    async def generate_invoice_number(self, user_id: str) -> str:
        """Generate next invoice number with financial year"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            # Get business profile
            cursor = await db.execute(
                'SELECT invoice_prefix, next_invoice_number FROM business_profile WHERE user_id = ?',
                (user_id,)
            )
            row = await cursor.fetchone()
            
            if row:
                prefix = row[0]
                next_num = row[1]
            else:
                prefix = 'INV'
                next_num = 1
            
            # Get current financial year (Apr-Mar)
            today = date.today()
            if today.month >= 4:
                fy = f"{today.year % 100}-{(today.year + 1) % 100}"
            else:
                fy = f"{(today.year - 1) % 100}-{today.year % 100}"
            
            invoice_number = f"{prefix}/{fy}/{next_num:04d}"
            
            # Increment counter
            await db.execute(
                'UPDATE business_profile SET next_invoice_number = ? WHERE user_id = ?',
                (next_num + 1, user_id)
            )
            await db.commit()
            
            return invoice_number
    
    async def create_invoice(
        self,
        user_id: str,
        customer_id: int,
        items: List[Dict[str, Any]],
        invoice_date: Optional[str] = None,
        due_date: Optional[str] = None,
        notes: Optional[str] = None
    ) -> Dict[str, Any]:
        """Create a new GST invoice"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            # Get business profile and customer
            profile = await self.get_business_profile(user_id)
            if not profile:
                raise Exception("Business profile not set. Please set your business details first.")
            
            customer = await self.get_customer(customer_id, user_id)
            if not customer:
                raise Exception("Customer not found")
            
            # Convert items to InvoiceItem objects
            invoice_items = [
                InvoiceItem(
                    description=item['description'],
                    hsn_code=item['hsn_code'],
                    quantity=item['quantity'],
                    rate=item['rate'],
                    gst_rate=item['gst_rate']
                )
                for item in items
            ]
            
            # Calculate GST
            gst_calc = self.calculate_gst(
                invoice_items,
                profile['state_code'],
                customer.state_code
            )
            
            # Generate invoice number
            invoice_number = await self.generate_invoice_number(user_id)
            
            # Create invoice
            now = datetime.utcnow().isoformat()
            invoice_date = invoice_date or date.today().isoformat()
            
            cursor = await db.execute('''
                INSERT INTO invoices 
                (user_id, invoice_number, customer_id, invoice_date, due_date, place_of_supply,
                 taxable_amount, cgst, sgst, igst, cess, total_amount, status, notes, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'draft', ?, ?)
            ''', (
                user_id, invoice_number, customer_id, invoice_date, due_date,
                customer.state_code,
                gst_calc['taxable_amount'],
                gst_calc['cgst'],
                gst_calc['sgst'],
                gst_calc['igst'],
                gst_calc['cess'],
                gst_calc['total_amount'],
                notes,
                now
            ))
            
            invoice_id = cursor.lastrowid
            
            # Insert invoice items
            for item in invoice_items:
                await db.execute('''
                    INSERT INTO invoice_items 
                    (invoice_id, description, hsn_code, quantity, rate, gst_rate,
                     taxable_value, gst_amount, total_value)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    invoice_id,
                    item.description,
                    item.hsn_code,
                    item.quantity,
                    item.rate,
                    item.gst_rate,
                    item.taxable_value,
                    item.gst_amount,
                    item.total_value
                ))
            
            await db.commit()
            
            return {
                'invoice_id': invoice_id,
                'invoice_number': invoice_number,
                'customer_name': customer.business_name,
                'invoice_date': invoice_date,
                **gst_calc
            }
    
    async def get_invoice(self, invoice_id: int, user_id: str) -> Optional[Dict[str, Any]]:
        """Get complete invoice with items"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            
            # Get invoice
            cursor = await db.execute(
                'SELECT * FROM invoices WHERE id = ? AND user_id = ?',
                (invoice_id, user_id)
            )
            invoice_row = await cursor.fetchone()
            
            if not invoice_row:
                return None
            
            invoice = dict(invoice_row)
            
            # Get items
            cursor = await db.execute(
                'SELECT * FROM invoice_items WHERE invoice_id = ?',
                (invoice_id,)
            )
            items = [dict(row) for row in await cursor.fetchall()]
            
            # Get customer
            customer = await self.get_customer(invoice['customer_id'], user_id)
            
            invoice['items'] = items
            invoice['customer'] = asdict(customer) if customer else None
            
            return invoice
    
    async def get_invoices(
        self,
        user_id: str,
        status: Optional[str] = None,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        """Get all invoices for a user"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            
            query = 'SELECT * FROM invoices WHERE user_id = ?'
            params = [user_id]
            
            if status:
                query += ' AND status = ?'
                params.append(status)
            
            query += ' ORDER BY invoice_date DESC, created_at DESC LIMIT ?'
            params.append(limit)
            
            cursor = await db.execute(query, params)
            return [dict(row) for row in await cursor.fetchall()]
    
    async def update_invoice_status(
        self,
        invoice_id: int,
        user_id: str,
        status: str,
        payment_status: Optional[str] = None
    ) -> bool:
        """Update invoice status (draft, sent, paid)"""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            updates = {'status': status}
            if payment_status:
                updates['payment_status'] = payment_status
            
            set_clause = ', '.join(f'{k} = ?' for k in updates.keys())
            values = list(updates.values()) + [invoice_id, user_id]
            
            await db.execute(
                f'UPDATE invoices SET {set_clause} WHERE id = ? AND user_id = ?',
                values
            )
            await db.commit()
            return True
    
    # ==================== HSN CODE LOOKUP ====================
    
    def suggest_hsn_code(self, product_name: str) -> Optional[str]:
        """Suggest HSN code based on product name"""
        product_lower = product_name.lower()
        
        for key, hsn in HSN_CODES.items():
            if key in product_lower:
                return hsn
        
        return None
    
    def get_common_hsn_codes(self) -> Dict[str, str]:
        """Get list of common HSN codes"""
        return HSN_CODES.copy()


# Singleton instance
gst_invoice_service = GSTInvoiceService()
