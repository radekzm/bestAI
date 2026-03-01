import json
import os
from collections import Counter

def analyze_and_heal(log_path=".claude/events.jsonl", pitfalls_path="memory/pitfalls.md"):
    print("\033[1;35m🩹 bestAI Self-Heal: Analyzing failures...\033[0m")
    
    if not os.path.exists(log_path):
        return

    # Count blocks per hook
    with open(log_path, 'r') as f:
        blocks = [json.loads(line) for line in f if '"type":"BLOCK"' in line]
    
    if not blocks:
        print("No recent blocks found. System is healthy.")
        return

    reasons = [b.get('details', {}).get('reason', 'Unknown violation') for b in blocks]
    most_common = Counter(reasons).most_common(1)[0]
    
    reason, count = most_common
    if count >= 2: # Threshold for learning
        print(f"Detected recurring violation ({count} times): {reason}")
        
        os.makedirs(os.path.dirname(pitfalls_path), exist_ok=True)
        with open(pitfalls_path, "a") as f:
            f.write(f"\n- [AUTO-HEAL] Anti-loop rule: Prevents '{reason}'. Verified by hook logs.\n")
        
        print(f"\033[1;32m✅ Knowledge base updated: {pitfalls_path}\033[0m")

if __name__ == "__main__":
    analyze_and_heal()
