#!/bin/bash
# tools/serve-dashboard.sh — bestAI Swarm Dashboard Server
# Usage: bestai serve-dashboard

set -euo pipefail

echo "[bestAI] Generating fresh dashboard metrics..."
python3 "$(dirname "$0")/dashboard-gen.py"

echo "[bestAI] 🚀 Starting Dashboard Server at http://localhost:8000"
echo "Press Ctrl+C to stop."

cd .bestai/dashboard && python3 -m http.server 8000
