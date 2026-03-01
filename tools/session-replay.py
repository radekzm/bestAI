#!/usr/bin/env python3
"""Replay agent session JSONL logs for debugging."""

import argparse
import json
import sys
import time


def colored(text: str, color_code: str) -> str:
    return f"\033[{color_code}m{text}\033[0m"


def replay_session(log_file: str, delay: float = 0.5, max_tool_output: int = 500) -> None:
    try:
        with open(log_file, "r", encoding="utf-8") as fh:
            lines = fh.readlines()
    except FileNotFoundError:
        print(f"File not found: {log_file}", file=sys.stderr)
        raise SystemExit(1)

    print(colored(f"=== REPLAYING SESSION: {log_file} ===", "1;34"))
    print("Press Ctrl+C to stop playback.\n")

    try:
        for line in lines:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue

            role = str(event.get("role", "unknown")).upper()
            content = event.get("content", "")
            tool_calls = event.get("tool_calls", [])

            if role == "USER":
                print(colored("\n[USER] ->", "1;32"))
                print(content)
            elif role == "ASSISTANT":
                print(colored("\n[AGENT] ->", "1;35"))
                if content:
                    print(content)
                for tool in tool_calls:
                    function = tool.get("function", {})
                    t_name = function.get("name", "unknown")
                    t_args = function.get("arguments", "{}")
                    print(colored(f"  TOOL CALL: {t_name}", "1;33"))
                    print(colored(f"    {t_args}", "33"))
            elif role == "TOOL":
                print(colored("\n[SYSTEM] -> Tool Result:", "1;36"))
                output = str(content)
                if len(output) > max_tool_output:
                    output = output[:max_tool_output] + "... [TRUNCATED]"
                print(output)

            time.sleep(delay)
    except KeyboardInterrupt:
        print("\nPlayback interrupted by user.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Replay agent JSONL session logs.")
    parser.add_argument("log_file", help="Path to the JSONL log file")
    parser.add_argument(
        "--speed",
        type=float,
        default=0.5,
        help="Delay between events in seconds (default: 0.5)",
    )
    parser.add_argument(
        "--max-tool-output",
        type=int,
        default=500,
        help="Max characters printed for TOOL output (default: 500)",
    )
    args = parser.parse_args()

    replay_session(args.log_file, args.speed, args.max_tool_output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
