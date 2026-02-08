#!/usr/bin/env python3
"""
Standalone PDF Parser Test Script
Tests the parse_bank_statement_text function from flutter_bridge.py
"""

import re
import json
from datetime import datetime

# ============ CATEGORIZATION ============
def categorize_transaction(description: str, amount: float = 0.0) -> dict:
    """Categorize a transaction based on description."""
    desc_lower = description.lower()
    
    categories = {
        'Food': ['swiggy', 'zomato', 'dominos', 'pizza', 'restaurant', 'food', 'cafe', 'tiffin', 'juice', 'biryani', 'meals'],
        'Shopping': ['amazon', 'flipkart', 'myntra', 'ajio', 'meesho', 'shopping', 'mart', 'store'],
        'Groceries': ['bigbasket', 'zepto', 'blinkit', 'jiomart', 'dmart', 'grocery', 'vegetable', 'fruits'],
        'Transport': ['uber', 'ola', 'rapido', 'irctc', 'petrol', 'diesel', 'fuel'],
        'Bills': ['airtel', 'jio', 'bsnl', 'vodafone', 'electricity', 'water', 'gas', 'recharged', 'recharge', 'dth'],
        'Healthcare': ['apollo', 'pharmeasy', 'medplus', 'pharmacy', 'clinic', 'hospital', 'doctor', 'remedy'],
        'Entertainment': ['netflix', 'spotify', 'hotstar', 'prime', 'youtube', 'movie'],
        'Travel': ['makemytrip', 'goibibo', 'oyo', 'hotel', 'flight', 'booking'],
        'Investments': ['zerodha', 'groww', 'upstox', 'mutual fund', 'sip'],
        'Insurance': ['lic', 'insurance', 'policy'],
    }
    
    for category, keywords in categories.items():
        if any(kw in desc_lower for kw in keywords):
            return {'category': category, 'merchant': description}
    
    # Check for income patterns
    if 'received from' in desc_lower or 'credited' in desc_lower:
        return {'category': 'Income', 'merchant': description}
    
    return {'category': 'Other', 'merchant': description}


