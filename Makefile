SHELL := /bin/zsh
DOTFILES_DIR := ~/.dotfiles

.PHONY: all help homebrew misc zsh macos nvim git npm uninstall

all: sudo macos homebrew misc zsh nvim git npm

.DEFAULT_GOAL := help

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

sudo:
	@echo -e "\033[1m\033[34m==> Installation with sudo required\033[0m"
	sudo -v
	while true; do sudo -n true; sleep 300; kill -0 "$$" || exit; done 2>/dev/null &

homebrew:
	@echo -e "\033[1m\033[34m==> Installing brew if not already present\033[0m"
	which brew || curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install | ruby
	@echo -e "\033[1m\033[34m==> Installing brew formulas\033[0m"
	brew bundle --file=$(DOTFILES_DIR)/Brewfile

misc:
	@echo -e "\033[1m\033[34m==> Installing misc\033[0m"
	ln -sfv $(DOTFILES_DIR)/alacritty.yml ~/.config/alacritty/
	ln -sfv $(DOTFILES_DIR)/wgetrc ~/.wgetrc
	ln -sfv $(DOTFILES_DIR)/curlrc ~/.curlrc
	ln -sfv $(DOTFILES_DIR)/tmux/tmux.conf ~/.tmux.conf
	ln -sfv $(DOTFILES_DIR)/htoprc ~/.config/htop/htoprc
	ln -sfv $(DOTFILES_DIR)/latexmkrc ~/.latexmkrc

zsh:
	@echo -e "\033[1m\033[34m==> Installing zsh and tools\033[0m"
	which antibody || curl -sL git.io/antibody | sh -s
	antibody bundle < $(DOTFILES_DIR)/antibody/bundles.txt > ~/.zsh_plugins.sh
	ln -sfv $(DOTFILES_DIR)/zsh/zshrc ~/.zshrc;
	ln -sfv $(DOTFILES_DIR)/zsh/zshenv ~/.zshenv;
	ln -sfv $(DOTFILES_DIR)/zsh/zprofile ~/.zprofile;
	sudo sh -c "echo $(which zsh) >> /etc/shells"
	bash $(DOTFILES_DIR)/autoloaded/switch_zsh
	source ~/.zshrc
	fast-theme free

npm:
	@echo -e "\033[1m\033[34m==> Installing npm packages\033[0m"
	npm i -g npm@latest
	npm i -g typescript
	npm i -g eslint
	ln -sfv $(DOTFILES_DIR)/eslintrc ~/.eslintrc

nvim:
	@echo -e "\033[1m\033[34m==> Installing nvim dependencies\033[0m"
	nvim +PlugInstall +qall
	nvim +"call mkdir(stdpath('config'), 'p')" +qall
	ln -sfv $(DOTFILES_DIR)/vim/init.vim ~/.config/nvim/
	ln -sfv $(DOTFILES_DIR)/vim/snips ~/.config/nvim/
	ln -sfv $(DOTFILES_DIR)/vim/pythonx  ~/.config/nvim/
	ln -sfv $(DOTFILES_DIR)/vim/spell  ~/.config/nvim/
	ln -sfv $(DOTFILES_DIR)/vim/colors  ~/.config/nvim/
	pip install setuptools
	pip install neovim
	pip install unidecode

git:
	@echo -e "\033[1m\033[34m==> Installing stuff for git\033[0m"
	curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o ~/.git-completion.bash
	ln -sfv $(DOTFILES_DIR)/git/gitconfig ~/.gitconfig
	ln -sfv $(DOTFILES_DIR)/git/gitignore ~/.gitignore

macos:
	@echo -e "\033[1m\033[34m==> Configure macos and applications\033[0m"
	if [ -n "$(xcode-select -p)" ]; then xcode-select --install; xcodebuild -license accept; fi
	mkdir -p $(HOME)/screens
	bash $(DOTFILES_DIR)/macos/main.bash
	which airport || sudo ln -s /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport /usr/local/bin/airport

uninstall:
	rm ~/.zshrc
	rm ~/.zshenv
	rm ~/.zprofile
	rm ~/.zsh_plugins.sh
	rm ~/.tmux.conf
	rm ~/.wgetrc
	rm ~/.curlrc
	rm ~/.latexmkrc
	rm ~/.gitignore
	rm ~/.gitconfig

test:
	@echo -e "\033[1m\033[34m==> Check if commands are available\033[0m"
	which brew && which git && which npm && which nvim && which zsh \
		&& which pip && which airport && which antibody || exit 1
