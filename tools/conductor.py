import os
import json
import subprocess
import threading
from datetime import datetime

class ElasticBrainConductor:
    def __init__(self):
        self.project_dir = os.getcwd()
        self.gps_path = ".bestai/GPS.json"
        self.vault_dir = ".bestai/vault"
        os.makedirs(self.vault_dir, exist_ok=True)

    def run(self):
        print("\n\033[1;35m🧠 bestAI v14.0 'The Elastic Brain' Active\033[0m")
        print("Mode: Syndicate Orchestration enabled.\n")
        while True:
            try:
                user_msg = input("\033[1;32mYOU > \033[0m")
                if user_msg.lower() in ["exit", "quit"]: break
                print(f"\033[1;34mCONDUCTOR >\033[0m Dispatching task to Swarm. Monitoring GPS.json...")
            except KeyboardInterrupt: break

if __name__ == "__main__":
    conductor = ElasticBrainConductor()
    conductor.run()
