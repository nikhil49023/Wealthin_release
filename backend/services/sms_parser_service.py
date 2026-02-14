"""
SMS Transaction Parser Service
Parses bank transaction SMS from various Indian banks to extract transaction details
"""

import re
from typing import Dict, Any, Optional, List
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


class SMSTransactionParser:
    """
    Parses SMS from major Indian banks to extract transaction information.
    Supports: SBI, HDFC, ICICI, Axis, Kotak, PNB, BOB, Canara, and others.
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
            # UPI / wallet senders
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
            'money sent', 'payment of', 'upi-',
        ]

        self.credit_keywords = [
            'credited', 'received', 'deposited',
            'salary', 'sal cr', 'refund', 'cashback',
            'interest credited', 'reward credited',
        ]

    def is_transaction_sms(self, sender: str, message: str) -> bool:
        """Check if SMS is a transaction notification"""
        # Check sender
        sender_upper = sender.upper()
        is_bank_sender = any(bank in sender_upper for bank in self.bank_senders)

        # Check for transaction keywords
        msg_lower = message.lower()
        has_transaction_keyword = (
            any(kw in msg_lower for kw in self.debit_keywords) or
            any(kw in msg_lower for kw in self.credit_keywords) or
            # Also check word-boundary "dr"/"cr" patterns
            bool(re.search(r'\bdr\b', msg_lower)) or
            bool(re.search(r'\bcr\b', msg_lower)) or
            # UPI transaction patterns
            bool(re.search(r'upitxn|upi[-/]|upi\s+txn|upi\s+ref', msg_lower))
        )

        # Check for amount pattern
        has_amount = bool(re.search(r'(?:rs\.?|inr|₹)\s*[\d,]+(?:\.\d{1,2})?', msg_lower))

        return is_bank_sender and has_transaction_keyword and has_amount

    def parse_sms(self, sender: str, message: str, timestamp: Optional[datetime] = None) -> Optional[Dict[str, Any]]:
        """
        Parse transaction SMS and extract details

        Args:
            sender: SMS sender ID
            message: SMS text content
            timestamp: SMS timestamp

        Returns:
            Transaction dict or None if parsing fails
        """
        if not self.is_transaction_sms(sender, message):
            return None

        try:
            # Extract balance FIRST so we can exclude it from amount extraction
            balance = self._extract_balance(message)

            # Extract transaction amount (context-aware, avoids balance)
            amount = self._extract_amount(message, balance)
            if not amount:
                return None

            # Determine transaction type
            tx_type = self._determine_type(message)

            # Extract merchant/description
            description = self._extract_description(message)

            # Extract account number (last 4 digits)
            account = self._extract_account(message)

            # Extract date/time if present in SMS
            tx_date = self._extract_date(message) or timestamp or datetime.now()

            # Categorize transaction
            category = self._categorize_transaction(description, message)

            # Determine bank from sender
            bank = self._identify_bank(sender)

            return {
                'amount': amount,
                'type': tx_type,
                'description': description,
                'category': category,
                'date': tx_date.isoformat() if isinstance(tx_date, datetime) else tx_date,
                'account_last4': account,
                'balance': balance,
                'bank': bank,
                'source': 'sms',
                'raw_sms': message,
                'sender': sender
            }

        except Exception as e:
            logger.error(f"Error parsing SMS: {e}")
            return None

    def parse_sms_with_confidence(self, sender: str, message: str, timestamp: Optional[datetime] = None) -> tuple[Optional[Dict[str, Any]], float]:
        """
        Parse transaction SMS and return result with confidence score

        Args:
            sender: SMS sender ID
            message: SMS text content
            timestamp: SMS timestamp

        Returns:
            Tuple of (transaction_dict, confidence_score)
            confidence_score ranges from 0.0 to 1.0
        """
        parsed = self.parse_sms(sender, message, timestamp)

        if not parsed:
            return (None, 0.0)

        # Calculate confidence based on extracted fields
        confidence = 0.0

        # Amount: +30% (critical field)
        if parsed.get('amount') and parsed['amount'] > 0:
            confidence += 0.30

        # Type: +20% (critical field)
        if parsed.get('type') in ['debit', 'credit']:
            confidence += 0.20

        # Merchant/Description: +20% (important field)
        description = parsed.get('description', '')
        if description and description != 'Transaction' and len(description) > 3:
            confidence += 0.20

        # Date: +15% (important field)
        if parsed.get('date'):
            # Check if date was extracted from SMS (not just timestamp fallback)
            date_extracted = self._extract_date(message) is not None
            if date_extracted:
                confidence += 0.15
            else:
                confidence += 0.05  # Partial credit for timestamp fallback

        # Balance: +10% (nice to have)
        if parsed.get('balance') and parsed['balance'] > 0:
            confidence += 0.10

        # Category: +5% (nice to have)
        if parsed.get('category') and parsed['category'] != 'Others':
            confidence += 0.05

        return (parsed, confidence)

    def _extract_amount(self, text: str, balance: Optional[float] = None) -> Optional[float]:
        """Extract transaction amount, avoiding confusion with balance"""
        msg_lower = text.lower()

        # Strategy 1: Look for amount right next to debit/credit keywords
        # e.g. "debited by Rs.500", "credited with Rs.1000", "paid Rs.250"
        contextual_patterns = [
            r'(?:debited|debit|paid|withdrawn|spent|purchased|sent|charged|transferred)\s*(?:by\s*|for\s*|of\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([\d,]+(?:\.\d{1,2})?)',
            r'(?:credited|received|deposited|refund)\s*(?:by\s*|with\s*|of\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([\d,]+(?:\.\d{1,2})?)',
            r'(?:rs\.?\s*|inr\s*|₹\s*)([\d,]+(?:\.\d{1,2})?)\s*(?:has been\s*)?(?:debited|credited|paid|withdrawn|received|deposited|transferred|sent)',
            # UPI specific: "UPI-Rs.500" / "UPI txn Rs.250"
            r'upi[-/\s](?:txn\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([\d,]+(?:\.\d{1,2})?)',
            # "sent Rs.500 to" / "transfer Rs.300 to"
            r'(?:sent|transfer)\s*(?:rs\.?\s*|inr\s*|₹\s*)([\d,]+(?:\.\d{1,2})?)\s*(?:to|from)',
        ]

        for pattern in contextual_patterns:
            match = re.search(pattern, msg_lower)
            if match:
                amount_str = match.group(1).replace(',', '')
                try:
                    amount = float(amount_str)
                    if 0.01 <= amount <= 10_000_000:
                        return amount
                except (ValueError, OverflowError):
                    pass

        # Strategy 2: Generic Rs/INR patterns, but skip amounts that match the balance
        generic_patterns = [
            r'(?:rs\.?\s*|inr\s*|₹\s*)([\d,]+(?:\.\d{1,2})?)',
            r'([\d,]+(?:\.\d{1,2})?)\s*(?:inr|rs\.?)',
            r'(?:amount|amt)\s*(?:of\s*)?(?:rs\.?\s*|inr\s*|₹\s*)?([\d,]+(?:\.\d{1,2})?)',
        ]

        # Collect all amount matches, excluding those in balance context
        balance_region = self._find_balance_region(text)

        for pattern in generic_patterns:
            for match in re.finditer(pattern, text, re.IGNORECASE):
                # Skip if this match is inside the balance region
                if balance_region and balance_region[0] <= match.start() <= balance_region[1]:
                    continue

                amount_str = match.group(1).replace(',', '')
                try:
                    amount = float(amount_str)
                    # Skip if amount equals the balance (likely picked up balance)
                    if balance is not None and abs(amount - balance) < 0.01:
                        continue
                    if 0.01 <= amount <= 10_000_000:
                        return amount
                except (ValueError, OverflowError):
                    pass

        return None

    def _find_balance_region(self, text: str) -> Optional[tuple]:
        """Find the character range in text where balance info appears"""
        balance_markers = [
            r'(?:avl\.?\s*bal|avail(?:able)?\s*bal(?:ance)?|a/c\s*bal|net\s*(?:avl\.?\s*)?bal|closing\s*bal|bal(?:ance)?)\s*[:.]?\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)?[\d,]+(?:\.\d{1,2})?',
            r'(?:rs\.?\s*|inr\s*|₹\s*)[\d,]+(?:\.\d{1,2})?\s*(?:available|avl|avail)',
        ]
        for pattern in balance_markers:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return (match.start(), match.end())
        return None

    def _determine_type(self, text: str) -> str:
        """Determine if transaction is debit or credit"""
        text_lower = text.lower()

        # Exclusion: "credit card" is a DEBIT instrument, not a credit transaction
        has_credit_card = 'credit card' in text_lower or 'creditcard' in text_lower

        # Check credit keywords first (more specific phrases)
        # But skip if the only "credit" match is from "credit card"
        if not has_credit_card:
            if any(kw in text_lower for kw in self.credit_keywords):
                return 'credit'
            # Word-boundary check for standalone "cr" (e.g. "Cr Rs.500")
            if re.search(r'\bcr\b', text_lower):
                return 'credit'
        else:
            # Even with "credit card", check for explicit credited/received etc.
            specific_credit = ['credited', 'received', 'deposited', 'refund', 'cashback', 'salary']
            if any(kw in text_lower for kw in specific_credit):
                return 'credit'

        # Check debit keywords
        if any(kw in text_lower for kw in self.debit_keywords):
            return 'debit'
        # Word-boundary check for standalone "dr" (e.g. "Dr Rs.1000")
        if re.search(r'\bdr\b', text_lower):
            return 'debit'

        return 'debit'  # Default to debit if unclear

    def _extract_description(self, text: str) -> str:
        """Extract merchant/transaction description"""
        # Words that should not be treated as merchant names
        skip_words = {'your', 'my', 'the', 'this', 'his', 'her', 'their', 'our', 'a/c', 'account',
                       'bank', 'dear', 'customer', 'user', 'sir', 'madam'}

        patterns = [
            r'(?:paid to|sent to|transferred to)\s+([A-Za-z0-9][A-Za-z0-9\s&\-\.]+?)(?:\s+on|\s+ref|\s+via|\.|$)',
            r'(?:received from|credited from)\s+([A-Za-z0-9][A-Za-z0-9\s&\-\.]+?)(?:\s+on|\s+ref|\.|$)',
            r'(?:at|to|from)\s+([A-Za-z0-9][A-Za-z0-9\s&\-\.]+?)(?:\s+on|\s+ref|\s+a/c|\.|$)',
            # UPI patterns: "UPI/CRED/name" or "UPI-name@upi"
            r'(?:UPI[/\-])([\w\s@\-\.]+?)(?:/|\s+ref|\s+on|\.|$)',
            r'(?:VPA[:\s-])([\w@\.]+)',
            r'(?:UPITXN[:\s])([\w@\.]+)',
            r'(?:for\s+)([\w\s&\-\.]+?)(?:\s+on|\s+at|\s+ref|\.|$)',
        ]

        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                desc = match.group(1).strip()
                desc = re.sub(r'\s+', ' ', desc)
                # Clean up UPI IDs: remove @upi, @ybl, @paytm, etc.
                desc = re.sub(r'@[a-zA-Z]+$', '', desc).strip()
                # Remove trailing UPI reference numbers
                desc = re.sub(r'\d{10,}$', '', desc).strip()
                # Skip if description is just a common word (not a merchant name)
                if desc.lower() in skip_words:
                    continue
                if len(desc) > 2:
                    return desc

        # Fallback: Extract first capitalized phrase
        words = text.split()
        cap_phrase = []
        for word in words:
            if word and word[0].isupper() and len(word) > 2:
                cap_phrase.append(word)
                if len(cap_phrase) >= 3:
                    break

        if cap_phrase:
            return ' '.join(cap_phrase)

        return 'Transaction'

    def _extract_account(self, text: str) -> Optional[str]:
        """Extract last 4 digits of account"""
        patterns = [
            r'(?:a/c|acct?|account|card)\s*(?:no\.?\s*)?(?:\*{2,}|[xX]{2,})?(\d{4})',
            r'(?:\*{2,}|[xX]{2,})(\d{4})',
        ]

        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return match.group(1)
        return None

    def _extract_balance(self, text: str) -> Optional[float]:
        """Extract available balance if mentioned in SMS"""
        # Comprehensive balance patterns for Indian banks
        # Order matters: more specific patterns first
        patterns = [
            # "Avl Bal Rs.10,000.00" / "Avl. Bal: Rs 10000" / "Avail Bal INR 5000"
            r'(?:avl\.?\s*bal|avail(?:able)?\s*bal(?:ance)?)\s*[:.]?\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([\d,]+(?:\.\d{1,2})?)',
            # "A/c bal: Rs.10000" / "Account balance Rs.5000"
            r'(?:a/c\s*bal(?:ance)?|account\s*bal(?:ance)?)\s*[:.]?\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([\d,]+(?:\.\d{1,2})?)',
            # "Net Avl Bal Rs.10000" / "Net Bal: INR 5000"
            r'(?:net\s*(?:avl\.?\s*)?bal(?:ance)?)\s*[:.]?\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([\d,]+(?:\.\d{1,2})?)',
            # "Closing Bal Rs.10000"
            r'(?:closing\s*bal(?:ance)?)\s*[:.]?\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([\d,]+(?:\.\d{1,2})?)',
            # "Balance Rs.10000" / "Bal Rs 5000" / "Bal: INR 10000" / "Bal:Rs.5000"
            r'(?:bal(?:ance)?)\s*[:.]?\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([\d,]+(?:\.\d{1,2})?)',
            # Reversed: "Rs.10000 available" / "INR 5000 avl"
            r'(?:rs\.?\s*|inr\s*|₹\s*)([\d,]+(?:\.\d{1,2})?)\s*(?:available|avl|avail)',
        ]

        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                try:
                    return float(match.group(1).replace(',', ''))
                except (ValueError, OverflowError):
                    pass
        return None

    def _extract_date(self, text: str) -> Optional[datetime]:
        """Extract transaction date if present, including relative terms"""
        current_year = datetime.now().year
        today = datetime.now()

        # Handle relative date terms first
        text_lower = text.lower()
        if 'today' in text_lower:
            return today.replace(hour=0, minute=0, second=0, microsecond=0)
        if 'yesterday' in text_lower:
            from datetime import timedelta
            return (today - timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)

        patterns = [
            (r'(\d{1,2})-(\w{3})-(\d{2,4})', '%d-%b-%y'),  # 12-Jan-26
            (r'(\d{1,2})/(\d{1,2})/(\d{2,4})', None),     # 12/01/26 (custom)
            (r'(\d{2})-(\d{2})-(\d{2,4})', None),         # 12-01-2026 (dd-mm-yyyy)
            (r'(\d{1,2})\s+(\w{3})', None),               # 12 Jan (custom)
            (r'on\s+(\d{1,2})-(\d{1,2})-(\d{2,4})', None), # on 12-01-2026
            (r'on\s+(\d{1,2})\s+(\w{3})\s*(\d{2,4})?', None), # on 12 Jan 2026
        ]

        for pattern_tuple in patterns:
            pattern = pattern_tuple[0]
            fmt = pattern_tuple[1] if len(pattern_tuple) > 1 else None
            match = re.search(pattern, text, re.IGNORECASE)

            if match:
                try:
                    if fmt:
                        date_str = match.group(0)
                        # Handle 4-digit year in dd-Mon-yyyy format
                        if re.match(r'\d{1,2}-\w{3}-\d{4}', date_str):
                            parsed = datetime.strptime(date_str, '%d-%b-%Y')
                        else:
                            parsed = datetime.strptime(date_str, fmt)
                        if parsed.year < 100:
                            if parsed.year <= 50:
                                parsed = parsed.replace(year=parsed.year + 2000)
                            else:
                                parsed = parsed.replace(year=parsed.year + 1900)
                        return parsed
                    else:
                        groups = match.groups()
                        if len(groups) >= 2 and groups[1].isalpha():
                            day = int(groups[0])
                            month_abbr = groups[1][:3].title()
                            year = current_year
                            if len(groups) > 2 and groups[2]:
                                year = int(groups[2])
                                if year < 100:
                                    year = year + 2000 if year <= 50 else year + 1900
                            date_str = f"{day} {month_abbr} {year}"
                            parsed = datetime.strptime(date_str, '%d %b %Y')
                            return parsed
                        elif len(groups) >= 2:
                            day = int(groups[0])
                            month = int(groups[1])
                            year = int(groups[2]) if len(groups) > 2 and groups[2] else current_year
                            if year < 100:
                                year = year + 2000 if year <= 50 else year + 1900
                            return datetime(year, month, day)
                except Exception as e:
                    logger.debug(f"Date parsing failed for pattern {pattern}: {e}")
                    continue

        return None

    def _categorize_transaction(self, description: str, full_text: str) -> str:
        """Auto-categorize transaction based on merchant"""
        desc_lower = description.lower()
        text_lower = full_text.lower()

        categories = {
            'Food & Dining': ['zomato', 'swiggy', 'dominos', 'mcdonald', 'kfc', 'restaurant', 'cafe', 'pizza', 'burger', 'starbucks', 'subway'],
            'Shopping': ['amazon', 'flipkart', 'myntra', 'ajio', 'nykaa', 'shop', 'meesho', 'jiomart'],
            'Transport': ['uber', 'ola', 'rapido', 'petrol', 'fuel', 'metro', 'parking', 'fastag', 'toll'],
            'Utilities': ['electricity', 'water', 'gas', 'broadband', 'mobile', 'recharge', 'bill', 'airtel', 'jio', 'vodafone', 'bsnl'],
            'Entertainment': ['netflix', 'prime', 'spotify', 'hotstar', 'movie', 'ticket', 'zee5', 'sonyliv'],
            'Groceries': ['bigbasket', 'dmart', 'grofers', 'blinkit', 'grocery', 'zepto', 'instamart'],
            'Healthcare': ['pharmacy', 'hospital', 'clinic', 'doctor', 'medicine', 'apollo', 'medplus', '1mg'],
            'Education': ['school', 'college', 'course', 'tuition', 'fees', 'udemy', 'byjus'],
            'Rent & Housing': ['rent', 'maintenance', 'society', 'housing'],
            'Insurance': ['insurance', 'policy', 'premium', 'lic'],
            'Investments': ['mutual fund', 'sip', 'stock', 'zerodha', 'groww', 'upstox', 'fd', 'ppf', 'nps'],
            'EMI': ['emi', 'loan'],
            'Salary': ['salary', 'sal cr'],
            'Transfer': ['upi', 'imps', 'neft', 'rtgs', 'transfer']
        }

        for category, keywords in categories.items():
            if any(kw in desc_lower or kw in text_lower for kw in keywords):
                return category

        # ATM check
        if 'atm' in text_lower or 'cash withdrawal' in text_lower:
            return 'Cash Withdrawal'

        return 'Others'

    def _identify_bank(self, sender: str) -> str:
        """Identify bank from sender ID"""
        sender_upper = sender.upper()

        bank_map = {
            'SBI': 'State Bank of India',
            'HDFC': 'HDFC Bank',
            'ICICI': 'ICICI Bank',
            'AXIS': 'Axis Bank',
            'KOTAK': 'Kotak Mahindra Bank',
            'PNB': 'Punjab National Bank',
            'BOB': 'Bank of Baroda',
            'CANBNK': 'Canara Bank',
            'UNION': 'Union Bank',
            'IDBI': 'IDBI Bank',
            'YES': 'Yes Bank',
            'AUBANK': 'AU Small Finance Bank',
            'INDBNK': 'IndusInd Bank',
            'SCBANK': 'Standard Chartered',
            'FEDERAL': 'Federal Bank',
            'IDFC': 'IDFC First Bank',
            'RBL': 'RBL Bank',
            'PAYTM': 'Paytm Payments Bank',
            'PHONEPE': 'PhonePe',
            'GPAY': 'Google Pay',
        }

        for key, name in bank_map.items():
            if key in sender_upper:
                return name

        return 'Unknown Bank'

    def parse_batch(self, sms_list: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Parse multiple SMS messages

        Args:
            sms_list: List of dicts with 'sender', 'message', 'timestamp'

        Returns:
            List of parsed transactions
        """
        transactions = []

        for sms in sms_list:
            result = self.parse_sms(
                sender=sms.get('sender', ''),
                message=sms.get('message', ''),
                timestamp=sms.get('timestamp')
            )

            if result:
                transactions.append(result)

        logger.info(f"Parsed {len(transactions)} transactions from {len(sms_list)} SMS")
        return transactions


# Singleton instance
sms_parser = SMSTransactionParser()
