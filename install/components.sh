#!/usr/bin/env bash
# Component install functions for the dotfiles installer.
# Sourced by install.sh after common.sh. Each function is idempotent: symlinks
# are refreshed on every run, installs are skipped when already present.

# --- shared helpers ---------------------------------------------------------

# ensure_tree_sitter : install the tree-sitter CLI when it is not already present.
ensure_tree_sitter() {
  have tree-sitter && return 0
  print_step "Installing tree-sitter"
  if ! bash "$DOTFILES/scripts/tree-sitter.sh"; then
    print_error "tree-sitter install failed"
    return 1
  fi
}

# --- shared components (used by macOS, Linux, Asahi) ------------------------

comp_directories() {
  print_step "Creating directories"
  mkdir -p "$HOME/.config" "$HOME/.zsh" "$HOME/.config/htop" "$HOME/tmp" \
    "$HOME/.Trash" "$HOME/Downloads" "$HOME/bin" "$HOME/.zcompcache"
}

comp_zsh() {
  print_step "Installing zsh and tools"
  # Link first so a missing binary still leaves a usable config for later installs.
  link_if_exists "$DOTFILES/zsh/zshrc"    "$HOME/.zshrc"
  link_if_exists "$DOTFILES/zsh/zlogin"   "$HOME/.zlogin"
  link_if_exists "$DOTFILES/zsh/zshenv"   "$HOME/.zshenv"
  link_if_exists "$DOTFILES/zsh/zprofile" "$HOME/.zprofile"
  mkdir -p "$HOME/.zsh/completion"
  if ! have zsh; then
    print_error "Zsh is not installed (required for linux/minimal)"
    return 1
  fi
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
    if have ty; then print_ok "ty already installed"; else uv tool install ty@latest; fi
    if have ipython; then print_ok "ipython already installed"; else uv tool install ipython --with matplotlib --with numpy; fi
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
    print_ok "Node.js is already installed"
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
      print_ok "npm package $pkg already installed"
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
  nvim --headless "+lua vim.pack.update()" "+qa" || print_error "nvim plugin sync failed"
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

# --- iCloud private configs (macOS) -----------------------------------------
# Copy machine-local state that must not live in git into CloudDocs/configs.
# Restore fills local gaps; existing local files win; dict-cc is repo-built.

_icloud_configs() {
  printf '%s\n' "$HOME/Library/Mobile Documents/com~apple~CloudDocs/configs"
}

_cp_missing() {
  [ -f "$1" ] && [ ! -e "$2" ] || return 1
  mkdir -p "$(dirname "$2")"
  cp -f "$1" "$2"
}

_cp_to() {
  [ -f "$1" ] || return 0
  mkdir -p "$(dirname "$2")"
  cp -f "$1" "$2"
}

_rsync_ext() {
  mkdir -p "$2"
  rsync -a --exclude '.DS_Store' --exclude '*.icloud' "$1/" "$2/"
}

# Restore missing vicinae files from iCloud, then copy local store.* + json back.
icloud_sync_vicinae() {
  local docs="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
  [ -d "$docs" ] || { print_warning "iCloud Drive not available; skip vicinae configs"; return 0; }

  local cloud="$docs/configs/vicinae"
  local share="$HOME/.local/share/vicinae"
  local cfg="$HOME/.config/vicinae"
  local src dst name restored=0

  print_step "Syncing vicinae private configs with iCloud"
  mkdir -p "$cloud" "$cfg" "$share/extensions"
  brctl download "$cloud" >/dev/null 2>&1 || true

  _cp_missing "$cloud/settings.json" "$cfg/settings.json" && restored=1
  _cp_missing "$cloud/snippets.json" "$share/snippets/snippets.json" && restored=1
  _cp_missing "$cloud/shortcuts.json" "$share/shortcuts/shortcuts.json" && restored=1
  for src in "$cloud/extensions"/store.*; do
    [ -d "$src" ] || continue
    name="${src##*/}"
    dst="$share/extensions/$name"
    [ -d "$dst" ] && continue
    if _rsync_ext "$src" "$dst"; then restored=1; else print_warning "failed to restore $name"; fi
  done

  _cp_to "$cfg/settings.json" "$cloud/settings.json"
  _cp_to "$share/snippets/snippets.json" "$cloud/snippets.json"
  _cp_to "$share/shortcuts/shortcuts.json" "$cloud/shortcuts.json"
  for src in "$share/extensions"/store.*; do
    [ -d "$src" ] || continue
    name="${src##*/}"
    _rsync_ext "$src" "$cloud/extensions/$name" || print_warning "failed to store $name"
  done
  print_ok "vicinae iCloud sync done"

  if [ "$restored" -eq 1 ] && [ "$HOME" = "/Users/${USER}" ] && have vicinae && vicinae ping >/dev/null 2>&1; then
    print_step "Restarting vicinae to pick up restored data"
    vicinae server --replace || print_warning "vicinae server restart failed"
  fi
}

comp_icloud() {
  require_macos
  icloud_sync_vicinae
}

comp_vicinae() {
  require_macos
  print_step "Configuring vicinae"
  mkdir -p "$HOME/.config/vicinae"
  link_if_exists "$DOTFILES/vicinae/dotfiles.json" "$HOME/.config/vicinae/dotfiles.json"
  icloud_sync_vicinae
  local dictcc="$DOTFILES/vicinae/extensions/dict-cc"
  if have vicinae && have npm && [ -f "$dictcc/package.json" ]; then
    print_step "Building vicinae dict-cc extension"
    if ! (cd "$dictcc" && npm install --omit=dev && npx vici build); then
      print_warning "vicinae dict-cc build failed"
    fi
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
    print_ok "Homebrew is already installed"
  fi
  print_step "Installing brew formulas"
  brew bundle --file="$DOTFILES/Brewfile"
  brew cleanup
}

comp_macos_apps() {
  require_macos
  print_step "Configure macos and applications"
  if ! xcode-select -p >/dev/null 2>&1; then
    print_step "Installing Xcode command line tools"
    sudo xcode-select --install
    sudo xcodebuild -license accept
  else
    print_ok "Xcode command line tools already installed"
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
    print_ok "sketchybar app font already installed"
  else
    print_step "Downloading sketchybar font"
    bash "$DOTFILES/scripts/sketchybar_app_font.sh"
  fi
  replace_with_symlink "$DOTFILES/skhd" "$HOME/.config/skhd"
  print_step "Linking LibreWolf config"
  # Official macOS overrides path (not Application Support): https://librewolf.net/docs/settings/
  mkdir -p "$HOME/.librewolf"
  link_if_exists "$DOTFILES/shared/librewolf/librewolf.overrides.cfg" "$HOME/.librewolf/librewolf.overrides.cfg"
  local profile
  for profile in "$HOME/Library/Application Support/LibreWolf/Profiles/"*.default*; do
    [ -d "$profile" ] || continue
    mkdir -p "$profile/chrome"
    ln -sfn "$DOTFILES/shared/librewolf/userChrome.css" "$profile/chrome/userChrome.css" || true
  done
  if have sioyek; then
    print_ok "sioyek already installed"
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
  comp_vicinae
}

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
    bash "$DOTFILES/linux/apt.sh" "default" || print_error "apt package install failed"
  fi
  link_if_exists "$DOTFILES/htop/server" "$HOME/.config/htop/htoprc"
  if ! have nvim; then
    if [ -z "$NOSUDO" ]; then
      bash "$DOTFILES/scripts/nvim.sh" "source" || print_error "nvim source install failed"
    else
      bash "$DOTFILES/scripts/nvim.sh" "binary" || print_error "nvim binary install failed"
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

# Power-button tap ignore + no hibernate. Safe to rerun on a live Hyprland
# session: SIGHUP reloads logind.conf.d; do not restart systemd-logind.
comp_asahi_logind() {
  require_linux
  print_step "Installing Asahi logind drop-ins (ignore power tap, no hibernate)"
  if [ -n "$NOSUDO" ]; then
    print_error "asahi-logind writes /etc/systemd; rerun without --no-sudo"
    exit 1
  fi
  local src_login src_sleep
  src_login="$DOTFILES/asahi/systemd/logind.conf.d/10-asahi-sleep.conf"
  src_sleep="$DOTFILES/asahi/systemd/sleep.conf.d/10-asahi-no-hibernate.conf"
  [ -f "$src_login" ] && [ -f "$src_sleep" ] || {
    print_error "missing Asahi systemd drop-ins under $DOTFILES/asahi/systemd"
    exit 1
  }
  sudo install -Dm644 "$src_login" /etc/systemd/logind.conf.d/10-asahi-sleep.conf
  sudo install -Dm644 "$src_sleep" /etc/systemd/sleep.conf.d/10-asahi-no-hibernate.conf
  if ! cmp -s "$src_login" /etc/systemd/logind.conf.d/10-asahi-sleep.conf; then
    print_error "installed logind drop-in does not match $src_login"
    exit 1
  fi
  # Reload logind.conf.d without restarting the unit (restart would kill the session).
  sudo systemctl kill -s HUP systemd-logind
  local live
  live="$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandlePowerKey 2>/dev/null || true)"
  if printf '%s\n' "$live" | grep -q '"ignore"'; then
    print_ok "HandlePowerKey=ignore (tap ignored; ~10s SMC hold still force-resets)"
  else
    print_error "logind HandlePowerKey is still ${live:-unknown} after SIGHUP"
    exit 1
  fi
}

comp_asahi_system() {
  require_linux
  bash "$DOTFILES/asahi/dnf.sh"
  sudo install -Dm644 "$DOTFILES/asahi/systemd/system/asahi-tty-font.service" /etc/systemd/system/asahi-tty-font.service
  comp_asahi_logind
  sudo systemctl daemon-reload
  sudo systemctl enable asahi-tty-font.service
  sudo systemctl restart asahi-tty-font.service
  # Full panel height beside the notch (appledrm). No-op without that driver.
  if modinfo appledrm >/dev/null 2>&1 && [ ! -f /etc/modprobe.d/asahi-notch.conf ]; then
    print_step "Enabling Asahi notch area (full display height)"
    echo "options appledrm show_notch=1" | sudo tee /etc/modprobe.d/asahi-notch.conf >/dev/null
    if ! have dracut; then
      print_error "dracut not found; cannot rebuild initramfs for appledrm show_notch=1"
      exit 1
    fi
    sudo dracut -f
    print_ok "asahi-notch.conf written; reboot required"
  fi
  # Apple Silicon: early-load Apple HID modules in initramfs to avoid trackpad race on boot.
  if [ "$(uname -m)" = "aarch64" ] && grep -qi apple /proc/device-tree/compatible 2>/dev/null; then
    if [ ! -f /etc/mkinitcpio.conf.d/apple_hid_modules.conf ]; then
      print_step "Early-loading Apple HID modules (trackpad race fix)"
      sudo mkdir -p /etc/mkinitcpio.conf.d
      sudo tee /etc/mkinitcpio.conf.d/apple_hid_modules.conf >/dev/null <<'EOF'
# Load Apple HID before session start — avoids dockchannel-hid rebinding race on Asahi.
for _asahi_apple_hid_module in hid_apple hid_magicmouse; do
  modinfo -k "${KERNELVERSION:-$(uname -r)}" "$_asahi_apple_hid_module" >/dev/null 2>&1 &&
    MODULES+=("$_asahi_apple_hid_module")
done
unset _asahi_apple_hid_module
EOF
      if have dracut; then
        sudo dracut -f
        print_ok "apple_hid_modules.conf written; reboot required"
      else
        print_warning "dracut not found; apple_hid_modules.conf written but initramfs not rebuilt"
      fi
    fi
  fi
  if have brightnessctl; then
    brightnessctl --device='kbd_backlight' set 30% || true
  elif have light; then
    light -s sysfs/leds/kbd_backlight -S 30 || true
  fi
  comp_asahi_charge_limit
}

# udev + oneshot so macsmc charge thresholds are writable and reapplied at boot.
comp_asahi_charge_limit() {
  require_linux
  print_step "Installing Asahi charge-limit udev rule and oneshot"
  if [ -n "$NOSUDO" ]; then
    print_warning "asahi-charge-limit needs /etc/udev and /var/lib/asahi; skipping"
    return 0
  fi
  sudo install -Dm644 "$DOTFILES/asahi/udev/99-asahi-charge-limit.rules" \
    /etc/udev/rules.d/99-asahi-charge-limit.rules
  sudo install -Dm755 "$DOTFILES/asahi/bin/asahi-charge-limit" \
    /usr/local/libexec/asahi-charge-limit
  sudo install -Dm644 "$DOTFILES/asahi/systemd/system/asahi-charge-limit.service" \
    /etc/systemd/system/asahi-charge-limit.service
  sudo install -d -m 2775 -o root -g wheel /var/lib/asahi
  sudo udevadm control --reload-rules
  sudo udevadm trigger -s power_supply --action=add || true
  sudo systemctl daemon-reload
  sudo systemctl enable asahi-charge-limit.service
  if [ -r /sys/class/power_supply/macsmc-battery/charge_control_end_threshold ]; then
    sudo systemctl start asahi-charge-limit.service || true
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
  mkdir -p "$HOME/screenshots" "$HOME/Videos"
  local script
  for script in "$DOTFILES"/asahi/bin/* "$DOTFILES"/asahi/autostart-scripts/*; do
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
  # Hyprland is not KDE: stop kwalletd/ksecretd from claiming Secret Service
  # ("Default Keyring" wallet wizard). gnome-keyring is the store instead.
  link_if_exists "$DOTFILES/asahi/kwalletrc" "$HOME/.config/kwalletrc"
  mkdir -p "$HOME/.config/autostart"
  link_if_exists "$DOTFILES/asahi/autostart/gnome-keyring-ssh.desktop" \
    "$HOME/.config/autostart/gnome-keyring-ssh.desktop"
  mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
  mkdir -p "$HOME/.config/wireplumber/wireplumber.conf.d"
  link_if_exists "$DOTFILES/asahi/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf" \
    "$HOME/.config/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf"
  link_if_exists "$DOTFILES/asahi/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
  link_if_exists "$DOTFILES/asahi/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
  mkdir -p "$HOME/.config/librewolf/librewolf"
  link_if_exists "$DOTFILES/shared/librewolf/librewolf.overrides.cfg" "$HOME/.config/librewolf/librewolf/librewolf.overrides.cfg"
  local profile
  for profile in "$HOME"/.config/librewolf/librewolf/*.default*; do
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

# BBT has no CLI import. The iCloud export uses shorttitle(2,…); BBT default is (3,3).
_bbt_imported() {
  local f
  for f in "$HOME/Library/Application Support/Zotero/Profiles/"*/prefs.js; do
    [ -f "$f" ] || continue
    grep -E 'translators.better-bibtex.citekeyFormat".*shorttitle\(2' "$f" >/dev/null && return 0
  done
  return 1
}

comp_zotero_bbt() {
  require_macos
  print_step "Checking Zotero Better BibTeX preferences"
  local json
  json="$(_icloud_configs)/betterbib_config_export.json"
  if [ ! -f "$json" ]; then
    print_warning "Better BibTeX export missing (expected $json)"
    return 0
  fi
  if _bbt_imported; then
    print_ok "Better BibTeX prefs already imported"
    return 0
  fi
  print_warning "Import Better BibTeX prefs into Zotero (install the plugin if needed): Settings → Better BibTeX → Import → Import BetterBibTeX preferences/citation keys… then pick $json"
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
    comp_zotero_bbt
  fi
}

# ensure_asmvik_service CMD : write the launchd plist, then start.
# After a brew upgrade the plist is often gone. --start-service then only
# installs it; a second --start-service actually loads the job.
ensure_asmvik_service() {
  local cmd="$1"
  have "$cmd" || return 0
  "$cmd" --install-service >/dev/null 2>&1 || true
  if launchd_loaded "$cmd"; then
    print_step "Restarting $cmd service"
    "$cmd" --restart-service || print_warning "Failed to restart $cmd service"
    return 0
  fi
  print_step "Starting $cmd service"
  "$cmd" --start-service || true
  if ! launchd_loaded "$cmd"; then
    "$cmd" --start-service || print_warning "Failed to start $cmd service"
  fi
}

# ensure_brew_service NAME : start a brew-managed LaunchAgent if it is down.
ensure_brew_service() {
  local name="$1"
  have brew || return 0
  if brew_service_running "$name"; then
    print_ok "$name service already running"
  else
    print_step "Starting $name service"
    brew services start "$name" || print_warning "Failed to start $name service"
  fi
}

# (Re)start macOS desktop services (yabai, skhd, sketchybar).
# Called from make macos and make after. After brew upgrades: rewrite sudoers,
# reinstall missing plists, restart already-running asmvik jobs.
# borders is spawned from yabairc — do not brew-services it (double-instance).
comp_services() {
  require_macos
  if have yabai; then
    print_step "Refreshing yabai scripting-addition permissions"
    echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 "$(command -v yabai)" | cut -d ' ' -f 1) $(command -v yabai) --load-sa" | sudo tee /private/etc/sudoers.d/yabai >/dev/null
    ensure_asmvik_service yabai
    sudo yabai --load-sa || print_warning "yabai --load-sa failed"
  fi
  ensure_asmvik_service skhd
  ensure_brew_service sketchybar
}

