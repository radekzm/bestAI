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
        os.makedirs(".bestai", exist_ok=True)
        with open(".bestai/live_session.jsonl", "a") as f:
            f.write(json.dumps(entry) + "\n")

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
        print(f"\n\033[1;34m[CONDUCTOR]\033[0m 🛰️ Dispatching {vendor} for task: {task[:50]}...")
        
        def run():
            cmd = f"bestai swarm --vendor {vendor} --task \"{task}\""
            try:
                proc = subprocess.run(cmd, shell=True, capture_output=True, text=True)
                if "CRITICAL" in proc.stdout or "ERROR" in proc.stderr or "MILESTONE" in proc.stdout:
                    print(f"\n\033[1;33m[CONDUCTOR] 🔔 IMPORTANT UPDATE from {vendor}:\033[0m")
                    print(f"---\n{proc.stdout[-500:]}\n---")
                else:
                    self.log(f"subagent-{vendor}", "Task completed silently.")
            except Exception as e:
                print(f"Subagent error: {e}")

        thread = threading.Thread(target=run)
        thread.daemon = True
        thread.start()

    def chat_loop(self):
        print("\n\033[1;36m🛸 bestAI Living Swarm (v10.1) Online\033[0m")
        print("Ready for real-time syndicate orchestration.")
        
        while True:
            try:
                user_msg = input("\n\033[1;32mYOU > \033[0m")
                if user_msg.lower() in ["exit", "quit"]: break
                if not user_msg.strip(): continue
                
                self.log("user", user_msg)
                
                low_input = user_msg.lower()
                if any(x in low_input for x in ["research", "analyze", "find"]):
                    memo = self.get_cached_research(user_msg)
                    if memo:
                        print(f"\033[1;34mCONDUCTOR >\033[0m I already have this in my Vault: {memo[:200]}...")
                    else:
                        self.spawn_specialist("gemini", user_msg)
                        print(f"\033[1;34mCONDUCTOR >\033[0m Gemini is investigating. I'll let you know if they find something worthy.")
                
                elif any(x in low_input for x in ["build", "fix", "code", "refactor"]):
                    self.spawn_specialist("claude", user_msg)
                    print(f"\033[1;34mCONDUCTOR >\033[0m Lead Architect (Claude) dispatched. I am monitoring the GPS.")
                
                else:
                    print(f"\033[1;34mCONDUCTOR >\033[0m Understood. Tasks logged in project stream.")

            except KeyboardInterrupt:
                break

if __name__ == "__main__":
    conductor = SyndicateConductor()
    conductor.chat_loop()
