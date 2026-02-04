# New endpoints for web search and advanced PDF parsing
# Add this to main.py before the "# ============== Run Server ==============" section

@app.post("/search/finance")
async def search_finance(
    query: str,
    limit: int = 5,
    category: Optional[str] = None,
):
    """
    Search for financial news, tax updates, investment info
    
    Categories: finance_news, tax, investment, schemes, interest_rates
    Returns cached results when available (6-12h TTL)
    """
    from services.web_search_service import web_search_service
    
    try:
        results = await web_search_service.search_finance_news(
            query,
            limit=limit,
            category=category
        )
        
        return {
            "success": True,
            "query": query,
            "category": category,
            "results_count": len(results),
            "results": [
                {
                    "title": r.title,
                    "url": r.url,
                    "snippet": r.snippet,
                    "date": r.date,
                    "relevance": r.relevance_score,
                }
                for r in results
            ]
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "results": []
        }


@app.post("/search/tax-updates")
async def search_tax_updates(query: str = "income tax India 2025", limit: int = 5):
    """Search for current tax updates and guidelines"""
    from services.web_search_service import web_search_service
    
    results = await web_search_service.search_tax_updates(query, limit)
    return {
        "success": True,
        "category": "tax",
        "results_count": len(results),
        "results": [
            {
                "title": r.title,
                "url": r.url,
                "snippet": r.snippet,
            }
            for r in results
        ]
    }


@app.post("/search/schemes")
async def search_schemes(query: str, limit: int = 5):
    """Search for government schemes and benefits"""
    from services.web_search_service import web_search_service
    
    results = await web_search_service.search_schemes(query, limit)
    return {
        "success": True,
        "category": "schemes",
        "query": query,
        "results_count": len(results),
        "results": [
            {
                "title": r.title,
                "url": r.url,
                "snippet": r.snippet,
            }
            for r in results
        ]
    }


@app.post("/search/interest-rates")
async def search_interest_rates(query: str = "current interest rates India", limit: int = 5):
    """Search for current interest rates and market data"""
    from services.web_search_service import web_search_service
    
    results = await web_search_service.search_interest_rates(query, limit)
    return {
        "success": True,
        "category": "interest_rates",
        "results_count": len(results),
        "results": [
            {
                "title": r.title,
                "url": r.url,
                "snippet": r.snippet,
            }
            for r in results
        ]
    }


# ============== Advanced PDF Parsing with OCR ==============

@app.post("/extract-transactions")
async def extract_transactions_advanced(
    file: UploadFile = File(...),
    document_type: str = "auto",  # auto, receipt, bank_statement
):
    """
    Extract transactions from PDF with OCR and multi-method parsing
    
    Supports:
    - Bank statements (HDFC, SBI, ICICI, Axis)
    - Receipts (e-commerce, restaurants, retail)
    - Invoices
    
    Methods used (in order):
    1. Table extraction (most reliable for structured data)
    2. OCR for scanned documents
    3. Pattern matching for unstructured text
    """
    from services.pdf_parser_advanced import pdf_parser_service
    import tempfile
    import os
    
    temp_filename = None
    try:
        # Save file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
            content = await file.read()
            tmp.write(content)
            temp_filename = tmp.name
        
        # Extract transactions
        results = await pdf_parser_service.extract_transactions(
            temp_filename,
            document_type=document_type
        )
        
        return results
    
    except Exception as e:
        logger.error(f"PDF extraction error: {e}")
        return {
            "success": False,
            "error": str(e),
            "transactions": [],
            "count": 0,
        }
    
    finally:
        # Clean up temp file
        if temp_filename and os.path.exists(temp_filename):
            os.remove(temp_filename)


@app.post("/extract-receipt")
async def extract_receipt(file: UploadFile = File(...)):
    """
    Extract data from receipt image/PDF
    Returns: merchant, amount, date, items, category
    """
    from services.pdf_parser_advanced import ReceiptParser
    import tempfile
    import os
    
    temp_filename = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
            content = await file.read()
            tmp.write(content)
            temp_filename = tmp.name
        
        # Extract receipt data
        receipt_data = await asyncio.to_thread(
            ReceiptParser.extract_from_image,
            temp_filename
        )
        
        if not receipt_data:
            receipt_data = {}
        
        return {
            "success": bool(receipt_data),
            "merchant": receipt_data.get('merchant'),
            "amount": receipt_data.get('amount'),
            "date": receipt_data.get('date'),
            "category": receipt_data.get('category'),
            "items": receipt_data.get('items', []),
            "confidence": receipt_data.get('confidence', 0.8),
        }
    
    except Exception as e:
        logger.error(f"Receipt extraction error: {e}")
        return {
            "success": False,
            "error": str(e),
        }
    
    finally:
        if temp_filename and os.path.exists(temp_filename):
            os.remove(temp_filename)
