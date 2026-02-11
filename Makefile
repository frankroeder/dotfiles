# Makefile for dotfiles installation and configuration
# Usage: make <target>

SHELL := /bin/bash
.SHELLFLAGS := -ec
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

DOTFILES := $(PWD)
OSTYPE := $(shell uname -s)
ARCHITECTURE := $(shell uname -m)
DEVNUL := /dev/null
WHICH := which

PATH := $(PATH):/usr/local/bin:/usr/local/sbin:/usr/bin:$(HOME)/bin:$(HOME)/.local/bin:$(HOME)/.local/nodejs/bin

# Validation targets
.PHONY: validate-macos validate-linux validate-tools
validate-macos: ## Validate macOS environment
	@if [ "$(OSTYPE)" != "Darwin" ]; then echo "Error: This target requires macOS" && exit 1; fi

validate-linux: ## Validate Linux environment
	@if [ "$(OSTYPE)" = "Darwin" ]; then echo "Error: This target requires Linux" && exit 1; fi

validate-tools: ## Validate that minimal required tools are available
	@$(call print_step,Validating required tools)
	@command -v curl >/dev/null 2>&1 || { $(call print_error,curl is required); exit 1; }
	@command -v git >/dev/null 2>&1 || { $(call print_error,git is required); exit 1; }
	@command -v make >/dev/null 2>&1 || { $(call print_error,make is required); exit 1; }
	@$(call print_step,All required tools are available)

# Common functions
define create_symlink
	@if [ -e "$(1)" ] || [ -L "$(1)" ]; then \
		echo "Linking $(1) -> $(2)"; \
		ln -sfv $(1) $(2); \
	else \
		echo "\033[1m\033[33mWarning: Source $(1) does not exist, skipping symlink\033[0m"; \
	fi
endef

define print_step
	echo -e "\033[1m\033[34m==> $(1)\033[0m"
endef

define print_error
	echo -e "\033[1m\033[31mError: $(1)\033[0m" >&2
endef

define print_warning
	echo -e "\033[1m\033[33mWarning: $(1)\033[0m"
endef

# and homebrew available
ifeq ($(ARCHITECTURE), arm64)
	PATH := $(PATH):/opt/homebrew/bin:/opt/homebrew/sbin
endif

CONTAINER_CMD := $(shell if command -v podman >/dev/null 2>&1; then echo "podman"; elif command -v docker >/dev/null 2>&1; then echo "docker"; else echo "container"; fi)
ifeq ($(CONTAINER_CMD), docker)
CONTAINER_BUILD_CMD := build --platform linux/amd64 --progress plain --rm
else ifeq ($(CONTAINER_CMD), container)
CONTAINER_BUILD_CMD := build --progress plain --arch $(ARCHITECTURE)
else
CONTAINER_BUILD_CMD := build --progress plain --rm
endif

.DEFAULT_GOAL := help

.PHONY: macos
macos: ## Complete macOS setup with all components
macos: validate-macos validate-tools sudo directories homebrew _macos zsh python misc nvim _git node
	@$(call print_step,Finalizing macOS setup)
	$(call print_step,Switching to Zsh); \
	$(SHELL) $(DOTFILES)/autoloaded/switch_zsh; \
	zsh -i -c "fast-theme free" 2>/dev/null || $(call print_warning,Failed to set fast-theme); \
	compaudit 2>/dev/null | xargs chmod g-w 2>/dev/null || true

.PHONY: linux
linux: ## Complete Linux setup with all components
linux: validate-linux validate-tools sudo directories _linux _git zsh python misc node nvim
	@$(call print_step,Finalizing Linux setup)
	$(SHELL) $(DOTFILES)/autoloaded/switch_zsh

.PHONY: minimal
minimal: ## Minimal Linux setup without sudo requirements
minimal: validate-linux validate-tools directories _linux _git zsh python misc node nvim

