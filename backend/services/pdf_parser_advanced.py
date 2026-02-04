"""
Advanced PDF Parser Service with OCR and Receipt Support
Handles bank statements, receipts, invoices with pymupdf2 OCR
"""

import os
import re
import logging
from typing import List, Dict, Optional, Any, Tuple
from datetime import datetime, timedelta
from dataclasses import dataclass, asdict
import asyncio

try:
    import fitz  # pymupdf2
    HAS_OCR = True
except ImportError:
    HAS_OCR = False

try:
    import pdfplumber
except ImportError:
    pdfplumber = None

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Suppress noisy pdfminer logs
logging.getLogger("pdfminer").setLevel(logging.ERROR)


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
    def extract_from_image(image_path: str) -> Dict[str, Any]:
        """Extract receipt data from image using OCR"""
        try:
            if not HAS_OCR:
                logger.warning("PyMuPDF not available for OCR")
                return {}
            
            doc = fitz.open(image_path)
            text = ""
            for page in doc:
                text += page.get_text()
            doc.close()
            
            return ReceiptParser.parse_receipt_text(text)
        except Exception as e:
            logger.error(f"Receipt image extraction error: {e}")
            return {}
    
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
        
        # Extract items (if present)
        item_pattern = r'(?:Item|Product|Description)\s*[:\s]+\s*(.+?)(?:\s+₹|$)'
        items = re.findall(item_pattern, text, re.IGNORECASE)
        receipt_data['items'] = items[:5]  # Limit to 5 items
        
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
    }
    
    @staticmethod
    def detect_bank(text: str) -> str:
        """Detect which bank issued the statement"""
        for bank, patterns in BankStatementParser.BANK_PATTERNS.items():
            for marker in patterns['markers']:
                if marker in text.upper():
                    return bank
        return 'generic'
    
    @staticmethod
    def guess_category(description: str) -> str:
        """Guess category from transaction description"""
        # Helper for whole word matching
        def contains_word(text, words):
            for word in words:
                # \b matches word boundary
                if re.search(r'\b' + re.escape(word) + r'\b', text, re.IGNORECASE):
                    return True
            return False
            
        # Helper for substring matching (safer for long unique names)
        def contains_substring(text, substrings):
            text_upper = text.upper()
            return any(s in text_upper for s in substrings)

        if contains_substring(description, ['SWIGGY', 'ZOMATO', 'RESTAURANT', 'FOOD', 'CAFE', 'BURGER', 'PIZZA', 'DOMINOS', 'KFC', 'MCDONALDS']):
            return "Food"
        elif contains_substring(description, ['UBER', 'OLA', 'RAPIDO', 'METRO', 'BUS', 'FUEL', 'PETROL', 'SHELL', 'BPCL', 'HPCL']):
            return "Transport"
        elif contains_substring(description, ['GROCERY', 'MART', 'SUPERMARKET', 'BLINKIT', 'ZEPTO', 'BIGBASKET', 'DMART']):
            return "Groceries"
        # Use whole word matching for short/common terms
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
        # Remove extra whitespace
        line = ' '.join(line.split())
        
        # Date pattern
        date_match = re.search(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', line)
        if not date_match:
            return None
        
        date_str = date_match.group(1)
        
        # Amount pattern (with optional Dr/Cr indicator)
        amount_matches = re.findall(r'([\d,]+\.?\d+)\s*(Dr|Cr)?', line)
        if not amount_matches:
            return None
        
        # Get last significant amount (usually transaction amount)
        amount_str = amount_matches[-2][0] if len(amount_matches) > 1 else amount_matches[0][0]
        try:
            amount = float(amount_str.replace(',', ''))
        except ValueError:
            return None
        
        # Determine type based on Dr/Cr or amount position
        tx_type = amount_matches[-2][1] if len(amount_matches) > 1 and amount_matches[-2][1] else 'expense'
        tx_type = 'expense' if tx_type.upper() == 'DR' else 'income'
        
        # Description (everything between date and amount)
        desc_match = re.search(rf'{date_str}\s*(.+?)(?:\s*[\d,]+\.?\d+)', line)
        description = desc_match.group(1).strip() if desc_match else 'Transaction'
        
        # Intelligent Categorization
        category = BankStatementParser.guess_category(description)
        
        return ExtractedTransaction(
            date=date_str,
            description=description[:100],  # Limit description
            amount=amount,
            transaction_type=tx_type,
            category=category,
            confidence=0.7,
            source='bank_statement',
        )


class AdvancedPDFParser:
    """Main PDF parser combining text, table, and OCR extraction"""
    
    def __init__(self):
        self.recent_transactions: Dict[str, ExtractedTransaction] = {}
        self.duplicate_threshold_hours = 24
    
    async def extract_transactions(
        self,
        file_path: str,
        document_type: str = 'auto',  # auto, receipt, bank_statement
    ) -> Dict[str, Any]:
        """
        Extract transactions from PDF with multi-method approach
        
        Args:
            file_path: Path to PDF file
            document_type: Type of document
        
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
            
            # Read file
            if not os.path.exists(file_path):
                raise FileNotFoundError(f"File not found: {file_path}")
            
            # Auto-detect document type if needed
            if document_type == 'auto':
                document_type = self._detect_document_type(file_path)
                results['document_type'] = document_type
            
            transactions = []
            
            # Method 1: Try table extraction (most reliable for bank statements)
            if document_type == 'bank_statement' and pdfplumber:
                table_transactions = await asyncio.to_thread(
                    self._extract_from_tables,
                    file_path
                )
                if table_transactions:
                    transactions.extend(table_transactions)
                    results['method'].append('tables')
            
            # Method 2: OCR-based extraction for scanned documents
            if HAS_OCR and not transactions:
                ocr_transactions = await asyncio.to_thread(
                    self._extract_with_ocr,
                    file_path
                )
                if ocr_transactions:
                    transactions.extend(ocr_transactions)
                    results['method'].append('ocr')
            
            # Method 3: Pattern-based text extraction
            print(f"DEBUG: Entering Method 3. Transactions count so far: {len(transactions)}")
            if not transactions:
                # Check for PhonePe first
                full_text = ""
                if pdfplumber:
                    print("DEBUG: pdfplumber is available")
                    with pdfplumber.open(file_path) as pdf:
                        for page in pdf.pages:
                            full_text += (page.extract_text() or "") + "\n"
                else:
                    print("DEBUG: pdfplumber is NOT available")
                
                print(f"DEBUG: Full text length: {len(full_text)}")
                print(f"DEBUG: 'PHONEPE' in text? {'PHONEPE' in full_text.upper()}")
                
                if "PHONEPE" in full_text.upper():
                    results['bank'] = 'phonepe'
                    print("DEBUG: Calling _extract_phonepe...")
                    text_transactions = self._extract_phonepe(full_text)
                    print(f"DEBUG: _extract_phonepe returned {len(text_transactions)} txs")
                    if text_transactions:
                         transactions.extend(text_transactions)
                         results['method'].append('phonepe_parser')
                
                if not transactions:
                    print("DEBUG: Running generic regex fallback")
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
            
            return results
        
        except Exception as e:
            logger.error(f"PDF extraction error: {e}")
            return {
                'transactions': [],
                'status': 'error',
                'error': str(e),
                'count': 0,
            }
    
    def _extract_from_tables(self, file_path: str) -> List[ExtractedTransaction]:
        """Extract transactions from PDF tables"""
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
    
    def _extract_with_ocr(self, file_path: str) -> List[ExtractedTransaction]:
        """Extract transactions using OCR via pymupdf2"""
        if not HAS_OCR:
            return []
        
        transactions = []
        try:
            doc = fitz.open(file_path)
            full_text = ""
            
            for page in doc:
                # Get text with better recognition
                full_text += page.get_text() + "\n"
            
            doc.close()
            
            # Parse extracted text
            lines = full_text.split('\n')
            for line in lines:
                if not line.strip():
                    continue
                
                tx = BankStatementParser.parse_transaction_line(line, 'generic')
                if tx:
                    tx.confidence = 0.75  # OCR slightly lower confidence
                    transactions.append(tx)
        
        except Exception as e:
            logger.error(f"OCR extraction error: {e}")
        
        return transactions
    
    def _extract_from_text(self, file_path: str, doc_type: str) -> List[ExtractedTransaction]:
        """Extract transactions using text pattern matching"""
        transactions = []
        
        try:
            if pdfplumber:
                with pdfplumber.open(file_path) as pdf:
                    for page in pdf.pages:
                        text = page.extract_text()
                        if not text:
                            continue
                        
                        lines = text.split('\n')
                        for line in lines:
                            if not line.strip():
                                continue
                            
                            tx = BankStatementParser.parse_transaction_line(line, 'generic')
                            if tx:
                                tx.confidence = 0.65  # Text pattern lower confidence
                                transactions.append(tx)
        
        except Exception as e:
            logger.error(f"Text extraction error: {e}")
        
        return transactions
    
    def _detect_document_type(self, file_path: str) -> str:
        """Auto-detect if PDF is receipt or bank statement"""
        # Could use file size, ML, or content analysis
        # For now, use simple heuristics
        try:
            if pdfplumber:
                with pdfplumber.open(file_path) as pdf:
                    first_page_text = pdf.pages[0].extract_text().upper()
                    
                    # Check for bank statement markers
                    if any(marker in first_page_text for marker in ['STATEMENT', 'ACCOUNT', 'BANK']):
                        return 'bank_statement'
                    
                    # Check for receipt markers
                    if any(marker in first_page_text for marker in ['RECEIPT', 'INVOICE', 'BILL', 'TOTAL', '₹']):
                        return 'receipt'
        except:
            pass
        
        return 'bank_statement'  # Default
    
    @staticmethod
    def detect_bank(text: str) -> str:
        """Detect which bank issued the statement"""
        if 'PHONEPE' in text.upper():
            return 'phonepe'
        for bank, patterns in BankStatementParser.BANK_PATTERNS.items():
            for marker in patterns['markers']:
                if marker in text.upper():
                    return bank
        return 'generic'
    
    @staticmethod
    def parse_transaction_line(line: str, bank_type: str) -> Optional[ExtractedTransaction]:
        """Parse single transaction from text line"""
        # ... (keep existing implementation) ...
        # (Copied from original for completeness, but I'll trust the user to keep the rest if I use diff correctly)
        # Actually I need to replace the detect_bank and add extract_phonepe in AdvancedPDFParser
        return None # Placeholder, I will use insert/replace in proper targets

    def _extract_phonepe(self, text: str) -> List[ExtractedTransaction]:
        """Extract transactions from PhonePe statement (pdfplumber layout)"""
        transactions = []
        try:
            # Pattern: Nov 19, 2025 Received from Google Pay CREDIT ₹2
            # Regex for the main transaction line
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
                    
                    # Try to find time in the next line if it looks like a time
                    tx_time = None
                    if i + 1 < len(lines):
                        next_line = lines[i+1].strip()
                        time_match = re.search(time_pattern, next_line)
                        if time_match:
                            tx_time = time_match.group(1)
                            # Convert to HH:MM format
                            try:
                                t = datetime.strptime(tx_time.replace(" ", ""), "%I:%M%p")
                                tx_time = t.strftime("%H:%M")
                            except:
                                pass
                    
                    try:
                        amount = float(amount_str)
                    except:
                        continue
                        
                    tx_type = 'income' if type_str.upper() == 'CREDIT' else 'expense'
                    
                    # Enhanced Merchant & Category Extraction
                    merchant = None
                    category = "Miscellaneous" # Default
                    
                    desc_upper = description.upper()
                    
                    if description.startswith("Paid to "):
                        merchant = description[8:]
                    elif description.startswith("Received from "):
                        merchant = description[14:]
                    
                    # Enhanced Categorization
                    category = BankStatementParser.guess_category(description)

                    transactions.append(ExtractedTransaction(
                        date=self._parse_phonepe_date(date_str),
                        description=description,
                        amount=amount,
                        transaction_type=tx_type,
                        merchant=merchant,
                        source='phonepe_statement',
                        confidence=0.9,
                        extra_data={'time': tx_time, 'category': category}
                    ))
                    
        except Exception as e:
            logger.error(f"PhonePe extraction error: {e}")
        
        return transactions

    def _parse_phonepe_date(self, date_str: str) -> str:
        try:
            # Nov 19, 2025 -> 2025-11-19
            dt = datetime.strptime(date_str, '%b %d, %Y')
            return dt.strftime('%Y-%m-%d')
        except:
            return date_str

    def _remove_duplicates(
        self,
        transactions: List[ExtractedTransaction]
    ) -> Tuple[List[ExtractedTransaction], int]:
        """Remove duplicate transactions within 24 hours"""
        unique = []
        duplicates = 0
        
        for tx in sorted(transactions, key=lambda t: t.date):
            # Check if similar transaction exists
            is_duplicate = False
            
            for existing in unique:
                # Same amount and description within 24h = likely duplicate
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
                    except:
                        pass
            
            if not is_duplicate:
                unique.append(tx)
        
        return unique, duplicates


# Singleton instance
pdf_parser_service = AdvancedPDFParser()
