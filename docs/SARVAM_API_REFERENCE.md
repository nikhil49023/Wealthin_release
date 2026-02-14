# Sarvam Vision API - Quick Reference (CORRECTED)

## ❌ WRONG WAY (404 Errors)
```python
# These endpoints DO NOT EXIST in Sarvam API
url = "https://api.sarvam.ai/vision/ocr"           # ❌ 404
url = "https://api.sarvam.ai/v1/vision/analyze"    # ❌ 404
```

## ✅ CORRECT WAY (OpenAI-compatible Multimodal)
```python
import base64

# Read and encode image
with open(image_path, 'rb') as f:
    image_data = f.read()
image_base64 = base64.b64encode(image_data).decode('utf-8')

# Use chat completions with image_url
url = "https://api.sarvam.ai/v1/chat/completions"

payload = {
    "model": "sarvam-m",
    "messages": [
        {
            "role": "system",
            "content": "You are an expert financial document parser..."
        },
        {
            "role": "user",
            "content": [
                {
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/jpeg;base64,{image_base64}"
                    }
                },
                {
                    "type": "text",
                    "text": "Extract all transactions from this image."
                }
            ]
        }
    ],
    "max_tokens": 2000,
    "temperature": 0.1
}

headers = {
    "Content-Type": "application/json",
    "api-subscription-key": "YOUR_API_KEY"
}

response = requests.post(url, json=payload, headers=headers)
result = response.json()
content = result['choices'][0]['message']['content']
```

## 📊 Response Format
```json
{
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "JSON or text response here"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 150,
    "completion_tokens": 200,
    "total_tokens": 350
  }
}
```

## 🎯 Best Practices

### 1. Structured Output with System Prompts
```python
system_prompt = """Extract transactions as JSON array:
[
  {
    "date": "YYYY-MM-DD",
    "description": "merchant name",
    "amount": 0.00,
    "type": "expense|income",
    "category": "Food & Dining|Shopping|..."
  }
]
Return ONLY valid JSON. No markdown, no explanation."""
```

### 2. Image Format Support
- ✅ JPEG (.jpg, .jpeg)
- ✅ PNG (.png)
- ✅ WebP (.webp)
- ❌ PDF (use Document Intelligence API instead)

### 3. Error Handling
```python
try:
    response = requests.post(url, json=payload, headers=headers, timeout=60)
    response.raise_for_status()
    
    data = response.json()
    content = data['choices'][0]['message']['content']
    
    # Parse JSON from response
    transactions = json.loads(content)
    
except requests.HTTPError as e:
    # Handle API errors (404, 500, etc.)
    logger.error(f"Sarvam API error: {e}")
    fallback_ocr()
    
except json.JSONDecodeError:
    # Handle malformed JSON
    logger.warning("Invalid JSON from LLM, using text parsing")
    regex_extraction(content)
```

### 4. Fallback OCR Strategy
```python
def extract_transactions_with_fallback(image_path):
    try:
        # Primary: Sarvam Vision via chat completions
        return extract_via_sarvam_vision(image_path)
    except Exception as e:
        logger.warning(f"Sarvam failed: {e}, using fallback OCR")
        
        # Fallback: Basic OCR + regex
        text = basic_ocr(image_path)
        return regex_parse_transactions(text)
```

## 🔧 Configuration

### Environment Variables
```bash
# Required
SARVAM_API_KEY=your_api_key_here

# Optional
SARVAM_MODEL=sarvam-m
SARVAM_MAX_TOKENS=2000
SARVAM_TEMPERATURE=0.1
```

### Timeout Settings
```python
# Recommended timeouts
SARVAM_REQUEST_TIMEOUT = 60  # seconds (for image processing)
SARVAM_CONNECT_TIMEOUT = 10  # seconds
```

## 📈 Rate Limits & Costs
- **Rate Limit**: Check your Sarvam API plan
- **Cost**: ~₹0.50-2.00 per image (varies by token usage)
- **Optimization**: Use aggressive max_tokens limit, precise prompts

## 🐛 Common Issues & Fixes

### Issue: "404 Not Found"
**Cause**: Using `/vision/ocr` or `/v1/vision/analyze`  
**Fix**: Use `/v1/chat/completions` with image_url

### Issue: "Invalid base64 encoding"
**Cause**: Incorrect image encoding or missing data URI prefix  
**Fix**: Ensure format is `data:image/jpeg;base64,{base64_string}`

### Issue: "Response is not JSON"
**Cause**: LLM adds markdown formatting or explanation text  
**Fix**: Use strict system prompt, strip markdown with regex

### Issue: "Timeout after 30s"
**Cause**: Default timeout too short for large images  
**Fix**: Increase timeout to 60s, compress images before upload

## 📚 Related Documentation
- [Sarvam AI Docs](https://docs.sarvam.ai/) (if available)
- [OpenAI Vision API](https://platform.openai.com/docs/guides/vision) (similar pattern)
- WealthIn Implementation: `backend/services/sarvam_service.py`

---

**Last Updated**: 2026-02-12  
**Status**: ✅ Verified Working
