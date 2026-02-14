"""
WealthIn Merchant Flagging Service
Implements "One-Click" Merchant-to-Category Rules with Fuzzy Matching.
"""

import re
import aiosqlite
from typing import Optional, List, Dict, Any
from dataclasses import dataclass
import os

# Database path (same as planning.db for consistency)
PLANNING_DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'planning.db')


@dataclass
class MerchantRule:
    id: Optional[int]
    keyword: str  # Cleaned keyword (e.g., "ZOMATO")
    category: str
    is_auto: bool = True


class MerchantService:
    """
    Manages merchant-to-category rules for automatic transaction categorization.
    Uses fuzzy/substring matching to handle noisy transaction strings.
    """

    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    async def initialize(self):
        """Create the merchant_rules table if it doesn't exist."""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            await db.execute('''
                CREATE TABLE IF NOT EXISTS merchant_rules (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    keyword TEXT UNIQUE NOT NULL,
                    category TEXT NOT NULL,
                    is_auto INTEGER DEFAULT 1
                )
            ''')
            await db.execute('CREATE INDEX IF NOT EXISTS idx_merchant_keyword ON merchant_rules(keyword)')
            await db.commit()
            print("✅ Merchant Rules table initialized")

    @staticmethod
    def clean_merchant_name(raw_name: str) -> str:
        """
        Strips noise from transaction descriptions to extract the core merchant name.
        
        Examples:
        - "ZOMATO*ORDER12345" -> "ZOMATO"
        - "HDFC-ATM-VZN-123" -> "HDFC ATM VZN"
        - "AMAZON PAY INDIA PRIVATE LIMITED" -> "AMAZON PAY"
        - "POS 123456 STARBUCKS COFFEE" -> "STARBUCKS COFFEE"
        """
        if not raw_name:
            return ""
        
        # Convert to uppercase for consistency
        name = raw_name.upper().strip()
        
        # Remove common prefixes
        prefixes_to_remove = [
            r'^UPI[-/]',
            r'^POS\s*\d*\s*',
            r'^NEFT[-/]',
            r'^IMPS[-/]',
            r'^ATM[-/]',
            r'^VISA[-/]',
            r'^MSTR[-/]',  # Mastercard
        ]
        for prefix in prefixes_to_remove:
            name = re.sub(prefix, '', name)
        
        # Remove trailing reference numbers (e.g., *ORDER123, -TXN456)
        name = re.sub(r'[\*\-/#]\s*[A-Z0-9]{5,}$', '', name)
        
        # Remove standalone numbers at end
        name = re.sub(r'\s+\d+$', '', name)
        
        # Remove common suffixes
        suffixes_to_remove = [
            r'\s+PRIVATE\s+LIMITED.*$',
            r'\s+PVT\s+LTD.*$',
            r'\s+LTD.*$',
            r'\s+INDIA$',
        ]
        for suffix in suffixes_to_remove:
            name = re.sub(suffix, '', name, flags=re.IGNORECASE)
        
        # Replace multiple spaces/special chars with single space
        name = re.sub(r'[\-_/\*]+', ' ', name)
        name = re.sub(r'\s+', ' ', name).strip()
        
        # Take first 2-3 words as the core merchant name if too long
        words = name.split()
        if len(words) > 3:
            name = ' '.join(words[:3])
        
        return name.strip()

    async def get_all_rules(self) -> List[MerchantRule]:
        """Get all stored merchant rules."""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cursor = await db.execute('SELECT * FROM merchant_rules ORDER BY keyword')
            rows = await cursor.fetchall()
            return [MerchantRule(
                id=row['id'],
                keyword=row['keyword'],
                category=row['category'],
                is_auto=bool(row['is_auto'])
            ) for row in rows]

    async def find_matching_rule(self, raw_transaction_name: str) -> Optional[MerchantRule]:
        """
        Finds a matching rule using substring/fuzzy matching.
        
        Logic:
        1. Clean the incoming transaction name.
        2. Check if any stored keyword is a SUBSTRING of the cleaned name.
        3. Return the first match (longest keyword first for specificity).
        """
        cleaned = self.clean_merchant_name(raw_transaction_name)
        if not cleaned:
            return None
        
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            # Order by keyword length DESC to match most specific first
            cursor = await db.execute('''
                SELECT * FROM merchant_rules 
                ORDER BY LENGTH(keyword) DESC
            ''')
            rows = await cursor.fetchall()
            
            for row in rows:
                keyword = row['keyword'].upper()
                # Check if keyword is a substring of cleaned name
                if keyword in cleaned:
                    return MerchantRule(
                        id=row['id'],
                        keyword=row['keyword'],
                        category=row['category'],
                        is_auto=bool(row['is_auto'])
                    )
        
        return None

    async def add_rule(self, keyword: str, category: str, is_auto: bool = True) -> Optional[MerchantRule]:
        """
        Add a new merchant rule.
        The keyword is cleaned before storing for consistency.
        """
        cleaned_keyword = self.clean_merchant_name(keyword) if '*' in keyword or '-' in keyword else keyword.upper().strip()
        
        if not cleaned_keyword:
            return None
        
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            try:
                cursor = await db.execute('''
                    INSERT INTO merchant_rules (keyword, category, is_auto)
                    VALUES (?, ?, ?)
                ''', (cleaned_keyword, category, 1 if is_auto else 0))
                await db.commit()
                return MerchantRule(
                    id=cursor.lastrowid,
                    keyword=cleaned_keyword,
                    category=category,
                    is_auto=is_auto
                )
            except aiosqlite.IntegrityError:
                # Keyword already exists, update it
                await db.execute('''
                    UPDATE merchant_rules SET category = ?, is_auto = ?
                    WHERE keyword = ?
                ''', (category, 1 if is_auto else 0, cleaned_keyword))
                await db.commit()
                return MerchantRule(
                    id=None,  # Unknown after update
                    keyword=cleaned_keyword,
                    category=category,
                    is_auto=is_auto
                )

    async def delete_rule(self, rule_id: int) -> bool:
        """Delete a merchant rule by ID."""
        async with aiosqlite.connect(PLANNING_DB_PATH) as db:
            cursor = await db.execute('DELETE FROM merchant_rules WHERE id = ?', (rule_id,))
            await db.commit()
            return cursor.rowcount > 0

    async def seed_default_rules(self):
        """
        Seed the database with common Indian merchant rules for demo purposes.
        """
        default_rules = [
            ("AMAZON", "Shopping"),
            ("FLIPKART", "Shopping"),
            ("ZOMATO", "Food & Dining"),
            ("SWIGGY", "Food & Dining"),
            ("STARBUCKS", "Food & Dining"),
            ("UBER", "Transport"),
            ("OLA", "Transport"),
            ("NETFLIX", "Entertainment"),
            ("SPOTIFY", "Entertainment"),
            ("HDFC SIP", "Investment"),
            ("ICICI MF", "Investment"),
            ("LIC", "Insurance"),
            ("BESCOM", "Utilities"),
            ("BSNL", "Utilities"),
            ("JIO", "Utilities"),
            ("AIRTEL", "Utilities"),
        ]
        
        for keyword, category in default_rules:
            await self.add_rule(keyword, category, is_auto=True)
        
        print(f"✅ Seeded {len(default_rules)} default merchant rules")


# Singleton instance
merchant_service = MerchantService()