# ============ MAIN PARSER ============
def parse_bank_statement_text(text: str) -> str:
    """
    Parse bank statement from extracted PDF text.
    Handles PhonePe, HDFC, SBI, ICICI, Axis, Kotak, and generic formats.
    """
    try:
        transactions = []
        
        # Detect bank/source
        text_lower = text.lower()
        bank_detected = "UNKNOWN"
        for bank, keywords in [
            ("PHONEPE", ["phonepe", "phone pe", "transaction statement for"]),
            ("HDFC", ["hdfc", "hdfcbank"]),
            ("SBI", ["sbi", "state bank of india"]),
            ("ICICI", ["icici"]),
            ("AXIS", ["axis"]),
            ("KOTAK", ["kotak"]),
            ("PAYTM", ["paytm"]),
            ("GPAY", ["google pay", "gpay"]),
        ]:
            if any(kw in text_lower for kw in keywords):
                bank_detected = bank
                break
        
        print(f"[Parser] Detected bank: {bank_detected}")
        
        # Month name to number
        month_map = {
            'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
            'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
            'sep': '09', 'sept': '09', 'oct': '10', 'nov': '11', 'dec': '12'
        }
        
        lines = text.split('\n')
        
        # ============ PhonePe Parser ============
        if bank_detected == "PHONEPE":
            print("[Parser] Using PhonePe multi-line block parser")
            i = 0
            while i < len(lines):
                line = lines[i].strip()
                
                # Look for date pattern: "Jan 29, 2026" or "Jan 29 2026"
                date_match = re.search(r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{1,2}),?\s*(\d{4})', line, re.IGNORECASE)
                if date_match:
                    # Parse date
                    month = month_map.get(date_match.group(1).lower()[:3], '01')
                    day = date_match.group(2).zfill(2)
                    year = date_match.group(3)
                    tx_date = f"{year}-{month}-{day}"
                    
                    # Look ahead for DEBIT/CREDIT, amount, and description within next 7 lines
                    tx_type = None
                    tx_amount = None
                    tx_desc = None
                    
                    for j in range(i + 1, min(i + 8, len(lines))):
                        next_line = lines[j].strip()
                        
                        # Check for DEBIT/CREDIT
                        if next_line.upper() == 'DEBIT':
                            tx_type = 'expense'
                        elif next_line.upper() == 'CREDIT':
                            tx_type = 'income'
                        
                        # Check for amount (₹ followed by number)
                        if tx_amount is None:
                            amt_match = re.search(r'₹\s*([0-9,]+(?:\.\d{0,2})?)', next_line)
                            if amt_match:
                                try:
                                    tx_amount = float(amt_match.group(1).replace(',', ''))
                                except:
                                    pass
                        
                        # Check for description patterns (only after finding amount)
                        if tx_desc is None and tx_amount is not None:
                            desc_patterns = [
                                (r'Paid to\s+(.+)', True),
                                (r'Received from\s+(.+)', True),
                                (r'Mobile recharged\s+(.+)', True),
                                (r'Bill Payment\s+(.+)', True),
                                (r'Added to wallet', False),
                                (r'DTH Recharge', False),
                                (r'Electricity bill', False),
                            ]
                            for dp, has_group in desc_patterns:
                                dm = re.search(dp, next_line, re.IGNORECASE)
                                if dm:
                                    tx_desc = dm.group(1).strip() if has_group and dm.lastindex else dm.group(0).strip()
                                    break
                            
                            # If no pattern matched but line has meaningful text
                            if tx_desc is None and len(next_line) > 5:
                                skip_patterns = ['Transaction ID', 'UTR No', 'Paid by', 'Credited to', 
                                               'Reference', 'XXXX', 'Page', 'Date', 'Amount', 'Type',
                                               'support.phonepe', 'system generated']
                                if not any(sp.lower() in next_line.lower() for sp in skip_patterns):
                                    # Check if it's not just a time
                                    if not re.match(r'^\d{1,2}[f:]\d{2}\s*(am|pm)?$', next_line, re.IGNORECASE):
                                        tx_desc = next_line[:60]
                    
                    # Create transaction if we have enough info
                    if tx_type and tx_amount and tx_amount >= 1:
                        if tx_desc is None:
                            tx_desc = 'PhonePe Transaction'
                        
                        # Clean description
                        tx_desc = tx_desc.strip()[:60]
                        
                        # Get category
                        cat_result = categorize_transaction(tx_desc, tx_amount)
                        
                        transactions.append({
                            'date': tx_date,
                            'description': tx_desc,
                            'amount': tx_amount,
                            'type': tx_type,
                            'category': cat_result.get('category', 'Other'),
                            'merchant': cat_result.get('merchant', tx_desc)
                        })
                
                i += 1
        
        # ============ HDFC/SBI/ICICI/Generic Parser ============
        if not transactions:
            print("[Parser] Using generic line-by-line parser")
            last_date = None
            
            # Date patterns
            date_patterns = [
                # DD/MM/YYYY or DD-MM-YYYY
                (r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})', 'dmy'),
                # DD MMM YYYY or DD-MMM-YYYY
                (r'(\d{1,2})[/\-\s]+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[/\-\s]+(\d{4})', 'dmy_text'),
                # MMM DD, YYYY
                (r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{1,2}),?\s*(\d{4})', 'mdy_text'),
            ]
            
            for i, line in enumerate(lines):
                line = line.strip()
                if not line:
                    continue
                
                # Try to extract date from line
                for pattern, fmt in date_patterns:
                    match = re.search(pattern, line, re.IGNORECASE)
                    if match:
                        try:
                            groups = match.groups()
                            if fmt == 'dmy':
                                day = groups[0].zfill(2)
                                month = groups[1].zfill(2)
                                year = groups[2]
                            elif fmt == 'dmy_text':
                                day = groups[0].zfill(2)
                                month = month_map.get(groups[1].lower()[:3], '01')
                                year = groups[2]
                            elif fmt == 'mdy_text':
                                month = month_map.get(groups[0].lower()[:3], '01')
                                day = groups[1].zfill(2)
                                year = groups[2]
                            last_date = f"{year}-{month}-{day}"
                        except:
                            pass
                        break
                
                # Look for amount pattern in line
                amt_match = re.search(r'₹?\s*([0-9,]+(?:\.\d{2})?)\s*(Cr|Dr|CR|DR)?', line)
                if amt_match:
                    try:
                        amount = float(amt_match.group(1).replace(',', ''))
                        if 1 <= amount <= 10000000:  # ₹1 to ₹1 crore
                            # Determine type
                            tx_type = 'expense'
                            cr_dr = amt_match.group(2)
                            if cr_dr and cr_dr.upper() == 'CR':
                                tx_type = 'income'
                            elif 'credit' in line.lower() or '+' in line:
                                tx_type = 'income'
                            
                            # Get description - remove amount and date from line
                            desc = re.sub(r'₹?\s*[0-9,]+(?:\.\d{2})?\s*(Cr|Dr)?', '', line, flags=re.IGNORECASE)
                            desc = re.sub(r'\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}', '', desc)
                            desc = desc.strip()[:60]
                            
                            if len(desc) < 3:
                                desc = 'Transaction'
                            
                            # Get category
                            cat_result = categorize_transaction(desc, amount)
                            
                            transactions.append({
                                'date': last_date or datetime.now().strftime('%Y-%m-%d'),
                                'description': desc,
                                'amount': amount,
                                'type': tx_type,
                                'category': cat_result.get('category', 'Other'),
                                'merchant': cat_result.get('merchant', desc)
                            })
                    except:
                        pass
        
        # ============ Deduplicate ============
        seen = set()
        unique_txs = []
        for tx in transactions:
            key = f"{tx['date']}_{tx['amount']}_{tx['description'][:15]}"
            if key not in seen:
                seen.add(key)
                unique_txs.append(tx)
        
        # Filter out zero-amount transactions
        unique_txs = [tx for tx in unique_txs if tx['amount'] > 0]
        
        if not unique_txs:
            return json.dumps({
                "success": False,
                "error": "No transactions found. The statement format may not be supported.",
                "bank_detected": bank_detected,
                "text_preview": text[:500]
            })
        
        return json.dumps({
            "success": True,
            "bank_detected": bank_detected,
            "transactions": unique_txs,
            "imported_count": len(unique_txs)
        })
        
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


