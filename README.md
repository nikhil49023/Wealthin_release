# WealthIn Application

This repository contains the source code for the WealthIn personal finance application. The active branch is Android-only and optimized for mobile release readiness.

## Project Structure

### 1. Frontend (`frontend/`)
The frontend is built with **Flutter** and provides the Android application UI.
- **Location**: `frontend/wealthin_flutter/`
- **Key Features**:
  - Dashboard with financial overview
  - Transactions management
  - Budget tracking
  - AI Advisor interface

### 2. Backend Services (`backend/`)
Backend Python services are retained for development/testing utilities. The Android app runtime uses embedded Python integrations and local persistence.
- **Location**: `backend/`
- **Key Modules**:
  - `services/`: Contains core business logic (e.g., AI tools, subscription service).
  - `main.py`: Entry point for the backend server.
  - `services/pdf_parser_advanced.py`: PDF parsing and extraction.
  - `services/sarvam_service.py`: OCR + Indic AI integrations.

### 3. Documentation (`docs/`)
Documentation and reference materials for developers.
- **Location**: `docs/`
- **Contents**:
  - `SETUP.md`: Instructions for setting up the development environment.
  - `ARCHITECTURE.md`: System architecture and component overview.
  - `CHANGELOG.md`: Record of changes and updates.

## Getting Started

Please refer to `docs/SETUP.md` for detailed instructions on how to build and run the application.

Quick start (Android):
1. `./start_wealthin_android.sh`
2. Or run directly: `cd frontend/wealthin_flutter && flutter run`

## Branch Information
- **android**: The current development branch for Android features.
