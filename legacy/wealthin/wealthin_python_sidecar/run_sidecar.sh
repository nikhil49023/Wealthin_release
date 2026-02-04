#!/bin/bash
echo "Starting WealthIn Python Sidecar..."
source venv/bin/activate
uvicorn main:app --reload --port 8000
