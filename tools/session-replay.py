#!/usr/bin/env python3
# tools/session-replay.py
# Replays an agent's session from JSONL logs for debugging and analysis.

import json
import argparse
import time
import sys

def colored(text, color_code):
    return f"\033[{color_code}m{text}\033[0m"

def replay_session(log_file, delay=0.5):
    try:
        with open(log_file, 'r') as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"File not found: {log_file}")
        sys.exit(1)

    print(colored(f"=== REPLAYING SESSION: {log_file} ===", "1;34"))
    print("Press Ctrl+C to pause/exit.
")

    try:
        for i, line in enumerate(lines):
            try:
                event = json.loads(line)
                role = event.get("role", "unknown").upper()
                content = event.get("content", "")
                tool_calls = event.get("tool_calls", [])
                
                if role == "USER":
                    print(colored(f"
[USER] ->", "1;32"))
                    print(content)
                elif role == "ASSISTANT":
                    print(colored(f"
[AGENT] ->", "1;35"))
                    if content:
                        print(content)
                    for tool in tool_calls:
                        t_name = tool.get("function", {}).get("name", "unknown")
                        t_args = tool.get("function", {}).get("arguments", "{}")
                        print(colored(f"  🛠️ TOOL CALL: {t_name}", "1;33"))
                        print(colored(f"     {t_args}", "33"))
                elif role == "TOOL":
                    print(colored(f"
[SYSTEM] -> Tool Result:", "1;36"))
                    # Truncate long tool outputs
                    out = str(content)
                    if len(out) > 500:
                        out = out[:500] + "... [TRUNCATED]"
                    print(out)
                
                time.sleep(delay)
            except json.JSONDecodeError:
                pass
    except KeyboardInterrupt:
        print("

Playback paused.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Replay Agent JSONL Session")
    parser.add_argument("log_file", help="Path to the JSONL log file")
    parser.add_argument("--speed", type=float, default=0.5, help="Delay between messages (seconds)")
    args = parser.parse_args()
    
    replay_session(args.log_file, args.speed)
