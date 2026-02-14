"""
Advanced PDF Parser Service with Sarvam AI Integration
Handles bank statements, receipts, invoices with:
1. Sarvam Doc Intelligence (if API key available)
2. PyMuPDF (fitz) for fast local text extraction
3. pdfplumber for table extraction (fallback)

OPTIMIZED FOR MOBILE (Chaquopy/Android):
- Lazy imports to reduce startup time
- Progress reporting for long operations
- Minimal memory footprint
"""

import os
import re
import logging
from typing import List, Dict, Optional, Any, Tuple, Generator
from datetime import datetime
from dataclasses import dataclass, asdict
import asyncio

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Suppress noisy pdfminer logs
logging.getLogger("pdfminer").setLevel(logging.ERROR)

# Lazy imports - these are loaded only when needed
_fitz = None
_pdfplumber = None
_sarvam_service = None


def _get_fitz():
    """Lazy load PyMuPDF (fitz)"""
    global _fitz
    if _fitz is None:
        try:
            import fitz
            _fitz = fitz
        except ImportError:
            _fitz = False
    return _fitz if _fitz else None


def _get_pdfplumber():
    """Lazy load pdfplumber"""
    global _pdfplumber
    if _pdfplumber is None:
        try:
            import pdfplumber
            _pdfplumber = pdfplumber
        except ImportError:
            _pdfplumber = False
    return _pdfplumber if _pdfplumber else None


def _get_sarvam():
    """Lazy load Sarvam service"""
    global _sarvam_service
    if _sarvam_service is None:
        try:
            from services.sarvam_service import sarvam_service
            _sarvam_service = sarvam_service
        except ImportError:
            _sarvam_service = False
    return _sarvam_service if _sarvam_service else None


@dataclass
class ExtractedTransaction:
    date: str
    description: str
    amount: float
    transaction_type: str  # 'income' or 'expense'
    merchant: Optional[str] = None
    category: Optional[str] = None
    source: str = 'auto'
    confidence: float = 0.0
    extra_data: Optional[Dict[str, Any]] = None


class ReceiptParser:
    """Specialized parser for receipts (e-commerce, restaurants, etc.)"""
    
    MERCHANT_PATTERNS = {
        'amazon': [r'amazon\.com', r'amazon\.in', r'amzn'],
        'swiggy': [r'swiggy'],
        'zomato': [r'zomato'],
        'flipkart': [r'flipkart'],
        'myntra': [r'myntra'],
        'uber': [r'uber'],
        'ola': [r'ola\s+cabs'],
        'medical': [r'hospital', r'clinic', r'pharmacy', r'apollo', r'medplus', r'dr\.', r'doctor'],
        'education': [r'school', r'college', r'university', r'academy', r'tuition', r'fees'],
        'legal': [r'advocate', r'lawyer', r'legal', r'court', r'notary'],
    }
    
    AMOUNT_PATTERNS = [
        r'(?:Total|Total Amount|Grand Total|Amount|Price|Subtotal)\s*[:\s]+\s*₹?\s*([\d,]+\.?\d*)',
        r'₹\s*([\d,]+\.?\d*)',
        r'\$([\d,]+\.?\d*)',
    ]
    
    DATE_PATTERNS = [
        r'(?:Date|Order Date)\s*[:\s]+\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
        r'(\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4})',
        r'(\d{4}[/-]\d{1,2}[/-]\d{1,2})',
    ]
    
    @staticmethod
    def parse_receipt_text(text: str) -> Dict[str, Any]:
        """Parse receipt text to extract transaction details"""
        receipt_data = {
            'merchant': None,
            'amount': None,
            'date': None,
            'items': [],
            'category': 'Shopping',
            'confidence': 0.8,
        }
        
        # Detect merchant
        for merchant, patterns in ReceiptParser.MERCHANT_PATTERNS.items():
            for pattern in patterns:
                if re.search(pattern, text, re.IGNORECASE):
                    receipt_data['merchant'] = merchant
                    receipt_data['category'] = ReceiptParser._get_merchant_category(merchant)
                    break
            if receipt_data['merchant']:
                break
        
        # Extract amount
        for pattern in ReceiptParser.AMOUNT_PATTERNS:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                amount_str = match.group(1).replace(',', '')
                try:
                    receipt_data['amount'] = float(amount_str)
                    break
                except ValueError:
                    continue
        
        # Extract date
        for pattern in ReceiptParser.DATE_PATTERNS:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                receipt_data['date'] = match.group(1)
                break
        
        return receipt_data
    
    @staticmethod
    def _get_merchant_category(merchant: str) -> str:
        """Get transaction category from merchant"""
        categories = {
            'amazon': 'Shopping',
            'flipkart': 'Shopping',
            'myntra': 'Shopping',
            'swiggy': 'Food & Dining',
            'zomato': 'Food & Dining',
            'uber': 'Transport',
            'ola': 'Transport',
            'medical': 'Medical',
            'education': 'Education',
            'legal': 'Legal',
        }
        return categories.get(merchant.lower(), 'Shopping')


