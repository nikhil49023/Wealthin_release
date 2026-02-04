import asyncio
import logging
from services.pdf_parser_advanced import AdvancedPDFParser

# Configure logging
logging.basicConfig(level=logging.INFO)

async def test_extraction():
    parser = AdvancedPDFParser()
    file_path = "/tmp/phonepe.pdf"
    
    print(f"Testing extraction on {file_path}...")
    try:
        result = await parser.extract_transactions(file_path)
        print("\n--- Extraction Result ---")
        print(result) # Print EVERYTHING
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.run(test_extraction())
