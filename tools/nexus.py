import os
import json
import argparse
from datetime import datetime

def nexus_checkin(user, role, decision, project_dir="."):
    journal_path = os.path.join(project_dir, ".bestai/nexus_journal.jsonl")
    gps_path = os.path.join(project_dir, ".bestai/GPS.json")
    os.makedirs(os.path.dirname(journal_path), exist_ok=True)

    entry = {
        "ts": datetime.now().isoformat(),
        "user": user,
        "role": role,
        "decision": decision
    }

    # Append to Journal
    with open(journal_path, "a") as f:
        f.write(json.dumps(entry) + "
")

    # Update GPS Contributors
    if os.path.exists(gps_path):
        with open(gps_path, "r") as f:
            gps = json.load(f)
        
        if "contributors" not in gps:
            gps["contributors"] = []
        
        contributor = {"name": user, "role": role, "last_active": entry["ts"]}
        # Update existing or add new
        exists = False
        for c in gps["contributors"]:
            if c["name"] == user:
                c["last_active"] = entry["ts"]
                c["role"] = role
                exists = True
                break
        if not exists:
            gps["contributors"].append(contributor)

        with open(gps_path, "w") as f:
            json.dump(gps, f, indent=2)

    print(f"\033[1;32m✅ Nexus Check-in successful.\033[0m")
    print(f"User: {user} ({role})")
    print(f"Decision logged: {decision[:100]}...")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="bestAI Nexus: Human-AI Collaboration Tool")
    parser.add_argument("--user", required=True, help="Your name")
    parser.add_argument("--role", required=True, choices=["Lead", "Dev", "Junior", "Stakeholder"])
    parser.add_argument("--decision", required=True, help="Strategic decision or update to share with AI Swarm")
    args = parser.parse_args()
    
    nexus_checkin(args.user, args.role, args.decision)
