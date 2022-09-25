return function(lspconfig)
	lspconfig.elixirls.setup {
		cmd = { vim.fn.exepath "elixir-ls" },
		settings = {
			elixirLS = {
				dialyzerEnabled = false,
				fetchDeps = false
			}
		}
	}
end
