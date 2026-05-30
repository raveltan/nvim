-- webemulate: device emulation, user-agent override, and throttling.
-- Consumer of util.webclient. Actions (no panel) driven by vim.ui.select.

local client = require("util.webclient")

local M = {}

local IPHONE_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"
local ANDROID_UA = "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
local IPAD_UA = "Mozilla/5.0 (iPad; CPU OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"

local DEVICES = {
  { name = "Responsive (custom)", custom = true },
  { name = "iPhone SE", w = 375, h = 667, scale = 2, mobile = true, touch = true, ua = IPHONE_UA },
  { name = "iPhone 14 Pro Max", w = 430, h = 932, scale = 3, mobile = true, touch = true, ua = IPHONE_UA },
  { name = "Pixel 7", w = 412, h = 915, scale = 2.625, mobile = true, touch = true, ua = ANDROID_UA },
  { name = "Galaxy S20", w = 360, h = 800, scale = 3, mobile = true, touch = true, ua = ANDROID_UA },
  { name = "iPad Air", w = 820, h = 1180, scale = 2, mobile = true, touch = true, ua = IPAD_UA },
  { name = "Desktop 1280x800", w = 1280, h = 800, scale = 1, mobile = false, touch = false },
  { name = "Desktop 1920x1080", w = 1920, h = 1080, scale = 1, mobile = false, touch = false },
  { name = "Reset (no override)", reset = true },
}

