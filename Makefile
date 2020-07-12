SHELL := /bin/zsh
DOTFILES := $(PWD)
.DEFAULT_GOAL := help

.PHONY: all
all: sudo macos homebrew misc zsh nvim git npm


.PHONY: help
help:
	@echo "######################################################################"
	@echo "# Processes might get killed by some routines!                       #"
	@echo "######################################################################"
	@echo "all      	-- install all configs"
	@echo "nvim     	-- nvim setup with plugins, snippets and runtimes"
	@echo "homebrew 	-- brew packages and casks of Brewfile"
	@echo "npm      	-- npm packages"
	@echo "nvim     	-- neovim stuff"
	@echo "zsh      	-- symlinks for zsh"
	@echo "git      	-- gitconfigs, ignore and completion"
	@echo "macos    	-- default writes"
	@echo "uninstall	-- remove symlinks"

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
	if [ ! -d "$(HOME)/.zsh" ]; then mkdir -p $(HOME)/.zsh; fi
	@antibody bundle < $(DOTFILES)/antibody/bundles.txt > $(HOME)/.zsh/zsh_plugins.sh
	@ln -sfv $(DOTFILES)/zsh/zshrc $(HOME)/.zshrc;
	@ln -sfv $(DOTFILES)/zsh/zlogin $(HOME)/.zlogin;
	@ln -sfv $(DOTFILES)/zsh/zshenv $(HOME)/.zshenv;
	@ln -sfv $(DOTFILES)/zsh/zprofile $(HOME)/.zprofile;
	@sudo sh -c "echo $(which zsh) >> /etc/shells"
	@bash $(DOTFILES)/autoloaded/switch_zsh
	@zsh -i -c "fast-theme free"
	@source $(HOME)/.zshrc

.PHONY: npm
npm:
	@echo -e "\033[1m\033[34m==> Installing npm packages\033[0m"
	@npm i -g npm@latest
	@npm i -g typescript
	@npm i -g eslint
	@npm i -g neovim
	@npm i -g javascript-typescript-langserver
	@npm i -g vscode-html-languageserver-bin
	@npm i -g vscode-css-languageserver-bin

.PHONY: nvim
nvim:
	@echo -e "\033[1m\033[34m==> Installing nvim dependencies\033[0m"
	@nvim +PlugInstall +qall
	@nvim +"call mkdir(stdpath('config'), 'p')" +qall
	@ln -sfv $(DOTFILES)/nvim $(HOME)/.config
	-which go && GO111MODULE=on go get golang.org/x/tools/gopls@latest

.PHONY: git
git:
	@echo -e "\033[1m\033[34m==> Installing stuff for git\033[0m"
	@curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o $(HOME)/.git-completion.bash
	@ln -sfv $(DOTFILES)/git/gitconfig $(HOME)/.gitconfig
	@ln -sfv $(DOTFILES)/git/gitignore $(HOME)/.gitignore

.PHONY: linux
linux: sudo git misc zsh nvim
	@bash $(DOTFILES)/linux/apt.sh
	@which antibody || curl -sfL git.io/antibody | sh -s - -b $(HOME)/.local/bin
	@git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf; ~/.fzf/install --all --no-bash --no-zsh --no-fish
	@ln -sfv $(DOTFILES)/htop/server $(HOME)/.config/htop/htoprc

.PHONY: macos
macos:
	@echo -e "\033[1m\033[34m==> Configure macos and applications\033[0m"
	if [ -n "$(xcode-select -p)" ]; then xcode-select --install; xcodebuild -license accept; fi
	if [ ! -d "$(HOME)/screens" ]; then mkdir -p $(HOME)/screens; fi
	if [ ! -d "$(HOME)/tmp" ]; then mkdir -p $(HOME)/tmp; fi
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
test:
	@echo "Current directory for dotfiles $(DOTFILES)"
	@echo -e "\033[1m\033[34m==> Check if commands are available\033[0m"
	-which brew
	-which git
	-which nvim
	-which zsh
	-which pip3
	-which antibody
	-which npm
	-which airport
	-which vlc
	-which alacritty
