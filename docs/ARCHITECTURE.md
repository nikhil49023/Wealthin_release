# WealthIn Application Architecture

## 1. System Overview

WealthIn is a personal finance and business planning application tailored for Indian entrepreneurs and MSMEs. It employs a **hybrid architecture** combining a responsive Flutter frontend with a powerful local Python sidecar backend. This design allows for offline-first capabilities, high-performance data processing, and seamless integration of AI models.

### High-Level Architecture
```mermaid
graph TD
    User[User] <--> FlutterApp[Flutter Frontend (UI/UX)]
    FlutterApp <--> |HTTP/JSON| PythonSidecar[Python Backend (FastAPI)]
    
    subgraph "Frontend Layer"
        FlutterApp --> LocalDB[SQLite (Drift)]
    end
    
    subgraph "Backend Layer (Sidecar)"
        PythonSidecar --> Router[Intelligent Query Router]
        Router --> GovAPI[Government API Service]
        Router --> StaticKB[Static Knowledge Base (JSON)]
        Router --> AI[AI Agents (Sarvam/Zoho/OpenAI)]
        
        GovAPI --> APISetu[API Setu / Income Tax / GST]
        StaticKB --> LocalJSON[Tax Rules / Rates]
        AI --> ExternalAI[External LLMs]
    end
```

## 2. Core Components

### 2.1 Frontend (Flutter)
- **Role**: Handles UI rendering, user interaction, local data persistence, and business logic orchestration.
- **Tech Stack**: Dart, Flutter, SQLite (sqflite/drift).
- **Key Modules**:
  - `features/ai_advisor`: Chat interface for the AI financial assistant.
  - `features/dashboard`: Real-time financial overview.
  - `core/services/python_bridge_service.dart`: Main bridge to the Python backend.

### 2.2 Backend (Python Sidecar)
- **Role**: Intelligent processing, data retrieval, and complex reasoning.
- **Architecture**: **Government APIs First**.
- **Key Services**:
  - `government_api_service.py`: Integrates with API Setu, Income Tax, and GSTN for real-time verification.
  - `static_knowledge_service.py`: Provides instant access to tax slabs, deductions, and rules from offline JSON.
  - `query_router.py`: Routes queries based on cost and capability (Gov API > Static KB > Local DB > OpenAI).
  - `openai_service.py`: Handles complex reasoning tasks like DPR generation.

## 3. Key Algorithms & Services

### 3.1 AI Advisor & Query Routing
The AI Advisor uses a cost-efficient, accuracy-first routing strategy:
1.  **Gov API Check**: Detects intent for real-time verification (PAN, GST, ITR) and calls official APIs. **(Priority 1, FREE)**
2.  **Static KB Lookup**: Checks local JSON for tax rules, rates, and formulas. **(Priority 2, FREE, Offline)**
3.  **Local Transaction Query**: Queries the user's local SQLite database for spending analysis. **(Priority 3, Private)**
4.  **Web Search**: Uses search tools for latest news/prices.
5.  **LLM/RAG**: Falls back to OpenAI/Sarvam only for complex reasoning or DPR generation. **(Priority 4, Paid)**

### 3.2 Socratic Engine (Brainstorming)
A state-machine based engine that guides entrepreneurs through business planning using the Socratic method.
- **Question Types**:
  1.  **Clarification**: "What exactly do you mean by..."
  2.  **Probing Assumptions**: "What evidence supports..."
  3.  **Probing Evidence**: "What data do you have..."
  4.  **Viewpoints**: "How would a competitor view..."
  5.  **Implications**: "What if this fails..."
  6.  **Meta**: "Are we asking the right questions?"
- **Workflow**: Iterates through DPR sections (Market -> Technical -> Financial), ensuring deep thought before report generation.

### 3.3 What-If Financial Simulator
Performs sensitivity analysis for loan applications and business viability.
- **Algorithms**:
  -   **DSCR (Debt Service Coverage Ratio)**: `Net Income / Total Debt Service`.
  -   **Sensitivity Analysis**: Varies Revenue, Costs, and Interest Rate by ±20% to test stability.
  -   **Scenario Comparison**: Simulates Optimistic, Base, Conservative, and Worst-Case scenarios.
  -   **Cash Runway**: Calculates survival months under stress (e.g., 50% revenue drop).

### 3.4 Deep Research Agent
An autonomous agent responsible for market research.
- **Process**: `PLAN` -> `SEARCH` -> `BROWSE` -> `REFLECT` -> `SYNTHESIZE`.
- **Capabilities**:
  -   Multi-step web search (DuckDuckGo).
  -   Cross-referencing multiple sources (Amazon vs Flipkart for prices).
  -   Generating comprehensive markdown reports with citations.

### 3.5 detailed Project Report (DPR) Generator
Automates the creation of bank-ready project reports.
-   **Structure Compliance**: Follows RBI/MSME Ministry templates.
-   **Scoring**: Calculates a "Completeness Score" (0-100%) based on filled fields.
-   **Output**: Generates standardized PDFs (via ReportLab) or text reports.

## 4. Data Flow & Security

### 4.1 Integration Logic
1.  **Request**: Flutter triggers an action (e.g., "Analyze my spending").
2.  **Bridge**: `PythonBridgeService` sends a POST request to `localhost:8000/analyze/spending`.
3.  **Processing**: Python backend queries its local analytics DB or performs computation.
4.  **Response**: JSON result is returned to Flutter.
5.  **Persistence**: Flutter maps the JSON to Hive/SQLite models and updates the UI.

### 4.2 Security
-   **Local Execution**: All personal data processing (OCR, transaction categorization) happens locally on the device.
-   **API Keys**: Keys for Sarvam/Zoho are injected securely from the frontend or environment variables; no hardcoded keys in the codebase.
-   **Data Privacy**: Financial data remains in the local SQLite database and is not synced to any cloud server by default.

## 5. Directory Structure Mapping
-   `frontend/`: Flutter source code.
-   `backend/services/`: Core Python business logic.
-   `backend/main.py`: API Gateway.
-   `docs/`: Project documentation.