.PHONY: help
help: ## Show this help message
	@echo "#######################################################################"
	@echo "# Dotfiles Installation"
	@echo "#######################################################################"
	@grep -E '^[a-zA-Z0-9_-]+:.*## ' $(MAKEFILE_LIST) \
	| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m  %-15s\033[0m %s\n", $$1, $$2}'
	@echo "#######################################################################"

.PHONY: sudo
sudo: ## Authenticate and keep sudo session alive
	$(call print_step,Installation with sudo required)
	@if sudo -n true 2>/dev/null; then \
		$(call print_warning,sudo session already active); \
	else \
		sudo -v; \
	fi
	@while true; do sudo -n true; sleep 1200; kill -0 "$$" || exit; done 2>/dev/null &

.PHONY: homebrew
homebrew: ## Install Homebrew and bundle packages
homebrew: | sudo
	$(call print_step,Installing brew if not already present)
ifeq ($(ARCHITECTURE), arm64)
	$(call print_step,Installing rosetta for non-native apps)
	@if [ ! -d "/usr/libexec/rosetta" ]; then softwareupdate --install-rosetta --agree-to-license; fi
endif
ifeq ($(shell ${WHICH} brew 2>${DEVNUL}),)
	@$(SHELL) -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
	$(call print_warning,Homebrew is already installed)
endif
	$(call print_step,Installing brew formulas)
	@brew bundle --file="$(DOTFILES)/Brewfile" --no-lock
	@brew cleanup
	-brew doctor

.PHONY: python
python: ## Install Python tools and configure IPython
	$(call print_step,Installing python tools)
ifeq ($(OSTYPE), Linux)
	@if ! command -v uv >/dev/null 2>&1; then \
		$(call print_step,Installing uv package manager); \
		curl -LsSf https://astral.sh/uv/install.sh | sh; \
	else \
		$(call print_warning,uv is already installed); \
	fi
endif
	@if command -v uv >/dev/null 2>&1; then \
		uv tool install ty@latest; \
		uv tool install ipython; \
	else \
		$(call print_error,uv not available for Python tool installation); \
	fi
	# TODO: Search in uv tools
	@if command -v ipython >/dev/null 2>&1; then \
		mkdir -p $(HOME)/.ipython/profile_default; \
		ipython -c "exit()" && ln -sfv $(DOTFILES)/python/ipython_config.py $(HOME)/.ipython/profile_default/; \
	else \
		$(call print_warning,IPython not available for configuration); \
	fi

.PHONY: misc
misc: ## Install miscellaneous tools and configurations
	$(call print_step,Installing misc)
	@if ! command -v fzf >/dev/null 2>&1; then \
		$(call print_step,Installing fzf); \
		git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --bin; \
	else \
		$(call print_warning,fzf is already installed); \
	fi
	$(call create_symlink,$(DOTFILES)/wgetrc,$(HOME)/.wgetrc)
	$(call create_symlink,$(DOTFILES)/curlrc,$(HOME)/.curlrc)
	$(call create_symlink,$(DOTFILES)/tmux/tmux.conf,$(HOME)/.tmux.conf)
	$(call create_symlink,$(DOTFILES)/latexmkrc,$(HOME)/.latexmkrc)
	$(call create_symlink,$(DOTFILES)/btop,$(HOME)/.config/btop)


.PHONY: zsh
zsh: ## Install and configure Zsh with completions
zsh: | directories
	$(call print_step,Installing zsh and tools)
	@if ! command -v zsh >/dev/null 2>&1; then \
		$(call print_error,Zsh is not installed. Please install it first); \
		exit 1; \
	fi
	$(call create_symlink,$(DOTFILES)/zsh/zshrc,$(HOME)/.zshrc)
	$(call create_symlink,$(DOTFILES)/zsh/zlogin,$(HOME)/.zlogin)
	$(call create_symlink,$(DOTFILES)/zsh/zshenv,$(HOME)/.zshenv)
	$(call create_symlink,$(DOTFILES)/zsh/zprofile,$(HOME)/.zprofile)
	@mkdir -p $(HOME)/.zsh-complete
	@if command -v rg >/dev/null 2>&1; then \
		$(call print_step,Generating ripgrep completions); \
		rg --generate complete-zsh > $(HOME)/.zsh-complete/_rg; \
	fi
	@if [ -f "$(HOME)/.zshrc" ]; then \
		$(call print_step,Sourcing zshrc); \
		. $(HOME)/.zshrc || $(call print_warning,Failed to source .zshrc); \
	fi

.PHONY: node
node: ## Install Node.js and global npm packages
	$(call print_step,Installing node and npm packages)
	@if ! command -v node >/dev/null 2>&1; then \
		$(call print_step,Installing Node.js); \
		bash $(DOTFILES)/scripts/nodejs.sh; \
	else \
		$(call print_warning,Node.js is already installed); \
	fi
	@if command -v npm >/dev/null 2>&1; then \
		$(call print_step,Installing global npm packages); \
		npm i --location=global npm@latest; \
		npm i --location=global eslint; \
		npm i --location=global neovim; \
	else \
		$(call print_error,npm not available for package installation); \
	fi

.PHONY: nvim
nvim: ## Install and configure Neovim with plugins
nvim: | directories
	$(call print_step,Installing nvim dependencies)
	@if ! command -v nvim >/dev/null 2>&1; then \
		$(call print_error,Neovim is not installed. Please install it first); \
		exit 1; \
	fi
	nvim "+call mkdir(stdpath('config'), 'p')" +qall; \
	rm -rfv $(HOME)/.config/nvim; \
	touch $(HOME)/.localnvim.lua; \
	ln -sfv $(DOTFILES)/nvim $(HOME)/.config; \
	$(call print_step,Syncing Neovim plugins); \
	nvim --headless "+Lazy! sync" +qa; \

.PHONY: _git
_git: ## Configure Git with completion and dotfiles
	$(call print_step,Installing stuff for git)
	@if ! [ -f "$(HOME)/.git-completion.bash" ]; then \
		$(call print_step,Downloading git completion); \
		curl -fsSL https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o $(HOME)/.git-completion.bash; \
	else \
		$(call print_warning,Git completion already exists); \
	fi
	@if [ -f "$(DOTFILES)/git/gitconfig" ]; then ln -sfv $(DOTFILES)/git/gitconfig $(HOME)/.gitconfig; fi
	@if [ -f "$(DOTFILES)/git/gitignore" ]; then ln -sfv $(DOTFILES)/git/gitignore $(HOME)/.gitignore; fi

.PHONY: after
after: ## Post-installation setup and service start
after: _terminal
	$(call print_step,Post-installation setup)
	$(call print_step,Running git setup)
	@bash $(DOTFILES)/git/setup.sh
	@if [ "$(OSTYPE)" = "Linux" ] && [ -f "$(DOTFILES)/linux/apt.sh" ]; then \
		$(call print_step,Installing Linux desktop packages); \
		bash $(DOTFILES)/linux/apt.sh "desktop"; \
	fi
	@if command -v nvim >/dev/null 2>&1 ; then \
		$(call print_step,Updating Treesitter parsers); \
		nvim -i NONE -u $(DOTFILES)/nvim/init.lua -c "TSUpdate" -c "quitall"; \
	fi
ifeq ($(OSTYPE), Darwin)
	@if command -v yabai >/dev/null 2>&1; then \
		$(call print_step,Starting yabai and skhd service); \
		echo "$$(whoami) ALL=(root) NOPASSWD: sha256:$$(shasum -a 256 $$(which yabai) | cut -d ' ' -f 1) $$(which yabai) --load-sa" | sudo tee /private/etc/sudoers.d/yabai; \
		sudo yabai --install-sa; \
		yabai --start-service; \
		skhd --start-service; \
	fi
	@if command -v brew >/dev/null 2>&1; then \
		$(call print_step,Starting sketchybar service); \
		brew services start sketchybar; \
	fi
	# private configs
	# https://agents.md
	ln -sfv $(HOME)/Library/Mobile\ Documents/com\~apple\~CloudDocs/configs/AGENTS.md $(HOME)/.claude/CLAUDE.md;
	ln -sfv $(HOME)/Library/Mobile\ Documents/com\~apple\~CloudDocs/configs/AGENTS.md $(HOME)/.gemini/GEMINI.md;
	ln -sfv $(HOME)/Library/Mobile\ Documents/com\~apple\~CloudDocs/configs/claude_settings.json $(HOME)/.claude/settings.json;
	ln -sfv $(HOME)/Library/Mobile\ Documents/com\~apple\~CloudDocs/configs/opencode.jsonc $(HOME)/.config/opencode/;
	ln -sfv $(HOME)/Library/Mobile\ Documents/com\~apple\~CloudDocs/configs/gemini_settings.json $(HOME)/.gemini/settings.json;
endif

.PHONY: directories
directories: ## Create necessary directories
	$(call print_step,Creating directories)
	@mkdir -p $(HOME)/config
	@mkdir -p $(HOME)/.zsh
	@mkdir -p $(HOME)/.config/htop
	@mkdir -p $(HOME)/tmp
	@mkdir -p $(HOME)/.Trash
	@mkdir -p $(HOME)/Downloads
	@mkdir -p $(HOME)/bin
	@mkdir -p $(HOME)/.zcompcache


.PHONY: micro
micro: ## Minimal setup with bash configuration
micro: _backup _bash
	$(call print_step,Setting up micro configuration)
	$(call create_symlink,$(DOTFILES)/bash/tmux.conf,$(HOME)/.tmux.conf)
	$(call create_symlink,$(DOTFILES)/bash/vimrc,$(HOME)/.vimrc)
	$(call create_symlink,$(DOTFILES)/htop/server,$(HOME)/.htoprc)
	@mkdir -p $(HOME)/.Trash

.PHONY: _bash
_bash: ## Configure bash dotfiles
	$(call print_step,Configuring bash dotfiles)
	$(call create_symlink,$(DOTFILES)/bash/bash_profile,$(HOME)/.bash_profile)
	$(call create_symlink,$(DOTFILES)/bash/bashrc,$(HOME)/.bashrc)
	$(call create_symlink,$(DOTFILES)/bash/bash_prompt,$(HOME)/.bash_prompt)
	$(call create_symlink,$(DOTFILES)/bash/bash_logout,$(HOME)/.bash_logout)
	$(call create_symlink,$(DOTFILES)/bash/bash_aliases,$(HOME)/.bash_aliases)
	$(call create_symlink,$(DOTFILES)/bash/bash_functions,$(HOME)/.bash_functions)

.PHONY: _backup
_backup: ## Backup existing dotfiles
	$(call print_step,Backing up existing dotfiles)
	@mkdir -p $(HOME)/old_dots
	@for file in .bash* .profile .vimrc .tmux.conf .htoprc; do \
		if [ -e "$(HOME)/$$file" ]; then \
			echo "Backing up $$file"; \
			mv "$(HOME)/$$file" "$(HOME)/old_dots/" 2>/dev/null || true; \
		fi; \
	done

.PHONY: _linux
_linux: ## Linux-specific setup and package installation
	$(call print_step,Installing linux basis)
	@mkdir -p $(HOME)/bin $(HOME)/.local/bin $(HOME)/Uploads
	@if [ -z "$(NOSUDO)" ] ; then \
		$(call print_step,Installing Linux packages); \
		bash $(DOTFILES)/linux/apt.sh "default"; \
	fi
	@mkdir -p $(HOME)/.config/htop; \
	@ln -sfv $(DOTFILES)/htop/server $(HOME)/.config/htop/htoprc; \
	@if ! command -v nvim >/dev/null 2>&1; then \
		if [ -z "$(NOSUDO)" ]; then \
			bash $(DOTFILES)/scripts/nvim.sh "source"; \
		else \
			bash $(DOTFILES)/scripts/nvim.sh "binary"; \
		fi; \
	fi
	@if ! command -v tree-sitter >/dev/null 2>&1 ; then \
		$(call print_step,Installing tree-sitter); \
		bash $(DOTFILES)/scripts/tree-sitter.sh; \
	fi

.PHONY: _macos
_macos: ## macOS-specific configuration and applications
	$(call print_step,Configure macos and applications)
	@if ! xcode-select -p >/dev/null 2>&1; then \
		$(call print_step,Installing Xcode command line tools); \
		sudo xcode-select --install; \
		sudo xcodebuild -license accept; \
	else \
		$(call print_warning,Xcode command line tools already installed); \
	fi
	@mkdir -p $(HOME)/screens $(HOME)/.config $(HOME)/Library/Fonts
	$(call print_step,Running macOS setup script)
	@bash $(DOTFILES)/macos/main.bash
	@ln -sfv $(DOTFILES)/sketchybar/bottom $(HOME)/.config/sketchybar
	@ln -sfv $(DOTFILES)/sketchybar/top $(HOME)/.config/sketchybar-top
	$(MAKE) sketchybar-top
	$(call print_step,Downloading sketchybar font)
	@bash $(DOTFILES)/scripts/sketchybar_app_font.sh
	@ln -sfv $(DOTFILES)/skhd $(HOME)/.config/skhd
	$(call print_step,Running Sioyek setup)
	@zsh $(DOTFILES)/scripts/sioyek.sh
	@ln -sfv $(DOTFILES)/sioyek $(HOME)/.config/sioyek
	@if command -v swift >/dev/null 2>&1; then \
		mkdir -p $(HOME)/.zsh/completion; \
		swift package completion-tool generate-zsh-script > $(HOME)/.zsh/completion/_swift 2>/dev/null || true; \
	fi
	@if ! command -v sourcekit-lsp >/dev/null 2>&1 ; then \
		$(call print_step,Installing sourcekit-lsp); \
		bash $(DOTFILES)/scripts/sourcekit-lsp.sh; \
	fi
	@if ! command -v battery >/dev/null 2>&1; then \
		$(call print_step,Installing battery manager); \
		curl -fsSL https://raw.githubusercontent.com/actuallymentor/battery/main/setup.sh | bash; \
		battery maintain 80; \
	fi
	@ln -sfv $(DOTFILES)/mpv $(HOME)/.config/mpv
	@ln -sfv $(DOTFILES)/yabai $(HOME)/.config/yabai

.PHONY: _terminal
_terminal: ## Install and configure terminal emulator
	@if ! command -v ghostty >/dev/null 2>&1; then \
		$(call print_warning,Ghostty not installed); \
	else \
		$(call print_step,Ghostty is available); \
	fi
	@ln -sfv $(DOTFILES)/ghostty $(HOME)/.config/ghostty; \
	mkdir -p $(HOME)/.config/htop; \
	ln -sfv $(DOTFILES)/htop/personal $(HOME)/.config/htop/htoprc; \

.PHONY: check
check: ## Run Neovim health check
	@if command -v nvim >/dev/null 2>&1; then \
		$(call print_step,Running Neovim health check); \
		nvim -i NONE -c "checkhealth"; \
	else \
		$(call print_error,Neovim is not installed); \
		exit 1; \
	fi

.PHONY: benchmark
benchmark: ## Benchmark Neovim and Zsh startup times
	@if command -v nvim >/dev/null 2>&1; then \
		$(call print_step,nvim startuptime clean); \
		nvim --startuptime /tmp/startup-clean.log --clean "+qall" && \
		echo "Clean startup:" && \
		tail -2 /tmp/startup-clean.log && \
		rm -f /tmp/startup-clean.log; \
		$(call print_step,nvim startuptime with all plugins); \
		nvim --startuptime /tmp/startup-full.log "+qall" && \
		echo "Full startup:" && \
		tail -2 /tmp/startup-full.log && \
		rm -f /tmp/startup-full.log; \
	else \
		$(call print_warning,Neovim not available for benchmarking); \
	fi
	@if command -v zsh >/dev/null 2>&1 ; then \
		$(call print_step,zsh startuptime); \
		zsh $(DOTFILES)/autoloaded/bench_zsh; \
	else \
		$(call print_warning,Zsh benchmark script not available); \
	fi

.PHONY: format
format: ## Format Lua files with stylua
	@if command -v stylua >/dev/null 2>&1; then \
		$(call print_step,Formatting Lua files with stylua); \
		stylua -v -f $(DOTFILES)/.stylua.toml $$(find $(DOTFILES) -type f -name '*.lua' 2>/dev/null) || true; \
	else \
		$(call print_warning,stylua not installed); \
	fi
.PHONY: uninstall
uninstall: ## Remove installed dotfiles and configurations
	-@rm -f $(HOME)/.zshrc
	-@rm -f $(HOME)/.zshenv
	-@rm -f $(HOME)/.zprofile
	-@rm -f $(HOME)/.tmux.conf
	-@rm -f $(HOME)/.wgetrc
	-@rm -f $(HOME)/.curlrc
	-@rm -f $(HOME)/.latexmkrc
	-@rm -f $(HOME)/.gitignore
	-@rm -f $(HOME)/.gitconfig
	-@rm -rf $(HOME)/.config/htop
	-@rm -rf $(HOME)/.config/btop
	-@rm -rf $(HOME)/.config/nvim
ifeq ($(OSTYPE), Darwin)
	-@rm -rf $(HOME)/.config/skhd
	-@rm -rf $(HOME)/.config/sketchybar
	-@rm -rf $(HOME)/.config/sioyek
	-@rm -rf $(HOME)/.config/yabai
	-@sudo battery uninstall 2>/dev/null || true
endif

.PHONY: test
test: ## Test installation in Docker container
	$(call print_step,Testing linux installation on ${OSTYPE})
ifeq ($(NOSUDO), 1)
	$(CONTAINER_CMD) $(CONTAINER_BUILD_CMD) -t dotfiles ${PWD} -f $(DOTFILES)/docker/Dockerfile;
	$(CONTAINER_CMD) run -it --rm --name maketest -d dotfiles:latest;
	$(CONTAINER_CMD) exec -it maketest /bin/bash -c "make NOSUDO=$(NOSUDO) minimal";
else
	$(CONTAINER_CMD) $(CONTAINER_BUILD_CMD) -t dotfiles_sudo ${PWD} -f $(DOTFILES)/docker/sudoer.Dockerfile;
	$(CONTAINER_CMD) run -it --rm --name maketest_sudo -d dotfiles_sudo:latest;
	$(CONTAINER_CMD) exec -it maketest_sudo /bin/bash -c "make linux";
endif
	$(call print_step,Container can now be shut down)

.PHONY: sketchybar-top
sketchybar-top: ## Install and start SketchyBar Top LaunchAgent
	$(call print_step,Installing sketchybar-top LaunchAgent)
	@mkdir -p $(HOME)/Library/LaunchAgents
	@ln -sfv $(DOTFILES)/sketchybar/top/git.frank.sketchybar-top.plist $(HOME)/Library/LaunchAgents/git.frank.sketchybar-top.plist
	@launchctl bootout gui/$(shell id -u) $(HOME)/Library/LaunchAgents/git.frank.sketchybar-top.plist 2>/dev/null || true
	@launchctl bootstrap gui/$(shell id -u) $(HOME)/Library/LaunchAgents/git.frank.sketchybar-top.plist
