SHELL := /bin/zsh
DOTFILES_DIR := ~/.dotfiles
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
	@brew bundle --file="$(DOTFILES_DIR)/Brewfile"
	@brew cleanup
	-brew doctor

.PHONY: misc
misc:
	@echo -e "\033[1m\033[34m==> Installing misc\033[0m"
	@ln -sfv $(DOTFILES_DIR)/alacritty.yml ~/.config/alacritty/
	@ln -sfv $(DOTFILES_DIR)/wgetrc ~/.wgetrc
	@ln -sfv $(DOTFILES_DIR)/curlrc ~/.curlrc
	@ln -sfv $(DOTFILES_DIR)/tmux/tmux.conf ~/.tmux.conf
	@ln -sfv $(DOTFILES_DIR)/htoprc ~/.config/htop/htoprc
	@ln -sfv $(DOTFILES_DIR)/latexmkrc ~/.latexmkrc
	(cd $(DOTFILES_DIR)/tmux/bin && /usr/bin/swiftc $(DOTFILES_DIR)/scripts/now_playing.swift)
	@which osx-cpu-temp || bash $(DOTFILES_DIR)/scripts/install_osx_cpu_temp.sh

.PHONY: zsh
zsh:
	@echo -e "\033[1m\033[34m==> Installing zsh and tools\033[0m"
	@which antibody || curl -sL git.io/antibody | sh -s
	@antibody bundle < $(DOTFILES_DIR)/antibody/bundles.txt > ~/.zsh/zsh_plugins.sh
	@ln -sfv $(DOTFILES_DIR)/zsh/zshrc ~/.zshrc;
	@ln -sfv $(DOTFILES_DIR)/zsh/zlogin ~/.zlogin;
	@ln -sfv $(DOTFILES_DIR)/zsh/zshenv ~/.zshenv;
	@ln -sfv $(DOTFILES_DIR)/zsh/zprofile ~/.zprofile;
	@sudo sh -c "echo $(which zsh) >> /etc/shells"
	@bash $(DOTFILES_DIR)/autoloaded/switch_zsh
	@source ~/.zshrc
	@zsh -i -c "fast-theme free"

.PHONY: npm
npm:
	@echo -e "\033[1m\033[34m==> Installing npm packages\033[0m"
	@npm i -g npm@latest
	@npm i -g typescript
	@npm i -g eslint
	@npm i -g neovim
	@ln -sfv $(DOTFILES_DIR)/eslintrc ~/.eslintrc

.PHONY: nvim
nvim:
	@echo -e "\033[1m\033[34m==> Installing nvim dependencies\033[0m"
	@nvim +PlugInstall +qall
	@nvim +"call mkdir(stdpath('config'), 'p')" +qall
	@ln -sfv $(DOTFILES_DIR)/vim/init.vim ~/.config/nvim/
	@ln -sfv $(DOTFILES_DIR)/vim/plugin ~/.config/coc/
	@ln -sfv $(DOTFILES_DIR)/vim/ultisnips ~/.config/coc/
	@ln -sfv $(DOTFILES_DIR)/vim/pythonx  ~/.config/nvim/
	@ln -sfv $(DOTFILES_DIR)/vim/spell  ~/.config/nvim/
	@ln -sfv $(DOTFILES_DIR)/vim/colors  ~/.config/nvim/
	@ln -sfv $(DOTFILES_DIR)/vim/ftplugin ~/.config/nvim/
	@ln -sfv $(DOTFILES_DIR)/coc-settings.json ~/.config/nvim/
	GO111MODULE=on go get golang.org/x/tools/gopls@latest
	@which sourcekit-lsp || bash $(DOTFILES_DIR)/scripts/install_sourcekit-lsp.sh
	@python3 -m pip install setuptools neovim unidecode numpy matplotlib
	@python3 -m pip install --user jedi --upgrade

.PHONY: git
git:
	@echo -e "\033[1m\033[34m==> Installing stuff for git\033[0m"
	@curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o ~/.git-completion.bash
	@ln -sfv $(DOTFILES_DIR)/git/gitconfig ~/.gitconfig
	@ln -sfv $(DOTFILES_DIR)/git/gitignore ~/.gitignore

.PHONY: macos
macos:
	@echo -e "\033[1m\033[34m==> Configure macos and applications\033[0m"
	if [ -n "$(xcode-select -p)" ]; then xcode-select --install; xcodebuild -license accept; fi
	if [ ! -d "$(HOME)/screens" ]; then mkdir -p $(HOME)/screens; fi
	if [ ! -d "$(HOME)/tmp" ]; then mkdir -p $(HOME)/tmp; fi
	@bash $(DOTFILES_DIR)/macos/main.bash
	@which airport || sudo ln -s /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport /usr/local/bin/airport
	@which alacritty || sudo ln -s /Applications/Alacritty.app/Contents/MacOS/alacritty /usr/local/bin/alacritty

.PHONY: uninstall
uninstall:
	rm ~/.zshrc
	rm ~/.zshenv
	rm ~/.zprofile
	rm ~/.zsh/zsh_plugins.sh
	rm ~/.tmux.conf
	rm ~/.wgetrc
	rm ~/.curlrc
	rm ~/.latexmkrc
	rm ~/.gitignore
	rm ~/.gitconfig

.PHONY: test
test:
	@echo -e "\033[1m\033[34m==> Check if commands are available\033[0m"
	@which brew && which git && which npm && which nvim && which zsh \
		&& which pip && which airport && which antibody && which vlc \
		&& which alacritty || exit 1
