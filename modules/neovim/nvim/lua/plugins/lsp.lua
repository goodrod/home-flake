-- ~/.config/nvim/lua/plugins/lsp.lua
local M = {}

function M.setup()
  require("lspconfig").rust_analyzer.setup({})
end

return M
