#!/usr/bin/env bash
# Component install functions for the dotfiles installer.
# Sourced by install.sh after common.sh. Each function is idempotent: symlinks
# are refreshed on every run, installs are skipped when already present.

# --- shared helpers ---------------------------------------------------------

# ensure_tree_sitter : install the tree-sitter CLI when it is not already present.
ensure_tree_sitter() {
  have tree-sitter && return 0
  print_step "Installing tree-sitter"
  bash "$DOTFILES/scripts/tree-sitter.sh"
}

# --- shared components (used by macOS, Linux, Asahi) ------------------------

comp_directories() {
  print_step "Creating directories"
  mkdir -p "$HOME/.config" "$HOME/.zsh" "$HOME/.config/htop" "$HOME/tmp" \
    "$HOME/.Trash" "$HOME/Downloads" "$HOME/bin" "$HOME/.zcompcache"
}

comp_zsh() {
  print_step "Installing zsh and tools"
  if ! have zsh; then
    print_error "Zsh is not installed. Please install it first"
    return 1
  fi
  link_if_exists "$DOTFILES/zsh/zshrc"    "$HOME/.zshrc"
  link_if_exists "$DOTFILES/zsh/zlogin"   "$HOME/.zlogin"
  link_if_exists "$DOTFILES/zsh/zshenv"   "$HOME/.zshenv"
  link_if_exists "$DOTFILES/zsh/zprofile" "$HOME/.zprofile"
  mkdir -p "$HOME/.zsh/completion"
  if have rg; then
    print_step "Generating ripgrep completions"
    rg --generate complete-zsh > "$HOME/.zsh/completion/_rg"
  fi
  if [ -f "$HOME/.zshrc" ]; then
    print_step "Checking zshrc"
    zsh -n "$HOME/.zshrc" || print_warning "zshrc syntax check failed"
  fi
}

comp_git() {
  print_step "Installing stuff for git"
  if [ ! -f "$HOME/.git-completion.bash" ]; then
    print_step "Downloading git completion"
    curl -fsSL https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o "$HOME/.git-completion.bash"
  fi
  link_if_exists "$DOTFILES/git/gitconfig" "$HOME/.gitconfig"
  link_if_exists "$DOTFILES/git/gitignore" "$HOME/.gitignore"
}

comp_python() {
  print_step "Installing python tools"
  if [ "$OSTYPE_UNAME" = "Linux" ] && ! have uv; then
    print_step "Installing uv package manager"
    curl -LsSf https://astral.sh/uv/install.sh | sh
  fi
  if have uv; then
    if have ty; then print_warning "ty already installed"; else uv tool install ty@latest; fi
    if have ipython; then print_warning "ipython already installed"; else uv tool install ipython --with matplotlib --with numpy; fi
  else
    print_warning "uv not available for Python tool installation"
  fi
  have ipython && mkdir -p "$HOME/.ipython/profile_default"
  link_if_exists "$DOTFILES/python/ipython_config.py" "$HOME/.ipython/profile_default/ipython_config.py"
}

comp_misc() {
  print_step "Installing misc"
  if ! have fzf; then
    if [ -d "$HOME/.fzf/.git" ]; then
      print_step "Updating existing fzf checkout"
      git -C "$HOME/.fzf" pull --ff-only
      "$HOME/.fzf/install" --bin
    elif [ -e "$HOME/.fzf" ]; then
      print_warning "$HOME/.fzf already exists but is not a git checkout; skipping fzf clone"
    else
      print_step "Installing fzf"
      git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
      "$HOME/.fzf/install" --bin
    fi
  fi
  link_if_exists "$DOTFILES/wgetrc"         "$HOME/.wgetrc"
  link_if_exists "$DOTFILES/curlrc"         "$HOME/.curlrc"
  link_if_exists "$DOTFILES/tmux/tmux.conf" "$HOME/.tmux.conf"
  replace_with_symlink "$DOTFILES/fastfetch" "$HOME/.config/fastfetch"
  link_if_exists "$DOTFILES/latexmkrc"      "$HOME/.latexmkrc"
  replace_with_symlink "$DOTFILES/btop"     "$HOME/.config/btop"
}

