#!/bin/bash
# install-openclaw.sh — One-Command Installer for bestAI + OpenClaw (v9.0)
# Usage: curl -s https://raw.githubusercontent.com/radekzm/bestAI/master/install-openclaw.sh | bash

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}🚀 Installing bestAI v9.0 (OpenClaw Total Recall Edition)...${NC}"

# 1. Check prerequisites
if ! command -v npm &>/dev/null; then
    echo -e "${RED}Error: Node.js/npm is required but not installed.${NC}"
    exit 1
fi
if ! command -v git &>/dev/null; then
    echo -e "${RED}Error: git is required but not installed.${NC}"
    exit 1
fi
if ! command -v jq &>/dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    exit 1
fi

# 2. Install bestAI globally
echo -e "
${BOLD}📦 Installing @radekzm/bestai globally via NPM...${NC}"
npm install -g @radekzm/bestai@latest

# 3. Setup Project Directory
PROJECT_DIR="${1:-openclaw-workspace}"
echo -e "
${BOLD}📁 Setting up workspace in ./${PROJECT_DIR}...${NC}"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 4. Initialize bestAI with Omni-Vendor Profile
echo -e "
${BOLD}⚙️ Initializing bestAI infrastructure...${NC}"
npx bestai init . --profile omni-vendor --yes

# 5. Enable OpenClaw Total Recall Mode
echo -e "
${BOLD}🧠 Configuring OpenClaw Total Recall Mode...${NC}"
echo "export BESTAI_OPENCLAW=1" >> .env
echo "export BESTAI_DRY_RUN=0" >> .env
echo "{
  "project": {
    "name": "$PROJECT_DIR",
    "main_objective": "OpenClaw Autonomous Operation"
  }
}" > .bestai/GPS.json

# 6. Final Instructions
echo -e "
${GREEN}${BOLD}✅ Installation Complete!${NC}"
echo -e "Your OpenClaw workspace is ready at: ${BOLD}./$PROJECT_DIR${NC}"
echo -e "
To start your first autonomous task:"
echo -e "  cd $PROJECT_DIR"
echo -e "  source .env"
echo -e "  bestai swarm --task "Analyze this workspace" --vendor gemini"
echo -e "
${BLUE}Welcome to the era of infinite memory.${NC}"
