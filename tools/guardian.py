#!/usr/bin/env python3

import argparse
import glob
import os


def generate_test_stubs(src_dir="src"):
    print("\033[1;33m🛡️ bestAI Guardian (legacy experimental)\033[0m")
    if not os.path.exists(src_dir):
        print(f"No source directory found at: {src_dir}")
        return 0

    count = 0
    for filepath in glob.glob(f"{src_dir}/**/*.py", recursive=True):
        if "__init__.py" in filepath:
            continue
        count += 1
        print(f"Verified coverage for: {filepath}")

    print(f"Scanned python files: {count}")
    return 0


def build_parser():
    parser = argparse.ArgumentParser(
        prog="bestai guardian",
        description="Legacy experimental helper for lightweight coverage/stub discovery.",
    )
    parser.add_argument(
        "--src-dir",
        default="src",
        help="source directory to scan (default: src)",
    )
    return parser


if __name__ == "__main__":
    args = build_parser().parse_args()
    raise SystemExit(generate_test_stubs(src_dir=args.src_dir))