comp_node() {
  print_step "Installing node and npm packages"
  if ! have node; then
    print_step "Installing Node.js"
    bash "$DOTFILES/scripts/nodejs.sh"
  else
    print_warning "Node.js is already installed"
  fi
  if ! have npm; then
    print_warning "npm not available for package installation"
    return 0
  fi
  # Scope global installs to a writable prefix (~/.local) on Linux, global on macOS.
  local scope
  if [ "$OSTYPE_UNAME" = "Linux" ]; then
    mkdir -p "$HOME/.local/bin" "$HOME/.local/lib/node_modules"
    npm config set prefix "$HOME/.local" --location=user 2>/dev/null || true
    scope=(--prefix "$HOME/.local")
  else
    scope=(--location=global)
  fi
  local pkg
  for pkg in eslint neovim; do
    if npm ls "${scope[@]}" "$pkg" >/dev/null 2>&1; then
      print_warning "npm package $pkg already installed"
    else
      print_step "Installing npm package $pkg"
      npm install "${scope[@]}" "$pkg" || print_warning "Failed to install npm package $pkg"
    fi
  done
}

comp_nvim() {
  print_step "Installing nvim dependencies"
  if ! have nvim; then
    print_error "Neovim is not installed. Please install it first"
    return 1
  fi
  touch "$HOME/.localnvim.lua"
  replace_with_symlink "$DOTFILES/nvim" "$HOME/.config/nvim"
  print_step "Syncing Neovim plugins"
  nvim --headless "+lua vim.pack.update()" "+qa"
}

# agent_begin CLI NAME : if CLI is present announce the sync (return 0), else warn.
agent_begin() {
  if have "$1"; then print_step "Syncing $2 agent configuration"; return 0; fi
  print_warning "$2 CLI not installed; skipping $2 agent configuration"
  return 1
}

comp_agents() {
  local nc="${NEXTCLOUD_DIR:-$HOME/Nextcloud/portal}"
  if agent_begin codex Codex; then
    link_if_exists "$nc/AGENTS.md" "$HOME/.codex/AGENTS.md"
    link_first_exists "$HOME/.codex/config.toml" "$nc/codex_config.toml" "$nc/codex_settings.toml"
  fi
  if agent_begin claude Claude; then
    mkdir -p "$HOME/.claude"
    link_if_exists "$nc/AGENTS.md" "$HOME/.claude/CLAUDE.md"
    link_if_exists "$nc/claude_settings.json" "$HOME/.claude/settings.json"
  fi
  if agent_begin gemini Gemini; then
    mkdir -p "$HOME/.gemini"
    link_if_exists "$nc/AGENTS.md" "$HOME/.gemini/GEMINI.md"
    link_if_exists "$nc/gemini_settings.json" "$HOME/.gemini/settings.json"
  fi
  if agent_begin opencode OpenCode; then
    link_if_exists "$nc/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"
  fi
  if agent_begin grok Grok; then
    link_if_exists "$nc/AGENTS.md" "$HOME/.grok/AGENTS.md"
  fi
}

# --- macOS ------------------------------------------------------------------

comp_homebrew() {
  require_macos
  if [ "$ARCHITECTURE" = "arm64" ] && [ ! -d "/usr/libexec/rosetta" ]; then
    print_step "Installing rosetta for non-native apps"
    softwareupdate --install-rosetta --agree-to-license
  fi
  if ! have brew; then
    print_step "Installing Homebrew"
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    print_warning "Homebrew is already installed"
  fi
  print_step "Installing brew formulas"
  brew bundle --file="$DOTFILES/Brewfile"
  brew cleanup
  brew doctor || true
}

