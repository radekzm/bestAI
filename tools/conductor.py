import argparse
import os
import json
import subprocess
import threading
from datetime import datetime
import sys

class OmniConsole:
    def __init__(self):
        self.project_dir = os.getcwd()
        self.gps_path = ".bestai/GPS.json"
        self.events_path = ".claude/events.jsonl"
        self.vault_dir = ".bestai/vault"
        os.makedirs(self.vault_dir, exist_ok=True)

    def print_c(self, text, color="\033[1;34m", prefix="CONDUCTOR >"):
        print(f"{color}{prefix}\033[0m {text}")

    def analyze_health_and_suggest(self):
        suggestions = []
        
        # Check GPS
        if not os.path.exists(self.gps_path):
            suggestions.append("Run '/init' to setup Global Project State.")
        else:
            try:
                with open(self.gps_path, 'r') as f:
                    gps = json.load(f)
                    milestones = gps.get("milestones", [])
                    active = [m for m in milestones if m.get("status") != "completed"]
                    if not active:
                        suggestions.append("You have no active milestones. Type a new goal to start a swarm.")
                    else:
                        suggestions.append(f"Current milestone: {active[0].get('name')}. Type '/swarm claude' to continue work.")
            except:
                pass

        # Check for recent blocks (Learning opportunity)
        if os.path.exists(self.events_path):
            try:
                with open(self.events_path, 'r') as f:
                    lines = f.readlines()
                    recent_blocks = [line for line in lines[-20:] if '"type":"BLOCK"' in line]
                    if len(recent_blocks) > 2:
                        suggestions.append("Agents were blocked recently. Run '/heal' to analyze mistakes and update rules.")
            except:
                pass

        if suggestions:
            self.print_c("💡 Recommendations based on current state:", "\033[1;33m", "SYSTEM >")
            for s in suggestions:
                print(f"   - {s}")

    def execute_command(self, cmd_string):
        parts = cmd_string.split()
        base_cmd = parts[0].lower()
        args = " ".join(parts[1:])

        if base_cmd == "/doctor":
            subprocess.run("bestai doctor", shell=True)
        elif base_cmd == "/status" or base_cmd == "/cockpit":
            subprocess.run("bestai cockpit", shell=True)
        elif base_cmd == "/heal":
            subprocess.run("bestai self-heal", shell=True)
        elif base_cmd == "/permit":
            subprocess.run(f"bestai permit {args}", shell=True)
        elif base_cmd == "/nexus":
            subprocess.run(f"bestai nexus {args}", shell=True)
        elif base_cmd == "/swarm":
            # Simple wrapper
            vendor = "claude"
            if len(parts) > 1 and parts[1] in ["claude", "gemini", "codex", "ollama"]:
                vendor = parts[1]
                task = " ".join(parts[2:])
            else:
                task = args
            
            if not task:
                self.print_c("Specify a task: /swarm [vendor] <task>")
                return

            self.print_c(f"Dispatching task to {vendor}...", "\033[1;35m")
            subprocess.run(f"bestai swarm --vendor {vendor} --task \"{task}\"", shell=True)
        elif base_cmd == "/help":
            self.print_c("Available internal commands: /doctor, /status, /heal, /permit, /nexus, /swarm [vendor] [task]")
        else:
            self.print_c(f"Unknown internal command: {base_cmd}. Type /help.")

    def run(self, once_task=None):
        if once_task:
            self.print_c("Dispatching one-shot task to Claude (Lead Architect).", "\033[1;34m")
            subprocess.run(f"bestai swarm --vendor claude --task \"{once_task}\"", shell=True)
            return 0

        if not sys.stdin.isatty():
            self.print_c(
                "Interactive mode requires a TTY. Use '--once \"task\"' or 'bestai orchestrate'.",
                "\033[0;31m",
            )
            return 2

        print("\n\033[1;36m===================================================\033[0m")
        print("\033[1;36m 🛸 bestAI OMNI-CONSOLE (v14.1) - The Living Swarm \033[0m")
        print("\033[1;36m===================================================\033[0m\n")
        
        self.analyze_health_and_suggest()
        
        print("\nType your instructions, or use '/' for tools (e.g. /doctor, /swarm gemini). Type 'exit' to leave.\n")

        while True:
            try:
                user_msg = input("\033[1;32mYOU > \033[0m").strip()
                if not user_msg: continue
                if user_msg.lower() in ["exit", "quit"]: 
                    self.print_c("Closing communications. Swarm is standing by.")
                    return 0
                
                if user_msg.startswith("/"):
                    self.execute_command(user_msg)
                else:
                    # Natural language implies a task delegation or reasoning
                    if "?" in user_msg and len(user_msg.split()) < 10:
                        self.print_c("I am analyzing the question against GPS. If it requires deep research, I will spawn Gemini.", "\033[1;34m")
                        # Mock fast answer or dispatch
                        subprocess.run(f"bestai swarm --vendor gemini --task \"Answer user question: {user_msg}\"", shell=True)
                    else:
                        self.print_c("I am delegating this task to Claude (Lead Architect) for implementation.", "\033[1;34m")
                        subprocess.run(f"bestai swarm --vendor claude --task \"{user_msg}\"", shell=True)
                        
            except KeyboardInterrupt:
                print()
                self.print_c("Force exit. Goodbye.")
                return 130
            except EOFError:
                print()
                self.print_c("Input stream closed. Exiting console.")
                return 0


def build_parser():
    parser = argparse.ArgumentParser(
        prog="bestai conductor",
        description=(
            "Legacy experimental Omni-Console. Prefer orchestrator commands "
            "(bestai orchestrate/task/agent/events/console) for production flows."
        ),
    )
    parser.add_argument(
        "--once",
        metavar="TASK",
        help="dispatch a single task in non-interactive mode and exit",
    )
    return parser


if __name__ == "__main__":
    args = build_parser().parse_args()
    console = OmniConsole()
    raise SystemExit(console.run(once_task=args.once))
