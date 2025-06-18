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
.PHONY: validate-macos validate-linux
validate-macos: ## Validate macOS environment
	@if [ "$(OSTYPE)" != "Darwin" ]; then echo "Error: This target requires macOS" && exit 1; fi

validate-linux: ## Validate Linux environment
	@if [ "$(OSTYPE)" = "Darwin" ]; then echo "Error: This target requires Linux" && exit 1; fi

# Common functions
define create_symlink
	@echo "Linking $(1) -> $(2)"
	@ln -sfv $(1) $(2)
endef

define print_step
	@echo -e "\033[1m\033[34m==> $(1)\033[0m"
endef

ifeq ($(shell ${WHICH} container 2>${DEVNUL}),)
CONTAINER_CMD := docker
ifeq ($(ARCHITECTURE), arm64)
CONTAINER_BUILD_CMD := build --platform linux/amd64 --progress plain --rm
PATH := $(PATH):/opt/homebrew/bin:/opt/homebrew/sbin
else
CONTAINER_BUILD_CMD := build --progress plain --rm
endif
else
CONTAINER_CMD := container
CONTAINER_BUILD_CMD := build --progress plain --arch $(ARCHITECTURE)
endif

.DEFAULT_GOAL := help

.PHONY: macos
macos: ## Complete macOS setup with all components
macos: validate-macos sudo directories homebrew _macos zsh python misc nvim _git node
	@$(SHELL) $(DOTFILES)/autoloaded/switch_zsh
	@zsh -i -c "fast-theme free"
	@compaudit | xargs chmod g-w

.PHONY: linux
linux: ## Complete Linux setup with all components
linux: validate-linux sudo directories _linux _git zsh python misc node nvim
	@$(SHELL) $(DOTFILES)/autoloaded/switch_zsh

.PHONY: minimal
minimal: ## Minimal Linux setup without sudo requirements
minimal: directories _linux _git zsh python misc node nvim

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
	@sudo -v
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
	@$(SHELL) -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
endif
	@echo -e "\033[1m\033[34m==> Installing brew formulas\033[0m"
	@brew bundle --file="$(DOTFILES)/Brewfile --no-lock"
	@brew cleanup
	-brew doctor

.PHONY: python
python: ## Install Python tools and configure IPython
	$(call print_step,Installing python tools)
ifeq ($(OSTYPE), Linux)
	@command -v uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh
endif
	@uv tool install ty@latest
	@uv tool install ipython
ifeq ($(shell ${WHICH} ipython 2>${DEVNUL}),)
	@ipython -c exit && ln -sfv $(DOTFILES)/python/ipython_config.py $(HOME)/.ipython/profile_default/
endif

.PHONY: misc
misc: ## Install miscellaneous tools and configurations
	$(call print_step,Installing misc)
ifeq ($(shell ${WHICH} fzf 2>${DEVNUL}),)
	@git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --bin
endif
	$(call create_symlink,$(DOTFILES)/wgetrc,$(HOME)/.wgetrc)
	$(call create_symlink,$(DOTFILES)/curlrc,$(HOME)/.curlrc)
	$(call create_symlink,$(DOTFILES)/tmux/tmux.conf,$(HOME)/.tmux.conf)
	$(call create_symlink,$(DOTFILES)/latexmkrc,$(HOME)/.latexmkrc)
	$(call create_symlink,$(DOTFILES)/btop,$(HOME)/.config/btop)


.PHONY: zsh
zsh: ## Install and configure Zsh with completions
zsh: | directories
	$(call print_step,Installing zsh and tools)
	$(call create_symlink,$(DOTFILES)/zsh/zshrc,$(HOME)/.zshrc)
	$(call create_symlink,$(DOTFILES)/zsh/zlogin,$(HOME)/.zlogin)
	$(call create_symlink,$(DOTFILES)/zsh/zshenv,$(HOME)/.zshenv)
	$(call create_symlink,$(DOTFILES)/zsh/zprofile,$(HOME)/.zprofile)
	@mkdir -p $(HOME)/.zsh-complete
	@if command -v rg >/dev/null 2>&1; then rg --generate complete-zsh > $(HOME)/.zsh-complete/_rg; fi
	@. $(HOME)/.zshrc

.PHONY: node
node: ## Install Node.js and global npm packages
	$(call print_step,Installing node and npm packages)