# --- doctor: report on binaries and services --------------------------------

comp_doctor() {
  print_step "Checking core binaries"
  local b
  for b in zsh git curl make nvim node npm fzf rg uv tree-sitter tmux; do
    check_bin "$b" || true
  done
  if [ "$OSTYPE_UNAME" = "Darwin" ]; then
    print_step "Checking macOS binaries"
    for b in brew yabai skhd sketchybar ghostty vicinae battery sourcekit-lsp; do
      check_bin "$b" || true
    done
    print_step "Checking macOS services"
    report_check "sketchybar service" brew_service_running sketchybar
    report_check "sketchybar-top LaunchAgent" launchd_loaded sketchybar-top
    report_check "sketchybar-island LaunchAgent" launchd_loaded sketchybar-island
    report_check "yabai service" launchd_loaded yabai
    report_check "skhd service" launchd_loaded skhd
    report_check "borders process" pgrep -qx borders
  elif is_asahi; then
    print_step "Checking Asahi/Hyprland binaries"
    for b in Hyprland quickshell qs hypridle hyprlock hyprpaper brightnessctl nmcli bluetoothctl nm-connection-editor nmtui blueman-manager openconnect gnome-keyring-daemon wf-recorder; do
      check_bin "$b" || true
    done
    print_step "Checking Asahi hardware/session"
    report_check "asahi-notch.conf" test -f /etc/modprobe.d/asahi-notch.conf
    report_check "logind HandlePowerKey=ignore" grep -q '^HandlePowerKey=ignore' /etc/systemd/logind.conf.d/10-asahi-sleep.conf
    if busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandlePowerKey 2>/dev/null | grep -q '"ignore"'; then
      print_ok "logind live HandlePowerKey=ignore"
    else
      print_warning "logind still handles the power key (install drop-in + SIGHUP systemd-logind)"
    fi
    if [ -r /sys/module/appledrm/parameters/show_notch ]; then
      if [ "$(tr -d '[:space:]' < /sys/module/appledrm/parameters/show_notch)" = "Y" ]; then
        print_ok "appledrm show_notch active"
      else
        print_warning "appledrm show_notch not active (reboot after enabling)"
      fi
    fi
    if grep -q 'title: "Hibernate"' "$DOTFILES/asahi/quickshell/remix/modules/launcher/Data.js"; then
      print_warning "launcher still lists Hibernate"
    else
      print_ok "launcher has no Hibernate action"
    fi
    report_check "charge-limit udev" test -f /etc/udev/rules.d/99-asahi-charge-limit.rules
    report_check "charge-limit oneshot" test -f /etc/systemd/system/asahi-charge-limit.service
    report_check "asahi-charge-limit libexec" test -x /usr/local/libexec/asahi-charge-limit
    if [ -w /sys/class/power_supply/macsmc-battery/charge_control_end_threshold ]; then
      print_ok "macsmc charge_control_end_threshold is writable"
    else
      print_warning "macsmc charge threshold not writable (./install.sh asahi-system)"
    fi
    check_link "$HOME/.config/hypr"
    check_link "$HOME/.config/quickshell"
    check_link "$HOME/.config/kwalletrc"
  fi
  print_step "Checking config symlinks"
  local l
  for l in "$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.gitconfig" "$HOME/.gitignore" "$HOME/.tmux.conf" "$HOME/.config/nvim"; do
    check_link "$l"
  done
  if [ "$OSTYPE_UNAME" = "Darwin" ]; then
    for l in "$HOME/.config/sketchybar" "$HOME/.config/skhd" "$HOME/.config/yabai" "$HOME/.config/ghostty" \
             "$HOME/.config/vicinae/dotfiles.json"; do
      check_link "$l"
    done
    print_step "Checking iCloud private configs"
    local cloud
    cloud="$(_icloud_configs)"
    if [ ! -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]; then
      print_warning "iCloud Drive not available"
    else
      [ -f "$cloud/vicinae/settings.json" ] && print_ok "iCloud vicinae backup" || print_warning "iCloud vicinae backup missing (./install.sh icloud)"
      [ -f "$cloud/betterbib_config_export.json" ] && print_ok "iCloud Better BibTeX export" || print_warning "iCloud Better BibTeX export missing"
    fi
    if _bbt_imported; then print_ok "Zotero Better BibTeX prefs imported"
    else print_warning "Zotero Better BibTeX prefs not imported (Settings → Better BibTeX → Import)"; fi
  fi
}
