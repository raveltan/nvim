# gaf-keymaps
> Phabricator task/diff URL opener — `gx` on `D####` / `T####` tokens.

**Local file:** lua/gaf/keymaps.lua
**Tags:** gaf freelancer phabricator gx url-opener keymap

## Scope

Tiny helper that detects Phabricator object monograms (`D####` for diffs, `T####` for tasks) under the cursor and opens the corresponding Phabricator URL. It's invoked from the global `gx` keymap in `lua/config/keymaps.lua` before the normal `vim.ui.open(<cfile>)` fallback, so plain URL / file behaviour still works when the cursor isn't on a Phab token.

## How it loads

Lazy-required on every `gx` press from `lua/config/keymaps.lua`:

```lua
map("n", "gx", function()
  if vim.g.gaf and require("gaf.keymaps").open_phab_under_cursor() then return end
  local cfile = vim.fn.expand("<cfile>")
  if cfile ~= "" then vim.ui.open(cfile) end
end, { desc = "Open URL/file under cursor" })
```

Gated on `vim.g.gaf` — without `GAF=1`, the helper is never required. Returns `true` if it handled the cursor, `false` to fall through.

## Public API

- `M.open_phab_under_cursor()` — scans current line for `[DT]%d+` patterns, opens `https://phabricator.tools.flnltd.com/<TOKEN>` via `vim.ui.open` if one straddles the cursor column. Falls back to `<cword>` if no inline match. Returns `true` when it opened a URL, `false` otherwise.

Detection strategy (two-pass):
1. **Line scan** — `line:find("([DT]%d+)", init)` loop, picks the match where `col >= s and col <= e`. Handles tokens embedded in prose (`fixes T12345 from D67890`).
2. **`<cword>` fallback** — `cword:match("^[DT]%d+$")` — handles cases where the cursor is on isolated whitespace adjacent to the token.

## Keymaps / Commands

| Key/Cmd | Mode | Action | Desc |
|---|---|---|---|
| `gx` | n | `open_phab_under_cursor()` → fallback `vim.ui.open(<cfile>)` | GAF profile only — Phab-aware URL opener |

## Workflow examples

```text
Cursor on  →  Opens
  T12345       https://phabricator.tools.flnltd.com/T12345
  D98765       https://phabricator.tools.flnltd.com/D98765
  https://...  (falls through to vim.ui.open <cfile>)
  /etc/hosts   (falls through to vim.ui.open <cfile>)
```

Common scenario: commit message review — cursor on `Differential Revision: D12345`, press `gx`, browser opens the diff.

## Links

- [gaf-overview](gaf-overview.md) — profile bootstrap
- Wiring point: `lua/config/keymaps.lua` around `map("n", "gx", ...)`

## Notes

- URL base is hard-coded: `https://phabricator.tools.flnltd.com/`.
- `vim.ui.open` honours macOS / Linux open handlers — no extra config needed.
- Pattern is case-sensitive: `t12345` (lowercase) is **not** matched, intentionally — Phabricator monograms are always capital.
- Only `D` (Differential) and `T` (Maniphest task) are wired. Add more (`P` for paste, `F` for files) by extending the `[DT]` character class.