ifeq ($(shell ${WHICH} node 2>${DEVNUL}),)
	@bash $(DOTFILES)/scripts/nodejs.sh
endif
	@npm i --location=global npm@latest
	@npm i --location=global eslint
	@npm i --location=global neovim

.PHONY: nvim
nvim: ## Install and configure Neovim with plugins
nvim: | directories
	$(call print_step,Installing nvim dependencies)
	@nvim "+call mkdir(stdpath('config'), 'p')" +qall
	@rm -rfv $(HOME)/.config/nvim
	@touch $(HOME)/.localnvim.lua
	@ln -sfv $(DOTFILES)/nvim $(HOME)/.config
	@nvim --headless "+Lazy! sync" +qa

.PHONY: _git
_git: ## Configure Git with completion and dotfiles
	$(call print_step,Installing stuff for git)
	@curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o $(HOME)/.git-completion.bash
	@ln -sfv $(DOTFILES)/git/gitconfig $(HOME)/.gitconfig
	@ln -sfv $(DOTFILES)/git/gitignore $(HOME)/.gitignore

.PHONY: after
after: ## Post-installation setup and service start
after: _terminal
	$(call print_step,Post-installation setup)
	@bash $(DOTFILES)/git/setup.sh
	@if [ "$(OSTYPE)" == "Linux" ]; then bash $(DOTFILES)/linux/apt.sh "desktop"; fi
	@nvim -i NONE -u $(DOTFILES)/nvim/init.vim -c "TSUpdate" -c "quitall"
ifeq ($(OSTYPE), Darwin)
	@brew services start sketchybar
endif

.PHONY: directories
directories: ## Create necessary directories
	$(call print_step,Creating directories)
	mkdir -p $(HOME)/config
	mkdir -p $(HOME)/.zsh
	mkdir -p $(HOME)/.config/htop
	mkdir -p $(HOME)/tmp
	mkdir -p $(HOME)/.Trash
	mkdir -p $(HOME)/Downloads
	mkdir -p $(HOME)/bin


.PHONY: micro
micro: ## Minimal setup with bash configuration
micro: _backup _bash
	ln -sfv $(DOTFILES)/bash/tmux.conf $(HOME)/.tmux.conf
	ln -sfv $(DOTFILES)/bash/vimrc $(HOME)/.vimrc
	ln -sfv $(DOTFILES)/htop/server $(HOME)/.htoprc
	mkdir -p ~/.Trash

.PHONY: _bash
_bash: ## Configure bash dotfiles
	ln -sfv $(DOTFILES)/bash/bash_profile $(HOME)/.bash_profile;
	ln -sfv $(DOTFILES)/bash/bashrc $(HOME)/.bashrc;
	ln -sfv $(DOTFILES)/bash/bash_prompt $(HOME)/.bash_prompt;
	ln -sfv $(DOTFILES)/bash/bash_logout $(HOME)/.bash_logout;
	ln -sfv $(DOTFILES)/bash/bash_aliases ~/.bash_aliases
	ln -sfv $(DOTFILES)/bash/bash_functions ~/.bash_functions

.PHONY: _backup
_backup: ## Backup existing dotfiles
	mkdir -p $(HOME)/old_dots
	mv $(HOME)/.bash* $(HOME)/old_dots/ || echo "No .bash* found"
	mv $(HOME)/.profile $(HOME)/old_dots/ || echo "No .profile found"
	mv $(HOME)/.vimrc $(HOME)/old_dots/ || echo "No .vimrc found"
	mv $(HOME)/.tmux.conf $(HOME)/old_dots/ || echo "No .tmux.conf found"
	mv $(HOME)/.htoprc $(HOME)/old_dots/ || echo "No .htoprc found"

.PHONY: _linux
_linux: ## Linux-specific setup and package installation
	$(call print_step,Installing linux basis)
	@mkdir -p $(HOME)/bin
	@mkdir -p $(HOME)/.local/bin
	@mkdir -p $(HOME)/Uploads
	if [ -z $(NOSUDO) ]; then bash $(DOTFILES)/linux/apt.sh "default"; fi
	@ln -sfv $(DOTFILES)/htop/server $(HOME)/.config/htop/htoprc
ifeq ($(shell ${WHICH} nvim 2>${DEVNUL}),)
	if [ -z $(NOSUDO) ]; then bash $(DOTFILES)/scripts/nvim.sh "source"; else bash $(DOTFILES)/scripts/nvim.sh "binary"; fi
