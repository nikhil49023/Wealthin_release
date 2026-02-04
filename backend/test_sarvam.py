
import os
import asyncio
from dotenv import load_dotenv
from sarvamai import SarvamAI

load_dotenv()

async def test_sarvam():
    api_key = os.getenv("SARVAM_API_KEY")
    if not api_key:
        print("❌ SARVAM_API_KEY not found")
        return

    print(f"Testing Sarvam AI with key: {api_key[:4]}...{api_key[-4:]}")
    
    try:
        client = SarvamAI(api_subscription_key=api_key)
        # Simple completion test
        response = client.chat.completions(
            messages=[
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": "Hello, say 'Sarvam works!' in Hindi."}
            ]
        )
        
        print("\nResponse from Sarvam:")
        # Handle response format (object or dict)
        if hasattr(response, 'choices'):
            print(response.choices[0].message.content)
        else:
            print(response)
            
        print("\n✅ Sarvam SDK is working correctly!")
        
    except Exception as e:
        print(f"\n❌ Error calling Sarvam API: {e}")

if __name__ == "__main__":
    asyncio.run(test_sarvam())
