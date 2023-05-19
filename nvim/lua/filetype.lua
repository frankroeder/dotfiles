vim.filetype.add({
	filename = {
		["Brewfile"] = "ruby",
		[".env"] = "config",
	},
	pattern = {
		["*gitconfig"] = "gitconfig",
		["*.cls"] = "tex",
		["*.config"] = "config",
		["*.Dockerfile"] = "dockerfile",
		[".*/%.dockerignore"] = "gitignore",
	}
})
