DOTFILES="$HOME/.dotfiles"
sudo dnf upgrade;
curl -fsSL https://install.danklinux.com | sh;
ln -sfv $DOTFILES/hypr $HOME/.config;

mkdir -p $HOME/config
mkdir -p $HOME/.zsh
mkdir -p $HOME/tmp
mkdir -p $HOME/.Trash
mkdir -p $HOME/Downloads
mkdir -p $HOME/bin

git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --bin;
sudo dnf install neovim uv cargo jq ffmpeg zsh ripgrep;
touch $HOME/.localnvim.lua;
ln -sfv $DOTFILES/nvim $HOME/.config;

ln -sfv $DOTFILES/zsh/zshrc $HOME/.zshrc;
ln -sfv $DOTFILES/zsh/zlogin $HOME/.zlogin;
ln -sfv $DOTFILES/zsh/zshenv $HOME/.zshenv;
ln -sfv $DOTFILES/zsh/zprofile $HOME/.zprofile;
chsh -s "$(command -v zsh)"
source $HOME/.zshrc

curl -fsSL https://claude.ai/install.sh | bash
