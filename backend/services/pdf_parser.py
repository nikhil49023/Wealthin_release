"""
PDF Parser Service for Bank Statements and Financial Documents
Extracts transaction data from structured PDFs like bank statements.
Supports Indian bank formats: HDFC, SBI, ICICI, Axis, etc.
"""

import os
import re
import pdfplumber
from fastapi import UploadFile
from typing import List, Dict, Optional, Any
from datetime import datetime
from dataclasses import dataclass


@dataclass
class ExtractedTransaction:
    """Represents a transaction extracted from a document"""
    date: str
    description: str
    amount: float
    type: str  # 'income' or 'expense'
    balance: Optional[float] = None
    category: str = "Other"
    reference: str = ""


class PDFParserService:
    """
    Service for parsing PDF documents, especially bank statements.
    Uses pattern matching for Indian bank statement formats.
    """
    
    # Common Indian date formats
    DATE_PATTERNS = [
        r'\d{2}/\d{2}/\d{4}',  # DD/MM/YYYY
        r'\d{2}-\d{2}-\d{4}',  # DD-MM-YYYY
        r'\d{2}\s+\w{3}\s+\d{4}',  # DD MMM YYYY
        r'\d{2}/\d{2}/\d{2}',  # DD/MM/YY
        r'\d{4}-\d{2}-\d{2}',  # YYYY-MM-DD
    ]
    
    # Amount pattern (supports Indian format with commas)
    AMOUNT_PATTERN = r'[\d,]+\.?\d*'
    
    # Bank-specific patterns
    BANK_PATTERNS = {
        'hdfc': {
            'header_markers': ['HDFC BANK', 'Statement of Account'],
            'transaction_pattern': r'(\d{2}/\d{2}/\d{4})\s+(.+?)\s+([\d,]+\.?\d*)\s*(Dr|Cr)?\s*([\d,]+\.?\d*)?',
        },
        'sbi': {
            'header_markers': ['State Bank of India', 'SBI'],
            'transaction_pattern': r'(\d{2}\s+\w{3}\s+\d{4})\s+(.+?)\s+([\d,]+\.?\d*)\s*([\d,]+\.?\d*)?',
        },
        'icici': {
            'header_markers': ['ICICI Bank', 'ICICI BANK'],
            'transaction_pattern': r'(\d{2}-\d{2}-\d{4})\s+(.+?)\s+([\d,]+\.?\d*)\s+([\d,]+\.?\d*)?',
        },
        'axis': {
            'header_markers': ['Axis Bank', 'AXIS BANK'],
            'transaction_pattern': r'(\d{2}/\d{2}/\d{4})\s+(.+?)\s+([\d,]+\.?\d*)\s+([\d,]+\.?\d*)?',
        },
    }
    
    # Category detection keywords
    CATEGORY_KEYWORDS = {
        'Food & Dining': ['swiggy', 'zomato', 'restaurant', 'food', 'cafe', 'dining', 'pizza', 'burger', 'dominos', 'mcdonalds'],
        'Shopping': ['amazon', 'flipkart', 'myntra', 'ajio', 'mall', 'store', 'retail', 'shopping'],
        'Transport': ['uber', 'ola', 'rapido', 'fuel', 'petrol', 'diesel', 'parking', 'metro', 'railway', 'irctc'],
        'Entertainment': ['netflix', 'amazon prime', 'hotstar', 'spotify', 'movie', 'cinema', 'pvr', 'inox', 'gaming'],
        'Utilities': ['electricity', 'water', 'gas', 'internet', 'broadband', 'mobile', 'recharge', 'bill payment'],
        'Healthcare': ['pharmacy', 'hospital', 'doctor', 'medical', 'medicine', 'apollo', 'medplus', 'health'],
        'Education': ['school', 'college', 'tuition', 'course', 'udemy', 'coursera', 'books'],
        'Investment': ['mutual fund', 'sip', 'zerodha', 'groww', 'upstox', 'investment', 'stock', 'shares'],
        'Insurance': ['insurance', 'lic', 'premium', 'health insurance', 'life insurance'],
        'Rent': ['rent', 'house rent', 'room rent', 'pg', 'paying guest'],
        'Salary': ['salary', 'payroll', 'wages', 'income'],
        'Transfer': ['neft', 'imps', 'upi', 'transfer', 'p2p'],
        'ATM': ['atm', 'cash withdrawal', 'withdrawal'],
    }
    
    async def extract_text(self, file: UploadFile) -> str:
        """Extract raw text from PDF"""
        text = ""
        temp_filename = None
        try:
            temp_filename = f"temp_{file.filename}"
            content = await file.read()
            with open(temp_filename, "wb") as f:
                f.write(content)
            
            with pdfplumber.open(temp_filename) as pdf:
                for page in pdf.pages:
                    page_text = page.extract_text()
                    if page_text:
                        text += page_text + "\n"
            
            return text
        except Exception as e:
            return f"Error parsing PDF: {str(e)}"
        finally:
            if temp_filename and os.path.exists(temp_filename):
                os.remove(temp_filename)
    
    async def extract_transactions_from_pdf(
        self, 
        file: UploadFile
    ) -> Dict[str, Any]:
        """
        Extract transactions from a bank statement PDF.
        
        Returns:
            Dictionary with extracted transactions and metadata
        """
        temp_filename = None
        try:
            # Save file temporarily
            temp_filename = f"temp_{file.filename}"
            content = await file.read()
            with open(temp_filename, "wb") as f:
                f.write(content)
            
            # Extract text and tables
            full_text = ""
            all_tables = []
            
            with pdfplumber.open(temp_filename) as pdf:
                for page in pdf.pages:
                    page_text = page.extract_text()
                    if page_text:
                        full_text += page_text + "\n"
                    
                    # Extract tables (often contain structured transaction data)
                    tables = page.extract_tables()
                    if tables:
                        all_tables.extend(tables)
            
            # Detect bank type
            bank_type = self._detect_bank(full_text)
            
            # Extract transactions
            transactions = []
            
            # Try table extraction first (more reliable)
            if all_tables:
                transactions = self._extract_from_tables(all_tables, bank_type)
            
            # Fallback to text pattern matching
            if not transactions:
                transactions = self._extract_from_text(full_text, bank_type)
            
            # Auto-categorize transactions
            for tx in transactions:
                if tx.category == "Other":
                    tx.category = self._detect_category(tx.description)
            
            return {
                'success': True,
                'bank_detected': bank_type or 'unknown',
                'transaction_count': len(transactions),
                'transactions': [
                    {
                        'date': tx.date,
                        'description': tx.description,
                        'amount': tx.amount,
                        'type': tx.type,
                        'balance': tx.balance,
                        'category': tx.category,
                        'reference': tx.reference,
                    }
                    for tx in transactions
                ]
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': str(e),
                'transactions': []
            }
        finally:
            if temp_filename and os.path.exists(temp_filename):
                os.remove(temp_filename)
    
    def _detect_bank(self, text: str) -> Optional[str]:
        """Detect which bank the statement is from"""
        text_upper = text.upper()
        for bank, patterns in self.BANK_PATTERNS.items():
            for marker in patterns['header_markers']:
                if marker.upper() in text_upper:
                    return bank
        return None
    
    def _extract_from_tables(
        self, 
        tables: List[List[List[str]]], 
        bank_type: Optional[str]
    ) -> List[ExtractedTransaction]:
        """Extract transactions from PDF tables"""
        transactions = []
        
        for table in tables:
            if not table or len(table) < 2:
                continue
            
            # Find header row
            header_row = None
            header_idx = 0
            for idx, row in enumerate(table):
                row_text = ' '.join(str(cell).lower() for cell in row if cell)
                if any(kw in row_text for kw in ['date', 'description', 'amount', 'debit', 'credit', 'balance']):
                    header_row = row
                    header_idx = idx
                    break
            
            if not header_row:
                # Try first row as header
                header_row = table[0]
                header_idx = 0
            
            # Map columns
            col_map = self._map_columns(header_row)
            
            # Process data rows
            for row in table[header_idx + 1:]:
                tx = self._parse_table_row(row, col_map)
                if tx:
                    transactions.append(tx)
        
        return transactions
    
    def _map_columns(self, header_row: List[str]) -> Dict[str, int]:
        """Map column names to indices"""
        col_map = {}
        for idx, cell in enumerate(header_row):
            if not cell:
                continue
            cell_lower = str(cell).lower()
            
            if 'date' in cell_lower and 'value' not in cell_lower:
                col_map['date'] = idx
            elif 'description' in cell_lower or 'particular' in cell_lower or 'narration' in cell_lower:
                col_map['description'] = idx
            elif 'debit' in cell_lower or 'withdrawal' in cell_lower:
                col_map['debit'] = idx
            elif 'credit' in cell_lower or 'deposit' in cell_lower:
                col_map['credit'] = idx
            elif 'amount' in cell_lower:
                col_map['amount'] = idx
            elif 'balance' in cell_lower:
                col_map['balance'] = idx
            elif 'ref' in cell_lower or 'reference' in cell_lower:
                col_map['reference'] = idx
        
        return col_map
    
    def _parse_table_row(
        self, 
        row: List[str], 
        col_map: Dict[str, int]
    ) -> Optional[ExtractedTransaction]:
        """Parse a single table row into a transaction"""
        try:
            # Get date
            date_str = ""
            if 'date' in col_map and col_map['date'] < len(row):
                date_str = str(row[col_map['date']] or "").strip()
            
            if not date_str or not self._is_valid_date(date_str):
                return None
            
            # Get description
            description = ""
            if 'description' in col_map and col_map['description'] < len(row):
                description = str(row[col_map['description']] or "").strip()
            
            # Get amount and type
            amount = 0.0
            tx_type = 'expense'
            
            if 'debit' in col_map and col_map['debit'] < len(row):
                debit_val = self._parse_amount(row[col_map['debit']])
                if debit_val > 0:
                    amount = debit_val
                    tx_type = 'expense'
            
            if 'credit' in col_map and col_map['credit'] < len(row):
                credit_val = self._parse_amount(row[col_map['credit']])
                if credit_val > 0:
                    amount = credit_val
                    tx_type = 'income'
            
            if amount == 0 and 'amount' in col_map and col_map['amount'] < len(row):
                amount = self._parse_amount(row[col_map['amount']])
            
            if amount == 0:
                return None
            
            # Get balance
            balance = None
            if 'balance' in col_map and col_map['balance'] < len(row):
                balance = self._parse_amount(row[col_map['balance']])
            
            # Get reference
            reference = ""
            if 'reference' in col_map and col_map['reference'] < len(row):
                reference = str(row[col_map['reference']] or "").strip()
            
            return ExtractedTransaction(
                date=self._normalize_date(date_str),
                description=description,
                amount=amount,
                type=tx_type,
                balance=balance if balance else None,
                reference=reference
            )
            
        except Exception as e:
            print(f"Error parsing row: {e}")
            return None
    
    def _extract_from_text(
        self, 
        text: str, 
        bank_type: Optional[str]
    ) -> List[ExtractedTransaction]:
        """Extract transactions using text pattern matching"""
        transactions = []
        lines = text.split('\n')
        
        for line in lines:
            # Skip empty lines and headers
            if not line.strip() or len(line.strip()) < 10:
                continue
            
            # Try to find date at the beginning
            date_match = None
            for pattern in self.DATE_PATTERNS:
                match = re.search(pattern, line)
                if match:
                    date_match = match
                    break
            
            if not date_match:
                continue
            
            date_str = date_match.group()
            remaining = line[date_match.end():].strip()
            
            # Find amounts
            amounts = re.findall(self.AMOUNT_PATTERN, remaining)
            amounts = [self._parse_amount(a) for a in amounts if self._parse_amount(a) > 0]
            
            if not amounts:
                continue
            
            # Extract description (text between date and first amount)
            desc_end = remaining.find(str(amounts[0]).replace('.', '\\.'))
            if desc_end == -1:
                # Try to find where amounts start
                amount_matches = list(re.finditer(self.AMOUNT_PATTERN, remaining))
                if amount_matches:
                    desc_end = amount_matches[0].start()
                else:
                    desc_end = len(remaining)
            
            description = remaining[:desc_end].strip() if desc_end > 0 else remaining
            
            # Clean description
            description = re.sub(r'\s+', ' ', description).strip()
            
            # Determine transaction type
            tx_type = 'expense'
            if any(kw in line.lower() for kw in ['cr', 'credit', 'deposit', 'received', 'refund']):
                tx_type = 'income'
            elif any(kw in line.lower() for kw in ['dr', 'debit', 'withdrawal', 'paid', 'payment']):
                tx_type = 'expense'
            
            amount = amounts[0]
            balance = amounts[-1] if len(amounts) > 1 else None
            
            transactions.append(ExtractedTransaction(
                date=self._normalize_date(date_str),
                description=description,
                amount=amount,
                type=tx_type,
                balance=balance
            ))
        
        return transactions
    
    def _parse_amount(self, value: Any) -> float:
        """Parse amount string to float"""
        if not value:
            return 0.0
        try:
            # Remove commas and convert
            clean = str(value).replace(',', '').replace(' ', '').strip()
            # Remove trailing Dr/Cr
            clean = re.sub(r'(Dr|Cr|dr|cr)$', '', clean)
            return float(clean) if clean else 0.0
        except:
            return 0.0
    
    def _is_valid_date(self, date_str: str) -> bool:
        """Check if string looks like a valid date"""
        for pattern in self.DATE_PATTERNS:
            if re.match(pattern, date_str.strip()):
                return True
        return False
    
    def _normalize_date(self, date_str: str) -> str:
        """Normalize date to YYYY-MM-DD format"""
        date_str = date_str.strip()
        
        formats_to_try = [
            '%d/%m/%Y', '%d-%m-%Y', '%d %b %Y', '%d/%m/%y',
            '%Y-%m-%d', '%d-%b-%Y', '%d/%b/%Y'
        ]
        
        for fmt in formats_to_try:
            try:
                dt = datetime.strptime(date_str, fmt)
                return dt.strftime('%Y-%m-%d')
            except:
                continue
        
        return date_str  # Return as-is if parsing fails
    
    def _detect_category(self, description: str) -> str:
        """Detect transaction category from description"""
        desc_lower = description.lower()
        
        for category, keywords in self.CATEGORY_KEYWORDS.items():
            for keyword in keywords:
                if keyword in desc_lower:
                    return category
        
        return "Other"
    
    async def extract_from_bytes(self, content: bytes, filename: str) -> Dict[str, Any]:
        """
        Extract transactions from PDF bytes directly.
        Useful when file is already in memory.
        """
        temp_filename = None
        try:
            temp_filename = f"temp_{filename}"
            with open(temp_filename, "wb") as f:
                f.write(content)
            
            # Reuse the main extraction logic by creating a mock file object
            class MockFile:
                def __init__(self, fname: str, content: bytes):
                    self.filename = fname
                    self._content = content
                    self._read = False
                
                async def read(self):
                    return self._content
            
            mock_file = MockFile(filename, content)
            return await self.extract_transactions_from_pdf(mock_file)
            
        except Exception as e:
            return {
                'success': False,
                'error': str(e),
                'transactions': []
            }
        finally:
            if temp_filename and os.path.exists(temp_filename):
                os.remove(temp_filename)


# Singleton instance
pdf_parser_service = PDFParserService()
