import os
import json
import re

def retro_onboard(history_path=".claude/history.jsonl", output_dir=".bestai"):
    print("\033[1;36m🕰️ bestAI Time Machine: Retroactive Onboarding\033[0m")
    
    if not os.path.exists(history_path):
        print(f"No history found at {history_path}. Cannot retroactively onboard.")
        return

    os.makedirs(output_dir, exist_ok=True)
    gps_path = os.path.join(output_dir, "GPS.json")
    decisions_path = os.path.join(output_dir, "historical-decisions.md")

    # Load existing or create new GPS
    gps = {"project": {"name": "Retro-Fitted Project", "main_objective": "Recovered from logs"}, "milestones": [], "shared_context": {"architecture_decisions": []}}
    
    print("Scanning historical chat logs (Offline token-saving analysis)...")
    
    decisions = []
    milestones = set()
    
    with open(history_path, 'r') as f:
        for line in f:
            try:
                entry = json.loads(line)
                content = entry.get('content', '')
                if not content: continue
                
                # Heuristic 1: Find technologies/stack
                if "we will use" in content.lower() or "decided to use" in content.lower():
                    snippet = content[:100].replace('\n', ' ')
                    decisions.append(f"- Extracted: {snippet}...")
                    
                # Heuristic 2: Find milestones
                match = re.search(r'(completed|implemented) the ([a-zA-Z0-9_ ]+)', content, re.IGNORECASE)
                if match:
                    milestones.add(match.group(2).strip())
            except:
                pass

    # Update GPS
    gps["milestones"] = [{"id": f"m{i}", "name": m, "status": "completed"} for i, m in enumerate(milestones)][:10]
    
    with open(gps_path, 'w') as f:
        json.dump(gps, f, indent=2)
        
    with open(decisions_path, 'w') as f:
        f.write("# 🏛️ Historical Architecture Decisions (Auto-Recovered)\n\n")
        f.write("\n".join(decisions[:20])) # Cap at 20

    print(f"\033[1;32m✅ Recovery Complete!\033[0m")
    print(f"Recovered {len(milestones)} milestones into GPS.json")
    print(f"Extracted {min(len(decisions), 20)} architectural constraints.")
    print("Your project is now fully initialized with bestAI context as if we were here from day one.")

if __name__ == "__main__":
    retro_onboard()
