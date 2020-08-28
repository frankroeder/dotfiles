SHELL := /bin/bash
DOTFILES := $(PWD)
PATH := $(PATH):/usr/local/bin:/usr/local/sbin:/usr/bin:$(HOME)/bin:/$(HOME)/.local/bin

.DEFAULT_GOAL := help

.PHONY: macos
macos: sudo directories macos homebrew misc zsh nvim git npm
	@zsh -i -c "fast-theme free"

.PHONY: linux
linux: sudo directories _linux git zsh misc nvim

.PHONY: minimal
minimal: _minimal git misc nvim

.PHONY: help
help:
	@echo "######################################################################"
	@echo "macos    	-- macos setup"
	@echo "linux    	-- full linux setup"
	@echo "minimal   	-- minimal linux setup for servers without root privilege"
	@echo "nvim     	-- nvim setup with plugins, snippets and runtimes"
	@echo "homebrew 	-- brew packages and casks of Brewfile"
	@echo "npm      	-- npm packages"
	@echo "zsh      	-- symlinks for zsh"
	@echo "git      	-- gitconfigs, ignore and completion"
	@echo "uninstall	-- remove symlinks"
	@echo "######################################################################"

.PHONY: sudo
sudo:
	@echo -e "\033[1m\033[34m==> Installation with sudo required\033[0m"
	sudo -v
	@while true; do sudo -n true; sleep 300; kill -0 "$$" || exit; done 2>/dev/null &

.PHONY: homebrew
homebrew:
	@echo -e "\033[1m\033[34m==> Installing brew if not already present\033[0m"
	@which brew || curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install | ruby
	@echo -e "\033[1m\033[34m==> Installing brew formulas\033[0m"
	@brew bundle --file="$(DOTFILES)/Brewfile"
	@brew cleanup
	-brew doctor

.PHONY: misc
misc:
	@echo -e "\033[1m\033[34m==> Installing misc\033[0m"
	@ln -sfv $(DOTFILES)/wgetrc $(HOME)/.wgetrc
	@ln -sfv $(DOTFILES)/curlrc $(HOME)/.curlrc
	@ln -sfv $(DOTFILES)/tmux/tmux.conf $(HOME)/.tmux.conf
	@ln -sfv $(DOTFILES)/latexmkrc $(HOME)/.latexmkrc
	@pip3 install -r $(DOTFILES)/python/requirements.txt
	@which ipython && ipython -c exit && ln -sfv $(DOTFILES)/python/ipython_config.py $(HOME)/.ipython/profile_default/

.PHONY: zsh
zsh:
	@echo -e "\033[1m\033[34m==> Installing zsh and tools\033[0m"
	@antibody bundle < $(DOTFILES)/antibody/bundles.txt > $(HOME)/.zsh/zsh_plugins.sh
	@ln -sfv $(DOTFILES)/zsh/zshrc $(HOME)/.zshrc;
	@ln -sfv $(DOTFILES)/zsh/zlogin $(HOME)/.zlogin;
	@ln -sfv $(DOTFILES)/zsh/zshenv $(HOME)/.zshenv;
	@ln -sfv $(DOTFILES)/zsh/zprofile $(HOME)/.zprofile;
	@$(SHELL) $(DOTFILES)/autoloaded/switch_zsh
	@source $(HOME)/.zshrc

.PHONY: npm
npm:
	@echo -e "\033[1m\033[34m==> Installing npm packages\033[0m"
	@npm i -g npm@latest
	@npm i -g typescript
	@npm i -g eslint
	@npm i -g neovim
	@npm i -g typescript-language-server
	@npm i -g vscode-html-languageserver-bin
	@npm i -g vscode-css-languageserver-bin

.PHONY: nvim
nvim:
	@echo -e "\033[1m\033[34m==> Installing nvim dependencies\033[0m"
	@nvim +"call mkdir(stdpath('config'), 'p')" +qall
	@rm -rfv $(HOME)/.config/nvim
	@ln -sfv $(DOTFILES)/nvim $(HOME)/.config
	@if [ -x "$(command -v go)" ]; then GO111MODULE=on go get golang.org/x/tools/gopls@latest; fi
	-nvim -es -u $(DOTFILES)/nvim/init.vim -i NONE -c "PlugInstall" -c "qa"

git:
	@echo -e "\033[1m\033[34m==> Installing stuff for git\033[0m"
	@curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o $(HOME)/.git-completion.bash
	@ln -sfv $(DOTFILES)/git/gitconfig $(HOME)/.gitconfig
	@ln -sfv $(DOTFILES)/git/gitignore $(HOME)/.gitignore

directories:
	@echo -e "\033[1m\033[34m==> Creating directories\033[0m"
	mkdir -p $(HOME)/.zsh
	mkdir -p $(HOME)/.config/htop
	mkdir -p $(HOME)/tmp
	mkdir -p $(HOME)/.Trash

.PHONY: _minimal
_minimal:
	ln -sfv $(DOTFILES)/bash_profile ~/.bash_profile;
	ln -sfv $(DOTFILES)/bash_logout ~/.bash_logout;
	ln -sfv $(DOTFILES)/bashrc ~/.bashrc;

.PHONY: _linux
_linux:
	@echo -e "\033[1m\033[34m==> Installing linux packages\033[0m"
	@bash $(DOTFILES)/linux/apt.sh
	@git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf; ~/.fzf/install --all --no-bash --no-zsh --no-fish
	@curl -sfL git.io/antibody | sh -s - -b /usr/local/bin
	@ln -sfv $(DOTFILES)/htop/server $(HOME)/.config/htop/htoprc

.PHONY: _macos
_macos:
	@echo -e "\033[1m\033[34m==> Configure macos and applications\033[0m"
	if [ -n "$(xcode-select -p)" ]; then xcode-select --install; xcodebuild -license accept; fi
	@mkdir -p $(HOME)/screens
	@bash $(DOTFILES)/macos/main.bash
	@which airport || sudo ln -s /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport /usr/local/bin/airport
	@which alacritty || sudo ln -s /Applications/Alacritty.app/Contents/MacOS/alacritty /usr/local/bin/alacritty
	@ln -sfv $(DOTFILES)/alacritty.yml $(HOME)/.config/alacritty/
	(cd $(DOTFILES)/bin && /usr/bin/swiftc $(DOTFILES)/scripts/now_playing.swift)
	-which osx-cpu-temp || bash $(DOTFILES)/scripts/osx_cpu_temp.sh
	@swift package completion-tool generate-zsh-script > $(HOME)/.zsh/completion/_swift
	-which sourcekit-lsp || bash $(DOTFILES)/scripts/sourcekit-lsp.sh
	@ln -sfv $(DOTFILES)/htop/personal $(HOME)/.config/htop/htoprc

.PHONY: uninstall
uninstall:
	rm $(HOME)/.zshrc
	rm $(HOME)/.zshenv
	rm $(HOME)/.zprofile
	rm $(HOME)/.zsh/zsh_plugins.sh
	rm $(HOME)/.tmux.conf
	rm $(HOME)/.wgetrc
	rm $(HOME)/.curlrc
	rm $(HOME)/.latexmkrc
	rm $(HOME)/.gitignore
	rm $(HOME)/.gitconfig

.PHONY: test
test: maketest

.PHONY: maketest
maketest:
	@echo "Testing linux installation"
	@docker build --rm -t dotfiles ${PWD}
	@docker run -it --rm --name maketest -d dotfiles:latest
	@docker exec -it maketest /bin/bash -c "cd ${PWD}; make linux"
	@echo "Container can now be shut down"
