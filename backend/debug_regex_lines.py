import pdfplumber
import re

with pdfplumber.open("/tmp/phonepe.pdf") as pdf:
    text = pdf.pages[0].extract_text()
    lines = text.split('\n')
    pattern = r'([A-Z][a-z]{2} \d{1,2}, \d{4})\s+(.+?)\s+(CREDIT|DEBIT)\s+₹?([\d,]+\.?\d*)'
    
    print(f"Total lines: {len(lines)}")
    matches = 0
    for line in lines:
        line = line.strip()
        if re.search(pattern, line):
            matches += 1
            print(f"MATCH: {line}")
            
    print(f"Total Matches line-by-line: {matches}")
