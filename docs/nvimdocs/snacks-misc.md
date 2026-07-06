# snacks-misc
> Remaining enabled snacks modules — notifier, terminal, lazygit, statuscolumn, indent, bigfile, image, input, rename, quickfile, scope, scratch.

**Repo:** https://github.com/folke/snacks.nvim
**Local spec:** lua/plugins/snacks.lua:3, 21-33, 125-130
**Tags:** snacks notifier terminal lazygit statuscolumn indent image scratch

## Scope
Catch-all for the snacks modules that aren't the picker or dashboard. Most are toggled on with a single `enabled = true` — only `bigfile`, `indent`, and the projects-driven `image` need a real option. Three of these own keymaps (`lazygit`, `terminal`, `rename`, `scratch`); the rest are passive (notifier, statuscolumn, indent, bigfile, image, input, quickfile, scope).

## Install spec
```lua
image        = { enabled = true },
lazygit      = { enabled = true },
terminal     = { enabled = true },
indent       = { enabled = true, animate = { enabled = false } },
statuscolumn = { enabled = true },
input        = { enabled = true },
rename       = { enabled = true },
bigfile      = { enabled = true, size = 500 * 1024 },
notifier     = { enabled = true },
quickfile    = { enabled = true },
scope        = { enabled = true },
scratch      = { enabled = true },
-- explicitly OFF:
scroll       = { enabled = false },
words        = { enabled = false },
```

## Common customizations (per module)

### `notifier`
- `timeout` *(int, 3000)* — ms before fade.
- `style` *("compact"|"fancy"|"minimal")* — render template.
- `level` *(string, "TRACE")* — minimum log level shown.
- `top_down` *(bool, true)* — stack from top.
- `icons.{error,warn,info,debug,trace}` *(string)* — severity glyphs.
- `width` / `height` / `margin` / `padding` / `gap` — geometry.

Alternative: [ui-noice](ui-noice.md) also routes `vim.notify`; we use notifier for low-overhead toasts and let noice handle the cmdline.

### `terminal`
- `win` *(snacks.win.Config, `{style="terminal"}`)* — window style.
- `shell` *(string|string[])* — falls back to `&shell`.
- `start_insert`, `auto_insert`, `auto_close`, `interactive` *(bool)* — entry behaviour.
- `env` *(table)*, `cwd` *(string)*, `count` *(int)*.

### `lazygit`
- `configure` *(bool, true)* — auto-write a theme YAML matching the active colorscheme.
- `theme` *(table)* — per-element colour overrides (activeBorderColor, selectedLineBgColor, …).
- `theme_path` *(string)* — defaults to `stdpath('cache')`.
- `config` *(table)* — extra lazygit settings merged in; `editPreset = "nvim-remote"` for edit-from-lazygit.
- Functions: `Snacks.lazygit()`, `.log()`, `.log_file()`, `.open()`.

Related git tooling: [git-fugitive](git-fugitive.md).

### `statuscolumn`
- `left` *(string[], `{"mark","sign"}`)* — left-side components.
- `right` *(string[], `{"fold","git"}`)* — right-side components.
- `folds.open` *(bool, false)*, `folds.git_hl` *(bool, false)*.
- `git.patterns` *(string[])* — sign-name regexes treated as git (`GitSign`, `MiniDiffSign`).
- `refresh` *(int, 50)* — ms between redraws.

### `indent`
- `char` *(string, "│")* — guide glyph.
- `only_scope` / `only_current` *(bool)* — render scope-only / current-window only.
- `hl` *(string|string[])* — highlight group(s).
- `animate.enabled` *(bool, auto)* — **we set this `false`**.
- `animate.style` *("out"|"up_down"|"down"|"up")*, `animate.duration.{step,total}` *(ms)*.
- `scope.char` *(string)*, `scope.underline` *(bool)*, `scope.only_current` *(bool)*.
- `chunk.char.{corner_top,corner_bottom,horizontal,vertical,arrow}` — box-drawing scope frame.

### `bigfile`
- `size` *(int bytes, 1.5MB)* — **we set `500 * 1024` (500KB)**.
- `notify` *(bool, true)* — toast on detection.
- `line_length` *(int, 1000)* — average-line heuristic for minified files.
- `setup` *(function(ctx))* — called when triggered; default disables LSP, Treesitter, swap, undo.

### `image`
- `formats` *(string[])* — png/jpg/jpeg/gif/bmp/webp/tiff/heic/avif/mp4/mov/avi/mkv/webm/pdf/icns.
- `doc.inline` *(bool)* — render inline in buffer (requires unicode placeholder support: kitty, ghostty).
- `doc.float` *(bool)* — fallback floating window.
- `doc.max_width` / `doc.max_height` *(int, 80 / 40)*.
- `math.{latex,typst}` *(table)* — math preamble + font size.
- `convert.*` — ImageMagick density / mermaid pipeline.