endif
ifeq ($(shell ${WHICH} tree-sitter 2>${DEVNUL}),)
	@bash $(DOTFILES)/scripts/tree-sitter.sh
endif

.PHONY: _macos
_macos: ## macOS-specific configuration and applications
	$(call print_step,Configure macos and applications)
	if [ -n "$(xcode-select -p)" ]; then sudo xcode-select --install; sudo xcodebuild -license accept; fi
	@mkdir -p $(HOME)/screens
	@bash $(DOTFILES)/macos/main.bash
	@ln -sfv $(DOTFILES)/sketchybar $(HOME)/.config/sketchybar
	@curl -L https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v2.0.29/sketchybar-app-font.ttf -o $(HOME)/Library/Fonts/sketchybar-app-font.ttf
	@ln -sfv $(DOTFILES)/flashspace $(HOME)/.config/flashspace
	@ln -sfv $(DOTFILES)/skhd $(HOME)/.config/skhd
	@zsh $(DOTFILES)/scripts/sioyek.sh
	@ln -sfv $(DOTFILES)/sioyek $(HOME)/.config/sioyek
	@swift package completion-tool generate-zsh-script > $(HOME)/.zsh/completion/_swift
ifeq ($(shell ${WHICH} sourcekit-lsp 2>${DEVNUL}),)
	@bash $(DOTFILES)/scripts/sourcekit-lsp.sh
endif
ifeq ($(shell ${WHICH} battery 2>${DEVNUL}),)
	@curl -s https://raw.githubusercontent.com/actuallymentor/battery/main/setup.sh | bash
	@battery maintain 80
endif
	@ln -sfv $(DOTFILES)/mpv $(HOME)/.config/mpv

.PHONY: _terminal
_terminal: ## Install and configure terminal emulator
ifeq ($(shell ${WHICH} ghostty 2>${DEVNUL}),)
	@echo "Ghostty not installed!"
endif
	@ln -sfv $(DOTFILES)/ghostty $(HOME)/.config/ghostty
	@ln -sfv $(DOTFILES)/htop/personal $(HOME)/.config/htop/htoprc

.PHONY: check
check: ## Run Neovim health check
	@nvim -i NONE -c "checkhealth"

.PHONY: benchmark
benchmark: ## Benchmark Neovim and Zsh startup times
	$(call print_step,nvim startuptime clean)
	@nvim --startuptime /tmp/startup-clean.log --clean "+qall" && \
		echo "Clean startup:" && \
		tail -2 /tmp/startup-clean.log && \
		rm -f /tmp/startup-clean.log
	$(call print_step,nvim startuptime with all plugins)
	@nvim --startuptime /tmp/startup-full.log "+qall" && \
		echo "Full startup:" && \
		tail -2 /tmp/startup-full.log && \
		rm -f /tmp/startup-full.log
	$(call print_step,zsh startuptime)
	@zsh $(DOTFILES)/autoloaded/bench_zsh

.PHONY: format
format: ## Format Lua files with stylua
	@stylua -v -f $(DOTFILES)/.stylua.toml $$(find $(DOTFILES) -type f -name '*.lua')

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
	-@sudo battery uninstall 2>/dev/null || true
endif

.PHONY: test
test: ## Test installation in Docker container
	$(call print_step,Testing linux installation on ${OSTYPE})
ifeq ($(NOSUDO), 1)
		@$(CONTAINER_CMD) $(CONTAINER_BUILD_CMD) -t dotfiles ${PWD} -f $(DOTFILES)/docker/Dockerfile;
		@$(CONTAINER_CMD) run -it --rm --name maketest -d dotfiles:latest;
		@$(CONTAINER_CMD) exec -it maketest /bin/bash -c "make NOSUDO=$(NOSUDO) minimal";
else
		@$(CONTAINER_CMD) $(CONTAINER_BUILD_CMD) -t dotfiles_sudo ${PWD} -f $(DOTFILES)/docker/sudoer.Dockerfile;
		@$(CONTAINER_CMD) run -it --rm --name maketest_sudo -d dotfiles_sudo:latest;
		@$(CONTAINER_CMD) exec -it maketest_sudo /bin/bash -c "make linux";
endif
	$(call print_step,Container can now be shut down)
