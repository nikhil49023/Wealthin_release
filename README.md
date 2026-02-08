# WealthIn Application

This repository contains the source code for the WealthIn personal finance application. The project is structured into three main components: Frontend, Backend, and Documentation.

## Project Structure

### 1. Frontend (`frontend/`)
The frontend is built with **Flutter** and provides the user interface for the mobile application.
- **Location**: `frontend/wealthin_flutter/`
- **Key Features**:
  - Dashboard with financial overview
  - Transactions management
  - Budget tracking
  - AI Advisor interface

### 2. Backend Bridge (`backend/`)
The backend is a **Python sidecar** service that handles complex logic, data processing, and AI integration.
- **Location**: `backend/`
- **Key Modules**:
  - `services/`: Contains core business logic (e.g., AI tools, subscription service).
  - `main.py`: Entry point for the backend server.
  - `ocr_engine.py`: PDF parsing and OCR functionality.
  - `llm_inference_endpoints.py`: AI inference endpoints.

### 3. Documentation (`docs/`)
Documentation and reference materials for developers.
- **Location**: `docs/`
- **Contents**:
  - `SETUP.md`: Instructions for setting up the development environment.
  - `INTEGRATION_ROADMAP.md`: Plan for integrating backend and frontend.
  - `CHANGELOG.md`: Record of changes and updates.

## Getting Started

Please refer to `docs/SETUP.md` for detailed instructions on how to build and run the application.

## Branch Information
- **android**: The current development branch for Android features.