# ============ MAIN TEST ============
if __name__ == "__main__":
    import sys
    
    # Get PDF path from args or use default
    pdf_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/phonepe.pdf"
    
    print(f"Testing PDF: {pdf_path}")
    
    # Extract text using PyMuPDF
    try:
        import fitz
        doc = fitz.open(pdf_path)
        page_count = len(doc)
        text = ''
        for page in doc:
            text += page.get_text() + '\n\n'
        doc.close()
        print(f"Extracted {len(text)} characters from {page_count} pages")
    except Exception as e:
        print(f"Error reading PDF: {e}")
        sys.exit(1)
    
    # Parse the text
    result = parse_bank_statement_text(text)
    data = json.loads(result)
    
    if data.get('success'):
        print(f"\n✅ SUCCESS! Found {len(data.get('transactions', []))} transactions")
        print(f"Bank detected: {data.get('bank_detected')}")
        print("\nFirst 15 transactions:")
        for i, tx in enumerate(data.get('transactions', [])[:15], 1):
            emoji = "💰" if tx['type'] == 'income' else "💸"
            print(f"  {i}. {emoji} {tx['date']} | ₹{tx['amount']:,.0f} | {tx['description'][:35]}... | {tx['category']}")
    else:
        print(f"\n❌ ERROR: {data.get('error')}")
        print(f"Preview: {data.get('text_preview', '')[:200]}")
