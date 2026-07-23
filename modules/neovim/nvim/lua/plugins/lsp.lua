-- ~/.config/nvim/lua/plugins/lsp.lua
local M = {}

function M.setup()
  require("lspconfig").rust_analyzer.setup({})
  require("lspconfig").kotlin_language_server.setup({})
end

return M
