---
name: document-builder
description: Zoho-powered document generation for business reports and DPRs
---

# Zoho Document Builder Skill

This skill handles deterministic, high-quality business document generation using Zoho LLM Serve.

## Purpose

Generate professional business documents:
- Detailed Project Reports (DPR)
- Business Plans
- Financial Projections
- Loan Application Documents
- MSME Registration Documents

## Architecture

```
User Request → Document Template Selection → Data Collection
                            ↓
                      Zoho LLM Serve
                            ↓
                      PDF Generation
```

## Key Constraint

**NEVER use RAG or general LLM for document drafting.**

Document generation requires:
1. Deterministic output formatting
2. Consistent structure
3. Accurate financial calculations
4. Regulatory compliance

## Document Types

### 1. Detailed Project Report (DPR)
- Executive Summary
- Business Description
- Market Analysis
- Financial Projections
- Implementation Plan
- Risk Assessment

### 2. Loan Application
- Business Overview
- Revenue Model
- Collateral Details
- Repayment Schedule

### 3. Business Plan
- Vision & Mission
- SWOT Analysis
- Marketing Strategy
- Financial Plan

## Integration

The document builder uses:
- `ZohoService.chat()` for structured content generation
- Python sidecar for PDF rendering
- Template engine for consistent formatting

## Endpoint

```dart
// In brainstorm_endpoint.dart
Future<Map<String, dynamic>> generateDPR(
  Session session,
  DPRInput input,
) async {
  // Uses Zoho LLM for each section
  // Maintains consistent formatting
  // Returns structured document data
}
```

## Output Formats

- JSON (for app display)
- PDF (for download/print)
- HTML (for web preview)
