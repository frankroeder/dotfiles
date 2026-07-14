# Makefile for dotfiles — thin wrappers around ./install.sh plus test/bench/format helpers.
# The actual install logic lives in install.sh and install/*.sh. Run `./install.sh help`.

SHELL := /bin/bash
.SHELLFLAGS := -ec
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

NOSUDO ?=
DOTFILES := $(PWD)
OSTYPE := $(shell uname -s)
ARCHITECTURE := $(shell uname -m)
INSTALL := $(DOTFILES)/install.sh

# Override: make test CONTAINER_CMD=container  (podman | docker | container)
CONTAINER_CMD ?= $(shell \
	if command -v podman >/dev/null 2>&1; then echo podman; \
	elif command -v docker >/dev/null 2>&1; then echo docker; \
	elif command -v container >/dev/null 2>&1; then echo container; \
	else echo ""; fi)
ifeq ($(CONTAINER_CMD),docker)
CONTAINER_BUILD_CMD := build --platform linux/amd64 --progress plain --rm
else ifeq ($(CONTAINER_CMD),container)
# Apple container: https://github.com/apple/container — no --rm on build; --arch not --platform
CONTAINER_BUILD_CMD := build --progress plain --arch $(ARCHITECTURE)
else
CONTAINER_BUILD_CMD := build --progress plain --rm
endif

.DEFAULT_GOAL := help

# --- install profiles (delegated to install.sh) -----------------------------
.PHONY: macos linux minimal micro asahi
macos: ## Complete macOS setup
	@$(INSTALL) macos
linux: ## Complete Linux setup (with sudo)
	@$(INSTALL) linux
minimal: ## Minimal Linux setup without sudo
	@$(INSTALL) minimal
micro: ## Minimal bash-only setup
	@$(INSTALL) micro
asahi: ## Asahi Linux (Fedora Minimal + Hyprland)
	@$(INSTALL) asahi

.PHONY: doctor after
doctor: ## Report installed binaries and running services
	@$(INSTALL) doctor
after: ## Post-install setup and desktop services
	@$(INSTALL) after

.PHONY: help
help: ## Show this help message
	@echo "#######################################################################"
	@echo "# Dotfiles Installation — see ./install.sh help for components/options"
	@echo "#######################################################################"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*## / {printf "\033[36m  %-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo "#######################################################################"

# --- maintenance helpers ----------------------------------------------------
.PHONY: check
check: ## Run Neovim health check
	@if command -v nvim >/dev/null 2>&1; then \
		nvim -i NONE -c "checkhealth"; \
	else \
		echo "Neovim is not installed" >&2; exit 1; \
	fi

.PHONY: benchmark
benchmark: ## Benchmark Neovim and Zsh startup times
	@if command -v nvim >/dev/null 2>&1; then \
		echo "==> nvim startuptime clean"; \
		nvim --startuptime /tmp/startup-clean.log --clean "+qall" && tail -2 /tmp/startup-clean.log && rm -f /tmp/startup-clean.log; \
		echo "==> nvim startuptime with all plugins"; \
		nvim --startuptime /tmp/startup-full.log "+qall" && tail -2 /tmp/startup-full.log && rm -f /tmp/startup-full.log; \
	else \
		echo "Neovim not available for benchmarking"; \
	fi
	@if command -v zsh >/dev/null 2>&1 ; then \
		echo "==> zsh startuptime"; \
		zsh $(DOTFILES)/autoloaded/bench_zsh; \
	fi

.PHONY: format
format: ## Format Lua files with stylua
	@if command -v stylua >/dev/null 2>&1; then \
		stylua -v -f $(DOTFILES)/.stylua.toml $$(find $(DOTFILES) -type f -name '*.lua' ! -name 'colors.lua' 2>/dev/null) || true; \
	else \
		echo "stylua not installed"; \
	fi

.PHONY: test
test: ## Test installation in a container (podman|docker|macOS container)
	@if [ -z "$(CONTAINER_CMD)" ]; then echo "No container runtime (podman/docker/container)" >&2; exit 1; fi
	@echo "==> Testing linux installation with $(CONTAINER_CMD)"
ifeq ($(CONTAINER_CMD),container)
	@container system start
endif
ifeq ($(NOSUDO), 1)
	$(CONTAINER_CMD) $(CONTAINER_BUILD_CMD) -t dotfiles -f $(DOTFILES)/docker/Dockerfile $(PWD)
	-$(CONTAINER_CMD) rm -f maketest 2>/dev/null || true
	# Override CMD (/bin/bash): detached bash exits immediately → --rm deletes container before exec
	$(CONTAINER_CMD) run --name maketest --detach --rm dotfiles:latest sleep infinity
	# No -t: apple container fails exec when make has no pty ("fd is not a pty")
	$(CONTAINER_CMD) exec maketest /bin/bash -c "make NOSUDO=$(NOSUDO) minimal"
else
	$(CONTAINER_CMD) $(CONTAINER_BUILD_CMD) -t dotfiles_sudo -f $(DOTFILES)/docker/sudoer.Dockerfile $(PWD)
	-$(CONTAINER_CMD) rm -f maketest_sudo 2>/dev/null || true
	$(CONTAINER_CMD) run --name maketest_sudo --detach --rm dotfiles_sudo:latest sleep infinity
	$(CONTAINER_CMD) exec maketest_sudo /bin/bash -c "make linux"
endif
	@echo "==> Container can now be shut down (container stop <name>; apple: container system stop)"

.PHONY: uninstall
uninstall: ## Remove installed dotfiles and configurations
	-@rm -f $(HOME)/.zshrc
	-@rm -f $(HOME)/.zshenv
	-@rm -f $(HOME)/.zprofile
	-@rm -f $(HOME)/.zlogin
	-@rm -f $(HOME)/.tmux.conf
	-@rm -f $(HOME)/.wgetrc
	-@rm -f $(HOME)/.curlrc
	-@rm -f $(HOME)/.latexmkrc
	-@rm -f $(HOME)/.gitignore
	-@rm -f $(HOME)/.gitconfig
	-@rm -rf $(HOME)/.config/htop
	-@rm -rf $(HOME)/.config/btop
	-@rm -rf $(HOME)/.config/nvim
	-@rm -rf $(HOME)/.config/fastfetch
	-@rm -rf $(HOME)/.config/ghostty
ifeq ($(OSTYPE), Darwin)
	-@launchctl bootout gui/$(shell id -u) $(HOME)/Library/LaunchAgents/git.frank.sketchybar-top.plist 2>/dev/null || true
	-@launchctl bootout gui/$(shell id -u) $(HOME)/Library/LaunchAgents/git.frank.sketchybar-island.plist 2>/dev/null || true
	-@rm -f $(HOME)/Library/LaunchAgents/git.frank.sketchybar-top.plist
	-@rm -f $(HOME)/Library/LaunchAgents/git.frank.sketchybar-island.plist
	-@rm -rf $(HOME)/.config/skhd
	-@rm -rf $(HOME)/.config/sketchybar
	-@rm -rf $(HOME)/.config/sketchybar-top
	-@rm -rf $(HOME)/.config/sketchybar-island
	-@rm -rf $(HOME)/.config/sioyek
	-@rm -rf $(HOME)/.config/yabai
	-@rm -rf $(HOME)/.config/borders
	-@sudo battery uninstall 2>/dev/null || true
endif