Terminal requirement: kitty / ghostty / wezterm (limited) / tmux passthrough. **Zellij not supported**.

### `input`
- `icon` *(string, " ")*, `icon_hl` *(string)*.
- `prompt_pos` *("title"|"left"|false)* — prompt placement.
- `win` *(snacks.win.Config)* — border/size/position.
- `expand` *(bool, true)* — auto-grow with input.
- Functions: `Snacks.input.enable()`, `.disable()`.

### `rename`
- No real options — exposes two functions:
  - `Snacks.rename.rename_file({ from?, to?, on_rename? })` — prompt for new name if `to` omitted, fire LSP `workspace/willRenameFiles` + post-rename callbacks.
  - `Snacks.rename.on_rename_file(from, to, rename?)` — broadcast a rename to LSP clients.

### `quickfile`
- `exclude` *(string[], `{"latex"}`)* — treesitter langs to skip.
- Renders the file before deferred plugins load; transparent otherwise.

### `scope`
- `min_size` *(int, 2)* — minimum scope line count.
- `max_size` *(int|nil)* — expand toward this size if smaller.
- `cursor` *(bool)* — use cursor column to disambiguate scope.
- `treesitter.enabled` *(bool)*, `treesitter.blocks` *(string[])*, `treesitter.injections` *(bool)*.
- `edge` *(bool)* — include boundary lines.
- `siblings` *(bool)* — expand into single-line siblings.
- `filter` *(function(buf))*, `debounce` *(int ms)*.

### `scratch`
- `name` *(string)*, `ft` *(string|function)* — buffer display name / filetype.
- `root` *(string, `stdpath('data')/scratch`)* — persistence directory.
- `autowrite` *(bool)* — save on hide.
- `filekey.{cwd,branch,count}` *(bool)* — keys that disambiguate scratch files.
- `win_by_ft` *(table)* — per-filetype window config; e.g. `lua` binds `<CR>` to `Snacks.debug.run()`.
- Functions: `Snacks.scratch()` toggles, `Snacks.scratch.select()` picks among existing.

## Our config
- `bigfile.size = 500 * 1024` — disable heavy features at 500KB, well below the 1.5MB default; matches our typical generated-code / minified-JS threshold.
- `indent.animate.enabled = false` — animation conflicts with our relative-number redraws and feels janky on long jumps.
- `image.enabled = true` — kitty graphics protocol; works because primary terminal is kitty.
- All other enabled modules use upstream defaults.
- `scroll`, `words` are explicitly **off**: scroll smooth-animation is distracting; words LSP-reference highlights duplicate treesitter.

## Keymaps
| Key | Mode | Action | Desc |
|---|---|---|---|
| `<leader>gg` | n | `Snacks.lazygit()` | Lazygit |
| `<leader>fR` | n | `Snacks.rename.rename_file()` | Rename current file |
| `<leader>.` | n | `Snacks.scratch()` | Toggle scratch buffer |
| `<leader>fs` | n | `Snacks.scratch.select()` | Select scratch buffer |

`notifier`, `statuscolumn`, `indent`, `bigfile`, `image`, `input`, `quickfile`, `scope` have no keymaps — they augment editor behaviour passively.

## Links
- README: https://github.com/folke/snacks.nvim
- Per-module docs: `https://github.com/folke/snacks.nvim/blob/main/docs/<module>.md` (notifier, terminal, lazygit, statuscolumn, indent, bigfile, image, input, rename, quickfile, scope, scratch)
- Related: [snacks-core](snacks-core.md), [snacks-picker](snacks-picker.md), [snacks-dashboard](snacks-dashboard.md), [git-fugitive](git-fugitive.md), [ui-noice](ui-noice.md), [editor-which-key](editor-which-key.md)

## Notes
- `Snacks.rename.rename_file()` fires LSP `workspace/willRenameFiles` so language servers update imports automatically. For symbol renames in PHP we still use native `vim.lsp.buf.rename` (see auto-memory `nvim_php_rename.md`) due to the intelephense `$` sigil bug.
- The scratch directory is keyed by cwd/branch by default — switching git branches gives you a separate scratchpad per branch.
- The `terminal` module stays enabled because `Snacks.lazygit()` uses it internally, but it has no direct keybind — `<leader>/` now launches [seeker.nvim](nav-seeker.md) and tmux handles standalone terminals.
- `image` requires ImageMagick on `$PATH` for format conversion (PDF, mermaid, raster→png).
