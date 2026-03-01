#!/usr/bin/env python3

import argparse


def nexus_checkin(user, role, decision):
    print(f"\033[1;32m✅ Nexus Check-in successful for {user} ({role}).\033[0m")
    if decision:
        print(f"Decision: {decision}")
    return 0


def build_parser():
    parser = argparse.ArgumentParser(
        prog="bestai nexus",
        description="Legacy experimental helper for recording lightweight check-ins.",
    )
    parser.add_argument("--user", default="User", help="name of operator")
    parser.add_argument("--role", default="Lead", help="operator role")
    parser.add_argument(
        "--decision",
        default="Logged via Nexus",
        help="short decision/check-in note",
    )
    return parser


if __name__ == "__main__":
    args = build_parser().parse_args()
    raise SystemExit(nexus_checkin(args.user, args.role, args.decision))