comp_macos_apps() {
  require_macos
  print_step "Configure macos and applications"
  if ! xcode-select -p >/dev/null 2>&1; then
    print_step "Installing Xcode command line tools"
    sudo xcode-select --install
    sudo xcodebuild -license accept
  else
    print_warning "Xcode command line tools already installed"
  fi
  mkdir -p "$HOME/screens" "$HOME/.config" "$HOME/Library/Fonts"
  print_step "Running macOS setup script"
  bash "$DOTFILES/macos/main.bash"
  replace_with_symlink "$DOTFILES/sketchybar/bottom" "$HOME/.config/sketchybar"
  replace_with_symlink "$DOTFILES/sketchybar/top"    "$HOME/.config/sketchybar-top"
  replace_with_symlink "$DOTFILES/sketchybar/island" "$HOME/.config/sketchybar-island"
  comp_sketchybar_top
  comp_sketchybar_island
  if [ -f "$HOME/Library/Fonts/sketchybar-app-font.ttf" ]; then
    print_warning "sketchybar app font already installed"
  else
    print_step "Downloading sketchybar font"
    bash "$DOTFILES/scripts/sketchybar_app_font.sh"
  fi
  replace_with_symlink "$DOTFILES/skhd" "$HOME/.config/skhd"
  print_step "Linking LibreWolf config (Asahi settings)"
  mkdir -p "$HOME/Library/Application Support/LibreWolf/librewolf"
  link_if_exists "$DOTFILES/shared/librewolf/librewolf.overrides.cfg" "$HOME/Library/Application Support/LibreWolf/librewolf/librewolf.overrides.cfg"
  local profile
  for profile in "$HOME/Library/Application Support/LibreWolf/Profiles/"*.default*; do
    [ -d "$profile" ] || continue
    mkdir -p "$profile/chrome"
    ln -sfn "$DOTFILES/shared/librewolf/userChrome.css" "$profile/chrome/userChrome.css" || true
  done
  if have sioyek; then
    print_warning "sioyek already installed"
  else
    print_step "Running Sioyek setup"
    zsh "$DOTFILES/scripts/sioyek.sh"
  fi
  replace_with_symlink "$DOTFILES/sioyek" "$HOME/.config/sioyek"
  if have swift; then
    mkdir -p "$HOME/.zsh/completion"
    swift package completion-tool generate-zsh-script > "$HOME/.zsh/completion/_swift" 2>/dev/null || true
  fi
  if ! have sourcekit-lsp; then
    print_step "Installing sourcekit-lsp"
    bash "$DOTFILES/scripts/sourcekit-lsp.sh"
  fi
  if ! have battery; then
    print_step "Installing battery manager"
    curl -fsSL https://raw.githubusercontent.com/actuallymentor/battery/main/setup.sh | bash
    battery maintain 80
  fi
  replace_with_symlink "$DOTFILES/mpv"     "$HOME/.config/mpv"
  replace_with_symlink "$DOTFILES/yabai"   "$HOME/.config/yabai"
  replace_with_symlink "$DOTFILES/borders" "$HOME/.config/borders"
}

# _sketchybar_agent NAME : install and reload the sketchybar-NAME LaunchAgent.
_sketchybar_agent() {
  require_macos
  local name="$1"
  local plist="git.frank.sketchybar-$name.plist"
  local dst="$HOME/Library/LaunchAgents/$plist"
  print_step "Installing sketchybar-$name LaunchAgent"
  mkdir -p "$HOME/Library/LaunchAgents"
  ln -sf /opt/homebrew/bin/sketchybar "/opt/homebrew/bin/sketchybar-$name" 2>/dev/null || true
  link_if_exists "$DOTFILES/sketchybar/$name/$plist" "$dst"
  launchctl bootout gui/"$(id -u)" "$dst" 2>/dev/null || true
  launchctl bootstrap gui/"$(id -u)" "$dst" || print_warning "Failed to bootstrap sketchybar-$name"
}

