#!/usr/bin/env python3
"""Build/update semantic search index for nvim docs.

Walks doc dirs, chunks markdown by header, embeds via LM Studio,
stores in ~/.ravelnvim.db. Incremental by file mtime.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Iterator

import numpy as np

DEFAULT_DB = Path.home() / ".ravelnvim.db"
LMSTUDIO_URL = "http://localhost:1234/v1/embeddings"
EMBED_MODEL = "text-embedding-qwen3-embedding-0.6b"
EMBED_DIM = 1024
BATCH = 64
MAX_CHUNK_CHARS = 2000
MIN_CHUNK_CHARS = 40

NVIMDOCS_DIR = Path.home() / ".config/nvim/docs/nvimdocs"
DEVDOCS_DIR = Path.home() / ".local/share/nvim/devdocs/docs"


def lmstudio_embed(texts: list[str]) -> np.ndarray:
    payload = json.dumps({"model": EMBED_MODEL, "input": texts}).encode()
    req = urllib.request.Request(
        LMSTUDIO_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        body = json.loads(resp.read())
    vecs = np.array([d["embedding"] for d in body["data"]], dtype=np.float32)
    norms = np.linalg.norm(vecs, axis=1, keepdims=True)
    norms[norms == 0] = 1.0
    return vecs / norms


HEADER_RE = re.compile(r"^(#{1,6})\s+(.*)$", re.MULTILINE)


def chunk_markdown(text: str) -> Iterator[tuple[int, str, str]]:
    """Yield (line_number, anchor, chunk_text) splitting on headers."""
    lines = text.splitlines()
    headers: list[tuple[int, str]] = []
    for i, line in enumerate(lines):
        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            headers.append((i, m.group(2).strip()))
    if not headers:
        if len(text.strip()) >= MIN_CHUNK_CHARS:
            yield (1, "", text[:MAX_CHUNK_CHARS])
        return
    boundaries = [h[0] for h in headers] + [len(lines)]
    for idx, (line_no, anchor) in enumerate(headers):
        section = "\n".join(lines[boundaries[idx]:boundaries[idx + 1]])
        section = section.strip()
        if len(section) < MIN_CHUNK_CHARS:
            continue
        if len(section) <= MAX_CHUNK_CHARS:
            yield (line_no + 1, anchor, section)
        else:
            for off in range(0, len(section), MAX_CHUNK_CHARS - 200):
                piece = section[off:off + MAX_CHUNK_CHARS]
                if len(piece) >= MIN_CHUNK_CHARS:
                    yield (line_no + 1, anchor, piece)


def init_db(db_path: Path) -> sqlite3.Connection:
    db = sqlite3.connect(db_path)
    db.executescript(
        """
        CREATE TABLE IF NOT EXISTS files (
            path TEXT PRIMARY KEY,
            source TEXT NOT NULL,
            mtime REAL NOT NULL
        );
        CREATE TABLE IF NOT EXISTS chunks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file TEXT NOT NULL REFERENCES files(path) ON DELETE CASCADE,
            source TEXT NOT NULL,
            line INTEGER NOT NULL,
            anchor TEXT,
            text TEXT NOT NULL,
            vec BLOB NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_chunks_file ON chunks(file);
        CREATE INDEX IF NOT EXISTS idx_chunks_source ON chunks(source);
        CREATE TABLE IF NOT EXISTS meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """
    )
    db.execute(
        "INSERT OR REPLACE INTO meta(key,value) VALUES('model',?)",
        (EMBED_MODEL,),
    )
    db.execute(
        "INSERT OR REPLACE INTO meta(key,value) VALUES('dim',?)",
        (str(EMBED_DIM),),
    )
    db.commit()
    return db


def collect_files(source: str) -> Iterator[Path]:
    if source == "nvimdocs":
        if NVIMDOCS_DIR.exists():
            yield from sorted(NVIMDOCS_DIR.rglob("*.md"))
    elif source == "devdocs":
        if DEVDOCS_DIR.exists():
            yield from sorted(DEVDOCS_DIR.rglob("*.md"))


def index_source(
    db: sqlite3.Connection,
    source: str,
    full: bool,
    limit: int | None,
    batch_size: int,
) -> None:
    files = list(collect_files(source))
    if limit:
        files = files[:limit]
    if not files:
        print(f"[{source}] no files found", file=sys.stderr)
        return
    cur = db.cursor()
    existing = {row[0]: row[1] for row in cur.execute(
        "SELECT path,mtime FROM files WHERE source=?", (source,)
    )}
    todo: list[Path] = []
    for fp in files:
        mt = fp.stat().st_mtime
        if not full and existing.get(str(fp)) == mt:
            continue
        todo.append(fp)
    print(f"[{source}] {len(todo)}/{len(files)} files to (re)index", file=sys.stderr)
    if not todo:
        return

    pending_texts: list[str] = []
    pending_meta: list[tuple[str, str, int, str, str]] = []
    total_chunks = 0
    t0 = time.time()

    def flush() -> None:
        nonlocal pending_texts, pending_meta, total_chunks
        if not pending_texts:
            return
        try:
            vecs = lmstudio_embed(pending_texts)
        except urllib.error.URLError as e:
            print(f"[{source}] LM Studio error: {e}", file=sys.stderr)
            sys.exit(2)
        rows = []
        for meta, vec in zip(pending_meta, vecs):
            file_path, src, line, anchor, text = meta
            rows.append((file_path, src, line, anchor, text, vec.tobytes()))
        cur.executemany(
            "INSERT INTO chunks(file,source,line,anchor,text,vec) VALUES (?,?,?,?,?,?)",
            rows,
        )
        total_chunks += len(rows)
        pending_texts = []
        pending_meta = []

    for i, fp in enumerate(todo, 1):
        try:
            text = fp.read_text(encoding="utf-8", errors="replace")
        except OSError as e:
            print(f"  skip {fp}: {e}", file=sys.stderr, flush=True)
            continue
        cur.execute("DELETE FROM chunks WHERE file=?", (str(fp),))
        cur.execute(
            "INSERT OR REPLACE INTO files(path,source,mtime) VALUES(?,?,?)",
            (str(fp), source, fp.stat().st_mtime),
        )
        for line, anchor, chunk in chunk_markdown(text):
            pending_texts.append(chunk)
            pending_meta.append((str(fp), source, line, anchor, chunk))
            if len(pending_texts) >= batch_size:
                flush()
        if i % 10 == 0 or i == len(todo):
            db.commit()
            elapsed = time.time() - t0
            rate = i / elapsed if elapsed > 0 else 0
            eta = (len(todo) - i) / rate if rate > 0 else 0
            pct = 100 * i / len(todo)
            print(
                f"  [{source}] {i}/{len(todo)} ({pct:5.1f}%) files "
                f"| {total_chunks} chunks | {elapsed:5.1f}s | "
                f"{rate:4.1f} f/s | ETA {eta:5.1f}s",
                file=sys.stderr,
                flush=True,
            )
    flush()
    db.commit()
    elapsed = time.time() - t0
    print(f"[{source}] done: {len(todo)} files, {total_chunks} chunks in {elapsed:.1f}s", file=sys.stderr)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--db", type=Path, default=DEFAULT_DB)
    p.add_argument(
        "--sources",
        default="nvimdocs,devdocs",
        help="comma-separated: nvimdocs,devdocs",
    )
    p.add_argument("--full", action="store_true", help="re-index all (ignore mtime)")
    p.add_argument("--limit", type=int, default=None, help="cap files per source (testing)")
    p.add_argument("--clear", action="store_true", help="wipe DB before indexing")
    p.add_argument(
        "--batch", type=int, default=BATCH,
        help=f"embeddings per HTTP call (default {BATCH}; bump to 128 if VRAM OK)",
    )
    args = p.parse_args()

    if args.clear and args.db.exists():
        args.db.unlink()
        print(f"removed {args.db}", file=sys.stderr)

    db = init_db(args.db)
    db.execute("PRAGMA foreign_keys=ON")

    for src in [s.strip() for s in args.sources.split(",") if s.strip()]:
        if src not in ("nvimdocs", "devdocs"):
            print(f"unknown source: {src}", file=sys.stderr)
            continue
        index_source(db, src, full=args.full, limit=args.limit, batch_size=args.batch)

    n = db.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
    print(f"\nDB: {args.db}\nTotal chunks: {n}", file=sys.stderr)
    db.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
