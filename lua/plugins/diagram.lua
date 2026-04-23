-- Render mermaid/plantuml/d2/gnuplot code blocks inline in markdown/neorg buffers.
-- Requires a graphics-capable terminal (Kitty or Überzug++) and the CLI renderer(s)
-- (e.g. `mmdc` for mermaid, `d2`, `plantuml`, `gnuplot`).
return {
  {
    "3rd/image.nvim",
    build = false, -- skip luarocks; use the bundled magick_rock
    ft = { "markdown", "norg" },
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = false,
          download_remote_images = true,
          only_render_image_at_cursor = false,
          filetypes = { "markdown", "vimwiki" },
        },
      },
      max_width = 100,
      max_height = 12,
      max_width_window_percentage = nil,
      max_height_window_percentage = 50,
      window_overlap_clear_enabled = true,
      editor_only_render_when_focused = true,
    },
  },
  {
    "3rd/diagram.nvim",
    dependencies = { "3rd/image.nvim" },
    ft = { "markdown", "norg" },
    opts = function()
      return {
        integrations = {
          require("diagram.integrations.markdown"),
          require("diagram.integrations.neorg"),
        },
        renderer_options = {
          mermaid = { theme = "dark", scale = 2 },
          plantuml = { charset = "utf-8" },
          d2 = { theme_id = 200 },
          gnuplot = { theme = "dark", size = "800,600" },
        },
      }
    end,
    keys = {
      {
        "<leader>dd",
        function() require("diagram").show_diagram_hover() end,
        mode = "n",
        ft = { "markdown", "norg" },
        desc = "Diagram: show at cursor in new tab",
      },
    },
  },
}
