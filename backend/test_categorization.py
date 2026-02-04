import sys
import os

# Add backend directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from services.pdf_parser_advanced import BankStatementParser, ReceiptParser
from services.trends_service import trends_service

def test_categorization():
    print("Testing BankStatementParser.guess_category...")
    
    test_cases = [
        ("Payment to APOLLO PHARMACY", "Medical"),
        ("Paid to Delhi Public School Fees", "Education"),
        ("Transfer to Adv. Rahul Legal Fees", "Legal"),
        ("Swiggy Order #12345", "Food"),
        ("Uber Ride to work", "Transport"),
        ("Netflix Subscription", "Entertainment"),
        ("Month Rent Payment", "Housing"),
        ("Unknown Transaction", "Other"),  # Should not match 'ACT'
        ("Payment to ACT Fibernet", "Utilities"), # Should match 'ACT'
    ]
    
    for desc, expected in test_cases:
        result = BankStatementParser.guess_category(desc)
        status = "✅" if result == expected else f"❌ (Expected {expected})"
        print(f"{status} [{desc}] -> {result}")

def test_trends_context():
    print("\nTesting TrendsService AI Context...")
    
    # Mock transactions
    transactions = [
        {'amount': 5000, 'category': 'Medical', 'type': 'expense', 'description': 'Apollo'},
        {'amount': 15000, 'category': 'Education', 'type': 'expense', 'description': 'School Fee'},
        {'amount': 2000, 'category': 'Food', 'type': 'expense', 'description': 'Swiggy'},
        {'amount': 50000, 'category': 'Salary', 'type': 'income', 'description': 'Work'},
    ]
    
    import asyncio
    
    async def run_trends():
        res = await trends_service.analyze_transactions(transactions, "user1")
        print("\nGenerated AI Context:")
        print("-" * 40)
        print(res.ai_context)
        print("-" * 40)
        
        if "Spending by Category" in res.ai_context and "Medical" in res.ai_context and "Education" in res.ai_context:
            print("✅ Category breakdown present")
        else:
            print("❌ Category breakdown missing")

    asyncio.run(run_trends())

if __name__ == "__main__":
    test_categorization()
    test_trends_context()
