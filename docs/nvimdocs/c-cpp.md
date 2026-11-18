# c-cpp
> C / C++: clangd LSP, clang-format via clangd, codelldb debugging.

**Local specs:** lua/plugins/lsp.lua (clangd block), lua/plugins/dap.lua (`dap.configurations.c/cpp`), lua/plugins/treesitter.lua (`c`, `cpp` parsers)
**Tags:** c cpp clangd clang-tidy codelldb c23 c++23

## LSP
clangd comes from `$PATH` (Apple `/usr/bin/clangd` on macOS), not mason: upstream builds miss the macOS SDK headers on loose files.

| Situation | Standard used |
|---|---|
| `compile_commands.json`, `build/compile_commands.json` or `compile_flags.txt` in an ancestor dir | whatever the build says |
| loose `.c` file | `-std=c23` |
| loose C++ file | `-std=c++23` |

CMake: `set(CMAKE_CXX_STANDARD 23)` + `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` (configure into `build/`).
clang-tidy runs inside clangd and reads the project's `.clang-tidy`.

## Format
No conform entry: format-on-save falls back to clangd, which uses the project's `.clang-format`, else LLVM style.

## Debug
Build with `-g`. `<leader>dc` offers:
1. **codelldb: launch executable (prompt)**: path prefilled with `build/`, then args.
2. **codelldb: attach to process**: process picker.

Keys are shared with every language (`<leader>db`, `di`, `do`, `dO`, `dt`, `du`).
