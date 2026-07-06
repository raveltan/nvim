# ui-duck
> Spawns wandering animal emojis (ducks by default) that aimlessly walk around the buffer for fun.

**Repo:** https://github.com/tamton-aquib/duck.nvim
**Local spec:** lua/plugins/ui.lua:255
**Tags:** ui, fun, easter-egg

## Scope
Pure novelty plugin. `hatch()` spawns a floating-window critter that moves on a timer; `cook()` removes one; `cook_all()` removes them all. We bind the `<leader>ud*` family for hatch/cook variants and temporarily clear `winborder` so the duck floats render without a rounded frame (which would otherwise inherit our global `winborder = "rounded"`).

## Install spec
```lua
{
  "tamton-aquib/duck.nvim",
  cmd = { "DuckHatch", "DuckCook", "DuckKill", "DuckCookAll", "DuckKillAll" },
  keys = {
    { "<leader>udd", function() ... require("duck").hatch() ... end, desc = "Hatch duck" },
    { "<leader>udk", function() require("duck").cook() end,           desc = "Cook one duck" },
    { "<leader>uda", function() ... require("duck").hatch("🦆", 10) ... end, desc = "Hatch fast duck" },
    { "<leader>udK", function() require("duck").cook_all() end,       desc = "Cook all ducks" },
  },
}
```

## Common customizations
- `hatch(character, speed, custom_winopts)` — first arg is the glyph (default `"🦆"`, also `"🐈"`, `"🐤"`, `"🐦"`, `"🦀"`, etc.), second is move-interval ms (default `5`; lower = faster).
- `cook()` — removes the duck closest to the cursor.
- `cook_all()` / `kill_all()` — removes every duck.
- No setup() function; the plugin uses module-level state.
- Speed values: `10` is "fast" in our config, the upstream default `5` is faster, and `1` is hyperactive. Higher numbers slow it down (it's a polling interval).

WebFetch https://raw.githubusercontent.com/tamton-aquib/duck.nvim/HEAD/README.md if needed.

## Our config
- Lazy-loaded by `cmd` and `keys` only — zero startup cost.
- `<leader>udd` / `<leader>uda` save and restore `vim.o.winborder` around the `hatch()` call. We set `winborder = "rounded"` globally for floats; ducks look wrong inside a bordered float, so we flip it to `"none"` for the spawn and restore immediately. Cook variants don't touch `winborder`.
- `<leader>uda` uses speed `10` for a noticeably faster duck (use sparingly).

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>udd` | n | hatch with default glyph, borderless | Hatch duck |
| `<leader>udk` | n | `require("duck").cook()` | Cook one duck |
| `<leader>uda` | n | `hatch("🦆", 10)` borderless | Hatch fast duck |
| `<leader>udK` | n | `cook_all()` | Cook all ducks |

## Links
- README: https://github.com/tamton-aquib/duck.nvim/blob/main/README.md
- Source: https://github.com/tamton-aquib/duck.nvim/blob/main/lua/duck.lua

## Notes
- The wrapper functions for `udd`/`uda` save `vim.o.winborder` to a local `p` before mutating the global option, but there's a race: if another plugin reads `winborder` during the same tick it sees `"none"`. Negligible in practice.
- Multiple ducks can coexist; each runs its own timer.
- Floats are excluded from `satellite.nvim` because `noice`/`Trouble` etc. are listed but `duck` is not — ducks roam over the scrollbar without conflict since their windows are tiny.
