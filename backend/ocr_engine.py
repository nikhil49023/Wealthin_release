import pdfplumber
import re
import json
from datetime import datetime

class OCREngine:
    def __init__(self):
        # Patterns for common bank statement formats (HDFC, ICICI, SBI)
        self.patterns = {
            'date': r'(\d{2}/\d{2}/\d{4}|\d{2}-\d{2}-\d{4}|\d{2}\s[A-Za-z]{3}\s\d{4})',
            'amount': r'(\d{1,3}(?:,\d{3})*\.\d{2})',
            'balance': r'(?:Bal|Balance|Closing).*?(\d{1,3}(?:,\d{3})*\.\d{2})',
            'description': r'[A-Z0-9]{5,}\s+([A-Za-z0-9\s\.\-\/]+?)\s+(?:DEBIT|CREDIT|\d)',
        }

    def detect_bank_format(self, text):
        # Simple heuristic to detect bank format
        if "HDFC BANK" in text:
            return "HDFC"
        elif "ICICI BANK" in text:
            return "ICICI"
        elif "SBI" in text or "STATE BANK OF INDIA" in text:
            return "SBI"
        return "GENERIC"

    def parse_amount(self, amount_str):
        if not amount_str:
            return 0.0
        # Remove commas and convert to float
        clean_str = amount_str.replace(',', '')
        try:
            return float(clean_str)
        except ValueError:
            return 0.0

    def parse_date(self, date_str):
        # Normalize date to ISO format
        formats = ['%d/%m/%Y', '%d-%m-%Y', '%d %b %Y']
        for fmt in formats:
            try:
                return datetime.strptime(date_str, fmt).isoformat().split('T')[0]
            except ValueError:
                continue
        return date_str

    def extract_transactions(self, pdf_path):
        transactions = []
        with pdfplumber.open(pdf_path) as pdf:
            full_text = ""
            for page in pdf.pages:
                text = page.extract_text()
                if not text:
                    continue
                full_text += text
                
                # Line-by-line processing
                lines = text.split('\n')
                for line in lines:
                    # Generic parsing strategy: Look for lines with Date + Description + Amount
                    date_match = re.search(self.patterns['date'], line)
                    amount_matches = re.findall(self.patterns['amount'], line)
                    
                    if date_match and amount_matches:
                        # Extract date
                        date = self.parse_date(date_match.group(0))
                        
                        # Extract amounts (Debit/Credit/Balance)
                        # Logic varies by bank, this is a simplified generic approach
                        # Assuming last amount is balance, one before is transaction amount
                        # This needs refinement per bank
                        
                        amount = 0.0
                        tx_type = "unknown"
                        
                        if len(amount_matches) >= 1:
                           amount = self.parse_amount(amount_matches[0]) 
                           # Simple heuristic: if "Dr" or "Debit" in line -> Expense
                           if "Dr" in line or "Debit" in line:
                               tx_type = "expense"
                           else:
                               tx_type = "income"

                        # Description: Everything else
                        desc = line
                        # Remove date and amount from desc
                        desc = desc.replace(date_match.group(0), "")
                        for amt in amount_matches:
                            desc = desc.replace(amt, "")
                        desc = re.sub(r'\s+', ' ', desc).strip()

                        if desc and amount > 0:
                            transactions.append({
                                "date": date,
                                "description": desc,
                                "amount": amount,
                                "type": tx_type,
                                "category": "Uncategorized" # ML model can fill this later
                            })
                            
        return transactions

# Standalone execution for testing
if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        engine = OCREngine()
        results = engine.extract_transactions(sys.argv[1])
        print(json.dumps(results, indent=2))
    else:
        print("Usage: python ocr_engine.py <pdf_path>")
