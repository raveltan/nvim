#!/usr/bin/env python3
"""Semantic query CLI. Embeds query, scores cosine against ~/.ravelnvim.db,
emits JSON Lines to stdout. Consumed by nvim plugin.
"""
from __future__ import annotations

import argparse
import json
import sqlite3
import sys
import urllib.request
from pathlib import Path

import numpy as np

DEFAULT_DB = Path.home() / ".ravelnvim.db"
LMSTUDIO_URL = "http://localhost:1234/v1/embeddings"
EMBED_MODEL = "text-embedding-qwen3-embedding-0.6b"
QUERY_INSTRUCT = (
    "Instruct: Given a developer search query, retrieve documentation passages "
    "that answer it.\nQuery: "
)


def embed_query(q: str) -> np.ndarray:
    payload = json.dumps(
        {"model": EMBED_MODEL, "input": QUERY_INSTRUCT + q}
    ).encode()
    req = urllib.request.Request(
        LMSTUDIO_URL, data=payload, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        body = json.loads(resp.read())
    v = np.array(body["data"][0]["embedding"], dtype=np.float32)
    n = np.linalg.norm(v)
    return v if n == 0 else v / n


def search(db: sqlite3.Connection, qvec: np.ndarray, sources: list[str], top_n: int):
    if sources:
        placeholders = ",".join("?" for _ in sources)
        cur = db.execute(
            f"SELECT id,file,source,line,anchor,text,vec FROM chunks WHERE source IN ({placeholders})",
            sources,
        )
    else:
        cur = db.execute("SELECT id,file,source,line,anchor,text,vec FROM chunks")
    ids: list[int] = []
    metas: list[tuple] = []
    vecs: list[np.ndarray] = []
    for cid, file, source, line, anchor, text, blob in cur:
        ids.append(cid)
        metas.append((file, source, line, anchor, text))
        vecs.append(np.frombuffer(blob, dtype=np.float32))
    if not vecs:
        return []
    mat = np.stack(vecs)
    scores = mat @ qvec  # already normalised
    top = np.argpartition(-scores, min(top_n, len(scores) - 1))[:top_n]
    top = top[np.argsort(-scores[top])]
    out = []
    for i in top:
        file, source, line, anchor, text = metas[i]
        out.append(
            {
                "score": float(scores[i]),
                "file": file,
                "source": source,
                "line": int(line),
                "anchor": anchor or "",
                "text": text,
            }
        )
    return out


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("query")
    p.add_argument("--db", type=Path, default=DEFAULT_DB)
    p.add_argument("--sources", default="", help="comma-separated filter; empty=all")
    p.add_argument("-n", "--top", type=int, default=30)
    p.add_argument(
        "--format",
        choices=("jsonl", "json"),
        default="jsonl",
        help="jsonl per result, or single json array",
    )
    args = p.parse_args()

    if not args.db.exists():
        print(
            f"db not found: {args.db}. Run scripts/semantic/index.py first.",
            file=sys.stderr,
        )
        return 2

    db = sqlite3.connect(args.db)
    qvec = embed_query(args.query)
    sources = [s.strip() for s in args.sources.split(",") if s.strip()]
    results = search(db, qvec, sources, args.top)
    db.close()

    if args.format == "json":
        json.dump(results, sys.stdout)
        sys.stdout.write("\n")
    else:
        for r in results:
            sys.stdout.write(json.dumps(r) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
