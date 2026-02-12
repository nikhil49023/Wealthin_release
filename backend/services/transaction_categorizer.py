"""
Transaction Categorizer Service
Uses deterministic rules with Sarvam fallback to categorize financial transactions
based on description and common Indian spending patterns.
"""

import os
import json
from typing import Optional, List, Dict
from dotenv import load_dotenv

load_dotenv()

# Category definitions with Indian-specific keywords
CATEGORY_KEYWORDS = {
    "Food & Dining": [
        "swiggy", "zomato", "restaurant", "cafe", "food", "dining", "lunch", "dinner",
        "breakfast", "biryani", "pizza", "burger", "chai", "coffee", "tea", "snacks",
        "mess", "canteen", "dhaba", "hotel", "eatsure", "dominos", "kfc", "mcdonalds",
        "subway", "haldiram", "barbeque", "freshmen", "behrouz", "starbucks", "burger king",
        "pizza hut", "bistro", "diner", "coffee day", "ccd", "tim hortons", "taco bell",
        "oven story", "faasos", "box8", "wow momo"
    ],
    "Groceries": [
        "bigbasket", "grofers", "blinkit", "zepto", "dmart", "reliance fresh",
        "more megastore", "grocery", "vegetables", "fruits", "kirana", "supermarket",
        "provision", "ration", "jiomart", "amazon fresh", "nature's basket", "spencer's",
        "daily needs", "milk", "dairy", "bakery", "meat", "fish"
    ],
    "Transportation": [
        "uber", "ola", "rapido", "metro", "bus", "railway", "irctc", "petrol", "diesel",
        "fuel", "parking", "toll", "fastag", "auto", "cab", "taxi", "flight", "air",
        "indigo", "spicejet", "vistara", "redbus", "makemytrip", "cleartrip", "goibibo",
        "yatra", "ixigo", "blue smart", "indriver", "rly", "rail", "shell", "hpcl", "bpcl", "ioc"
    ],
    "Shopping": [
        "amazon", "flipkart", "myntra", "ajio", "nykaa", "meesho", "snapdeal",
        "shopclues", "paytm mall", "tata cliq", "lifestyle", "westside", "pantaloons",
        "max", "h&m", "zara", "uniqlo", "decathlon", "croma", "reliance digital",
        "trends", "zudio", "nike", "adidas", "puma", "skechers", "levi's", "marks & spencer"
    ],
    "Entertainment": [
        "netflix", "prime video", "hotstar", "disney", "youtube", "spotify", "gaana",
        "jio saavn", "pvr", "inox", "bookmyshow", "cinema", "movie", "games", "pubg",
        "dream11", "fantasy", "subscription", "ott", "cinepolis", "apple music", "audible",
        "sony liv", "zee5", "gaming", "steam", "playstation", "xbox"
    ],
    "Utilities": [
        "electricity", "water", "gas", "broadband", "internet", "wifi", "jio", "airtel",
        "vi", "vodafone", "bsnl", "act fibernet", "tata sky", "dish tv", "dth",
        "mobile recharge", "postpaid", "prepaid", "phone bill", "bescom", "bwssb",
        "mahavitaran", "adhani", "torrent power", "billdesk", "razorpay"
    ],
    "Healthcare": [
        "hospital", "clinic", "doctor", "pharma", "pharmacy", "medicine", "apollo",
        "medplus", "netmeds", "1mg", "pharmeasy", "tata 1mg", "diagnostic", "lab",
        "pathology", "consultation", "health", "medical", "dental", "eye", "practo",
        "cult.fit", "gym", "fitness"
    ],
    "Education": [
        "school", "college", "university", "course", "udemy", "coursera", "unacademy",
        "byju", "vedantu", "books", "stationery", "tuition", "coaching", "exam",
        "fees", "library", "kindle", "skillshare"
    ],
    "Investment": [
        "mutual fund", "sip", "zerodha", "groww", "upstox", "angel", "stocks", "shares",
        "trading", "demat", "nse", "bse", "investment", "fd", "fixed deposit",
        "ppf", "nps", "bonds", "gold", "sovereign", "smallcase", "kuvera", "indmoney"
    ],
    "Insurance": [
        "insurance", "lic", "hdfc life", "icici pru", "max life", "term", "health insurance",
        "motor insurance", "policy", "premium", "policybazaar", "digit", "acko", "navi"
    ],
    "EMI & Loans": [
        "emi", "loan", "installment", "credit card", "bajaj", "hdfc", "icici", "sbi",
        "home loan", "car loan", "personal loan", "education loan", "bnpl", "simpl", "lazypay"
    ],
    "Salary & Income": [
        "salary", "wages", "income", "payroll", "credit", "inward", "received",
        "payment received", "freelance", "bonus", "incentive", "commission", "refund", "interest"
    ],
    "Transfer": [
        "transfer", "neft", "imps", "rtgs", "upi", "gpay", "phonepe", "paytm",
        "bhim", "self transfer", "fund transfer", "account transfer", "cred"
    ],
    "Rent & Housing": [
        "rent", "house rent", "pg", "hostel", "accommodation", "maintenance",
        "society", "apartment", "flat", "deposit", "caution", "nobroker"
    ],
    "Personal Care": [
        "salon", "spa", "parlour", "haircut", "beauty", "cosmetics", "skincare",
        "grooming", "urban company", "looks", "javed habib"
    ]
}


