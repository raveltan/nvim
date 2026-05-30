# webconnect

A tiny Go bridge between the **Chrome DevTools Protocol (CDP)** and an editor.
**Phase 1: the console.** It attaches to a running Chrome tab, streams console
output, and evaluates JavaScript — talking to the editor over newline-delimited
JSON (NDJSON) on stdin/stdout.

```
Chrome --remote-debugging-port=9222
   │  CDP over WebSocket (Runtime domain)
   ▼
webconnect (Go)  ── NDJSON over stdin/stdout ──►  Neovim (lua/util/webconsole.lua)
```

Only dependency: [`gorilla/websocket`](https://github.com/gorilla/websocket) for
the transport. The CDP layer is hand-written but thin (plain JSON).

## Build

```sh
cd webconnect
go build -o webconnect .
```

(or run `:ChromeConsoleBuild` inside Neovim)

## Start Chrome with the debugger open

```sh
# macOS
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9222

# any Chromium
chromium --remote-debugging-port=9222
```

> The debug port is **localhost-only** and unauthenticated — anyone who can
> reach the port can run JS in your browser. Keep it on `127.0.0.1`.

## Use it standalone

List attachable targets (tabs/pages):

```sh
./webconnect -port 9222 -list
```

Attach and drive it. It reads commands on stdin, emits events on stdout:

```sh
./webconnect -port 9222
# then type (or pipe) NDJSON commands:
{"id":1,"op":"eval","expr":"document.title"}
{"id":2,"op":"eval","expr":"1 + 2 * 3"}
{"op":"reload"}
{"op":"quit"}
```

### Flags

| flag      | default     | meaning                                            |
|-----------|-------------|----------------------------------------------------|
| `-host`   | `127.0.0.1` | Chrome debug host                                  |
| `-port`   | `9222`      | Chrome remote debugging port                       |
| `-filter` | `""`        | attach to first page whose URL/title contains this |
| `-list`   | `false`     | print targets as JSON and exit                     |

## Protocol

### Commands (editor → webconnect), one JSON object per line

| op         | fields              | effect                                          |
|------------|---------------------|-------------------------------------------------|
| `eval`     | `id`, `expr`        | evaluate JS, reply with `result` (a `uiNode`)   |
| `getprops` | `reqid`, `objectId` | fetch an object's properties, reply with `props`|
| `reload`   | —                   | `Page.reload` (ignore cache)                    |
| `navigate` | `url`               | `Page.navigate`                                 |
| `quit`     | —                   | disconnect and exit                             |

A **`uiNode`** is `{name?, text, type, subtype?, objectId?, expandable}` — a
one-line label plus enough to lazily expand it. Send `getprops` with its
`objectId` to fetch children (themselves `uiNode`s).

### Events (webconnect → editor), one JSON object per line

```jsonc
{"type":"ready","target":"<url>","title":"..."}
{"type":"console","level":"log","text":"boot","args":[{"text":"Object","type":"object","objectId":"1.2","expandable":true}],"url":"app.js","line":42}
{"type":"exception","text":"TypeError: ..."}
{"type":"result","id":1,"ok":true,"node":{"text":"Array(3)","type":"object","subtype":"array","objectId":"1.5","expandable":true}}
{"type":"result","id":1,"ok":false,"error":"ReferenceError: x is not defined"}
{"type":"props","reqid":1,"ok":true,"children":[{"name":"length","text":"3","type":"number","expandable":false}]}
{"type":"error","text":"connector-level problem"}
{"type":"closed"}
```

`console.level` is the CDP type: `log`, `info`, `warning`, `error`, `debug`, …
For `console`, primitive args go into `text`; object/function args become
expandable `args` nodes.

## Notes & limits

- On attach, Chrome **replays its buffered console history** for the tab, so you
  may see a burst of old messages first.
- Objects keep their `objectId` and are expanded lazily via `getprops`
  (`Runtime.getProperties`, own properties, capped at 300). objectIds expire on
  navigation; this prototype does not call `releaseObject`.
- Accessor (getter) properties show as `(...)` and are not invoked.
- Single tab per process; pick it with `-filter`.

## Panels (phase 3): Network & Storage

These share the **same** Chrome connection as the console (one `webconnect`
process). Domains are enabled lazily when a panel opens.

Extra commands:

| op              | fields                     | effect                                       |
|-----------------|----------------------------|----------------------------------------------|
| `enable`        | `domain`                   | `network` or `dom_storage` (lazy enable)     |
| `net_body`      | `reqid`, `requestId`       | `Network.getResponseBody` → `net_body` event |
| `storage_get`   | `kind`                     | `local`/`session`/`cookies` → items/cookies  |
| `storage_set`   | `kind`,`key`,`value`       | `DOMStorage.setDOMStorageItem`               |
| `storage_remove`| `kind`,`key`               | `DOMStorage.removeDOMStorageItem`            |
| `storage_clear` | `kind`                     | `DOMStorage.clear`                           |
| `cookie_delete` | `name`,`url`               | `Network.deleteCookies`                      |

Extra events: `net_request` → `net_response` → `net_done` / `net_failed`;
`net_body`; `storage_items` (`{kind,items:[[k,v]]}`); `cookies`; `storage_error`.

Network notes:
- Filtering is **client-side** (CDP has no server-side type/url filter).
- Row size = `loadingFinished.encodedDataLength`; duration =
  `loadingFinished.ts − requestWillBeSent.ts`.
- Bodies are fetched lazily on row-select (only valid after `loadingFinished`;
  may be evicted).

Storage notes:
- DOMStorage `storageId` uses a **storageKey** (`Storage.getStorageKeyForFrame`);
  modern Chrome rejects the older `securityOrigin` form.
- Cookies via `Network.getCookies(urls)` (page-scoped); read + add + edit +
  delete (`Network.setCookie` / `deleteCookies`).
- Scopes: localStorage · sessionStorage · cookies · **IndexedDB** · **Cache
  Storage**. IndexedDB (db → object store → first 50 entries) and Cache Storage
  (cache → cached request URLs) are read-only snapshots rendered as JSON trees.

## Neovim integration

The Lua side is split into a shared core + per-panel modules:

| module                       | role                                              |
|------------------------------|---------------------------------------------------|
| `lua/util/webclient.lua`     | owns the process, stdout parsing, event registry, launch/build, screenshots |
| `lua/util/webconsole.lua`    | console REPL (readonly log + input, lazy object trees) |
| `lua/util/webnetwork.lua`    | network panel (master left / detail right, filter bar) |
| `lua/util/webstorage.lua`    | storage panel (scopes left / key-value right)     |
| `lua/util/webdom.lua`        | DOM inspect panel (outerHTML + computed styles)   |
| `lua/util/webemulate.lua`    | device / user-agent / throttle emulation          |
| `lua/util/webhelp.lua`       | `<leader>j?` cheat-sheet + live connection status |

Commands / maps (group `<leader>j…`):

| map / command                  | action                          |
|--------------------------------|---------------------------------|
| `<leader>jl` `:ChromeLaunch`   | boot debug Chrome + connect     |
| `<leader>jc` `:ChromeConsole`  | console REPL                    |
| `<leader>je` / `jp`            | eval line/selection / prompt    |
| `<leader>jg` `:ChromeNavigate` | navigate the tab to a URL       |
| `<leader>jx` `:ChromeClear`    | clear the console               |
| `<leader>jr` `:ChromeReload`   | reload page                     |
| `<leader>jn` `:ChromeNetwork`  | network panel                   |
| `<leader>js` `:ChromeStorage`  | storage panel                   |
| `<leader>ji` `:ChromeInspect`  | inspect a DOM element (selector) |
| `:ChromeDom`                   | toggle the DOM inspect panel    |
| `<leader>jt` `:ChromeTabs`     | pick which tab to attach to     |
| `<leader>jq`                   | disconnect                      |
| `<leader>jk` `:ChromeKill`     | kill stale debug port + lock    |
| `<leader>jP` `:ChromeShot[!]`  | screenshot viewport (`!`=full page) |
| `<leader>j?`                   | cheat-sheet + connection status |
| `:ChromeRelaunch[!]`           | kill port then launch (`!`=fresh profile) |

**Emulate subgroup** (`<leader>jd…`):

| map / command                       | action                     |
|-------------------------------------|----------------------------|
| `<leader>jdd` `:ChromeDevice`       | emulate device / responsive |
| `<leader>jdu` `:ChromeUserAgent`    | override user agent        |
| `<leader>jdw` `:ChromeThrottle`     | throttle network / CPU     |
| `<leader>jdr` `:ChromeEmulateReset` | reset all emulation        |
| `<leader>jdo`                       | rotate orientation         |

**Emulation** (vim.ui.select pickers, applied via CDP `Emulation.*`):
- `:ChromeDevice` — presets (iPhone/Pixel/iPad/desktop) set metrics + scale +
  touch + UA; "Responsive (custom)" prompts W×H; "Reset" clears.
- `:ChromeUserAgent` — preset/custom UA (`Network.setUserAgentOverride`); reset
  restores the browser default.
- `:ChromeThrottle` — network presets (Offline / Slow-Fast 3G / Slow 4G / none,
  via `Network.emulateNetworkConditions`) and CPU slowdown (`setCPUThrottlingRate`).

**Attached to the wrong tab?** (storage/network look empty) Run `:ChromeTabs`
(`<leader>jt`) to list page targets and re-attach — open panels refetch.

If a launch fails because a stale Chrome still holds the port, run
`:ChromeKill` (frees the port via `lsof`/`pkill` + clears the profile's
`SingletonLock`), or `:ChromeRelaunch` to kill-then-launch in one step.

The Console, Network and Storage panels each open **fullscreen in their own
tab** and are **toggled** by their map/command (`<leader>jc` / `<leader>jn` /
`<leader>js`) — one keypress opens, the next closes both windows at once.
Buffers and state persist across toggles (console history, request list, storage
all kept; `q` also closes). Every panel binds `?` for its own cheat-sheet, and
`<leader>j?` opens a global cheat-sheet that also shows the live connection /
emulation status. Panels **auto-clear and refetch on page navigation** so a
reload or in-page nav never leaves stale rows or object trees behind.

Console panel keys: `<CR>`/`<Tab>` expand a tree node · `Y` yank the value under
the cursor · `?` help. In the input line, `<CR>` evals and `<C-p>`/`<C-n>` walk
the eval history.

Network panel keys: `/` URL filter · `F` cycle status-class filter
(All → errors → 4xx → 5xx) · number keys `1`–`0` toggle type filters (`1`=All,
shown in the winbar — `hjkl` stay free) · `<CR>` select · `gd` detail ·
`yy` yank URL · `yc` **copy as curl** · `yr` yank response body · `yp` yank
payload · `b`/`B` block / unblock the URL pattern · `H` export a **HAR** file ·
`E` expand-all in the detail tree · `X` clear · `?` help · `q` close.
Detail/Response JSON expands with `<CR>`/`<Tab>`. Request Payload is parsed as
JSON **or** `application/x-www-form-urlencoded` (URL-decoded into key/value,
e.g. `user: joko@gmail.com`).

Storage panel keys: `<CR>` expand a JSON value / yank · `e` edit · `d` delete ·
`a` add · `C` clear · `R` refresh · `/` filter by key/name · `yk` yank the key ·
`?` help · `q` close. Cookies support `e`/`d`/`a` too.

DOM inspect panel keys (`<leader>ji` / `:ChromeInspect`): `i` (re)inspect a
selector · `?` help · `q` close. It shows the element's outerHTML plus its
computed styles.

Screenshots: `<leader>jP` (or `:ChromeShot`) captures the viewport;
`:ChromeShot!` captures the **full page**. The PNG path is reported via
`vim.notify`.

Quick start: `:ChromeConsoleBuild`, then `:ChromeLaunch` — or `<leader>jl`.
