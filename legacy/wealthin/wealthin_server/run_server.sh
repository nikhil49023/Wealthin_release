#!/bin/bash

# Configuration: Zoho Catalyst LLM
export ZOHO_CLIENT_ID="1000.S502C4RR4OX00EXMKPMKP246HJ9LYY"
export ZOHO_CLIENT_SECRET="267a55dc05912009bb6ee13aabe1ea4e00c303e94d"
export ZOHO_REFRESH_TOKEN="1000.9d9d2a78dd2bab8c51eb351f9f6d979f.904b8b7a8543ec3281d18749911184fd"
export ZOHO_PROJECT_ID="24392000000011167"
export ZOHO_CATALYST_ORG_ID="60056122667"

echo "Starting WealthIn Server..."
dart bin/main.dart --apply-migrations
