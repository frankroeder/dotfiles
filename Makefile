SHELL := /bin/bash
DOTFILES := $(PWD)
OSTYPE := $(shell uname -s)
ARCHITECTURE := $(shell uname -m)
DEVNUL := /dev/null
WHICH := which

PATH := $(PATH):/usr/local/bin:/usr/local/sbin:/usr/bin:$(HOME)/bin:/$(HOME)/.local/bin:$(HOME)/.local/nodejs/bin:$(HOME)/miniforge3/bin
ifeq ($(ARCHITECTURE), arm64)
DOCKER_BUILD_CMD := build --platform linux/amd64 --progress plain --rm
PATH := $(PATH):/opt/homebrew/bin:/opt/homebrew/sbin
else
DOCKER_BUILD_CMD := build --progress plain --rm
endif

ifeq ($(OSTYPE), Darwin)
PYOS := MacOSX
else
PYOS := $(OSTYPE)
endif

DEFAULT_GOAL := help

.PHONY: macos
macos: sudo directories homebrew _macos zsh python misc nvim _git node
	@$(SHELL) $(DOTFILES)/autoloaded/switch_zsh
	@zsh -i -c "fast-theme free"
	@compaudit | xargs chmod g-w

.PHONY: linux
linux: sudo directories _linux _git zsh python misc node nvim
	@$(SHELL) $(DOTFILES)/autoloaded/switch_zsh

.PHONY: minimal
minimal: directories _linux _git zsh python misc node nvim

