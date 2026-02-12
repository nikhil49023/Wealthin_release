# Transaction Extraction & MSME Features - Testing Guide

## 🧪 Test Plan for Sarvam Vision & MSME Enhancements

---

## I. Sarvam Vision - Transaction Extraction Testing

### Test Case 1: Receipt Photo Upload
**Objective**: Verify transaction extraction from receipt images

**Steps**:
1. Take a photo of a physical receipt (restaurant, grocery, etc.)
2. Upload via the app's transaction section
3. Verify extracted data:
   - Merchant name
   - Total amount
   - Date
   - Auto-category assignment

**Expected Results**:
- ✅ Transaction extracted with 85%+ accuracy
- ✅ Amount parsed correctly (removes ₹, Rs, commas)
- ✅ Category auto-assigned based on merchant
- ✅ Date in YYYY-MM-DD format

**Test Receipts to Use**:
- Swiggy/Zomato food delivery
- Grocery store (D-Mart, Reliance Fresh)
- Fuel station (Petrol pump)
- Pharmacy (Apollo, MedPlus)

---

### Test Case 2: Bank Statement Screenshot
**Objective**: Extract multiple transactions from bank statement

**Steps**:
1. Screenshot your bank app's transaction history (5-10 transactions)
2. Upload screenshot
3. Check if multiple transactions are extracted

**Expected Results**:
- ✅ All visible transactions extracted
- ✅ UPI merchants correctly identified (e.g., "UPI/SWIGGY/123" → "Swiggy")
- ✅ DR/CR correctly mapped to expense/income
- ✅ No duplicate entries

---

### Test Case 3: Fallback OCR (When API Fails)
**Objective**: Verify fallback mechanism works

**Steps**:
1. Temporarily set `SARVAM_API_KEY` to invalid value
2. Upload an image
3. Check if fallback regex parsing activates

**Expected Results**:
- ✅ Graceful degradation (no app crash)
- ✅ Basic amount/date extraction via regex
- ✅ User notified of reduced accuracy

---

## II. MSME Brainstorm Features Testing

### Test Case 4: Government Scheme Recommendations
**Objective**: Verify AI recommends correct schemes

**Test Queries**:
```
User: "I want to start a small bakery. Need ₹15 lakhs."
Expected AI Response:
- Mentions PMEGP (if manufacturing/service sector)
- Calculates subsidy (15-35% based on location)
- Mentions MUDRA Kishore (₹50K-₹5L) or Tarun (₹5L-₹10L)
- Asks about: location (urban/rural), category (general/special)
```

```
User: "I'm a woman entrepreneur. Need ₹40 lakhs for a clothing business."
Expected AI Response:
- Stand-Up India eligibility check
- PMEGP special category subsidy (25-35%)
- CGTMSE collateral-free coverage
- State-specific women entrepreneur schemes
```

**Validation**:
- ✅ Correct scheme mentioned
- ✅ Accurate calculations (subsidy %, own contribution, bank loan)
- ✅ Application process steps included
- ✅ Document checklist provided

---

### Test Case 5: Local Supplier Discovery
**Objective**: Verify AI suggests local MSME suppliers

**Test Query**:
```
User: "I'm starting a food packaging business in Pune. Where can I source corrugated boxes?"
Expected AI Response:
- Suggests searching local MSME suppliers
- Mentions UDYAM directory
- Highlights cost benefits (lower logistics, faster delivery)
- May mention specific packaging clusters in Maharashtra
```

**Validation**:
- ✅ Local ecosystem mentioned
- ✅ Cost optimization perspective
- ✅ Supply chain angle discussed

---

### Test Case 6: Business Viability Analysis
**Objective**: Verify AI can calculate DSCR, TAM/SAM/SOM

**Test Query**:
```
User: "My annual revenue is ₹50 lakhs, costs are ₹35 lakhs. I need a ₹20 lakh loan at 12% for 5 years. Can I get it?"
Expected AI Response:
- Calculate DSCR: (Revenue - Costs) / (Annual Debt Service)
- DSCR > 1.5 → Loan likely approved
- DSCR < 1.5 → Suggest improving revenue or reducing costs
- Show EMI calculation
```

**Validation**:
- ✅ DSCR formula applied correctly
- ✅ Recommendation based on DSCR threshold
- ✅ Sensitivity analysis mentioned (what if revenue drops 20%?)

---

### Test Case 7: Document Drafting Guidance
**Objective**: Verify AI offers to draft business documents

**Test Query**:
```
User: "I need to apply for PMEGP. What documents do I need?"
Expected AI Response:
- Lists required documents (Aadhaar, PAN, DPR, etc.)
- Offers to help draft DPR
- Explains DPR sections (executive summary, market analysis, financial projections)
- Mentions banking format requirements
```

**Validation**:
- ✅ Document drafting capability mentioned
- ✅ DPR sections outlined
- ✅ Actionable next steps

---

## III. End-to-End Workflow Testing

### Test Case 8: Complete MSME Journey
**Scenario**: New user wants to start a business

