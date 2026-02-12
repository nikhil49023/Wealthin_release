#!/usr/bin/env python3
"""
Quick test of Groq API integration
Verifies multi-provider service works before hackathon
"""

import asyncio
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from services.ai_provider_service import ai_provider
from dotenv import load_dotenv

load_dotenv()


async def test_groq():
    """Test Groq API"""
    print("=" * 60)
    print("🧪 Testing Groq API Integration")
    print("=" * 60)
    
    provider = os.getenv('AI_PROVIDER', 'groq')
    print(f"\n📡 Current Provider: {provider.upper()}")
    
    if provider == 'groq':
        api_key = os.getenv('GROQ_API_KEY')
        if api_key:
            print(f"✅ Groq API Key found: {api_key[:15]}...")
        else:
            print("❌ GROQAPI_KEY not found in .env!")
            return False
    
    # Test simple query
    print("\n1️⃣  Testing Simple Query...")
    try:
        response = await ai_provider.get_completion(
            prompt="What is 2 + 2? Answer in one sentence.",
            max_tokens=50
        )
        print(f"✅ Response: {response}")
    except Exception as e:
        print(f"❌ Error: {e}")
        return False
    
    # Test financial query
    print("\n2️⃣  Testing Financial Query...")
    try:
        response = await ai_provider.get_completion(
            prompt="Explain Section 80C tax deduction in India in 2 sentences.",
            max_tokens=100
        )
        print(f"✅ Response: {response}")
    except Exception as e:
        print(f"❌ Error: {e}")
        return False
    
    # Test token counting
    print("\n3️⃣  Testing Token Counting...")
    test_text = "This is a test of the token counting system for hackathon budget management."
    tokens = ai_provider.count_tokens(test_text)
    print(f"✅ Text: '{test_text}'")
    print(f"✅ Tokens: {tokens}")
    
    print("\n" + "=" * 60)
    print("✅ ALL TESTS PASSED!")
    print("=" * 60)
    print("\n💡 Groq is working! You can now:")
    print("   1. Test all features without using OpenAI quota")
    print("   2. Before finals: AI_PROVIDER=openai in .env")
    print("   3. Add OpenAI key from organizers")
    print("   4. Zero code changes needed!\n")
    
    return True


if __name__ == "__main__":
    success = asyncio.run(test_groq())
    sys.exit(0 if success else 1)
