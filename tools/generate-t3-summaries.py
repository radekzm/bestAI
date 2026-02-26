#!/usr/bin/env python3
"""Generate a compact T3 directory summary for bestAI."""

from __future__ import annotations

import argparse
import os
from pathlib import Path


SKIP_DIR_MARKERS = (".git", ".bestai", ".claude", "__pycache__")


def should_skip(path: Path) -> bool:
    parts = set(path.parts)
    return any(marker in parts for marker in SKIP_DIR_MARKERS)


def summarize_directory(root_dir: Path, output_file: Path) -> list[str]:
    summaries: list[str] = ["# Cold Storage Index (T3 Summary)", ""]

    for dirpath, _dirnames, filenames in os.walk(root_dir):
        current = Path(dirpath)
        if should_skip(current):
            continue

        visible_files = sorted(
            f for f in filenames if not f.startswith(".") and (current / f).is_file()
        )
        if not visible_files:
            continue

        relative_path = current.relative_to(root_dir)
        if str(relative_path) == ".":
            continue

        extensions = sorted({Path(name).suffix or "<no-ext>" for name in visible_files})
        ext_summary = ", ".join(extensions[:6])
        if len(extensions) > 6:
            ext_summary += ", ..."

        summaries.append(
            f"- `{relative_path.as_posix()}/`: "
            f"Contains {len(visible_files)} files ({ext_summary})."
        )

    output_file.parent.mkdir(parents=True, exist_ok=True)
    output_file.write_text("\n".join(summaries) + "\n", encoding="utf-8")
    return summaries


def main() -> int:
    parser = argparse.ArgumentParser(description="bestAI v4 T3 Summary Generator")
    parser.add_argument("--dir", default=".", help="Root directory to summarize")
    parser.add_argument(
        "--out",
        default=".bestai/T3-summary.md",
        help="Output summary markdown file",
    )
    args = parser.parse_args()

    root_dir = Path(args.dir).resolve()
    output_file = Path(args.out).resolve()
    summarize_directory(root_dir, output_file)
    print(f"Generated T3 index at {output_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