.PHONY: help
help:
	@echo "#######################################################################"
	@printf "%s\n" "Targets:"
	@grep -E '^[a-zA-Z0-9_-]+:.*' Makefile \
	| grep -v 'help:' \
	| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m  %-15s\033[0m %s\n", $$1, $$2}' \
	| sed 's/:$///g'
	@echo "#######################################################################"

.PHONY: sudo
sudo:
	@echo -e "\033[1m\033[34m==> Installation with sudo required\033[0m"
	sudo -v
	@while true; do sudo -n true; sleep 1200; kill -0 "$$" || exit; done 2>/dev/null &

.PHONY: homebrew
homebrew:
	@echo -e "\033[1m\033[34m==> Installing brew if not already present\033[0m"
ifeq ($(ARCHITECTURE), arm64)
	@echo -e "\033[1m\033[32m==> Installing rosetta for non-native apps \033[0m"
	@if [ ! -d "/usr/libexec/rosetta" ]; then softwareupdate --install-rosetta --agree-to-license; fi
endif
ifeq ($(shell ${WHICH} brew 2>${DEVNUL}),)
	@$(SHELL) -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
endif
	@echo -e "\033[1m\033[34m==> Installing brew formulas\033[0m"
	@brew bundle --file="$(DOTFILES)/Brewfile"
	@brew cleanup
	-brew doctor

.PHONY: python
CONDA_RELEASE := Miniforge3-$(PYOS)-$(ARCHITECTURE)
CONDA_HOME := $(HOME)/miniforge3
python:
ifeq "$(wildcard $(CONDA_HOME))" ""
	@echo -e "\033[1m\033[34m==> Downloading $(CONDA_RELEASE) ...\033[0m"
	@curl -fsSLO https://github.com/conda-forge/miniforge/releases/latest/download/$(CONDA_RELEASE).sh
	@bash "$(CONDA_RELEASE).sh" -b -p $(CONDA_HOME)
	@rm "$(CONDA_RELEASE).sh"
endif
	@conda init "$(shell basename ${SHELL})"
	@conda env update --file $(DOTFILES)/python/environment.yaml
	@conda install pytorch -n base -c pytorch -y
	@conda install scipy -n base -y
ifeq ($(shell ${WHICH} ipython 2>${DEVNUL}),)
	@ipython -c exit && ln -sfv $(DOTFILES)/python/ipython_config.py $(HOME)/.ipython/profile_default/
endif

.PHONY: misc
misc:
	@echo -e "\033[1m\033[34m==> Installing misc\033[0m"
ifeq ($(shell ${WHICH} fzf 2>${DEVNUL}),)
	git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf; ~/.fzf/install --bin
endif
	@ln -sfv $(DOTFILES)/wgetrc $(HOME)/.wgetrc
	@ln -sfv $(DOTFILES)/curlrc $(HOME)/.curlrc
	@ln -sfv $(DOTFILES)/tmux/tmux.conf $(HOME)/.tmux.conf
	@ln -sfv $(DOTFILES)/latexmkrc $(HOME)/.latexmkrc

.PHONY: zsh
zsh:
	@echo -e "\033[1m\033[34m==> Installing zsh and tools\033[0m"
	@ln -sfv $(DOTFILES)/zsh/zshrc $(HOME)/.zshrc
	@ln -sfv $(DOTFILES)/zsh/zlogin $(HOME)/.zlogin
	@ln -sfv $(DOTFILES)/zsh/zshenv $(HOME)/.zshenv
	@ln -sfv $(DOTFILES)/zsh/zprofile $(HOME)/.zprofile
	@. $(HOME)/.zshrc

.PHONY: node
node:
	@echo -e "\033[1m\033[34m==> Installing node and npm packages\033[0m"
ifeq ($(shell ${WHICH} node 2>${DEVNUL}),)
	bash $(DOTFILES)/scripts/nodejs.sh
endif
	@npm i --location=global npm@latest
	@npm i --location=global eslint
	@npm i --location=global neovim

.PHONY: nvim
nvim:
	@echo -e "\033[1m\033[34m==> Installing nvim dependencies\033[0m"
	@nvim "+call mkdir(stdpath('config'), 'p')" +qall
	@rm -rfv $(HOME)/.config/nvim
	@ln -sfv $(DOTFILES)/nvim $(HOME)/.config
	@nvim --headless "+Lazy! sync" +qa

_git:
	@echo -e "\033[1m\033[34m==> Installing stuff for git\033[0m"
	@curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o $(HOME)/.git-completion.bash
	@ln -sfv $(DOTFILES)/git/gitconfig $(HOME)/.gitconfig
	@ln -sfv $(DOTFILES)/git/gitignore $(HOME)/.gitignore

.PHONY: after
after:
	@echo -e "\033[1m\033[34m==> \033[0m"
	@bash $(DOTFILES)/git/setup.sh
	@if [ "$(OSTYPE)" == "Linux" ]; then bash $(DOTFILES)/linux/apt.sh "desktop"; fi
	@nvim -i NONE -u $(DOTFILES)/nvim/init.vim -c "TSUpdate" -c "quitall"
ifeq ($(OSTYPE), Darwin)
	@sudo yabai --install-sa
	@brew services start yabai
	@brew services start skhd
	@brew services start sketchybar
endif

directories:
	@echo -e "\033[1m\033[34m==> Creating directories\033[0m"
	mkdir -p $(HOME)/config
	mkdir -p $(HOME)/.zsh
	mkdir -p $(HOME)/.config/htop
	mkdir -p $(HOME)/tmp
	mkdir -p $(HOME)/.Trash
	mkdir -p $(HOME)/Downloads


.PHONY: micro
micro: _backup _bash
	ln -sfv $(DOTFILES)/bash/tmux.conf $(HOME)/.tmux.conf
	ln -sfv $(DOTFILES)/bash/vimrc $(HOME)/.vimrc
	ln -sfv $(DOTFILES)/htop/server $(HOME)/.htoprc
	mkdir -p ~/.Trash

_bash:
	ln -sfv $(DOTFILES)/bash/bash_profile $(HOME)/.bash_profile;
	ln -sfv $(DOTFILES)/bash/bashrc $(HOME)/.bashrc;
	ln -sfv $(DOTFILES)/bash/bash_prompt $(HOME)/.bash_prompt;
	ln -sfv $(DOTFILES)/bash/bash_logout $(HOME)/.bash_logout;
	ln -sfv $(DOTFILES)/bash/bash_aliases ~/.bash_aliases
	ln -sfv $(DOTFILES)/bash/bash_functions ~/.bash_functions

_backup:
	mkdir -p $(HOME)/old_dots
	mv $(HOME)/.bash* $(HOME)/old_dots/ || echo "No .bash* found"
	mv $(HOME)/.profile $(HOME)/old_dots/ || echo "No .profile found"
	mv $(HOME)/.vimrc $(HOME)/old_dots/ || echo "No .vimrc found"
	mv $(HOME)/.tmux.conf $(HOME)/old_dots/ || echo "No .tmux.conf found"
	mv $(HOME)/.htoprc $(HOME)/old_dots/ || echo "No .htoprc found"

.PHONY: _linux
_linux:
	@echo -e "\033[1m\033[34m==> Installing linux basis\033[0m"
	@mkdir -p $(HOME)/bin
	@mkdir -p $(HOME)/.local/bin
	@mkdir -p $(HOME)/Uploads
	if [ -z $(NOSUDO) ]; then bash $(DOTFILES)/linux/apt.sh "default"; fi
	@ln -sfv $(DOTFILES)/htop/server $(HOME)/.config/htop/htoprc
ifeq ($(shell ${WHICH} nvim 2>${DEVNUL}),)
	if [ -z $(NOSUDO) ]; then bash $(DOTFILES)/scripts/nvim.sh "src"; else bash $(DOTFILES)/scripts/nvim.sh "binary"; fi
endif
ifeq ($(shell ${WHICH} tree-sitter 2>${DEVNUL}),)
	@bash $(DOTFILES)/scripts/tree-sitter.sh
endif
ifeq ($(shell ${WHICH} nvidia-smi 2>${DEVNUL}),)
	@pip install nvitop
endif

.PHONY: _macos
_macos:
	@echo -e "\033[1m\033[34m==> Configure macos and applications\033[0m"
	if [ -n "$(xcode-select -p)" ]; then sudo xcode-select --install; sudo xcodebuild -license accept; fi
	@mkdir -p $(HOME)/screens
	@bash $(DOTFILES)/macos/main.bash
	@mkdir -p $(HOME)/.config/alacritty
	@ln -sfv $(DOTFILES)/yabai $(HOME)/.config/yabai
	@ln -sfv $(DOTFILES)/skhd $(HOME)/.config/skhd
	@ln -sfv $(DOTFILES)/sketchybar $(HOME)/.config/sketchybar
ifeq ($(shell ${WHICH} airport 2>${DEVNUL}),)
	@sudo ln -s /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport /usr/local/bin/airport
endif
ifeq ($(shell ${WHICH} alacritty 2>${DEVNUL}),)
	@sudo ln -s /Applications/Alacritty.app/Contents/MacOS/alacritty /usr/local/bin/alacritty
endif
	@ln -sfv $(DOTFILES)/alacritty.yml $(HOME)/.config/alacritty/
ifeq ($(shell ${WHICH} sioyek 2>${DEVNUL}),)
	@sudo ln -s /Applications/sioyek.app/Contents/MacOS/sioyek /usr/local/bin/sioyek
endif
	@ln -sfv $(DOTFILES)/sioyek $(HOME)/.config/sioyek
ifeq ($(ARCHITECTURE), x86_64)
	@bash $(DOTFILES)/scripts/osx_cpu_temp.sh
endif
	@swift package completion-tool generate-zsh-script > $(HOME)/.zsh/completion/_swift
ifeq ($(shell ${WHICH} sourcekit-lsp 2>${DEVNUL}),)
	@bash $(DOTFILES)/scripts/sourcekit-lsp.sh
endif
	@ln -sfv $(DOTFILES)/htop/personal $(HOME)/.config/htop/htoprc
	@if [ ! -d "$(HOME)/.config/alacritty/catppuccin" ]; then git clone https://github.com/catppuccin/alacritty.git $(HOME)/.config/alacritty/catppuccin; fi

.PHONY: check
check:
	@nvim -i NONE -c "checkhealth"

.PHONY: benchmark
benchmark:
	@echo -e "\033[1m\033[34m==> nvim startuptime clean\033[0m"
	@nvim --startuptime startup.log --clean "+qall" && cat startup.log | sort --key=2 --reverse && rm -f startup.log
	@echo -e "\033[1m\033[34m==> nvim startuptime with all plugins\033[0m"
	@nvim --startuptime startup.log "+qall" && cat startup.log | sort --key=2 --reverse && rm -f startup.log
	@echo -e "\033[1m\033[34m==> zsh startuptime\033[0m"
	@zsh $(DOTFILES)/autoloaded/bench_zsh

.PHONY: format
format:
	@cd $(DOTFILES)/nvim
	@stylua -f $(DOTFILES)/nvim/.stylua.toml **/*.lua

.PHONY: uninstall
uninstall:
	rm $(HOME)/.zshrc
	rm $(HOME)/.zshenv
	rm $(HOME)/.zprofile
	rm $(HOME)/.tmux.conf
	rm $(HOME)/.wgetrc
	rm $(HOME)/.curlrc
	rm $(HOME)/.latexmkrc
	rm $(HOME)/.gitignore
	rm $(HOME)/.gitconfig

.PHONY: test
test:
	@echo "Testing linux installation on ${OSTYPE}"
ifeq ($(NOSUDO), 1)
		@docker $(DOCKER_BUILD_CMD) -t dotfiles ${PWD} -f $(DOTFILES)/docker/Dockerfile;
		@docker run -it --rm --name maketest -d dotfiles:latest;
		@docker exec -it maketest /bin/bash -c "make NOSUDO=$(NOSUDO) minimal";
else
		@docker $(DOCKER_BUILD_CMD) -t dotfiles_sudo ${PWD} -f $(DOTFILES)/docker/sudoer.Dockerfile;
		@docker run -it --rm --name maketest_sudo -d dotfiles_sudo:latest;
		@docker exec -it maketest_sudo /bin/bash -c "make linux";
endif
	@echo "Container can now be shut down"
