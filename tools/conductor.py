import os
import json
import time
import subprocess
import threading
from datetime import datetime, timedelta

class SyndicateConductor:
    def __init__(self):
        self.project_dir = os.getcwd()
        self.gps_path = os.path.join(self.project_dir, ".bestai/GPS.json")
        self.vault_dir = os.path.join(self.project_dir, ".bestai/vault")
        os.makedirs(self.vault_dir, exist_ok=True)
        self.task_queue = []
        self.history = []

    def log(self, role, message):
        entry = {"ts": datetime.now().isoformat(), "role": role, "msg": message}
        self.history.append(entry)
        with open(".bestai/live_session.jsonl", "a") as f:
            f.write(json.dumps(entry) + "
")

    def get_cached_research(self, topic):
        memo_path = os.path.join(self.vault_dir, f"{topic.replace(' ', '_')}.memo")
        if os.path.exists(memo_path):
            with open(memo_path, 'r') as f:
                data = json.load(f)
                if datetime.now() < datetime.fromisoformat(data['expiry']):
                    return data['result']
        return None

    def save_research(self, topic, result, ttl_days=7):
        memo_path = os.path.join(self.vault_dir, f"{topic.replace(' ', '_')}.memo")
        expiry = (datetime.now() + timedelta(days=ttl_days)).isoformat()
        with open(memo_path, 'w') as f:
            json.dump({"result": result, "expiry": expiry}, f)

    def spawn_specialist(self, vendor, task):
        print(f"
\033[1;34m[CONDUCTOR]\033[0m 🛰️  Spawning {vendor} for sub-task...")
        
        def run():
            cmd = f"bestai swarm --vendor {vendor} --task "{task}""
            # Run silently in background
            proc = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            
            # Conductor Filters the importance
            if "CRITICAL" in proc.stdout or "ERROR" in proc.stderr or "MILESTONE" in proc.stdout:
                print(f"
\033[1;33m[CONDUCTOR] 🔔 IMPORTANT UPDATE from {vendor}:\033[0m")
                print(f"---
{proc.stdout[-500:]}
---")
            else:
                # Log silently to session
                self.log(f"subagent-{vendor}", "Task completed silently.")

        thread = threading.Thread(target=run)
        thread.daemon = True
        thread.start()

    def chat_loop(self):
        print("
\033[1;36m🛸 bestAI Living Swarm (v10.0) Online\033[0m")
        print("Ready for real-time syndicate orchestration.")
        
        while True:
            try:
                user_msg = input("
\033[1;32mYOU > \033[0m")
                if user_msg.lower() in ["exit", "quit"]: break
                
                self.log("user", user_msg)
                
                # Logic: Conductor routing
                if "research" in user_msg.lower() or "analyze" in user_msg.lower():
                    memo = self.get_cached_research(user_msg)
                    if memo:
                        print(f"\033[1;34mCONDUCTOR >\033[0m I already have this in my Vault: {memo[:200]}...")
                    else:
                        self.spawn_specialist("gemini", user_msg)
                        print(f"\033[1;34mCONDUCTOR >\033[0m Gemini is investigating. I'll let you know if they find something worthy of your attention.")
                
                elif "build" in user_msg.lower() or "fix" in user_msg.lower() or "code" in user_msg.lower():
                    self.spawn_specialist("claude", user_msg)
                    print(f"\033[1;34mCONDUCTOR >\033[0m Lead Architect (Claude) has been dispatched. I am monitoring the GPS.")
                
                else:
                    print(f"\033[1;34mCONDUCTOR >\033[0m Understood. Tasks logged. Standing by.")

            except KeyboardInterrupt:
                break

if __name__ == "__main__":
    conductor = SyndicateConductor()
    conductor.chat_loop()
