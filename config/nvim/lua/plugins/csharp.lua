return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        omnisharp = { enabled = false },
        csharp_ls = {
          mason = false,
          cmd = { "csharp-ls" },
          root_dir = function(fname)
            local util = require("lspconfig.util")
            return util.root_pattern("*.slnx", "*.sln", "Assembly-CSharp.csproj")(fname)
              or util.find_git_ancestor(fname)
          end,
        },
      },
    },
  },
}
