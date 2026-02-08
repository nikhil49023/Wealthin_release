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
        FlutterApp --> StateMgmt[Provider/Riverpod]
    end
    
    subgraph "Backend Layer (Sidecar)"
        PythonSidecar --> AI[AI Agents (Sarvam/Zoho)]
        PythonSidecar --> OCR[OCR Engine (Zoho/PDF)]
        PythonSidecar --> Analytics[Analytics Service]
        PythonSidecar --> PyDB[Analysis DB (SQLite)]
    end
    
    subgraph "External Services"
        AI --> SarvamAPI[Sarvam AI (Indic)]
        AI --> ZohoCatalyst[Zoho Catalyst (LLM)]
        OCR --> ZohoVision[Zoho Vision API]
    end
```

## 2. Core Components

### 2.1 Frontend (Flutter)
- **Role**: Handles UI rendering, user interaction, local data persistence, and business logic orchestration.
- **Tech Stack**: Dart, Flutter, SQLite (sqflite/drift).
- **Key Modules**:
  - `features/ai_advisor`: Chat interface for the AI financial assistant.
  - `features/dashboard`: Real-time financial overview.
  - `features/brainstorm`: Interactive business idea generation.
  - `core/services`: Bridges to the Python backend (`python_bridge_service.dart`).

### 2.2 Backend Bridge (Python Sidecar)
- **Role**: Performs heavy computation, AI inference, document parsing, and advanced financial modeling.
- **Tech Stack**: Python 3.9+, FastAPI, Pandas, ReportLab.
- **Key Services**:
  - `ai_tools_service.py`: Orchestrates agentic AI behaviors.
  - `ocr_engine.py`: Extracts data from receipts and bank statements.
  - `dpr_generator.py`: Generates Detailed Project Reports.
  - `socratic_engine.py`: Powers the brainstorming logic.

## 3. Key Algorithms & Services

### 3.1 AI Advisor & Agentic Loop
The AI Advisor operates on a **Sense-Plan-Act** agentic architecture.
- **Logic**:
  1.  **Perception**: Receives user query + financial context (trends, recent transactions).
  2.  **Fast Path (Regex)**: Instantly detects simple intent (e.g., "Budget 50k") using regex patterns to skip LLM latency.
  3.  **Cognition (LLM)**: Uses Sarvam AI (for Indic languages) or Zoho Catalyst (for English) to plan actions.
  4.  **Action**: Executes tools (e.g., `calculate_sip`, `web_search`) via the `AIToolsService`.
  5.  **Reflection**: Validates results against RBI guidelines (Debt-to-Income ratio, Savings Rate > 20%).

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
