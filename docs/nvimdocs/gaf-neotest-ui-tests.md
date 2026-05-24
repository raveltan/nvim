# gaf-neotest-ui-tests
> Neotest adapter for Freelancer webapp Karma UI tests (`ui-tests/src/*.spec.ts`).

**Local spec:** lua/gaf/neotest-ui-tests.lua:1-135
**Tags:** gaf neotest karma ui-tests angular webapp yarn

## Scope
Custom neotest adapter that runs Angular UI specs through the webapp's `yarn ui:<project>` Karma scripts. File-level only — Karma can't target individual `describe`/`it`, so positions are parsed but every result rolls up to file status. Supports `--mobile` and `--watch` flags via `extra_args`.

## Public API
Standard neotest.Adapter interface:
- `name = "neotest-ui-tests"`
- `is_test_file(file_path)` — true iff path matches `ui-tests/src/.+%.spec%.ts$`.
- `root(path)` — for ui-tests paths, walks upward finding a `package.json` containing `"ui:main"` (the GAF webapp root marker).
- `filter_dir(name)` — skips `node_modules`, `dist`, `.angular`.
- `discover_positions(path)` — treesitter-based.
- `build_spec(args)` — extracts `projects/<project>/ui-tests/src/` from the path, builds:
  ```
  cd <webapp_root> && SPECS="<file>.spec.ts" yarn ui:<project>[:mobile][:watch:instant] 2>&1 | tee <tmp>
  ```
- `results(spec, result, tree)` — file pass/fail propagated to every position in the tree.

## Keymaps
Not bound here. The adapter is run via the standard neotest keys (`<leader>tr`, `<leader>tf`). GAF adds (via `gaf.test.setup_autocmds`):

| Key | Mode | Action | Desc |
|-----|------|--------|------|
| `<leader>tm` | n (ui-tests buf) | `neotest.run.run({extra_args={"--mobile"}})` | Mobile project (`yarn ui:<p>:mobile`) |
| `<leader>tw` | n (ui-tests buf) | `neotest.run.run({extra_args={"--watch"}})` | Watch instant (`yarn ui:<p>:watch:instant`) |

## GAF integration
Prepended to `opts.adapters` in `gaf.test.extend`. Jest and Vitest adapter configs both exclude `ui-tests/src/*.spec.ts`, so this is the only adapter that claims those files.

`find_webapp_root` is GAF-specific — it requires a `package.json` containing `"ui:main"` (the canonical script name in the freelancer webapp). Generic Angular workspaces will not match.

`build_spec`'s project extraction (`projects/([^/]+)/ui%-tests/src/`) maps directly to the Nx-style monorepo layout at `webapp/projects/<project>/ui-tests/src/`.

## Links
- Related: [gaf-test](gaf-test.md), [test-neotest](test-neotest.md), [gaf-ui-test](gaf-ui-test.md)

## Notes
- The command uses `tee` + `exit ${PIPESTATUS[0]}` because `yarn`/Karma exit status must propagate through the pipe for neotest to mark failures.
- `discover_positions` passes empty query `""` — relies on treesitter providing structural positions; without an `it`/`describe` query, only the file node is meaningful for status reporting (which matches the file-level limitation).
- `results_path` tempfile is cleaned up after results parsing — but neotest already has `result.output`, so the tee file is redundant for now (kept for future per-test parsing).
- A separate, overseer-based runner at `gaf.ui_test` covers ad-hoc `yarn ui:*` task running outside neotest.
