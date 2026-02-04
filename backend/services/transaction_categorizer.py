"""
Transaction Categorizer Service
Uses Zoho Catalyst LLM to intelligently categorize financial transactions
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
    Categorizes transactions using rule-based matching + Zoho Catalyst LLM fallback.
    """
    
    def __init__(self):
        # Import zoho_vision_service for LLM access
        from .zoho_vision_service import zoho_vision_service
        self.zoho_service = zoho_vision_service
    
    def _rule_based_categorize(self, description: str) -> Optional[str]:
        """
        Try to categorize using keyword matching first.
        """
        desc_lower = description.lower()
        
        for category, keywords in CATEGORY_KEYWORDS.items():
            for keyword in keywords:
                if keyword in desc_lower:
                    return category
        
        return None
    
    async def categorize_single(self, description: str, amount: float, tx_type: str) -> str:
        """
        Categorize a single transaction.
        """
        # Try rule-based first (fast & free)
        category = self._rule_based_categorize(description)
        if category:
            return category
        
        # Fall back to Zoho Catalyst LLM if rules don't match
        if self.zoho_service.is_configured:
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
                
                response = await self.zoho_service.llm_chat(
                    prompt=prompt,
                    system_prompt="You are a transaction categorizer. Respond with only the category name.",
                    max_tokens=50
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
        if uncategorized and self.gemini_model:
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
                
                response = self.gemini_model.generate_content(prompt)
                categories = response.text.strip().split("\n")
                
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
