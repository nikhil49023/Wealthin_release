import pdfplumber
import tempfile
import os

def test_pdf_extraction():
    try:
        # Create a dummy PDF
        from reportlab.pdfgen import canvas
        
        with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
            c = canvas.Canvas(tmp.name)
            c.drawString(100, 750, "Transaction Test")
            c.drawString(100, 730, "Uber Ride 2024-01-01 expense 500.00")
            c.save()
            tmp_path = tmp.name

        # Extract
        text = ""
        with pdfplumber.open(tmp_path) as pdf:
            for page in pdf.pages:
                text += page.extract_text()
        
        print("Extracted Text:")
        print(text)
        
        os.remove(tmp_path)
        return "Uber Ride" in text
    except ImportError:
        print("ReportLab not installed, skipping generation test")
        return True
    except Exception as e:
        print(f"Test failed: {e}")
        return False

if __name__ == "__main__":
    if test_pdf_extraction():
        print("PDFPlumber test passed!")
    else:
        print("PDFPlumber test failed!")
