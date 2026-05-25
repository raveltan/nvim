-- Semantic search over nvimdocs + devdocs via LM Studio embeddings.
-- Index lives at ~/.ravelnvim.db (outside repo). Build with :SemanticIndex.

local M = {}

local nvim_root = vim.fn.stdpath("config")
local scripts_dir = nvim_root .. "/scripts/semantic"

M.config = {
  python = scripts_dir .. "/.venv/bin/python3",
  query_script = scripts_dir .. "/query.py",
  index_script = scripts_dir .. "/index.py",
  setup_script = scripts_dir .. "/setup.sh",
  db = vim.fn.expand("~/.ravelnvim.db"),
  top_n = 30,
}

local function check_ready()
  if vim.fn.executable(M.config.python) ~= 1 then
    vim.notify(
      "Semantic: venv missing. Run: bash " .. M.config.setup_script,
      vim.log.levels.ERROR
    )
    return false
  end
  if vim.fn.filereadable(M.config.db) == 0 then
    vim.notify(
      "Semantic: db missing. Run :SemanticIndex first.",
      vim.log.levels.WARN
    )
    return false
  end
  return true
end

---@param query string
---@param sources string  comma-separated, "" for all
---@param cb fun(items: table[])
local function run_query(query, sources, cb)
  local args = {
    M.config.python,
    M.config.query_script,
    query,
    "-n",
    tostring(M.config.top_n),
    "--db",
    M.config.db,
    "--format",
    "jsonl",
  }
  if sources ~= "" then
    table.insert(args, "--sources")
    table.insert(args, sources)
  end
  vim.system(args, { text = true }, function(out)
    vim.schedule(function()
      if out.code ~= 0 then
        vim.notify(
          "Semantic query failed:\n" .. (out.stderr or ""),
          vim.log.levels.ERROR
        )
        cb({})
        return
      end
      local items = {}
      for line in (out.stdout or ""):gmatch("[^\n]+") do
        local ok, decoded = pcall(vim.json.decode, line)
        if ok and decoded then
          table.insert(items, decoded)
        end
      end
      cb(items)
    end)
  end)
end

---Convert query results into snacks picker items.
local function to_snacks_items(results)
  local items = {}
  for idx, r in ipairs(results) do
    local label = vim.fn.fnamemodify(r.file, ":t:r")
    if r.anchor ~= "" then
      label = label .. " :: " .. r.anchor
    end
    local snippet = (r.text or ""):gsub("\n", " ")
    if #snippet > 120 then
      snippet = snippet:sub(1, 120) .. "…"
    end
    table.insert(items, {
      idx = idx,
      score = r.score,
      text = string.format("%.3f  [%s]  %s  %s",
        r.score, r.source, label, snippet),
      file = r.file,
      pos = { r.line, 0 },
      source = r.source,
      anchor = r.anchor,
      preview = {
        text = r.text,
        ft = "markdown",
      },
    })
  end
  return items
end

---@param sources string
---@param prompt string
function M.pick(sources, prompt)
  if not check_ready() then return end
  local query = vim.fn.input(prompt .. " > ")
  if query == nil or query == "" then return end

  vim.notify("Semantic: searching " .. (sources == "" and "all" or sources) .. "…")
  run_query(query, sources, function(results)
    if #results == 0 then
      vim.notify("Semantic: no results", vim.log.levels.WARN)
      return
    end
    local items = to_snacks_items(results)
    Snacks.picker.pick({
      source = "semantic",
      items = items,
      format = "text",
      sort = { fields = { "idx" } },
      title = "Semantic: " .. query,
      preview = "file",
      confirm = function(picker, item)
        picker:close()
        if item and item.file then
          vim.cmd("edit " .. vim.fn.fnameescape(item.file))
          if item.pos and item.pos[1] then
            pcall(vim.api.nvim_win_set_cursor, 0, { item.pos[1], 0 })
          end
        end
      end,
    })
  end)
end

---@param full boolean
---@param sources string
---@param mode? "terminal"|"background"  default "terminal"
function M.rebuild(full, sources, mode)
  if vim.fn.executable(M.config.python) ~= 1 then
    vim.notify(
      "Semantic: run `bash " .. M.config.setup_script .. "` first",
      vim.log.levels.ERROR
    )
    return
  end
  mode = mode or "terminal"

  local parts = {
    vim.fn.shellescape(M.config.python),
    vim.fn.shellescape(M.config.index_script),
    "--db", vim.fn.shellescape(M.config.db),
    "--sources", vim.fn.shellescape(sources),
  }
  if full then table.insert(parts, "--full") end
  local cmd = table.concat(parts, " ")

  if mode == "terminal" then
    vim.cmd("botright 15split")
    vim.cmd("terminal " .. cmd)
    vim.cmd("setlocal nonumber norelativenumber signcolumn=no")
    vim.bo.bufhidden = "wipe"
    vim.cmd("startinsert")
    return
  end

  -- background: stream progress via notify, replace-by-id
  local notify_id = "semantic-index-" .. sources
  local function note(msg, lvl)
    vim.notify(msg, lvl or vim.log.levels.INFO, {
      id = notify_id, title = "Semantic Index", replace = notify_id,
    })
  end
  note("Indexing " .. sources .. (full and " (full)" or "") .. "…")

  local last_line = ""
  vim.system(vim.list_extend({ M.config.python, M.config.index_script,
      "--db", M.config.db, "--sources", sources },
      full and { "--full" } or {}), {
    text = true,
    stderr = function(_, data)
      if not data then return end
      for line in data:gmatch("[^\n]+") do
        last_line = line
        vim.schedule(function() note(line) end)
      end
    end,
  }, function(out)
    vim.schedule(function()
      if out.code == 0 then
        note("Done. " .. last_line)
      else
        note("FAILED:\n" .. (out.stderr or ""), vim.log.levels.ERROR)
      end
    end)
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("SemanticSearch", function()
    M.pick("", "Semantic (all)")
  end, {})
  vim.api.nvim_create_user_command("SemanticSearchNvim", function()
    M.pick("nvimdocs", "Semantic (nvimdocs)")
  end, {})
  vim.api.nvim_create_user_command("SemanticSearchDevdocs", function()
    M.pick("devdocs", "Semantic (devdocs)")
  end, {})
  local complete = function() return { "nvimdocs", "devdocs", "nvimdocs,devdocs" } end
  vim.api.nvim_create_user_command("SemanticIndex", function(opts)
    M.rebuild(false, opts.args ~= "" and opts.args or "nvimdocs,devdocs", "terminal")
  end, { nargs = "?", complete = complete, desc = "Semantic: incremental index in terminal split" })
  vim.api.nvim_create_user_command("SemanticIndexFull", function(opts)
    M.rebuild(true, opts.args ~= "" and opts.args or "nvimdocs,devdocs", "terminal")
  end, { nargs = "?", complete = complete, desc = "Semantic: full reindex in terminal split" })
  vim.api.nvim_create_user_command("SemanticIndexBg", function(opts)
    M.rebuild(false, opts.args ~= "" and opts.args or "nvimdocs,devdocs", "background")
  end, { nargs = "?", complete = complete, desc = "Semantic: index in background (notify-only)" })
end

return M
