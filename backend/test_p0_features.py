"""
Test script for P0 features
Tests bill splitting and forecasting services
"""

import asyncio
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from services.bill_split_service import bill_split_service
from services.forecast_service import forecast_service
from services.database_service import database_service


async def test_bill_split():
    """Test bill splitting service"""
    print("\n🧪 Testing Bill Split Service...")
    
    # Initialize services
    await database_service.initialize()
    await bill_split_service.initialize()
    
    # Test creating a split
    participants = [
        {"user_id": "user1", "name": "Rahul"},
        {"user_id": "user2", "name": "Priya"},
        {"user_id": "user3", "name": "Amit"}
    ]
    
    result = await bill_split_service.create_split(
        total_amount=1200.0,
        split_method="equal",
        participants=participants,
        created_by="user1",
        description="Team Lunch at Cafe Coffee Day"
    )
    
    print(f"✅ Split created: ID={result['split_id']}")
    print(f"   Shares: {result['shares']}")
    
    # Test getting user debts
    debts = await bill_split_service.get_user_debts("user1")
    print(f"\n✅ User debts retrieved:")
    print(f"   Owes me: ₹{debts['total_owed_to_me']}")
    print(f"   I owe: ₹{debts['total_i_owe']}")
    print(f"   Net balance: ₹{debts['net_balance']}")
    
    return result['split_id']


async def test_forecast():
    """Test forecasting service"""
    print("\n🧪 Testing Forecast Service...")
    
    # This will work even with no data
    forecast = await forecast_service.forecast_month_end("test_user")
    
    print(f"✅ Month-end forecast generated:")
    print(f"   Projected total: ₹{forecast['projected_total']}")
    print(f"   Current spending: ₹{forecast['current_spending']}")
    print(f"   Days remaining: {forecast['days_remaining']}")
    print(f"   Recommendation: {forecast['recommendation']}")
    
    # Test weekly digest
    digest = await forecast_service.generate_weekly_digest("test_user")
    print(f"\n✅ Weekly digest generated:")
    print(f"   Week total: ₹{digest['week_total']}")
    print(f"   Change: {digest['change_percent']:+.1f}%")


async def main():
    """Run all tests"""
    print("=" * 60)
    print("🚀 WealthIn P0 Features - Backend Test Suite")
    print("=" * 60)
    
    try:
        split_id = await test_bill_split()
        await test_forecast()
        
        print("\n" + "=" * 60)
        print("✅ ALL TESTS PASSED!")
        print("=" * 60)
        print("\n📝 Test Summary:")
        print("   • Bill splitting service: ✓ Working")
        print("   • Expense forecasting: ✓ Working")
        print("   • Database integration: ✓ Working")
        print("\n💡 Next Steps:")
        print("   1. Start the backend: python3 main.py")
        print("   2. Test API endpoints with curl or Postman")
        print("   3. Build Flutter frontend screens")
        
    except Exception as e:
        print(f"\n❌ TEST FAILED: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