class BankStatementParser:
    """Enhanced parser for bank statements with table extraction"""
    
    BANK_PATTERNS = {
        'hdfc': {
            'markers': ['HDFC BANK', 'Statement of Account'],
            'table_keywords': ['Date', 'Particulars', 'Debit', 'Credit', 'Balance'],
        },
        'sbi': {
            'markers': ['State Bank of India', 'SBI'],
            'table_keywords': ['Date', 'Particulars', 'Debit', 'Credit', 'Balance'],
        },
        'icici': {
            'markers': ['ICICI Bank', 'ICICI'],
            'table_keywords': ['Date', 'Description', 'Debit', 'Credit', 'Balance'],
        },
        'axis': {
            'markers': ['Axis Bank', 'AXIS'],
            'table_keywords': ['Date', 'Description', 'Debit', 'Credit', 'Balance'],
        },
        'phonepe': {
            'markers': ['PHONEPE', 'PhonePe'],
            'table_keywords': ['Date', 'Description', 'Amount'],
        },
    }
    
    @staticmethod
    def detect_bank(text: str) -> str:
        """Detect which bank issued the statement"""
        text_upper = text.upper()
        if 'PHONEPE' in text_upper:
            return 'phonepe'
        for bank, patterns in BankStatementParser.BANK_PATTERNS.items():
            for marker in patterns['markers']:
                if marker.upper() in text_upper:
                    return bank
        return 'generic'
    
    @staticmethod
    def guess_category(description: str) -> str:
        """Guess category from transaction description"""
        def contains_word(text, words):
            for word in words:
                if re.search(r'\b' + re.escape(word) + r'\b', text, re.IGNORECASE):
                    return True
            return False
            
        def contains_substring(text, substrings):
            text_upper = text.upper()
            return any(s in text_upper for s in substrings)

        if contains_substring(description, ['SWIGGY', 'ZOMATO', 'RESTAURANT', 'FOOD', 'CAFE', 'BURGER', 'PIZZA', 'DOMINOS', 'KFC', 'MCDONALDS']):
            return "Food"
        elif contains_substring(description, ['UBER', 'OLA', 'RAPIDO', 'METRO', 'BUS', 'FUEL', 'PETROL', 'SHELL', 'BPCL', 'HPCL']):
            return "Transport"
        elif contains_substring(description, ['GROCERY', 'MART', 'SUPERMARKET', 'BLINKIT', 'ZEPTO', 'BIGBASKET', 'DMART']):
            return "Groceries"
        elif contains_word(description, ['JIO', 'AIRTEL', 'BSNL', 'ACT', 'POWER', 'ELECTRICITY', 'BESCOM', 'WATER', 'GAS', 'BROADBAND']):
            return "Utilities"
        elif contains_substring(description, ['HOSPITAL', 'CLINIC', 'PHARMACY', 'MEDPLUS', 'APOLLO', 'DOCTOR', 'LAB', 'DIAGNOSTIC', 'MEDICINE', 'HEALTH']):
            return "Medical"
        elif contains_substring(description, ['ADVOCATE', 'LAWYER', 'LEGAL', 'COURT', 'NOTARY']):
            return "Legal"
        elif contains_substring(description, ['SCHOOL', 'COLLEGE', 'UNIVERSITY', 'FEES', 'ACADEMY', 'EDUCATION', 'TUITION', 'UDEMY', 'COURSERA']):
            return "Education"
        elif contains_substring(description, ['AMAZON', 'FLIPKART', 'MYNTRA', 'SHOPPING', 'CLOTHES', 'DRESS', 'MALL', 'ZARA', 'H&M']):
            return "Shopping"
        elif contains_substring(description, ['NETFLIX', 'SPOTIFY', 'PRIME', 'HOTSTAR', 'MOVIE', 'CINEMA', 'BOOKMYSHOW']):
            return "Entertainment"
        elif contains_word(description, ['RENT', 'MAINTENANCE']):
            return "Housing"
            
        return "Other"

    @staticmethod
    def parse_transaction_line(line: str, bank_type: str) -> Optional[ExtractedTransaction]:
        """Parse single transaction from text line"""
        line = ' '.join(line.split())
        
        date_match = re.search(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', line)
        if not date_match:
            return None
        
        date_str = date_match.group(1)
        
        amount_matches = re.findall(r'([\d,]+\.?\d+)\s*(Dr|Cr)?', line)
        if not amount_matches:
            return None
        
        amount_str = amount_matches[-2][0] if len(amount_matches) > 1 else amount_matches[0][0]
        try:
            amount = float(amount_str.replace(',', ''))
        except ValueError:
            return None
        
        tx_type = amount_matches[-2][1] if len(amount_matches) > 1 and amount_matches[-2][1] else 'expense'
        tx_type = 'expense' if tx_type.upper() == 'DR' else 'income'
        
        desc_match = re.search(rf'{date_str}\s*(.+?)(?:\s*[\d,]+\.?\d+)', line)
        description = desc_match.group(1).strip() if desc_match else 'Transaction'
        
        category = BankStatementParser.guess_category(description)
        
        return ExtractedTransaction(
            date=date_str,
            description=description[:100],
            amount=amount,
            transaction_type=tx_type,
            category=category,
            confidence=0.7,
            source='bank_statement',
        )


class AdvancedPDFParser:
    """
    Main PDF parser with multi-method extraction strategy:
    1. Sarvam AI (cloud, if API key present)
    2. PyMuPDF/fitz (fast local, recommended for mobile)
    3. pdfplumber (tables, slower but reliable)
    """
    
    def __init__(self):
        self.recent_transactions: Dict[str, ExtractedTransaction] = {}
        self.duplicate_threshold_hours = 24
    
    async def extract_transactions(
        self,
        file_path: str,
        document_type: str = 'auto',
        progress_callback: Optional[callable] = None,
    ) -> Dict[str, Any]:
        """
        Extract transactions from PDF with multi-method approach.
        
        Args:
            file_path: Path to PDF file
            document_type: Type of document ('auto', 'receipt', 'bank_statement')
            progress_callback: Optional callback(current_page, total_pages, message)
        
        Returns:
            Dictionary with transactions and metadata
        """
        try:
            results = {
                'transactions': [],
                'document_type': document_type,
                'bank': 'generic',
                'status': 'success',
                'method': [],
                'count': 0,
                'duplicates_removed': 0,
            }
            
            if not os.path.exists(file_path):
                raise FileNotFoundError(f"File not found: {file_path}")
            
            # Auto-detect document type
            if document_type == 'auto':
                document_type = self._detect_document_type(file_path)
                results['document_type'] = document_type
            
            transactions = []
            
            # === METHOD 1: Sarvam AI (if available) ===
            sarvam = _get_sarvam()
            if sarvam and sarvam.is_configured:
                if progress_callback:
                    progress_callback(0, 1, "Using Sarvam AI for parsing...")
                
                sarvam_result = sarvam.parse_document(file_path)
                if sarvam_result.get('success'):
                    logger.info("Sarvam AI parsing successful")
                    # Parse the structured content from Sarvam
                    sarvam_transactions = self._parse_sarvam_content(
                        sarvam_result.get('content', '')
                    )
                    if sarvam_transactions:
                        transactions.extend(sarvam_transactions)
                        results['method'].append('sarvam_ai')
            
            # === METHOD 2: pdfplumber (tables) - PRIORITIZED for Bank Statements ===
            # pdfplumber excels at extracting tabular data, which is critical for bank statements.
            if not transactions and document_type == 'bank_statement':
                pdfplumber_lib = _get_pdfplumber()
                if pdfplumber_lib:
                    if progress_callback:
                        progress_callback(0, 1, "Extracting tables with pdfplumber (best for bank statements)...")
                    
                    table_transactions = await asyncio.to_thread(
                        self._extract_from_tables,
                        file_path
                    )
                    if table_transactions:
                        transactions.extend(table_transactions)
                        results['method'].append('pdfplumber_tables')
            
            # === METHOD 3: PyMuPDF/fitz (fast local text) - Fallback/Receipts ===
            if not transactions:
                fitz = _get_fitz()
                if fitz:
                    if progress_callback:
                        progress_callback(0, 1, "Using PyMuPDF for text extraction...")
                    
                    fitz_transactions = await asyncio.to_thread(
                        self._extract_with_fitz,
                        file_path,
                        progress_callback
                    )
                    if fitz_transactions:
                        transactions.extend(fitz_transactions)
                        results['method'].append('pymupdf')
            
            # === METHOD 4: Pattern matching fallback ===
            if not transactions:
                if progress_callback:
                    progress_callback(0, 1, "Trying pattern matching...")
                
                text_transactions = await asyncio.to_thread(
                    self._extract_from_text,
                    file_path,
                    document_type
                )
                if text_transactions:
                    transactions.extend(text_transactions)
                    results['method'].append('pattern_matching')
            
            # Remove duplicates
            unique_transactions, dup_count = self._remove_duplicates(transactions)
            results['transactions'] = [asdict(t) for t in unique_transactions]
            results['count'] = len(unique_transactions)
            results['duplicates_removed'] = dup_count
            
            if progress_callback:
                progress_callback(1, 1, f"Found {results['count']} transactions")
            
            return results
        
        except Exception as e:
            logger.error(f"PDF extraction error: {e}")
            return {
                'transactions': [],
                'status': 'error',
                'error': str(e),
                'count': 0,
            }
    
    def _extract_with_fitz(
        self,
        file_path: str,
        progress_callback: Optional[callable] = None
    ) -> List[ExtractedTransaction]:
        """Extract transactions using PyMuPDF (fast)"""
        fitz = _get_fitz()
        if not fitz:
            return []
        
        transactions = []
        try:
            doc = fitz.open(file_path)
            total_pages = len(doc)
            full_text = ""
            
            for page_num, page in enumerate(doc):
                if progress_callback:
                    progress_callback(page_num + 1, total_pages, f"Reading page {page_num + 1}/{total_pages}")
                
                full_text += page.get_text() + "\n"
            
            doc.close()
            
            # Detect bank type
            bank_type = BankStatementParser.detect_bank(full_text)
            
            # PhonePe special handling
            if bank_type == 'phonepe':
                return self._extract_phonepe(full_text)
            
            # Generic parsing
            lines = full_text.split('\n')
            for line in lines:
                if not line.strip():
                    continue
                
                tx = BankStatementParser.parse_transaction_line(line, bank_type)
                if tx:
                    tx.confidence = 0.85  # Higher confidence with fitz
                    transactions.append(tx)
        
        except Exception as e:
            logger.error(f"PyMuPDF extraction error: {e}")
        
        return transactions
    
    def _parse_sarvam_content(self, content: str) -> List[ExtractedTransaction]:
        """Parse structured content from Sarvam AI response"""
        transactions = []
        
        # Sarvam returns markdown/structured text
        # Look for transaction patterns in the content
        lines = content.split('\n')
        for line in lines:
            tx = BankStatementParser.parse_transaction_line(line, 'generic')
            if tx:
                tx.source = 'sarvam_ai'
                tx.confidence = 0.95  # High confidence from AI
                transactions.append(tx)
        
        return transactions
    
    def _extract_from_tables(self, file_path: str) -> List[ExtractedTransaction]:
        """Extract transactions from PDF tables"""
        pdfplumber = _get_pdfplumber()
        if not pdfplumber:
            return []
        
        transactions = []
        try:
            with pdfplumber.open(file_path) as pdf:
                for page_num, page in enumerate(pdf.pages):
                    tables = page.extract_tables()
                    if not tables:
                        continue
                    
                    for table in tables:
                        for row in table:
                            if not row or len(row) < 3:
                                continue
                            
                            row_text = ' '.join(str(cell or '') for cell in row).strip()
                            tx = BankStatementParser.parse_transaction_line(row_text, 'generic')
                            if tx:
                                transactions.append(tx)
        except Exception as e:
            logger.error(f"Table extraction error: {e}")
        
        return transactions
    
    def _extract_from_text(self, file_path: str, doc_type: str) -> List[ExtractedTransaction]:
        """Extract transactions using text pattern matching"""
        transactions = []
        
        # Try fitz first (faster)
        fitz = _get_fitz()
        if fitz:
            try:
                doc = fitz.open(file_path)
                full_text = ""
                for page in doc:
                    full_text += page.get_text() + "\n"
                doc.close()
                
                bank_type = BankStatementParser.detect_bank(full_text)
                if bank_type == 'phonepe':
                    return self._extract_phonepe(full_text)
                
                for line in full_text.split('\n'):
                    if not line.strip():
                        continue
                    tx = BankStatementParser.parse_transaction_line(line, bank_type)
                    if tx:
                        tx.confidence = 0.65
                        transactions.append(tx)
                        
                return transactions
            except Exception as e:
                logger.warning(f"Fitz text extraction failed: {e}")
        
        # Fallback to pdfplumber
        pdfplumber = _get_pdfplumber()
        if pdfplumber:
            try:
                with pdfplumber.open(file_path) as pdf:
                    for page in pdf.pages:
                        text = page.extract_text()
                        if not text:
                            continue
                        
                        for line in text.split('\n'):
                            if not line.strip():
                                continue
                            
                            tx = BankStatementParser.parse_transaction_line(line, 'generic')
                            if tx:
                                tx.confidence = 0.65
                                transactions.append(tx)
            except Exception as e:
                logger.error(f"pdfplumber text extraction error: {e}")
        
        return transactions
    
    def _detect_document_type(self, file_path: str) -> str:
        """Auto-detect if PDF is receipt or bank statement"""
        fitz = _get_fitz()
        pdfplumber = _get_pdfplumber()
        
        try:
            text = ""
            if fitz:
                doc = fitz.open(file_path)
                if len(doc) > 0:
                    text = doc[0].get_text().upper()
                doc.close()
            elif pdfplumber:
                with pdfplumber.open(file_path) as pdf:
                    if pdf.pages:
                        text = (pdf.pages[0].extract_text() or "").upper()
            
            if any(marker in text for marker in ['STATEMENT', 'ACCOUNT', 'BANK']):
                return 'bank_statement'
            
            if any(marker in text for marker in ['RECEIPT', 'INVOICE', 'BILL', 'TOTAL', '₹']):
                return 'receipt'
        except Exception:
            pass
        
        return 'bank_statement'
    
    def _extract_phonepe(self, text: str) -> List[ExtractedTransaction]:
        """Extract transactions from PhonePe statement"""
        transactions = []
        try:
            pattern = r'([A-Z][a-z]{2} \d{1,2}, \d{4})\s+(.+?)\s+(CREDIT|DEBIT)\s+₹?([\d,]+\.?\d*)'
            time_pattern = r'(\d{1,2}:\d{2}\s?(?:am|pm|AM|PM))'
            
            lines = text.split('\n')
            for i, line in enumerate(lines):
                line = line.strip()
                if not line:
                    continue
                
                match = re.search(pattern, line)
                if match:
                    date_str = match.group(1)
                    description = match.group(2).strip()
                    type_str = match.group(3)
                    amount_str = match.group(4).replace(',', '')
                    
                    tx_time = None
                    if i + 1 < len(lines):
                        next_line = lines[i+1].strip()
                        time_match = re.search(time_pattern, next_line)
                        if time_match:
                            tx_time = time_match.group(1)
                            try:
                                t = datetime.strptime(tx_time.replace(" ", ""), "%I:%M%p")
                                tx_time = t.strftime("%H:%M")
                            except Exception:
                                pass
                    
                    try:
                        amount = float(amount_str)
                    except ValueError:
                        continue
                        
                    tx_type = 'income' if type_str.upper() == 'CREDIT' else 'expense'
                    
                    merchant = None
                    if description.startswith("Paid to "):
                        merchant = description[8:]
                    elif description.startswith("Received from "):
                        merchant = description[14:]
                    
                    category = BankStatementParser.guess_category(description)

                    transactions.append(ExtractedTransaction(
                        date=self._parse_phonepe_date(date_str),
                        description=description,
                        amount=amount,
                        transaction_type=tx_type,
                        merchant=merchant,
                        category=category,
                        source='phonepe_statement',
                        confidence=0.9,
                        extra_data={'time': tx_time}
                    ))
                    
        except Exception as e:
            logger.error(f"PhonePe extraction error: {e}")
        
        return transactions

    def _parse_phonepe_date(self, date_str: str) -> str:
        try:
            dt = datetime.strptime(date_str, '%b %d, %Y')
            return dt.strftime('%Y-%m-%d')
        except Exception:
            return date_str

    def _remove_duplicates(
        self,
        transactions: List[ExtractedTransaction]
    ) -> Tuple[List[ExtractedTransaction], int]:
        """Remove duplicate transactions"""
        unique = []
        duplicates = 0
        
        for tx in sorted(transactions, key=lambda t: t.date):
            is_duplicate = False
            
            for existing in unique:
                if (tx.amount == existing.amount and
                    tx.transaction_type == existing.transaction_type and
                    tx.description.lower() == existing.description.lower()):
                    
                    try:
                        tx_date = datetime.strptime(tx.date, '%Y-%m-%d')
                        ex_date = datetime.strptime(existing.date, '%Y-%m-%d')
                        
                        if abs((tx_date - ex_date).days) <= 1:
                            is_duplicate = True
                            duplicates += 1
                            break
                    except Exception:
                        pass
            
            if not is_duplicate:
                unique.append(tx)
        
        return unique, duplicates


# Singleton instance
pdf_parser_service = AdvancedPDFParser()
