# WealthIn - AI-Powered Financial Operating System for Indian Entrepreneurs

WealthIn is an **AI-first "CFO in your pocket"** designed to bridge the financial gap for individuals and MSMEs in India. It combines automated financial tracking with institutional-grade wealth planning tools, helping users move from passive tracking to active wealth creation.

---

## 🚀 Problem Statement: The MSME Credit & Information Gap

The biggest barrier to wealth creation for small enterprises (MSMEs) and aspiring entrepreneurs in India is not just a lack of capital, but a **lack of structured access** to it.

1.  **The Credit Gap:** While the government offers numerous incentives (PLI, Mudra Loans) and credit schemes, most entrepreneurs are unaware of them or find the eligibility criteria too complex.
2.  **Documentation Paralysis:** Banks reject loan applications not because the business idea is bad, but because the applicant lacks professional financial projections and a **Detailed Project Report (DPR)**. Small businesses cannot afford expensive CAs to prepare these.
3.  **Fragmented Financial Reality:** Financial data is scattered across SMS, emails, and PDFs. Without a consolidated, verified view of cash flow, informal businesses cannot prove their creditworthiness to formal lenders.
4.  **The "Optimism Trap":** Aspiring founders often launch businesses without validating unit economics, leading to high failure rates. They lack a "critical partner" to stress-test their ideas.

---

## 💡 The Solution: WealthIn

WealthIn acts as an **AI-powered Financial Consultant** that bridges the gap between informal aspirants and formal opportunities.

### Key Features & Solutions

#### 1. 🏦 Bridging the Credit Gap (Government & Institutional Access)
*   **Contextual Scheme Mapping:** The "Ideas" section doesn't just brainstorm; it maps user ideas to specific **Government Incentives and Schemes**.
*   **Local Supply Chain Promotion:** The app promotes local vendors in generated plans to strengthen the domestic supply chain ecosystem.
*   **Solution:** A textile business owner is automatically guided to relevant subsidies (e.g., PLI schemes), ensuring they claim available capital.

#### 2. 📄 Turnkey Loan Documentation (AI-Generated DPR)
*   **Automated DPR Generation:** Once an idea is validated, WealthIn generates a professional-grade **Detailed Project Report (DPR)**.
*   **Bank-Ready:** The report includes market analysis, projected P&L, and unit economics formatted specifically for loan applications.
*   **Solution:** "Unlocks" credit for users who couldn't otherwise afford professional documentation.

#### 3. 📉 The "Cynical VC" Validation Engine
*   **Reality Check:** The AI switches to a "Cynical VC" persona to ruthlessly critique business models for **Unit Economics**, **CAC**, and **Burn Rate**.
*   **Risk Management:** Prevents users from investing in unviable ideas and ensures that applications made with WealthIn DPRs are robust and defensible.

#### 4. 📊 Automated Financial "Source of Truth"
*   **Aggregated Health Score:** By parsing SMS and emails (using `pdf_parser_advanced`), the app builds a consolidated "Financial Health" dashboard.
*   **Creditworthiness:** Creates a verified digital footprint of cash flow, helping informal businesses build a formal credit history.

---

## 🏗️ Architecture & Technology Stack

WealthIn follows a **"Sense-Plan-Act" Agentic Architecture**, split between a Flutter frontend and a powerful Python backend.

### 📱 Frontend (Mobile App)
*   **Framework:** **Flutter** (Dart) for cross-platform performance (Android focused).
*   **State Management:** `ValueNotifier`, `Provider` (lightweight reactive state).
*   **Local Database:** `sqflite` for offline-first transaction storage.
*   **Authentication:** **Supabase** (Auth & Cloud Sync).
*   **UI/UX:** Custom design system with `flutter_animate` and glassmorphism effects.
*   **Key Packages:**
    *   `speech_to_text`: for voice-based financial logging.
    *   `fl_chart`: for financial visualization.
    *   `syncfusion_flutter_pdf`: for document handling.

### 🧠 Backend (Founder's OS)
*   **Framework:** **FastAPI** (Python) - High-performance async API.
*   **Architecture Layers:**
    1.  **Perception (Sensing):**
        *   **SMS/Email Parsing:** Extracts transactions from digital clutter.
        *   **PDF Parser:** `pdfplumber` & `pymupdf` for analyzing bank statements.
        *   **OCR:** **Zoho Vision** & **Sarvam AI** for reading physical receipts.
    2.  **Cognition (Thinking):**
        *   **LLM Inference:** **Groq** (Llama-3/Mixtral) for ultra-fast reasoning.
        *   **Reasoning Fallback:** **OpenAI (GPT-4o)** for complex "Cynical VC" critiques.
        *   **Indic Support:** **Sarvam AI** for regional language financial advice.
        *   **RAG:** Lightweight TF-IDF + SQLite vector search for retrieving financial knowledge.
    3.  **Action (Doing):**
        *   **DPR Generator:** Automates the creation of PDF project reports.
        *   **Calculators:** SIP, EMI, and Unit Economics engines.
        *   **Scheme Matcher:** Logic to map business types to government databases.

### 🔌 External APIs & Integrations
*   **Groq API:** For millisecond-latency LLM responses (powering the Chat & Brainstorm).
*   **OpenAI API:** For high-logic tasks (DPR drafting, complex reasoning).
*   **Sarvam AI:** For best-in-class Indic language support and OCR.
*   **DuckDuckGo:** For real-time market news and web search.
*   **Supabase:** For secure user authentication and cloud synchronization.
*   **Government APIs (Mock/Integration):** For validating PAN/GST status.

---

## � Data & Privacy

WealthIn is designed as a **User-Centric Data Platform**. It does **not** sell user data.

1.  **User Data (The "Source of Truth"):**
    *   **SMS & Email:** Parsed locally or via secure APIs to generate transaction logs.
    *   **Documents:** PDF statements are processed in-memory.
    *   **Storage:** All personal financial data is stored in the **Supabase** cloud database with Row Level Security (RLS).

2.  **Knowledge Bases (RAG):**
    *   **Static Data:** The app includes curated datasets for **GST Rates** (`data/knowledge_base/gst_rates.json`) and **Income Tax Rules** (`data/knowledge_base/income_tax_2024.json`) to provide accurate, offline-ready advice.
    *   **Vector Database:** A lightweight SQLite-based vector store (`knowledge_base.db`) allows the AI to "remember" financial context without sending sensitive queries to third-party LLMs unnecessarily.

3.  **External Data:**
    *   **Market Data:** Real-time stock and news data is fetched via DuckDuckGo and specialized financial APIs, not stored locally.

---

## �🛠️ Getting Started

### Prerequisites
*   **Flutter SDK:** `>=3.22.0`
*   **Python:** `>=3.10`
*   **API Keys:** OpenAI, Groq, Sarvam AI, Supabase (stored in `.env` or Secure Storage).

### Installation (Android)
1.  **Clone the repository:**
    ```bash
    git clone https://github.com/yourusername/wealthin.git
    cd wealthin
    ```

2.  **Run the Backend (Development):**
    ```bash
    cd backend
    pip install -r requirements.txt
    python main.py
    ```

3.  **Run the Frontend:**
    ```bash
    cd frontend/wealthin_flutter
    flutter pub get
    flutter run
    ```
