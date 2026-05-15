return {
  {
    "maskudo/devdocs.nvim",
    dependencies = { "folke/snacks.nvim" },
    cmd = { "DevDocs", "DevDocsOpen", "DevDocsJump", "DevDocsGrep", "DevDocsGrepAll", "DevDocsGrepVisual", "DevDocsGrepVisualAll" },
    keys = {
      { "<leader>ko", "<cmd>DevDocsOpen<cr>",     desc = "DevDocs open (pick doc → file)" },
      { "<leader>kj", "<cmd>DevDocsJump<cr>",     desc = "DevDocs jump file in last doc" },
      { "<leader>ks", "<cmd>DevDocsGrep<cr>",     desc = "DevDocs grep in last doc" },
      { "<leader>kS", "<cmd>DevDocsGrepAll<cr>",  desc = "DevDocs grep all installed" },
      { "<leader>ks", "<cmd>DevDocsGrepVisual<cr>",    mode = "x", desc = "DevDocs grep selection in last doc" },
      { "<leader>kS", "<cmd>DevDocsGrepVisualAll<cr>", mode = "x", desc = "DevDocs grep selection all docs" },
      { "<leader>ki", "<cmd>DevDocs install<cr>", desc = "DevDocs install" },
      { "<leader>kf", "<cmd>DevDocs fetch<cr>",   desc = "DevDocs fetch index" },
      { "<leader>kd", "<cmd>DevDocs delete<cr>",  desc = "DevDocs delete" },
    },
    opts = {
      ensure_installed = {
        "ruby~4.0", "rails~8.1",
        "javascript", "typescript", "node",
        "php", "html", "css", "http", "lua~5.1",
        "tailwindcss", "react", "angular~20",
        "markdown", "nginx", "sqlite",
        "bash", "git", "docker", "redis","rxjs", "rust", "typescript~5.1",
        "sass", "minitest", "playwright","python~3.12",
      },
    },
    config = function(_, opts)
      -- Strip inline SVG data URIs from HTML before pandoc.
      -- DevDocs SVGs use CSS vars (var(--primary-contrast)) that ImageMagick
      -- cannot parse, causing image.nvim render errors and UI lag.
      local D = require("devdocs.docs")
      local orig = D.ConvertHtmlToMarkdown
      D.ConvertHtmlToMarkdown = function(htmlContent, outputFile, callback)
        if type(htmlContent) == "string" then
          htmlContent = htmlContent:gsub("<img[^>]-data:image/svg%+xml[^>]->", "")
        end
        return orig(htmlContent, outputFile, callback)
      end
      require("devdocs").setup(opts)

      local C = require("devdocs.constants")
      local DD = require("devdocs")
      local docs_root = C.DOCS_DIR
      local last_doc

      local function jump_anchor(slug)
        slug = slug:lower()
        local stripped = slug:gsub("^pdf%-", "")
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        for i, l in ipairs(lines) do
          local heading = l:match("^#+%s+(.+)$")
          if heading then
            local hslug = heading:lower():gsub("`", ""):gsub("[^%w%-]+", "-")
              :gsub("^%-+", ""):gsub("%-+$", "")
            if hslug == slug or hslug == stripped then
              vim.api.nvim_win_set_cursor(0, { i, 0 })
              vim.cmd("normal! zt")
              return true
            end
          end
        end
        local ok = pcall(vim.fn.search, "\\c" .. vim.fn.escape(stripped, "\\/."))
        return ok
      end

      local function open_target(target)
        if target:match("^https?://") or target:match("^mailto:") then
          return vim.ui.open(target)
        end
        if target:sub(1, 1) == "#" then
          return jump_anchor(target:sub(2))
        end
        local path, anchor = target:match("^([^#]*)#?(.*)$")
        path = (path ~= "" and path) or target
        local dir = vim.fn.expand("%:p:h")
        local candidates = {
          dir .. "/" .. path,
          dir .. "/" .. path .. ".md",
          dir .. "/" .. path .. "/index.md",
        }
        for _, c in ipairs(candidates) do
          if vim.fn.filereadable(c) == 1 then
            vim.cmd("edit " .. vim.fn.fnameescape(c))
            if anchor and anchor ~= "" then jump_anchor(anchor) end
            return true
          end
        end
        vim.notify("Devdocs: link not resolved: " .. target, vim.log.levels.WARN)
        return false
      end

      local function follow_link()
        local line = vim.api.nvim_get_current_line()
        local col = vim.api.nvim_win_get_cursor(0)[2] + 1
        -- Markdown links [text](target)
        local s = 1
        while true do
          local ls, le, _, target = line:find("%[([^%]]*)%]%(([^)]+)%)", s)
          if not ls then break end
          if col >= ls and col <= le then return open_target(target) end
          s = le + 1
        end
        -- Raw HTML <a href="..."> (php docs)
        s = 1
        while true do
          local ls, le, target = line:find('<a%s[^>]-href=["\']([^"\']+)["\'][^>]->[^<]-</a>', s)
          if not ls then
            ls, le, target = line:find('<a%s[^>]-href=["\']([^"\']+)["\']', s)
          end
          if not ls then break end
          if col >= ls and col <= le then return open_target(target) end
          s = le + 1
        end
        -- Bare autolink <https://...>
        local bare = line:match("<(https?://[^>]+)>")
        if bare then return vim.ui.open(bare) end
        vim.cmd("normal! gf")
      end

      vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("devdocs_buf", { clear = true }),
        pattern = docs_root .. "/*",
        callback = function(args)
          local p = vim.api.nvim_buf_get_name(args.buf)
          local rel = p:sub(#docs_root + 2)
          local slug = rel:match("^([^/]+)")
          if slug and slug ~= "" then last_doc = slug end
          vim.keymap.set("n", "gf", follow_link, { buffer = args.buf, desc = "DevDocs follow link" })
          vim.keymap.set("n", "<CR>", follow_link, { buffer = args.buf, desc = "DevDocs follow link" })
        end,
      })

      local function pick_doc(cb)
        local docs = DD.GetInstalledDocs()
        if #docs == 0 then
          vim.notify("No docs installed", vim.log.levels.WARN)
          return
        end
        table.sort(docs)
        Snacks.picker.select(docs, { prompt = "Select Doc" }, function(s)
          if s then cb(s) end
        end)
      end

      local function pick_file_in_doc(slug)
        local dir = DD.GetDocDir(slug)
        last_doc = slug
        Snacks.picker.files({
          cwd = dir,
          prompt = slug .. " ❯ ",
          confirm = "edit_vsplit",
        })
      end

      local function grep_in_doc(slug, seed)
        local dir = DD.GetDocDir(slug)
        last_doc = slug
        Snacks.picker.grep({
          cwd = dir,
          prompt = slug .. " grep ❯ ",
          search = seed,
          confirm = "edit_vsplit",
        })
      end

      local function visual_selection()
        local mode = vim.fn.mode()
        local s_start, s_end, region_type
        if mode == "v" or mode == "V" or mode == "\22" then
          s_start = vim.fn.getpos("v")
          s_end = vim.fn.getpos(".")
          region_type = mode
        else
          s_start = vim.fn.getpos("'<")
          s_end = vim.fn.getpos("'>")
          region_type = "v"
        end
        local ok, lines = pcall(vim.fn.getregion, s_start, s_end, { type = region_type })
        if not ok or not lines or #lines == 0 then return "" end
        return table.concat(lines, " "):gsub("^%s+", ""):gsub("%s+$", "")
      end

      local function grep_visual()
        local sel = visual_selection()
        if sel == "" then return end
        vim.api.nvim_input("<Esc>")
        if last_doc then
          grep_in_doc(last_doc, sel)
        else
          pick_doc(function(s) grep_in_doc(s, sel) end)
        end
      end

      local function grep_visual_all()
        local sel = visual_selection()
        if sel == "" then return end
        vim.api.nvim_input("<Esc>")
        Snacks.picker.grep({
          cwd = docs_root,
          prompt = "All docs grep ❯ ",
          search = sel,
          confirm = "edit_vsplit",
        })
      end

      vim.api.nvim_create_user_command("DevDocsGrepVisual", grep_visual, { range = true })
      vim.api.nvim_create_user_command("DevDocsGrepVisualAll", grep_visual_all, { range = true })

      local function with_last_or_pick(fn)
        if last_doc then fn(last_doc) else pick_doc(fn) end
      end

      vim.api.nvim_create_user_command("DevDocsOpen", function()
        pick_doc(pick_file_in_doc)
      end, {})
      vim.api.nvim_create_user_command("DevDocsJump", function()
        with_last_or_pick(pick_file_in_doc)
      end, {})
      vim.api.nvim_create_user_command("DevDocsGrep", function()
        with_last_or_pick(grep_in_doc)
      end, {})
      vim.api.nvim_create_user_command("DevDocsGrepAll", function()
        Snacks.picker.grep({
          cwd = docs_root,
          prompt = "All docs grep ❯ ",
          confirm = "edit_vsplit",
        })
      end, {})
    end,
  },
}
