# WealthIn Implementation Documentation

## 1. Project Overview
WealthIn is a financial management application designed for Indian entrepreneurs and small business owners. The recent development phase focused on integrating a robust, multi-model AI agent system to provide intelligent financial advice, document handling, and transaction management.

## 2. Core Architecture: The "Quad-Model" AI System

We implemented a sophisticated **AI Router (`AIRouterService`)** that acts as the central brain, dynamically routing user queries to the most appropriate AI model based on intent, language, and complexity.

### The Models
1.  **Sarvam AI (Indic Layer)**: 
    *   **Role**: Handles queries in Indian regional languages (Hindi, Telugu, Tamil, etc.) and understands local context (e.g., "Kirana store", "Mudra loan").
    *   **Trigger**: Detected via regex patterns for Indian language scripts.
2.  **Zoho RAG (Factual Layer)**:
    *   **Role**: Used for high-stakes, factual queries requiring grounded answers from a knowledge base (e.g., tax laws, government schemes, investment rules).
    *   **Trigger**: Keywords like "tax", "gst", "scheme", "compliance".
3.  **Zoho LLM (Conversational Layer)**:
    *   **Role**: Handles general conversation, advice, and personality-driven interactions.
    *   **Trigger**: Conversational patterns, short queries, opinions.
4.  **OpenAI (Orchestrator/Fallback)**:
    *   **Role**: Acts as the ultimate fallback for reliability and handles complex reasoning or tool calling when other models fail.
    *   **Trigger**: System failures or when specifically required for advanced reasoning.

### Routing Logic (`routeQuery`)
The router analyzes the query using:
1.  **Pattern Matching**: Checks for specific keywords (financial terms, greetings).
2.  **Language Detection**: Identifies non-English scripts.
3.  **Heuristics**: length of query, presence of specific entities.

## 3. Reliability & Fallback Mechanism
A robust error handling system was implemented to ensure 99.9% availability.

*   **Error Detection**: The system analyzes AI responses for failure patterns (e.g., "I'm having trouble", "cannot process").
*   **Cascading Fallback**: If a primary model fails (e.g., RAG returns 400), the system automatically retries with the next best model.
    *   *Example*: RAG (Primary) -> Fails -> LLM (Secondary) -> Fails -> OpenAI (Ultimate).
*   **Response Validation**: Ensures no empty or error-message-only responses are shown to the user.

## 4. Key Features Implemented

### A. Intelligent AI Advisor
*   **Context-Aware**: The advisor receives the user's recent transactions and user profile context.
*   **Routing**: Automatically switches between factual answers (RAG) and friendly advice (LLM).
*   **Indic Support**: Capable of understanding and responding in key Indian languages via Sarvam.

### B. Transaction Management
*   **Unified Import Dialog**: A new, Flutter-based `ImportTransactionsDialog` that supports:
    *   PDF and Image file picking with preview.
    *   One-click extraction and import.
*   **OCR Integration**:
    *   **Python Sidecar**: For structured PDF bank statements.
    *   **Zoho Vision**: For unstructured image receipts.

### C. Backend Services
*   **`AIRouterService`**: The detailed routing logic.
*   **`ZohoService`**: Integration with Zoho Catalyst (RAG/LLM).
*   **`SarvamService`**: Integration with Sarvam AI APIs.
*   **`OpenAIService`**: Integration with OpenAI for high-level reasoning.
*   **`AIToolsService`** (In Progress): Adding capability for the AI to *do* things (Create Budget, Set Goal).

### D. UI/UX Enhancements
*   **Animations**: Added `flutter_animate` effects to dashboard cards and chat bubbles.
*   **Bug Fixes**: Resolved `ParentDataWidget` errors in the dashboard grid layout.
*   **Port Config**: Fixed port conflicts between backend (8085) and frontend (8080).

## 5. Configuration & Environment
The system uses environment variables for secure credential management.

**Required Variables (.env):**
```bash
# Zoho (For RAG & LLM)
ZOHO_CLIENT_ID=...
ZOHO_CLIENT_SECRET=...
ZOHO_REFRESH_TOKEN=...
ZOHO_PROJECT_ID=...
ZOHO_CATALYST_ORG_ID=...

# Sarvam (For Indic Languages)
SARVAM_API_KEY=...

# OpenAI (Fallback & Tools)
OPENAI_API_KEY=...
```

## 6. Next Steps
1.  **Connect AI Tools**: Fully wire up the `AIToolsService` to the Chat UI so the AI can execute actions like "Create a budget for food".
2.  **Finalize OCR**: Ensure the Python sidecar is fully answering the Flutter request for PDF extraction.

## 7. Future Implementation Plan (To-Do)

### A. Critical Technical Tasks
1.  **AI Tools Integration (`AIToolsService`)**:
    *   Connect the `AIToolsService` (already created) to the `AiAdvisorEndpoint`.
    *   Update `AiAdvisorEndpoint` to recognize when a tool has been triggered (e.g., "Budget Created") and format the response to the user accordingly.
    *   Test end-to-end flow: User says "Create budget" -> AI function call -> Database update -> Confirmation message.
2.  **PDF Extraction Python Service**:
    *   The `TransactionImportEndpoint` currently expects a Python sidecar at a specific URL. This Python service needs to be verified/implemented to handle the actual PDF parsing (using libraries like `PyMuPDF` or `tabula-py`) and interface with the Zoho/OpenAI models for structuration.
3.  **Authentication & User Context**:
    *   Currently, we are using a hardcoded `userId = 1`. We need to implement proper user session management using Serverpod's auth module to ensure data privacy and personalization.

### B. Feature Enhancements
1.  **Voice Interaction**:
    *   Implement voice-to-text input for the AI Advisor (using Web Speech API or Sarvam's speech models).
    *   Add text-to-speech output for accessibility and a "talking advisor" experience.
2.  **Document Generator Tool**:
    *   Implement the "Document Builder" skill.
    *   Allow users to request documents like "Generate a loan application letter" or "Create a project report for my shop".
    *   Use the AI to draft the content and generate a downloadable PDF.
3.  **Regional Localization**:
    *   Fully utilize Sarvam AI to translate the *app interface* itself dynamically, not just the chat responses.
4.  **Dashboard Personalization**:
    *   Use AI to generate a "Daily Financial Insight" card on the dashboard based on the user's latest transaction trends.

### C. Testing & Deployment
1.  **Unit & Integration Tests**:
    *   Write tests for the `AIRouterService` to verify routing logic (mocking the API calls).
    *   Test the fallback mechanism to ensure it triggers correctly.
2.  **Production Deployment**:
    *   Set up Docker orchestration for the Serverpod backend, Redis, Postgres, and the Python sidecar.
    *   Configure CI/CD pipelines.

