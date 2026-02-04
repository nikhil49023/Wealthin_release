import pdfplumber

with pdfplumber.open("/tmp/phonepe.pdf") as pdf:
    text = pdf.pages[0].extract_text()
    print(repr(text[:500]))
    
    # Try my regex on it
    import re
    pattern = r'([A-Z][a-z]{2} \d{1,2}, \d{4})\s+(.+?)\s+(CREDIT|DEBIT)\s+₹?([\d,]+\.?\d*)'
    matches = re.findall(pattern, text)
    print(f"Matches found: {len(matches)}")
    if matches:
        print(matches[0])