comp_sketchybar_top()    { _sketchybar_agent top; }
comp_sketchybar_island() { _sketchybar_agent island; }

# --- Linux ------------------------------------------------------------------

comp_linux_base() {
  require_linux
  print_step "Installing linux basis"
  mkdir -p "$HOME/bin" "$HOME/.local/bin" "$HOME/Uploads"
  if [ -z "$NOSUDO" ]; then
    print_step "Installing Linux packages"
    bash "$DOTFILES/linux/apt.sh" "default"
  fi
  link_if_exists "$DOTFILES/htop/server" "$HOME/.config/htop/htoprc"
  if ! have nvim; then
    if [ -z "$NOSUDO" ]; then
      bash "$DOTFILES/scripts/nvim.sh" "source"
    else
      bash "$DOTFILES/scripts/nvim.sh" "binary"
    fi
  fi
  ensure_tree_sitter
}

# --- micro (bash-only, no external tooling) ---------------------------------

comp_backup() {
  print_step "Backing up existing dotfiles"
  mkdir -p "$HOME/old_dots"
  local file target
  for file in .bash_profile .bashrc .bash_prompt .bash_logout .bash_aliases .bash_functions .profile .vimrc .tmux.conf .htoprc; do
    target="$HOME/$file"
    [ -e "$target" ] || [ -L "$target" ] || continue
    # Already one of our symlinks into the repo: leave it, comp_bash refreshes it.
    if [ -L "$target" ] && [[ "$(readlink "$target")" == "$DOTFILES"/* ]]; then
      continue
    fi
    echo "Backing up $file"
    mv "$target" "$HOME/old_dots/" 2>/dev/null || true
  done
}

comp_bash() {
  print_step "Configuring bash dotfiles"
  link_if_exists "$DOTFILES/bash/bash_profile"   "$HOME/.bash_profile"
  link_if_exists "$DOTFILES/bash/bashrc"         "$HOME/.bashrc"
  link_if_exists "$DOTFILES/bash/bash_prompt"    "$HOME/.bash_prompt"
  link_if_exists "$DOTFILES/bash/bash_logout"    "$HOME/.bash_logout"
  link_if_exists "$DOTFILES/bash/bash_aliases"   "$HOME/.bash_aliases"
  link_if_exists "$DOTFILES/bash/bash_functions" "$HOME/.bash_functions"
}

comp_micro() {
  print_step "Setting up micro configuration"
  link_if_exists "$DOTFILES/bash/tmux.conf" "$HOME/.tmux.conf"
  link_if_exists "$DOTFILES/bash/vimrc"     "$HOME/.vimrc"
  link_if_exists "$DOTFILES/htop/server"    "$HOME/.htoprc"
  mkdir -p "$HOME/.Trash"
}

# --- Asahi Linux ------------------------------------------------------------

comp_asahi_system() {
  require_linux
  bash "$DOTFILES/asahi/dnf.sh"
  sudo install -Dm644 "$DOTFILES/asahi/systemd/system/asahi-tty-font.service" /etc/systemd/system/asahi-tty-font.service
  sudo systemctl daemon-reload
  sudo systemctl enable asahi-tty-font.service
  sudo systemctl restart asahi-tty-font.service
  if have brightnessctl; then
    brightnessctl --device='kbd_backlight' set 30% || true
  elif have light; then
    light -s sysfs/leds/kbd_backlight -S 30 || true
  fi
}

comp_asahi_zotero() {
  if [ -x "/opt/zotero/zotero" ]; then
    print_warning "Zotero already installed at /opt/zotero; skipping setup script"
  else
    print_step "Installing Zotero ARM64"
    bash "$DOTFILES/scripts/setup_zotero.sh"
  fi
}

comp_asahi_common() {
  comp_directories
  comp_git
  comp_zsh
  comp_python
  comp_misc
  comp_nvim
  mkdir -p "$HOME/.config/environment.d" "$HOME/.local/share/applications"
  link_if_exists "$DOTFILES/asahi/mimeapps.list" "$HOME/.config/mimeapps.list"
  print_step "Fixing Linux desktop icons"
  bash "$DOTFILES/scripts/fix_linux_desktop_icons.sh"
  ensure_tree_sitter
}

comp_asahi_desktop() {
  comp_asahi_common
  mkdir -p "$HOME/screenshots"
  local script
  for script in "$DOTFILES"/asahi/bin/*; do
    [ -f "$script" ] && chmod +x "$script"
  done
  mkdir -p "$HOME/.config/systemd/user"
  link_if_exists "$DOTFILES/asahi/systemd/user/hyprland-session.target" "$HOME/.config/systemd/user/hyprland-session.target"
  replace_with_symlink "$DOTFILES/asahi/hypr"      "$HOME/.config/hypr"
  replace_with_symlink "$DOTFILES/asahi/quickshell" "$HOME/.config/quickshell"
  replace_with_symlink "$DOTFILES/asahi/ghostty"   "$HOME/.config/ghostty"
  mkdir -p "$HOME/.config/mpv"
  link_if_exists "$DOTFILES/mpv/mpv_asahi.conf" "$HOME/.config/mpv/mpv.conf"
  link_if_exists "$DOTFILES/asahi/environment.d/90-asahi.conf" "$HOME/.config/environment.d/90-asahi.conf"
  mkdir -p "$HOME/.config/librewolf/librewolf"
  link_if_exists "$DOTFILES/shared/librewolf/librewolf.overrides.cfg" "$HOME/.config/librewolf/librewolf/librewolf.overrides.cfg"
  local profile
  for profile in "$HOME"/.librewolf/*.default*; do
    [ -d "$profile" ] || continue
    mkdir -p "$profile/chrome"
    ln -sfn "$DOTFILES/shared/librewolf/userChrome.css" "$profile/chrome/userChrome.css"
  done
  for profile in "$HOME"/.thunderbird/*.default*; do
    [ -d "$profile" ] || continue
    ln -sfn "$DOTFILES/asahi/thunderbird/user.js" "$profile/user.js"
  done
}

comp_asahi_battery_alerts() {
  print_step "Installing Asahi battery alerts"
  DOTFILES="$DOTFILES" bash "$DOTFILES/scripts/asahi-battery-alerts.sh"
}

comp_asahi_wallpapers() {
  local dir="${ASAHI_WALLPAPERS_DIR:-$HOME/Pictures/wallpaper}"
  if [ -d "$dir/.git" ]; then
    print_step "Updating wallpapers"
    git -C "$dir" pull --ff-only || print_warning "Failed to update wallpapers"
  elif [ -e "$dir" ]; then
    print_warning "$dir already exists and is not a git checkout; skipping wallpaper clone"
  else
    print_step "Downloading wallpapers"
    mkdir -p "$HOME/Pictures"
    git clone https://github.com/mylinuxforwork/wallpaper.git "$dir"
  fi
}

# --- shell default / terminal / services -----------------------------------

comp_default_shell() {
  print_step "Switching to Zsh"
  "$DOTFILES/autoloaded/switch_zsh"
}

comp_terminal() {
  if have ghostty; then print_step "Ghostty is available"; else print_warning "Ghostty not installed"; fi
  # Asahi links its own ghostty config; keep it instead of the generic one.
  if [ "$(readlink "$HOME/.config/ghostty" 2>/dev/null)" = "$DOTFILES/asahi/ghostty" ]; then
    echo "Keeping Asahi ghostty config: $HOME/.config/ghostty"
  else
    replace_with_symlink "$DOTFILES/ghostty" "$HOME/.config/ghostty"
  fi
  link_if_exists "$DOTFILES/htop/personal" "$HOME/.config/htop/htoprc"
}

# Post-install: run git setup, TS parsers, and (re)start desktop services.
comp_after() {
  comp_terminal
  print_step "Post-installation setup"
  print_step "Running git setup"
  bash "$DOTFILES/git/setup.sh"
  if [ "$OSTYPE_UNAME" = "Linux" ] && [ -f "$DOTFILES/linux/apt.sh" ] && have apt-get; then
    print_step "Installing Linux desktop packages"
    bash "$DOTFILES/linux/apt.sh" "desktop"
  fi
  if have nvim; then
    print_step "Updating Treesitter parsers"
    nvim -i NONE -u "$DOTFILES/nvim/init.lua" -c "TSUpdate" -c "quitall"
  fi
  if [ "$OSTYPE_UNAME" = "Darwin" ]; then
    comp_services
    comp_agents
  fi
}

# (Re)start macOS desktop services (yabai, skhd, sketchybar). Idempotent: the
# scripting-addition sudoers entry is refreshed (needed after yabai upgrades) but
# services are only started when not already loaded.
comp_services() {
  require_macos
  if have yabai; then
    print_step "Refreshing yabai scripting-addition permissions"
    echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 "$(command -v yabai)" | cut -d ' ' -f 1) $(command -v yabai) --load-sa" | sudo tee /private/etc/sudoers.d/yabai >/dev/null
    sudo yabai --load-sa || print_warning "yabai --load-sa failed"
    if launchd_loaded yabai; then
      print_warning "yabai service already running"
    else
      print_step "Starting yabai service"
      yabai --start-service || print_warning "Failed to start yabai service"
    fi
  fi
  if have skhd; then
    if launchd_loaded skhd; then
      print_warning "skhd service already running"
    else
      print_step "Starting skhd service"
      skhd --start-service || print_warning "Failed to start skhd service"
    fi
  fi
  if have brew; then
    if brew_service_running sketchybar; then
      print_warning "sketchybar service already running"
    else
      print_step "Starting sketchybar service"
      brew services start sketchybar || print_warning "Failed to start sketchybar service"
    fi
  fi
}

# --- doctor: report on binaries and services --------------------------------

comp_doctor() {
  print_step "Checking core binaries"
  local b
  for b in zsh git curl make nvim node npm fzf rg uv tree-sitter; do
    check_bin "$b" || true
  done
  if [ "$OSTYPE_UNAME" = "Darwin" ]; then
    print_step "Checking macOS binaries"
    for b in brew yabai skhd sketchybar ghostty battery sourcekit-lsp; do
      check_bin "$b" || true
    done
    print_step "Checking macOS services"
    report_check "sketchybar service" brew_service_running sketchybar
    report_check "sketchybar-top LaunchAgent" launchd_loaded sketchybar-top
    report_check "sketchybar-island LaunchAgent" launchd_loaded sketchybar-island
    report_check "yabai service" launchd_loaded yabai
    report_check "skhd service" launchd_loaded skhd
  else
    print_step "Checking Asahi/Hyprland binaries"
    for b in Hyprland quickshell qs hypridle hyprlock hyprpaper brightnessctl nmcli bluetoothctl nm-connection-editor nmtui blueman-manager; do
      check_bin "$b" || true
    done
  fi
  print_step "Checking config symlinks"
  local l
  for l in "$HOME/.zshrc" "$HOME/.gitconfig" "$HOME/.gitignore" "$HOME/.tmux.conf" "$HOME/.config/nvim"; do
    check_link "$l"
  done
  if [ "$OSTYPE_UNAME" = "Darwin" ]; then
    for l in "$HOME/.config/sketchybar" "$HOME/.config/skhd" "$HOME/.config/yabai" "$HOME/.config/ghostty"; do
      check_link "$l"
    done
  fi
}