class TransactionCategorizer:
    """
    Categorizes transactions using:
    1. MerchantService rules (User-defined, highest priority)
    2. Rule-based keyword matching (Fallback)
    3. Sarvam AI (Final fallback)
    """
    
    def __init__(self):
        # Import services
        from .sarvam_service import sarvam_service
        from .merchant_service import merchant_service
        self.sarvam_service = sarvam_service
        self.merchant_service = merchant_service
    
    async def _merchant_rule_categorize(self, description: str) -> str | None:
        """
        Check user-defined merchant rules first (Highest Priority).
        """
        try:
            rule = await self.merchant_service.find_matching_rule(description)
            if rule:
                return rule.category
        except Exception as e:
            print(f"Merchant rule lookup failed: {e}")
        return None
    
    def _rule_based_categorize(self, description: str) -> str | None:
        """
        Try to categorize using keyword matching.
        """
        desc_lower = description.lower()
        
        for category, keywords in CATEGORY_KEYWORDS.items():
            for keyword in keywords:
                if keyword in desc_lower:
                    return category
        
        return None
    
    async def categorize_single(self, description: str, amount: float, tx_type: str) -> str:
        """
        Categorize a single transaction using the priority chain:
        1. User-defined Merchant Rules (Fastest, Highest Priority)
        2. Keyword Matching (Fast)
        3. AI Fallback (Slowest)
        """
        # 1. Check user-defined merchant rules FIRST (Fast Path)
        category = await self._merchant_rule_categorize(description)
        if category:
            return category
        
        # 2. Try rule-based keyword matching
        category = self._rule_based_categorize(description)
        if category:
            return category
        
        # Fall back to Sarvam if rules don't match
        if self.sarvam_service.is_configured:
            try:
                prompt = f"""Categorize this Indian financial transaction into ONE of these categories:
- Food & Dining
- Groceries
- Transportation
- Shopping
- Entertainment
- Utilities
- Healthcare
- Education
- Investment
- Insurance
- EMI & Loans
- Salary & Income
- Transfer
- Rent & Housing
- Personal Care
- Other

Transaction: "{description}"
Amount: ₹{amount}
Type: {tx_type}

Respond with ONLY the category name, nothing else."""
                
                response = await self.sarvam_service.simple_chat(
                    prompt,
                    "You are a transaction categorizer. Respond with only one category name from the provided list."
                )
                return response.strip()
            except Exception as e:
                print(f"AI categorization failed: {e}")
        
        # Default fallback
        return "Other"
    
    async def categorize_batch(self, transactions: List[Dict]) -> List[Dict]:
        """
        Categorize multiple transactions efficiently.
        Uses batch processing for AI calls.
        """
        results = []
        uncategorized = []
        
        # First pass: Rule-based categorization
        for i, tx in enumerate(transactions):
            desc = tx.get("description", "")
            category = self._rule_based_categorize(desc)
            
            if category:
                tx["category"] = category
                results.append(tx)
            else:
                uncategorized.append((i, tx))
        
        # Second pass: AI categorization for uncategorized
        if uncategorized and self.sarvam_service.is_configured:
            try:
                # Build batch prompt
                batch_items = "\n".join([
                    f"{i+1}. {tx.get('description', 'Unknown')} - ₹{tx.get('amount', 0)}"
                    for i, (_, tx) in enumerate(uncategorized)
                ])

                prompt = f"""Categorize these Indian financial transactions. For each, respond with ONLY the category name from this list:
Food & Dining, Groceries, Transportation, Shopping, Entertainment, Utilities, Healthcare, Education, Investment, Insurance, EMI & Loans, Salary & Income, Transfer, Rent & Housing, Personal Care, Other

Transactions:
{batch_items}

Respond with one category per line, in the same order:"""

                response = await self.sarvam_service.simple_chat(
                    prompt,
                    "You are a transaction categorizer. Respond with category names only, one per line.",
                )
                categories = response.strip().split("\n")
                
                for j, (orig_idx, tx) in enumerate(uncategorized):
                    if j < len(categories):
                        tx["category"] = categories[j].strip()
                    else:
                        tx["category"] = "Other"
                    results.append(tx)
                    
            except Exception as e:
                print(f"Batch AI categorization failed: {e}")
                for _, tx in uncategorized:
                    tx["category"] = "Other"
                    results.append(tx)
        else:
            for _, tx in uncategorized:
                tx["category"] = "Other"
                results.append(tx)
        
        return results
    
    def get_spending_by_category(self, transactions: List[Dict]) -> Dict[str, float]:
        """
        Aggregate spending by category.
        """
        spending = {}
        for tx in transactions:
            category = tx.get("category", "Other")
            amount = tx.get("amount", 0)
            tx_type = tx.get("type", "expense")
            
            if tx_type == "expense":
                spending[category] = spending.get(category, 0) + amount
        
        return dict(sorted(spending.items(), key=lambda x: x[1], reverse=True))


# Singleton instance
transaction_categorizer = TransactionCategorizer()

async def categorize_transaction(description: str, amount: float, tx_type: str = 'expense') -> str:
    """Wrapper function for easier imports"""
    return await transaction_categorizer.categorize_single(description, amount, tx_type)
