"""
Enhanced SMS Transaction Parser
Supports UPI transactions, contact name resolution, merchant detection, and improved categorization.
"""

import re
from typing import Dict, Any, Optional, List, Tuple
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)


class EnhancedSMSParser:
    """
    Enhanced SMS parser with:
    - UPI transaction support (UPITXN, UPI-, UPI/)
    - UPI ID extraction and cleaning
    - Mobile number extraction from UPI IDs
    - Improved date extraction (relative dates, multiple formats)
    - Enhanced merchant detection
    - Better description extraction
    """

    def __init__(self):
        # Common bank sender IDs
        self.bank_senders = [
            'SBI', 'SBIINB', 'SBIACCOUNT', 'SBIPSG',
            'HDFCBK', 'HDFCBANK',
            'ICICIB', 'ICICIBANK',
            'AXISBK', 'AXISBANK',
            'KOTAKBK', 'KOTAK',
            'PNBSMS', 'BOBCARD', 'BOBSMS', 'CANBNK',
            'UNIONBK', 'IDBIBK', 'YESBANK',
            'AUBANK', 'INDBNK', 'SCBANK',
            'FEDERALBK', 'ILOANBK', 'ABORIG',
            'PAYTM', 'PHONEPE', 'GPAY', 'CRED',
            'IDFCFIRST', 'BAJFINANCE', 'RBLBANK',
            'UPIAXIS', 'UPIBOB', 'UPISBI', 'UPIHDF',
            'JUPITERMF', 'SLICE', 'FIBANK', 'NIYO',
            'JUSPAY', 'RAZRPAY', 'AIRTEL',
        ]

        # Transaction type keywords
        self.debit_keywords = [
            'debited', 'debit', 'paid', 'withdrawn', 'spent',
            'purchase', 'purchased', 'sent', 'transferred to',
            'charged', 'txn at', 'txn of', 'pos txn', 'upi txn',
            'transaction at', 'sent to', 'transfer to',
            'money sent', 'payment of', 'upi-', 'upitxn',
        ]

        self.credit_keywords = [
            'credited', 'received', 'deposited',
            'salary', 'sal cr', 'refund', 'cashback',
            'interest credited', 'reward credited', 'received from',
        ]

        # UPI handle suffixes
        self.upi_suffixes = [
            '@upi', '@ybl', '@paytm', '@oksbi', '@okaxis', '@okicici',
            '@okhdfcbank', '@okbizaxis', '@axisbank', '@ibl', '@icici',
            '@sbi', '@hdfc', '@kotak', '@yesbankltd', '@idfcbank',
            '@federal', '@pnb', '@boi', '@bob', '@canara', '@indianbank',
            '@airtel', '@apl', '@fbl', '@pingpay', '@jupiteraxis',
        ]

        # Merchant keywords for better detection
        self.merchant_keywords = {
            'food': ['swiggy', 'zomato', 'dominos', 'kfc', 'mcdonalds', 'burger king', 'pizza hut'],
            'grocery': ['bigbasket', 'grofers', 'blinkit', 'zepto', 'dmart', 'jiomart'],
            'transport': ['uber', 'ola', 'rapido', 'metro', 'irctc'],
            'shopping': ['amazon', 'flipkart', 'myntra', 'ajio', 'nykaa', 'meesho'],
            'entertainment': ['netflix', 'prime', 'hotstar', 'bookmyshow', 'spotify'],
            'utilities': ['jio', 'airtel', 'vi', 'vodafone', 'electricity', 'gas'],
        }

    def is_transaction_sms(self, sender: str, message: str) -> bool:
        """Check if SMS is a transaction notification"""
        sender_upper = sender.upper()
        is_bank_sender = any(bank in sender_upper for bank in self.bank_senders)

        msg_lower = message.lower()
        has_transaction_keyword = (
            any(kw in msg_lower for kw in self.debit_keywords) or
            any(kw in msg_lower for kw in self.credit_keywords) or
            bool(re.search(r'\bdr\b|\bcr\b', msg_lower)) or
            bool(re.search(r'upitxn|upi[-/]|upi\s+txn|upi\s+ref', msg_lower))
        )

        has_amount = bool(re.search(r'(?:rs\.?|inr|₹)\s*[\d,]+(?:\.\d{1,2})?', msg_lower))

        return is_bank_sender and has_transaction_keyword and has_amount

    def parse_sms(self, sender: str, message: str, timestamp: Optional[datetime] = None) -> Optional[Dict[str, Any]]:
        """
        Parse transaction SMS and extract details with UPI support
        
        Returns:
            Transaction dict with fields:
            - amount, type, description, category, date
            - upi_id, mobile_number (if UPI transaction)
            - merchant_name, contact_name (resolved)
            - confidence_score
        """
        if not self.is_transaction_sms(sender, message):
            return None

        try:
            # Extract balance
            balance = self._extract_balance(message)

            # Extract amount
            amount = self._extract_amount(message, balance)
            if not amount:
                return None

            # Determine transaction type
            tx_type = self._determine_type(message)

            # Extract UPI ID if present
            upi_id = self._extract_upi_id(message)
            
            # Extract mobile number from UPI ID or SMS
            mobile_number = self._extract_mobile_number(message, upi_id)

            # Extract merchant/description with UPI awareness
            description, merchant_name = self._extract_description_and_merchant(message, upi_id)

            # Extract account number
            account = self._extract_account(message)

            # Extract date with relative date support
            tx_date = self._extract_date_enhanced(message, timestamp)

            # Categorize transaction with merchant context
            category, confidence = self._categorize_with_confidence(description, merchant_name, message)

            # Determine bank
            bank = self._identify_bank(sender)

            return {
                'amount': amount,
                'type': tx_type,
                'description': description,
                'merchant_name': merchant_name,
                'category': category,
                'category_confidence': confidence,
                'date': tx_date.isoformat() if isinstance(tx_date, datetime) else tx_date,
                'account_last4': account,
                'balance': balance,
                'bank': bank,
                'upi_id': upi_id,
                'mobile_number': mobile_number,
                'source': 'sms',
                'raw_sms': message,
                'sender': sender,
                # Placeholder for contact name - will be resolved by Flutter contact service
                'contact_name': None,
            }

        except Exception as e:
            logger.error(f"Error parsing SMS: {e}")
            return None

    def _extract_upi_id(self, message: str) -> Optional[str]:
        """Extract UPI ID from SMS"""
        # Pattern: word@suffix (e.g., merchant@paytm, 9876543210@ybl)
        patterns = [
            r'(?:to|from|@)\s*([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+)',
            r'UPI ID[:\s]+([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+)',
            r'VPA[:\s]+([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+)',
        ]

        for pattern in patterns:
            match = re.search(pattern, message, re.IGNORECASE)
            if match:
                upi_id = match.group(1).strip()
                # Clean up any trailing punctuation
                upi_id = re.sub(r'[.,;!?\s]+$', '', upi_id)
                return upi_id

        return None

    def _extract_mobile_number(self, message: str, upi_id: Optional[str] = None) -> Optional[str]:
        """Extract mobile number from UPI ID or SMS"""
        # First try to extract from UPI ID
        if upi_id:
            # Pattern: 10-digit number before @
            match = re.search(r'(\d{10})@', upi_id)
            if match:
                return match.group(1)

        # Try to extract from SMS body
        # Look for 10-digit mobile numbers (not account numbers)
        matches = re.findall(r'\b([6-9]\d{9})\b', message)
        if matches:
            # Return first match (usually the most relevant)
            return matches[0]

        return None

    def _extract_description_and_merchant(self, message: str, upi_id: Optional[str] = None) -> Tuple[str, Optional[str]]:
        """
        Extract description and merchant name with UPI awareness
        
        Returns:
            (description, merchant_name)
        """
        merchant_name = None
        
        # First, try to extract merchant from UPI ID
        if upi_id:
            merchant_name = self._extract_merchant_from_upi(upi_id)

        # Patterns for description extraction
        patterns = [
            r'(?:to|from|at|for)\s+([A-Z][A-Za-z0-9\s&.-]+?)(?:\s+(?:on|dated|ref|upi|txn|a\/c))',
            r'(?:sent to|paid to|transfer to|received from)\s+([A-Za-z0-9\s&.-]+?)(?:\s+(?:on|upi|ref))',
            r'VPA:\s*[^\s]+\s+([A-Z][A-Za-z\s&.-]+?)(?:\s+(?:ref|txn))',
            r'(?:debited|credited).*?(?:to|from)\s+([A-Za-z\s&.-]+?)(?:\s+(?:a\/c|ref|upi))',
        ]

        description = None
        for pattern in patterns:
            match = re.search(pattern, message, re.IGNORECASE)
            if match:
                desc = match.group(1).strip()
                # Clean up
                desc = re.sub(r'\s+', ' ', desc)
                desc = re.sub(r'[.,;]+$', '', desc)
                
                # Check if this looks like a merchant name
                if not merchant_name and any(kw in desc.lower() for cat_kws in self.merchant_keywords.values() for kw in cat_kws):
                    merchant_name = desc
                
                description = desc
                break

        # Fallback: Use UPI ID or merchant name as description
        if not description:
            if merchant_name:
                description = merchant_name
            elif upi_id:
                description = f"UPI to {upi_id.split('@')[0]}"
            else:
                description = "Transaction"

        # Clean up description: remove UPI reference numbers
        description = re.sub(r'\b\d{12,}\b', '', description).strip()

        return description, merchant_name

    def _extract_merchant_from_upi(self, upi_id: str) -> Optional[str]:
        """Extract merchant name from UPI ID"""
        if not upi_id:
            return None

        # Split UPI ID
        parts = upi_id.split('@')
        if len(parts) != 2:
            return None

        username = parts[0]
        
        # Check if username is a known merchant
        for category, merchants in self.merchant_keywords.items():
            for merchant in merchants:
                if merchant.lower() in username.lower():
                    return merchant.capitalize()

        # Check if it's a merchant format (e.g., merchant.12345)
        if '.' in username:
            merchant_part = username.split('.')[0]
            # Capitalize first letter
            return merchant_part.capitalize() if len(merchant_part) > 2 else None

        # If username is not a phone number, it might be a merchant name
        if not re.match(r'^\d+$', username):
            return username.capitalize()

        return None

    def _extract_date_enhanced(self, message: str, timestamp: Optional[datetime] = None) -> datetime:
        """
        Extract date with support for relative dates and multiple formats
        """
        now = timestamp or datetime.now()
        msg_lower = message.lower()

        # Check for relative dates
        if 'today' in msg_lower:
            return now
        elif 'yesterday' in msg_lower:
            return now - timedelta(days=1)

        # Try standard date patterns
        date_patterns = [
            # dd-mm-yyyy, dd/mm/yyyy
            (r'(\d{2})[-/](\d{2})[-/](\d{4})', '%d-%m-%Y'),
            # dd Mon yyyy (e.g., 25 Dec 2024)
            (r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{4})', '%d %b %Y'),
            # dd-Mon-yy (e.g., 25-Dec-24)
            (r'(\d{1,2})[-]([A-Za-z]{3})[-](\d{2})', '%d-%b-%y'),
        ]

        for pattern, date_format in date_patterns:
            match = re.search(pattern, message, re.IGNORECASE)
            if match:
                try:
                    if len(match.groups()) == 3:
                        date_str = f"{match.group(1)}-{match.group(2)}-{match.group(3)}"
                        return datetime.strptime(date_str, date_format.replace('-', '-'))
                    else:
                        date_str = match.group(0)
                        return datetime.strptime(date_str, date_format)
                except ValueError:
                    continue

        # Fallback to timestamp or now
        return now

    def _extract_amount(self, message: str, balance: Optional[float] = None) -> Optional[float]:
        """Extract transaction amount (avoiding balance)"""
        # Patterns for amount extraction
        patterns = [
            r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
            r'([\d,]+(?:\.\d{1,2})?)\s*(?:rs|inr|₹)',
        ]

        amounts = []
        for pattern in patterns:
            matches = re.findall(pattern, message, re.IGNORECASE)
            for match in matches:
                try:
                    amount = float(match.replace(',', ''))
                    # Skip if this looks like balance
                    if balance and abs(amount - balance) < 1:
                        continue
                    amounts.append(amount)
                except ValueError:
                    continue

        if not amounts:
            return None

        # Return the smallest non-zero amount (usually the transaction amount)
        amounts.sort()
        return amounts[0] if amounts else None

    def _extract_balance(self, message: str) -> Optional[float]:
        """Extract account balance"""
        patterns = [
            r'(?:balance|bal|avl bal)[:\s]*.?(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
            r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:bal|balance|avl)',
        ]

        for pattern in patterns:
            match = re.search(pattern, message, re.IGNORECASE)
            if match:
                try:
                    return float(match.group(1).replace(',', ''))
                except ValueError:
                    continue

        return None

    def _determine_type(self, message: str) -> str:
        """Determine if transaction is debit or credit"""
        msg_lower = message.lower()
        
        if any(kw in msg_lower for kw in self.credit_keywords):
            return 'income'
        elif any(kw in msg_lower for kw in self.debit_keywords):
            return 'expense'
        
        # Check for dr/cr patterns
        if re.search(r'\bdr\b', msg_lower):
            return 'expense'
        elif re.search(r'\bcr\b', msg_lower):
            return 'income'

        # Default to expense for UPI transactions
        return 'expense'

    def _extract_account(self, message: str) -> Optional[str]:
        """Extract last 4 digits of account number"""
        patterns = [
            r'a/c\s*(?:no\.?|number)?\s*[xX*]*(\d{4})',
            r'account\s*[xX*]*(\d{4})',
            r'card\s*[xX*]*(\d{4})',
        ]

        for pattern in patterns:
            match = re.search(pattern, message, re.IGNORECASE)
            if match:
                return match.group(1)

        return None

    def _categorize_with_confidence(self, description: str, merchant: Optional[str], message: str) -> Tuple[str, float]:
        """
        Categorize transaction with confidence score
        
        Returns:
            (category, confidence_score)
        """
        desc_lower = (merchant or description).lower()
        
        # Check merchant keywords
        for category, keywords in self.merchant_keywords.items():
            for keyword in keywords:
                if keyword in desc_lower:
                    return category.capitalize(), 0.9

        # Fallback to basic keyword matching
        msg_lower = message.lower()
        
        if any(kw in msg_lower for kw in ['food', 'restaurant', 'zomato', 'swiggy']):
            return 'Food & Dining', 0.7
        elif any(kw in msg_lower for kw in ['grocery', 'vegetables', 'fruits']):
            return 'Groceries', 0.7
        elif any(kw in msg_lower for kw in ['uber', 'ola', 'metro', 'fuel']):
            return 'Transportation', 0.7
        elif any(kw in msg_lower for kw in ['amazon', 'flipkart', 'shopping']):
            return 'Shopping', 0.7
        
        # Default
        return 'Others', 0.3

    def _identify_bank(self, sender: str) -> str:
        """Identify bank from sender ID"""
        sender_upper = sender.upper()
        
        bank_mapping = {
            'SBI': 'State Bank of India',
            'HDFC': 'HDFC Bank',
            'ICICI': 'ICICI Bank',
            'AXIS': 'Axis Bank',
            'KOTAK': 'Kotak Mahindra Bank',
            'PNB': 'Punjab National Bank',
            'BOB': 'Bank of Baroda',
            'CANARA': 'Canara Bank',
            'UNION': 'Union Bank',
            'IDBI': 'IDBI Bank',
            'YES': 'Yes Bank',
            'AU': 'AU Small Finance Bank',
            'INDUSIND': 'IndusInd Bank',
            'SC': 'Standard Chartered',
            'FEDERAL': 'Federal Bank',
            'IDFC': 'IDFC First Bank',
            'RBL': 'RBL Bank',
        }

        for key, value in bank_mapping.items():
            if key in sender_upper:
                return value

        return 'Unknown Bank'


# Singleton instance
enhanced_sms_parser = EnhancedSMSParser()