local UAS = {
  { name = "Chrome (Windows)", ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" },
  { name = "Safari (macOS)", ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15" },
  { name = "Firefox (Windows)", ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0" },
  { name = "iPhone Safari", ua = IPHONE_UA },
  { name = "Android Chrome", ua = ANDROID_UA },
  { name = "Googlebot", ua = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" },
  { name = "Custom…", custom = true },
  { name = "Reset (default)", reset = true },
}

-- network presets (throughput in bytes/sec; -1 = unlimited) + CPU multipliers
local THROTTLE = {
  { name = "No throttling", setNet = true, offline = false, latency = 0, down = -1, up = -1 },
  { name = "Offline", setNet = true, offline = true, latency = 0, down = 0, up = 0 },
  { name = "Slow 3G", setNet = true, latency = 400, down = 50000, up = 50000 },
  { name = "Fast 3G", setNet = true, latency = 150, down = 180000, up = 84375 },
  { name = "Slow 4G", setNet = true, latency = 80, down = 350000, up = 150000 },
  { name = "CPU: 4x slowdown", cpu = 4 },
  { name = "CPU: 6x slowdown", cpu = 6 },
  { name = "CPU: no slowdown", cpu = 1 },
}

-- the no-throttle preset, used by reset_all and to clear the throttle field.
local NO_THROTTLE = THROTTLE[1]

-- ── module-local active emulation state ────────────────────────────────────
-- `current.device`/`ua`/`throttle` hold human labels for status/pickers.
-- `current.dev` keeps the full device spec (w/h/scale/...) so we can rotate
-- and re-apply on reconnect/navigation. `current.ua_str` keeps the raw UA
-- string for re-apply. `current.thr` keeps the throttle command for re-apply.
local current = {
  device = nil,
  ua = nil,
  throttle = nil,
  dev = nil, -- { w, h, scale, mobile, touch, ua }
  ua_str = nil,
  thr = nil, -- the throttle command table (sans op)
}

-- guard: true while we are re-applying cached state, so the emulation acks the
-- re-apply triggers don't loop us back into another re-apply.
local reapplying = false

local registered = false
local function register()
  if registered then
    return
  end
  registered = true

  -- the bridge acks each emulation op; we render the notify label Lua-side from
  -- `current` (richer than the bridge's raw WxH / "ok" label).
  client.on("emulation", function(ev)
    local what = ev.what or "emulation"
    local label
    if what == "device" then
      label = current.device or "reset"
    elseif what == "useragent" then
      label = current.ua or "reset"
    elseif what == "throttle" then
      label = current.throttle or "ok"
    else
      label = ev.label or "ok"
    end
    vim.notify("chrome " .. what .. ": " .. label)
  end)

  -- re-apply cached emulation after a tab re-pick / bridge restart / navigation,
  -- so emulation isn't silently lost. Guarded against re-entrancy loops.
  client.on("ready", function()
    M._reapply()
  end)
  client.on("navigated", function()
    M._reapply()
  end)
end

local function name_of(x)
  return x.name
end

-- format_item that marks the active item with a leading "● ".
local function marker(active_label)
  return function(x)
    if active_label and x.name == active_label then
      return "● " .. x.name
    end
    return "  " .. x.name
  end
end

-- "Prompt [active: Foo]:" — surfaces the current selection in the picker prompt.
local function prompt_with(base, active_label)
  if active_label and active_label ~= "" then
    return base .. " [active: " .. active_label .. "]:"
  end
  return base .. ":"
end

-- ── status (used by help/winbar) ───────────────────────────────────────────
-- short one-line summary of active emulation, or "" when nothing is active.
function M.status()
  local parts = {}
  if current.device then
    parts[#parts + 1] = current.device
  end
  if current.ua then
    parts[#parts + 1] = "UA:" .. current.ua
  end
  if current.throttle then
    parts[#parts + 1] = "Net:" .. current.throttle
  end
  return table.concat(parts, " · ")
end

-- ── senders (also update `current`) ────────────────────────────────────────

-- send a device override and remember the applied spec + label.
local function apply_device(spec, label)
  current.dev = {
    w = spec.w,
    h = spec.h,
    scale = spec.scale,
    mobile = spec.mobile,
    touch = spec.touch,
    ua = spec.ua,
  }
  current.device = label
  client.send({
    op = "device",
    width = spec.w,
    height = spec.h,
    scale = spec.scale,
    mobile = spec.mobile,
    touch = spec.touch,
    ua = spec.ua,
  })
end

local function reset_device()
  current.device = nil
  current.dev = nil
  client.send({ op = "device", reset = true })
end

local function apply_ua(ua_str, label)
  current.ua = label
  current.ua_str = ua_str
  client.send({ op = "useragent", ua = ua_str })
end

local function reset_ua()
  current.ua = nil
  current.ua_str = nil
  client.send({ op = "useragent", reset = true })
end

-- build a throttle command table (without op) from a preset.
local function throttle_cmd(preset)
  local cmd = {}
  if preset.setNet then
    cmd.setNet = true
    cmd.offline = preset.offline or false
    cmd.latency = preset.latency or 0
    cmd.down = preset.down or -1
    cmd.up = preset.up or -1
  end
  if preset.cpu then
    cmd.cpu = preset.cpu
  end
  return cmd
end

local function apply_throttle(preset)
  local cmd = throttle_cmd(preset)
  current.thr = cmd
  -- "No throttling" means nothing active: clear the field rather than label it.
  if preset == NO_THROTTLE or preset.name == NO_THROTTLE.name then
    current.throttle = nil
    current.thr = nil
  else
    current.throttle = preset.name
  end
  cmd.op = "throttle"
  client.send(cmd)
end

-- ── public actions ─────────────────────────────────────────────────────────

function M.device()
  register()
  client.ensure(function()
    vim.ui.select(DEVICES, {
      prompt = prompt_with("Emulate device", current.device),
      format_item = marker(current.device),
    }, function(d)
      if not d then
        return
      end
      if d.reset then
        reset_device()
      elseif d.custom then
        -- single WxH prompt (e.g. "390x844"); blank falls back to the two-prompt
        -- flow. Both paths validate numerics.
        vim.ui.input({ prompt = "size WxH (e.g. 390x844, blank for separate): " }, function(wh)
          if wh == nil then
            return
          end
          local cw, ch = wh:match("^%s*(%d+)%s*[xX]%s*(%d+)%s*$")
          if cw and ch then
            apply_device(
              { w = tonumber(cw), h = tonumber(ch), scale = 1, mobile = true, touch = true },
              "Custom " .. cw .. "x" .. ch
            )
            return
          end
          if wh ~= "" then
            vim.notify("emulate: invalid size '" .. wh .. "' (use WxH)", vim.log.levels.WARN)
            return
          end
          -- blank: fall back to two separate prompts.
          vim.ui.input({ prompt = "width: ", default = "390" }, function(ws)
            if not ws then
              return
            end
            local w = tonumber(ws)
            if not w then
              vim.notify("emulate: invalid width '" .. ws .. "'", vim.log.levels.WARN)
              return
            end
            vim.ui.input({ prompt = "height: ", default = "844" }, function(hs)
              if not hs then
                return
              end
              local h = tonumber(hs)
              if not h then
                vim.notify("emulate: invalid height '" .. hs .. "'", vim.log.levels.WARN)
                return
              end
              apply_device(
                { w = w, h = h, scale = 1, mobile = true, touch = true },
                "Custom " .. w .. "x" .. h
              )
            end)
          end)
        end)
      else
        apply_device(d, d.name)
      end
    end)
  end)
end

function M.user_agent()
  register()
  client.ensure(function()
    vim.ui.select(UAS, {
      prompt = prompt_with("User agent", current.ua),
      format_item = marker(current.ua),
    }, function(u)
      if not u then
        return
      end
      if u.reset then
        reset_ua()
      elseif u.custom then
        vim.ui.input({ prompt = "UA string: " }, function(s)
          if s and s ~= "" then
            apply_ua(s, "Custom")
          end
        end)
      else
        apply_ua(u.ua, u.name)
      end
    end)
  end)
end

function M.throttle()
  register()
  client.ensure(function()
    vim.ui.select(THROTTLE, {
      prompt = prompt_with("Throttle", current.throttle),
      format_item = marker(current.throttle),
    }, function(n)
      if not n then
        return
      end
      apply_throttle(n)
    end)
  end)
end

-- reset device + UA + throttle in one call, then clear `current`.
function M.reset_all()
  register()
  client.ensure(function()
    reset_device()
    reset_ua()
    apply_throttle(NO_THROTTLE)
    current.device, current.ua, current.throttle = nil, nil, nil
    current.dev, current.ua_str, current.thr = nil, nil, nil
    vim.notify("emulation reset")
  end)
end

-- swap the active device's width/height and re-apply.
function M.rotate()
  register()
  local d = current.dev
  if not d or not d.w or not d.h then
    vim.notify("emulate: no device to rotate", vim.log.levels.WARN)
    return
  end
  client.ensure(function()
    local label = current.device or "device"
    apply_device(
      { w = d.h, h = d.w, scale = d.scale, mobile = d.mobile, touch = d.touch, ua = d.ua },
      label
    )
  end)
end

-- re-send cached emulation (device/ua/throttle) after reconnect/navigation.
-- guarded so the emulation acks it provokes don't recurse into another reapply.
function M._reapply()
  if reapplying then
    return
  end
  if not (current.dev or current.ua_str or current.thr) then
    return
  end
  reapplying = true
  if current.dev then
    client.send({
      op = "device",
      width = current.dev.w,
      height = current.dev.h,
      scale = current.dev.scale,
      mobile = current.dev.mobile,
      touch = current.dev.touch,
      ua = current.dev.ua,
    })
  end
  if current.ua_str then
    client.send({ op = "useragent", ua = current.ua_str })
  end
  if current.thr then
    local cmd = vim.tbl_extend("force", { op = "throttle" }, current.thr)
    client.send(cmd)
  end
  -- release the guard on the next tick, after this batch's acks have arrived.
  vim.schedule(function()
    reapplying = false
  end)
end

return M