**Steps**:
1. **Idea Generation**:
   ```
   User: "I want to start a business in Bangalore with ₹10 lakhs. What can I do?"
   ```
   - ✅ AI suggests 3-5 ideas based on location and budget
   - ✅ Mentions local market trends

2. **Idea Validation**:
   ```
   User: "I like the cloud kitchen idea. How do I validate it?"
   ```
   - ✅ AI suggests TAM/SAM/SOM calculations
   - ✅ Recommends competitor analysis
   - ✅ Offers DSCR calculation

3. **Funding Guidance**:
   ```
   User: "How do I get funding?"
   ```
   - ✅ PMEGP/MUDRA eligibility check
   - ✅ Subsidy calculations
   - ✅ Application process

4. **Supplier Discovery**:
   ```
   User: "Where can I source kitchen equipment in Bangalore?"
   ```
   - ✅ Local MSME supplier suggestions
   - ✅ Cost optimization tips

5. **Document Drafting**:
   ```
   User: "Help me prepare my DPR"
   ```
   - ✅ DPR template provided
   - ✅ Section-by-section guidance

---

## IV. Performance & Error Handling

### Test Case 9: API Timeout Handling
**Steps**:
1. Simulate slow network (use network throttling)
2. Upload image for transaction extraction
3. Verify timeout handling

**Expected**:
- ✅ Graceful timeout (60s max)
- ✅ User notified with friendly message
- ✅ Option to retry

---

### Test Case 10: Invalid Image Format
**Steps**:
1. Upload a non-image file (.pdf, .txt)
2. Verify error handling

**Expected**:
- ✅ Clear error message
- ✅ Supported formats listed (jpg, png, webp)
- ✅ No app crash

---

## V. Regression Testing

### Ensure Existing Features Still Work
- [ ] Dashboard analytics display correctly
- [ ] Manual transaction entry works
- [ ] Budgets and goals functional
- [ ] Analysis/Health score calculation accurate
- [ ] PDF report export works
- [ ] SMS transaction parsing (if implemented)

---

## VI. Acceptance Criteria

### Critical (Must Pass)
- [ ] Sarvam Vision extracts transactions with 80%+ accuracy
- [ ] No 404 errors from Sarvam API
- [ ] AI mentions relevant government schemes based on context
- [ ] DSCR/PMEGP calculations are mathematically correct
- [ ] Fall back mechanisms work when APIs fail

### Important (Should Pass)
- [ ] Local supplier discovery suggestions appear
- [ ] Document drafting guidance provided when requested
- [ ] Supply chain optimization mentioned in relevant contexts
- [ ] Conservative/optimistic scenarios shown for financial projections

### Nice-to-Have (Can Pass)
- [ ] State-specific scheme recommendations
- [ ] Real-time UDYAM verification (if API available)
- [ ] Automated DPR generation (Phase 2)

---

## VII. Known Limitations

1. **Government API Availability**: Some government APIs may have rate limits or downtime
2. **OCR Accuracy**: Handwritten receipts may have lower accuracy
3. **Language Support**: Currently optimized for English text in images
4. **UDYAM Real-time Verification**: Mock data used until actual API integration

---

## VIII. Test Data Sets

### Sample Receipts to Test
1. **Food Delivery**: Swiggy, Zomato
2. **Grocery**: D-Mart, Big Bazaar
3. **Fuel**: Indian Oil, BPCL, HPCL
4. **Healthcare**: Apollo Pharmacy, 1mg
5. **Entertainment**: PVR, BookMyShow

### Sample Business Scenarios
1. **Micro Manufacturing** (₹5L investment)
2. **Small Service Business** (₹15L investment)
3. **Women Entrepreneur** (₹25L, special category)
4. **Rural Business** (₹10L, higher subsidy)

---

## IX. Reporting Issues

### Bug Report Template
```
**Issue**: [Brief description]
**Steps to Reproduce**:
1. ...
2. ...

**Expected**: [What should happen]
**Actual**: [What actually happened]
**Screenshot**: [Attached]
**Device**: [Android/Desktop, OS version]
**Logs**: [Error messages from console]
```

### Performance Report Template
```
**Test**: [Test case name]
**Response Time**: [Seconds]
**Accuracy**: [Percentage]
**Notes**: [Additional observations]
```

---

## ✅ Test Sign-off

| Test Case | Status | Notes | Tester | Date |
|-----------|--------|-------|--------|------|
| TC1: Receipt Photo | ⬜ | | | |
| TC2: Bank Statement | ⬜ | | | |
| TC3: Fallback OCR | ⬜ | | | |
| TC4: Scheme Recommendations | ⬜ | | | |
| TC5: Supplier Discovery | ⬜ | | | |
| TC6: Viability Analysis | ⬜ | | | |
| TC7: Document Drafting | ⬜ | | | |
| TC8: E2E Journey | ⬜ | | | |
| TC9: Timeout Handling | ⬜ | | | |
| TC10: Invalid Format | ⬜ | | | |

---

**Ready to test!** 🚀

Use this guide to systematically verify all new features and fixes.
