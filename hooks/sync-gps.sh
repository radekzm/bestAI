#!/bin/bash
# hooks/sync-gps.sh — Stop hook
# Updates the Global Project State (GPS) after a session ends.

GPS_FILE=".bestai/GPS.json"

if [ ! -f "$GPS_FILE" ]; then
    # Create default GPS if it doesn't exist
    mkdir -p .bestai
    cat > "$GPS_FILE" << 'EOF'
{
  "project": { "name": "Unknown", "main_objective": "To be defined" },
  "milestones": [],
  "active_tasks": [],
  "blockers": [],
  "shared_context": {}
}
EOF
fi

# Here we would ideally parse the session summary or memory overflow
# to automatically update the GPS using jq or a lightweight python script.
# For now, this hook ensures the file exists and is accessible.
# Agents should be instructed to update this file manually via Edit/Write tools
# if a dedicated parsing mechanism is not available in the environment.

echo "[bestAI] GPS state checked at $GPS_FILE"
exit 0
