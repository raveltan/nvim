# nuxt-vue
> Nuxt 3/4 + Vue 3 SFC support: `vue_ls` + vtsls, `.nuxt/` codegen, dev-server debugging.

**Repo:** https://github.com/vuejs/language-tools (`@vue/language-server`)
**Local spec:** lua/nuxtdev/init.lua — wired from lua/plugins/lsp.lua, dap.lua, formatting.lua, treesitter.lua, test.lua
**Tags:** nuxt, vue, sfc, vtsls, vue_ls, typescript

## Scope
Everything for a `.vue` buffer outside GAF: LSP (both halves), highlighting, formatting, tailwind classes, vitest, and the three debug shapes a Nuxt bug can live in. Disabled wholesale under `GAF=1` — fl-gaf is Angular and has no `.vue` files.

## The two-server split
`@vue/language-server` v3 dropped takeover mode ([PR #5248](https://github.com/vuejs/language-tools/pull/5248)), so a working SFC needs both:

| Server | Owns | Wiring |
|---|---|---|
| `vue_ls` | `<template>`, `<style>`, directives, props | mason `vue-language-server`; rooted on `nuxt.config.*` → `vite.config.*` → `package.json` |
| `vtsls` | `<script>` | `vue` added to `filetypes` + `@vue/typescript-plugin` in `settings.vtsls.tsserver.globalPlugins` |

Notes:
- `vue_ls` forwards every TS request to the ts client on the same buffer and errors if there is none, so `vue` stays in vtsls's `filetypes` even before the mason package finishes installing.
- The plugin `location` points at the **mason** install, not the project's `node_modules`. `globalPlugins` is one global setting on a single vtsls instance serving every project in the session.
- `languages = { "vue" }` is required on top of `filetypes`: nvim picks the client by filetype, tsserver picks the plugin by language id.
- Diagnostics from the script block carry `source = "ts-plugin"` — that string is the fastest confirmation the plugin actually loaded.

## `.nuxt/` codegen
Auto-imports (`useFetch`, `useState`, `definePageMeta`), `#app`, `#imports` and the `~/` alias exist only in the generated `.nuxt/` that the app's tsconfig extends. Before the first `nuxi prepare` every one of them is `Cannot find name '…'`.

| Command | Action |
|---|---|
| `:NuxtPrepare` | `node node_modules/nuxt/bin/nuxt.mjs prepare` in the Nuxt root, async |
| `:NuxtDev` | dev server in a Snacks terminal float |

A one-shot warning fires per app root on the first `vue`/`ts`/`js` buffer when `.nuxt/tsconfig.json` (Nuxt 3) or `.nuxt/tsconfig.app.json` (Nuxt 4) is missing. It notifies rather than auto-running: `prepare` executes the app's own config and its modules' hooks.

## Everything else
- **Treesitter:** `vue` parser; it injects `css`/`typescript` into `<style>`/`<script>`, and `windwp/nvim-ts-autotag` already aliases `vue` upstream.
- **Formatting:** conform → `prettierd`/`prettier` (native SFC parser). `vue_ls`'s own formatter is disabled in `on_attach` to keep one owner.
- **Lint:** the `eslint` LSP ships `vue` in its default filetypes — nothing to add.
- **Tailwind:** `vue` added to `tailwindcss` filetypes.
- **Test:** neotest-vitest covers `*.{test,spec}.ts`; `.nuxt`/`.output` are excluded from the directory walk or every real test file gets a phantom duplicate.
- **Debug:** `vue` added to the pwa-node/pwa-chrome filetype loop, plus three Nuxt configs — SSR dev-server launch (`autoAttachChildProcesses`, nitro is a forked child), attach to `nuxi dev --inspect` on 9229 (`restart = true`, nitro restarts on config change), and Chrome on `localhost:3000`.

## Links
- [[lsp-vtsls]] — the TS half, source-action keymaps
- [[ts-nvim-treesitter]] — parser list
- [[format-conform]] — formatter resolution
- [[test-neotest-adapters]] — vitest adapter
- [[typescript-debug-coverage]] — pwa-node/pwa-chrome adapters
