#!/usr/bin/env python3
"""Vectorize markdown/python files into a local JSON vector store."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
from typing import Any, Iterable, Optional


def cosine_ready_hash_embedding(text: str, dims: int = 384) -> list[float]:
    """Deterministic fallback embedding (no external model dependency)."""
    vec = [0.0] * dims
    words = text.lower().split()
    if not words:
        return vec

    for token in words:
        digest = hashlib.sha256(token.encode("utf-8")).digest()
        idx = int.from_bytes(digest[:4], "big") % dims
        sign = -1.0 if digest[4] % 2 else 1.0
        vec[idx] += sign

    # L2 normalize to make cosine similarity meaningful.
    norm = sum(v * v for v in vec) ** 0.5
    if norm > 0:
        vec = [v / norm for v in vec]
    return vec


def load_sentence_transformer(model_name: str) -> Optional[Any]:
    try:
        from sentence_transformers import SentenceTransformer
    except Exception:
        return None
    return SentenceTransformer(model_name)


def get_embedding(text: str, model: Optional[Any], dims: int = 384) -> list[float]:
    if model is not None:
        result = model.encode(text, normalize_embeddings=True)
        return [float(v) for v in result]
    return cosine_ready_hash_embedding(text, dims=dims)


def iter_files(directory: Path) -> Iterable[Path]:
    for suffix in ("*.md", "*.py"):
        yield from directory.rglob(suffix)


def index_files(
    directory: Path,
    output_file: Path,
    chunk_size: int,
    model_name: str,
    dims: int,
) -> int:
    model = load_sentence_transformer(model_name)
    provider = "sentence-transformers" if model is not None else "hash-fallback"
    index: list[dict[str, Any]] = []
    indexed_files = 0

    for path in sorted(iter_files(directory)):
        if not path.is_file():
            continue
        if any(marker in path.parts for marker in (".git", ".bestai", ".claude", "__pycache__")):
            continue

        content = path.read_text(encoding="utf-8", errors="ignore")
        chunks = [content[i : i + chunk_size] for i in range(0, len(content), chunk_size)] or [""]
        for i, chunk in enumerate(chunks):
            index.append(
                {
                    "path": str(path),
                    "chunk": i,
                    "content": chunk,
                    "embedding": get_embedding(chunk, model=model, dims=dims),
                    "provider": provider,
                }
            )
        indexed_files += 1

    output_file.parent.mkdir(parents=True, exist_ok=True)
    output_file.write_text(
        json.dumps(
            {
                "meta": {
                    "provider": provider,
                    "model": model_name if model is not None else "hash-fallback",
                    "chunk_size": chunk_size,
                    "dims": dims,
                    "indexed_files": indexed_files,
                    "indexed_chunks": len(index),
                },
                "rows": index,
            },
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )
    print(f"Indexed {indexed_files} files into {output_file} ({provider})")
    return indexed_files


def main() -> int:
    parser = argparse.ArgumentParser(description="bestAI local vectorization tool")
    parser.add_argument("--dir", default=".", help="Directory to index")
    parser.add_argument("--out", default=".bestai/vector-store.json", help="Output JSON file")
    parser.add_argument("--chunk-size", type=int, default=1000, help="Chunk size in characters")
    parser.add_argument(
        "--model",
        default="sentence-transformers/all-MiniLM-L6-v2",
        help="Sentence-transformers model name",
    )
    parser.add_argument("--dims", type=int, default=384, help="Fallback embedding size")
    args = parser.parse_args()

    directory = Path(args.dir).resolve()
    output_file = Path(args.out).resolve()
    index_files(
        directory=directory,
        output_file=output_file,
        chunk_size=max(100, args.chunk_size),
        model_name=args.model,
        dims=max(32, args.dims),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
