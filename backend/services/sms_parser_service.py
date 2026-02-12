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
            'SBI', 'SBIINB', 'SBIACCOUNT',
            'HDFCBK', 'HDFCBANK',
            'ICICIB', 'ICICIBANK',
            'AXISBK', 'AXISBANK',
            'KOTAKBK', 'KOTAK',
            'PNBSMS', 'BOBCARD', 'CANBNK',
            'UNIONBK', 'IDBIBK', 'YESBANK',
            'AUBANK', 'INDBNK', 'SCBANK'
        ]
        
        # Transaction type keywords
        self.debit_keywords = [
            'debited', 'debit', 'paid', 'withdrawn', 'spent',
            'purchase', 'dr', 'sent', 'transferred to'
        ]
        
        self.credit_keywords = [
            'credited', 'credit', 'received', 'deposited',
            'cr', 'salary', 'refund', 'cashback'
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
            any(kw in msg_lower for kw in self.credit_keywords)
        )
        
        # Check for amount pattern
        has_amount = bool(re.search(r'(?:rs\.?|inr|₹)\s*[\d,]+(?:\.\d{2})?', msg_lower))
        
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
            # Extract amount
            amount = self._extract_amount(message)
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
            
            # Extract balance if available
            balance = self._extract_balance(message)
            
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

    def _extract_amount(self, text: str) -> Optional[float]:
        """Extract transaction amount"""
        # Common patterns:
        # Rs.1,234.56 | INR 1234.56 | ₹1,234 | Rs 1234 | Rs.100.5
        patterns = [
            r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',  # Match 1-2 decimals
            r'([\d,]+(?:\.\d{1,2})?)\s*(?:inr|rs\.?)',
            r'amount\s*(?:of\s*)?(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                amount_str = match.group(1).replace(',', '')
                try:
                    return float(amount_str)
                except:
                    pass
        return None
    
    def _determine_type(self, text: str) -> str:
        """Determine if transaction is debit or credit"""
        text_lower = text.lower()
        
        # Check credit first (more specific)
        if any(kw in text_lower for kw in self.credit_keywords):
            return 'credit'
        
        # Check debit
        if any(kw in text_lower for kw in self.debit_keywords):
            return 'debit'
        
        return 'debit'  # Default to debit if unclear
    
    def _extract_description(self, text: str) -> str:
        """Extract merchant/transaction description"""
        # Common patterns (case-insensitive for merchant names)
        patterns = [
            r'(?:at|to|from)\s+([A-Za-z0-9][A-Za-z0-9\s&\-\.]+?)(?:\s+on|\.|$)',
            r'(?:paid to|sent to)\s+([A-Za-z0-9][A-Za-z0-9\s&\-\.]+?)(?:\s+on|\.|$)',
            r'(?:received from)\s+([A-Za-z0-9][A-Za-z0-9\s&\-\.]+?)(?:\s+on|\.|$)',
            r'(?:UPI/)([\w\s@\-\.]+?)(?:/|$)',
            r'(?:VPA-)([\w@\.]+)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text)
            if match:
                desc = match.group(1).strip()
                # Clean up
                desc = re.sub(r'\s+', ' ', desc)
                if len(desc) > 3:  # Avoid single letters
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
        # Pattern: A/C **1234 or Account XX1234
        patterns = [
            r'(?:a/c|account|card)\s*(?:\*{2,}|xx)?(\d{4})',
            r'(\d{4})\s*(?:on|at)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return match.group(1)
        return None
    
    def _extract_balance(self, text: str) -> Optional[float]:
        """Extract available balance if mentioned"""
        patterns = [
            r'(?:balance|bal|avl\.?\s*bal)\.?\s*(?:is\s*)?(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{2})?)',
            r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s*(?:available|avl)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                try:
                    return float(match.group(1).replace(',', ''))
                except:
                    pass
        return None
    
    def _extract_date(self, text: str) -> Optional[datetime]:
        """Extract transaction date if present"""
        current_year = datetime.now().year

        # Pattern: 12-Jan-26 | 12/01/26 | 12 Jan
        patterns = [
            (r'(\d{1,2})-(\w{3})-(\d{2})', '%d-%b-%y'),  # 12-Jan-26
            (r'(\d{1,2})/(\d{1,2})/(\d{2,4})', None),     # 12/01/26 (custom)
            (r'(\d{1,2})\s+(\w{3})', None),               # 12 Jan (custom)
            (r'on\s+(\d{1,2})-(\d{1,2})-(\d{2,4})', None), # on 12-01-2026
        ]

        for pattern_tuple in patterns:
            pattern = pattern_tuple[0]
            fmt = pattern_tuple[1] if len(pattern_tuple) > 1 else None
            match = re.search(pattern, text, re.IGNORECASE)

            if match:
                try:
                    if fmt:
                        # Use strptime for standard formats
                        date_str = match.group(0)
                        parsed = datetime.strptime(date_str, fmt)
                        # Handle 2-digit years: 00-50 -> 2000s, 51-99 -> 1900s
                        if parsed.year < 100:
                            if parsed.year <= 50:
                                parsed = parsed.replace(year=parsed.year + 2000)
                            else:
                                parsed = parsed.replace(year=parsed.year + 1900)
                        return parsed
                    else:
                        # Custom parsing for flexible formats
                        groups = match.groups()
                        if len(groups) == 2 and groups[1].isalpha():
                            # Format: "12 Jan" (no year)
                            day = int(groups[0])
                            month_abbr = groups[1][:3].title()
                            date_str = f"{day} {month_abbr} {current_year}"
                            parsed = datetime.strptime(date_str, '%d %b %Y')
                            return parsed
                        elif len(groups) >= 2:
                            # Format: "12/01/26" or "12-01-2026"
                            day = int(groups[0])
                            month = int(groups[1])
                            year = int(groups[2]) if len(groups) > 2 else current_year
                            # Handle 2-digit years
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
        
        # Category mapping
        categories = {
            'Food & Dining': ['zomato', 'swiggy', 'dominos', 'mcdonald', 'kfc', 'restaurant', 'cafe'],
            'Shopping': ['amazon', 'flipkart', 'myntra', 'ajio', 'nykaa', 'shop'],
            'Transport': ['uber', 'ola', 'petrol', 'fuel', 'metro', 'parking'],
            'Utilities': ['electricity', 'water', 'gas', 'broadband', 'mobile', 'recharge', 'bill'],
            'Entertainment': ['netflix', 'prime', 'spotify', 'hotstar', 'movie', 'ticket'],
            'Groceries': ['bigbasket', 'dmart', 'grofers', 'blinkit', 'grocery'],
            'Healthcare': ['pharmacy', 'hospital', 'clinic', 'doctor', 'medicine', 'apollo'],
            'Education': ['school', 'college', 'course', 'tuition', 'fees'],
            'EMI': ['emi', 'loan', 'credit card'],
            'Salary': ['salary', 'sal cr'],
            'Transfer': ['upi', 'imps', 'neft', 'transfer']
        }
        
        for category, keywords in categories.items():
            if any(kw in desc_lower or kw in text_lower for kw in keywords):
                return category
        
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
            'SCBANK': 'Standard Chartered'
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
