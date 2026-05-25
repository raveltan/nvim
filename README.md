# Neovim Configuration

Modular, LSP-first Neovim built on [lazy.nvim](https://github.com/folke/lazy.nvim). Polyglot: TypeScript, PHP, Ruby on Rails, Python, Rust, Flutter. Opt-in GAF profile (`GAF=1 nvim`).

## Install

```sh
git clone git@github.com:raveltan/nvim.git ~/.config/nvim
nvim
```

## Docs

- [`docs/nvimdocs/INDEX.md`](docs/nvimdocs/INDEX.md) — every plugin / module, grouped
- [`docs/keybinds.md`](docs/keybinds.md) — keybind cheatsheet
- [`docs/obsidian.md`](docs/obsidian.md) — Obsidian note-taking workflow guide
- [`docs/nvimdocs/config-init.md`](docs/nvimdocs/config-init.md) — bootstrap order
- [`docs/nvimdocs/gaf-overview.md`](docs/nvimdocs/gaf-overview.md) — GAF profile

## Semantic search (`<leader>kx*`)

Local embedding-based search across `docs/nvimdocs/` and installed devdocs. Backed by [LM Studio](https://lmstudio.ai) (OpenAI-compatible local server). DB lives at `~/.ravelnvim.db` (outside this repo).

### One-time setup

1. **LM Studio** — install, then download these models from the Discover tab:
   - Embedder: `Qwen/Qwen3-Embedding-0.6B-GGUF` (Q8_0, ~600MB VRAM)
   - Reranker (optional, not yet wired): `BAAI/bge-reranker-v2-m3-GGUF`
2. **Load + serve** — open Developer tab, load `qwen3-embedding-0.6b`, start the server (default `http://localhost:1234`). Verify:
   ```sh
   curl -s http://localhost:1234/v1/models | grep qwen3-embedding
   ```
3. **Python venv** (one-shot, installs numpy):
   ```sh
   bash ~/.config/nvim/scripts/semantic/setup.sh
   ```
4. **Build the index** — inside nvim:
   ```
   :SemanticIndex            " incremental, both sources
   :SemanticIndex nvimdocs   " just local docs
   :SemanticIndexFull        " force re-embed everything
   ```
   First full index of devdocs can take a while (≈50ms per chunk × thousands).

### Keymaps

| Key            | Action                                       |
|----------------|----------------------------------------------|
| `<leader>kxx`  | Search nvimdocs + devdocs                    |
| `<leader>kxn`  | Search nvimdocs only                         |
| `<leader>kxd`  | Search devdocs only                          |
| `<leader>kxr`  | Rebuild (incremental) — terminal split, live progress |
| `<leader>kxR`  | Rebuild (full) — terminal split, live progress        |
| `<leader>kxb`  | Rebuild (incremental) — background, notify only       |

Progress line example:
```
[devdocs]  120/22349 (  0.5%) files | 980 chunks |  62.3s | 1.9 f/s | ETA 11697.6s
```
Terminal split is the default — `botright 15split | terminal …`. Close with `:q` when done. Background mode (`kxb`) streams the same progress to `vim.notify` and stays out of the way.

### How it works

- **Model:** `Qwen3-Embedding-0.6B`, 1024-dim, 32K context. Instruction-prefixed queries (`Instruct: …\nQuery: …`) for asymmetric retrieval.
- **Storage:** SQLite at `~/.ravelnvim.db`. Float32 blobs, L2-normalised at index time → cosine = single matmul at query time. Add `~/.ravelnvim.db` is outside the repo; nothing to gitignore.
- **Chunking:** markdown split per header (H1–H6), 40–2000 chars per chunk, oversize sections sliced with overlap.
- **Pipeline:** query embed (LM Studio, ~50ms) → cosine over all rows (numpy, ~50ms / 10k chunks) → top-30 → Snacks picker with semantic order preserved.
- **No reranker yet:** LM Studio does not expose `/v1/rerank`. Skipping is fine for this corpus; add a Python sentence-transformers sidecar if quality plateaus.

### Files

- `scripts/semantic/index.py` — indexer
- `scripts/semantic/query.py` — query CLI (returns JSONL)
- `scripts/semantic/setup.sh` — venv bootstrap
- `lua/semantic/init.lua` — picker + commands
- `lua/plugins/semantic.lua` — lazy spec + keymaps

## Layout

- `init.lua` — entry
- `lua/config/` — options, lazy, keymaps, autocmds
- `lua/plugins/` — plugin specs (auto-imported)
- `lua/gaf/` — GAF profile modules (gated on `vim.g.gaf`)
- `lua/overseer/template/user/` — task templates
- `after/ftplugin/` — per-filetype tweaks
- `snippets/` — LuaSnip JSON
- `scripts/` — shell helpers
- `docs/` — see [INDEX](docs/nvimdocs/INDEX.md)
