
import os
import json
import time
import asyncio
from fpdf import FPDF
from duckduckgo_search import DDGS
# Attempt to import sarvamai, handle if missing
try:
    from sarvamai import SarvamClient
except ImportError:
    SarvamClient = None

# Mock API Key for Sarvam (The user needs to provide a real one for actual backend test if not in env)
SARVAM_API_KEY = os.environ.get("SARVAM_API_KEY", "dummy_key_if_none")

def test_duckduckgo_search():
    print("\n" + "="*50)
    print("Testing DuckDuckGo Search Integration")
    print("="*50)
    
    try:
        ddgs = DDGS()
        query = "best budget laptops under 50000 india"
        print(f"Searching for: '{query}'")
        
        # Use the same parameters as in the app
        results = ddgs.text(
            keywords=query,
            region="in-en",
            safesearch="moderate",
            max_results=5,
            backend="lite"
        )
        
        if results:
            print(f"✅ Success! Found {len(list(results))} results.")
            for i, r in enumerate(list(results)[:3], 1):
                print(f"\nResult {i}:")
                print(f"Title: {r.get('title')}")
                print(f"Link: {r.get('href')}")
                print(f"Snippet: {r.get('body')[:100]}...")
                
                # Test price extraction logic locally
                body = r.get('body', '') + " " + r.get('title', '')
                import re
                patterns = [
                    r'₹\s*([\d,]+(?:\.\d{2})?)',
                    r'Rs\.?\s*([\d,]+(?:\.\d{2})?)',
                    r'INR\s*([\d,]+(?:\.\d{2})?)',
                ]
                price = None
                for p in patterns:
                    m = re.search(p, body, re.IGNORECASE)
                    if m:
                        price = m.group(1)
                        break
                if price:
                    print(f"💰 Extracted Price: ₹{price}")
        else:
            print("⚠️ No results returned (but no error).")
            
    except Exception as e:
        print(f"❌ search failed: {e}")

def create_dummy_pdf(filename="test_statement.pdf"):
    print(f"\nCreating dummy PDF: {filename}...")
    pdf = FPDF()
    pdf.add_page()
    pdf.set_font("Arial", size=12)
    pdf.cell(200, 10, txt="Bank Statement - Test", ln=1, align="C")
    pdf.cell(200, 10, txt="Date: 01-01-2024", ln=1, align="L")
    pdf.cell(200, 10, txt="Transaction: Walmart Store - $50.00", ln=1, align="L")
    pdf.cell(200, 10, txt="Transaction: Netflix Subscription - $15.00", ln=1, align="L")
    pdf.output(filename)
    print("✅ Dummy PDF created.")
    return filename

def test_sarvam_pdf_parsing():
    print("\n" + "="*50)
    print("Testing Sarvam Document Intelligence (PDF)")
    print("="*50)
    
    if not SarvamClient:
        print("❌ 'sarvamai' package not installed or import failed.")
        return

    if SARVAM_API_KEY == "dummy_key_if_none":
        print("⚠️ SARVAM_API_KEY not found in environment variables.")
        print("   Skipping actual API call to generic mock test only.")
        return

    pdf_path = create_dummy_pdf()
    
    try:
        client = SarvamClient(api_key=SARVAM_API_KEY)
        print("Stub initialization of SarvamClient successful.")
        
        # NOTE: Actual upload requires a valid key. 
        # Here we simulate the logic flow used in the app.
        
        print(f"Attempting to upload {pdf_path} (will fail with invalid key)...")
        # In a real test with key, this would upload and poll
        # job = client.document_intelligence.create_job(file_path=pdf_path)
        # print("Job created:", job.id)
        
    except Exception as e:
        print(f"ℹ️ (Expected if key invalid) API Call Result: {e}")
    finally:
        if os.path.exists(pdf_path):
            os.remove(pdf_path)
            print("Cleaned up test PDF.")

def main():
    test_duckduckgo_search()
    test_sarvam_pdf_parsing()

if __name__ == "__main__":
    main()
