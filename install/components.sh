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
  # btop.conf asks for "asahi-adaptive"; asahi-autotheme regenerates it from the
  # wallpaper. Seed it so btop still has a theme on macOS / before the first run.
  if [ ! -f "$DOTFILES/btop/themes/asahi-adaptive.theme" ]; then
    cp -f "$DOTFILES/btop/themes/HotPurpleTrafficLight.theme" "$DOTFILES/btop/themes/asahi-adaptive.theme"
  fi
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
  # force: headless has no confirm buffer, so without it updates are fetched but never checked out.
  nvim --headless "+lua vim.pack.update(nil, { force = true })" "+qa" || print_error "nvim plugin sync failed"
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

# --- Apple Silicon (Aurora Fedora Remix; Fedora Asahi Remix) -----------------

# tty1 getty is the login password. Safe on a live session: removes a leftover
# drop-in, swaps kmscon for getty on disk, daemon-reloads. Do not restart getty@tty1 (kills Hyprland).
comp_asahi_getty() {
  require_linux
  print_step "Ensuring tty1 getty asks for a password (no autologin)"
  if [ -n "$NOSUDO" ]; then
    print_error "asahi-getty writes /etc/systemd; rerun without --no-sudo"
    exit 1
  fi
  local dropin=/etc/systemd/system/getty@tty1.service.d/10-asahi-autologin.conf
  local dropdir=/etc/systemd/system/getty@tty1.service.d
  if [ -f "$dropin" ]; then
    sudo rm -f "$dropin" || {
      print_error "failed to remove $dropin"
      exit 1
    }
    if [ -d "$dropdir" ] && [ -z "$(ls -A "$dropdir" 2>/dev/null)" ]; then
      sudo rmdir "$dropdir"
    fi
    sudo systemctl daemon-reload || {
      print_error "systemctl daemon-reload failed after removing autologin"
      exit 1
    }
  fi
  if systemctl cat getty@tty1.service 2>/dev/null | grep -q -- '--autologin'; then
    print_error "getty@tty1 still has --autologin after cleanup"
    exit 1
  fi
  # Fedora 45 presets kmscon as autovt@ instead of getty@: kmscon keeps the display's DRM master (Hyprland's
  # TakeDevice gets EBUSY) and logs in on a pty, so zprofile's tty1 check never starts Hyprland. Applies on
  # the next boot (nothing is stopped here). Masked so a kmscon reinstall cannot preset it back.
  if systemctl list-unit-files kmsconvt@.service >/dev/null 2>&1 &&
    [ "$(systemctl is-enabled kmsconvt@.service 2>/dev/null)" != masked ]; then
    sudo systemctl disable kmsconvt@.service kmsconvt@tty1.service && sudo systemctl mask kmsconvt@.service || {
      print_error "failed to disable kmscon (kmsconvt@.service)"
      exit 1
    }
  fi
  # The template: autovt@ alias + getty@tty1.
  sudo systemctl enable getty@.service || {
    print_error "failed to enable getty@.service"
    exit 1
  }
  print_ok "tty1 getty has no --autologin and no kmscon (password required on next boot)"
}

# No hibernate + HDMI lid inhibit + Bluetooth wake on AC + clean poweroff at critical battery. Safe to rerun
# on a live Hyprland session: SIGHUP reloads logind.conf.d; do not restart
# systemd-logind. Do not udevadm trigger drm (that hotplugs HDMI).
comp_asahi_logind() {
  require_linux
  print_step "Installing Asahi logind drop-ins (no hibernate, HDMI lid inhibit, Bluetooth wake on AC, critical battery)"
  if [ -n "$NOSUDO" ]; then
    print_error "asahi-logind writes /etc/systemd; rerun without --no-sudo"
    exit 1
  fi
  local src_login src_sleep src_udev src_btwake src_unit src_failed src_onfail
  src_login="$DOTFILES/asahi/systemd/logind.conf.d/90-asahi-sleep.conf"
  src_sleep="$DOTFILES/asahi/systemd/sleep.conf.d/10-asahi-no-hibernate.conf"
  src_udev="$DOTFILES/asahi/udev/99-asahi-hdmi-lid-inhibit.rules"
  src_btwake="$DOTFILES/asahi/udev/99-asahi-bt-wake.rules"
  src_unit="$DOTFILES/asahi/systemd/system/asahi-hdmi-lid-inhibit.service"
  # Failed suspend (apple-drm -22): stop logind's lid retry loop until lid opens.
  src_failed="$DOTFILES/asahi/systemd/system/asahi-suspend-failed.service"
  src_onfail="$DOTFILES/asahi/systemd/system/systemd-suspend.service.d/10-asahi-onfailure.conf"
  [ -f "$src_login" ] && [ -f "$src_sleep" ] && [ -f "$src_udev" ] && [ -f "$src_btwake" ] && [ -f "$src_unit" ] &&
    [ -f "$src_failed" ] && [ -f "$src_onfail" ] || {
    print_error "missing Asahi systemd drop-ins under $DOTFILES/asahi/systemd"
    exit 1
  }
  sudo_install "$src_login" /etc/systemd/logind.conf.d/90-asahi-sleep.conf
  # Old name (10-): sorted before Aurora's 50-aurora-sep.conf, which then won.
  sudo rm -f /etc/systemd/logind.conf.d/10-asahi-sleep.conf
  # UPower reads it at start (next boot): PowerOff instead of Auto's s2idle at 2 %.
  sudo_install "$DOTFILES/asahi/upower/90-asahi-critical.conf" /etc/UPower/UPower.conf.d/90-asahi-critical.conf
  sudo_install "$src_sleep" /etc/systemd/sleep.conf.d/10-asahi-no-hibernate.conf
  sudo_install "$src_udev" /etc/udev/rules.d/99-asahi-hdmi-lid-inhibit.rules
  sudo_install "$src_btwake" /etc/udev/rules.d/99-asahi-bt-wake.rules
  sudo_install "$src_unit" /etc/systemd/system/asahi-hdmi-lid-inhibit.service
  sudo_install "$src_failed" /etc/systemd/system/asahi-suspend-failed.service
  sudo_install "$src_onfail" /etc/systemd/system/systemd-suspend.service.d/10-asahi-onfailure.conf
  if ! cmp -s "$src_login" /etc/systemd/logind.conf.d/90-asahi-sleep.conf ||
    ! cmp -s "$DOTFILES/asahi/upower/90-asahi-critical.conf" /etc/UPower/UPower.conf.d/90-asahi-critical.conf; then
    print_error "installed logind / UPower drop-in does not match the repo"
    exit 1
  fi
  sudo udevadm control --reload-rules
  # Bluetooth wake follows the charger now, not only after the next plug or boot.
  if [ -e /sys/class/power_supply/macsmc-ac ] && ! sudo udevadm trigger --action=change /sys/class/power_supply/macsmc-ac; then
    print_error "udevadm trigger macsmc-ac failed (Bluetooth wake not synced)"
    exit 1
  fi
  sudo systemctl daemon-reload
  sudo systemctl enable asahi-hdmi-lid-inhibit.service || {
    print_error "failed to enable asahi-hdmi-lid-inhibit.service"
    exit 1
  }
  sudo systemctl reset-failed asahi-hdmi-lid-inhibit.service 2>/dev/null || true
  sudo systemctl kill -s HUP systemd-logind
  local live
  # LidSwitchIgnoreInhibited is not on D-Bus; InhibitDelayMaxSec=15 is ours too.
  live="$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager \
    InhibitDelayMaxUSec 2>/dev/null || true)"
  if [ "$live" = "t 15000000" ]; then
    print_ok "logind drop-in live (InhibitDelayMaxSec=15; power key = Aurora's suspend / 5 s poweroff)"
  else
    print_error "logind InhibitDelayMaxUSec is ${live:-unknown} after SIGHUP (drop-in not live)"
    exit 1
  fi
  if grep -qsx connected /sys/class/drm/card*-HDMI-A-*/status /sys/class/drm/card*-DP-*/status; then
    sudo systemctl start asahi-hdmi-lid-inhibit.service || {
      print_error "asahi-hdmi-lid-inhibit.service failed to start with an external display connected"
      exit 1
    }
  else
    sudo systemctl stop asahi-hdmi-lid-inhibit.service 2>/dev/null || true
  fi
}

comp_asahi_system() {
  require_linux
  # Aurora (before dnf, so kernel updates see it): m1n1 Stage 2 carries the default kernel's DTBs. Stale ones
  # (the old fairydust pin) lack the `sep` alias, so aura cannot hand SEP its local-policy-manifest: no Touch ID.
  # update-m1n1 refuses while a pre-Aurora kernel (DT ABI generation 0) is installed — remove those first.
  if grep -q '^VARIANT_ID=aurora' /etc/os-release; then
    print_step "Aurora boot chain: m1n1 DTBs follow the default kernel"
    sudo rm -rf /boot/dtbs
    sudo sed -i 's|^DTBS=.*|DTBS="/boot/dtb"|' /etc/sysconfig/update-m1n1
    sudo sed -i 's/^UPDATEDEFAULT=.*/UPDATEDEFAULT=yes/; s/^DEFAULTKERNEL=.*/DEFAULTKERNEL=kernel-aurora-core/' /etc/sysconfig/kernel
    # A key the file lacks (fresh image) is appended: sed only rewrites existing lines.
    grep -q '^DTBS=' /etc/sysconfig/update-m1n1 || echo 'DTBS="/boot/dtb"' | sudo tee -a /etc/sysconfig/update-m1n1 >/dev/null
    grep -q '^UPDATEDEFAULT=' /etc/sysconfig/kernel || echo UPDATEDEFAULT=yes | sudo tee -a /etc/sysconfig/kernel >/dev/null
    grep -q '^DEFAULTKERNEL=' /etc/sysconfig/kernel || echo DEFAULTKERNEL=kernel-aurora-core | sudo tee -a /etc/sysconfig/kernel >/dev/null
    # aurora-userpages' default (per-process 4K pages, FEX); a manual kernel-install add drops what /etc/kernel/cmdline lacks.
    if [ -f /etc/kernel/cmdline ] && ! grep -qw 'user4k=on' /etc/kernel/cmdline; then
      sudo sed -i '1s/$/ user4k=on/' /etc/kernel/cmdline && sudo grubby --update-kernel=ALL --args=user4k=on || {
        print_error "failed to add user4k=on to the kernel command line"
        exit 1
      }
    fi
    # Converted Fedora Asahi installs: pre-Aurora kernels (no dtb-abi = DT generation 0) make update-m1n1 refuse every
    # kernel install. Only once an Aurora kernel booted (the working fallback) do kernel-16k and fairydust go.
    if [[ $(uname -r) == *aurora* ]]; then
      local v
      if rpm -q kernel-16k-core >/dev/null 2>&1; then
        sudo dnf remove -y --no-autoremove 'kernel-16k*' || { print_error "failed to remove Fedora Asahi kernel-16k"; exit 1; }
      fi
      for v in /usr/lib/modules/*fairydust*; do
        [ -d "$v" ] || continue
        sudo kernel-install remove "${v##*/}" && sudo rm -rf "$v" "/boot/dtb-${v##*/}" ||
          { print_error "failed to remove kernel ${v##*/}"; exit 1; }
      done
      # Hand-made for fairydust's DP alt mode; Aurora autoloads typec_displayport / typec_thunderbolt.
      sudo rm -f /etc/modules-load.d/fairydust-typec.conf
      # Fedora Asahi leftovers: orphaned COPR metapackages (they pull asahi-battery back) and asahi-battery, a second
      # charge-limit store rewritten on every battery uevent (ours: asahi-charge-limit).
      local pkg old=()
      for pkg in asahi-platform-metapackage-desktop asahi-platform-metapackage-mesa asahi-battery; do
        rpm -q "$pkg" >/dev/null 2>&1 && old+=("$pkg")
      done
      if [ ${#old[@]} -gt 0 ]; then
        sudo systemctl stop macsmc-battery-charge-control-end-threshold.path 2>/dev/null || true
        sudo dnf remove -y --no-autoremove "${old[@]}" || { print_error "failed to remove ${old[*]}"; exit 1; }
      fi
      # An Aurora kernel whose kernel-install add was refused (or ran out of /boot space) has no image / initramfs.
      # Only the newest is repaired: every add becomes the GRUB default and Stage 2's DTB source (UPDATEDEFAULT),
      # so adding an older one would make it the default.
      v=$(printf '%s\n' /usr/lib/modules/*aurora* | sort -V | tail -n 1)
      if [ -f "$v/vmlinuz" ] && { [ ! -e "/boot/vmlinuz-${v##*/}" ] || [ ! -e "/boot/initramfs-${v##*/}.img" ]; }; then
        sudo kernel-install add "${v##*/}" "$v/vmlinuz" || { print_error "kernel-install add ${v##*/} failed"; exit 1; }
      fi
    fi
    sudo update-m1n1 || {
      print_error "update-m1n1 refused: pre-Aurora kernels installed? Boot an Aurora kernel (GRUB), rerun (asahi/CLAUDE.md 'Aurora boot chain')"
      exit 1
    }
    # Keyboard light from the ambient light sensor: Aurora's daemon (respects keys and idle dimming). Undo an old mask.
    sudo systemctl unmask aurora-kbd-light.service && sudo systemctl enable --now aurora-kbd-light.service || {
      print_error "failed to enable aurora-kbd-light.service"
      exit 1
    }
  fi
  bash "$DOTFILES/asahi/dnf.sh" || { print_error "asahi/dnf.sh failed (packages, flatpaks or services)"; exit 1; }
  # Grok Bot desktop agent from Cursor's update API: third-party and optional.
  bash "$DOTFILES/asahi/grokbot.sh" || print_warning "Grok Bot install failed (optional; rerun asahi/grokbot.sh)"
  # tty1 getty is the auth gate. These two lines unlock the login keyring
  # with that password. There is no display manager to do it.
  if ! rpm -q gnome-keyring-pam >/dev/null 2>&1 || ! sudo "$DOTFILES/asahi/bin/asahi-keyring-pam" /etc/pam.d/login; then
    print_error "pam_gnome_keyring not set up in /etc/pam.d/login (gnome-keyring-pam missing?)"
    exit 1
  fi
  # Console font, getty prompt included. This has to be vconsole.conf rather
  # than a setfont unit: systemd-vconsole-setup is udev-triggered and re-runs
  # as the DRM devices appear, so it overwrites anything a service set earlier.
  sudo_install "$DOTFILES/asahi/vconsole.conf" /etc/vconsole.conf
  sudo systemctl restart systemd-vconsole-setup.service || {
    print_error "systemd-vconsole-setup failed (KEYMAP/FONT in asahi/vconsole.conf)"
    exit 1
  }
  # Getty is the auth gate. A leftover agetty --autologin drop-in (tried, then
  # reverted in the repo) still skips the tty1 password until it is removed.
  comp_asahi_getty
  comp_asahi_logind
  comp_asahi_sshd
  # RTC in UTC like macOS (LOCAL leaves every boot hours off until chrony).
  sudo timedatectl set-local-rtc 0
  if [ "$(timedatectl show -p LocalRTC --value)" != no ]; then
    print_error "RTC still in local time"
    exit 1
  fi
  sudo_install "$DOTFILES/asahi/systemd/system/plocate-updatedb.service.d/10-ac-only.conf" \
    /etc/systemd/system/plocate-updatedb.service.d/10-ac-only.conf
  # Faster shutdown (omarchy): 10 s stop timeout (system + user managers), fprintd 3 s. Next boot.
  sudo_install "$DOTFILES/asahi/systemd/system.conf.d/10-asahi-stop-timeout.conf" /etc/systemd/system.conf.d/10-asahi-stop-timeout.conf
  sudo_install "$DOTFILES/asahi/systemd/user.conf.d/10-asahi-stop-timeout.conf" /etc/systemd/user.conf.d/10-asahi-stop-timeout.conf
  sudo_install "$DOTFILES/asahi/systemd/system/fprintd.service.d/10-asahi-stop-timeout.conf" \
    /etc/systemd/system/fprintd.service.d/10-asahi-stop-timeout.conf
  # AsahiLocker's fastfetch helper: cryptsetup luksDump as root on every LUKS / BitLocker disk (USB too) every 15 min;
  # our fastfetch config never shows it.
  if [ "$(systemctl is-enabled luks-fetch-cache.timer 2>/dev/null)" = enabled ]; then
    sudo systemctl disable --now luks-fetch-cache.timer
  fi
  # abrt (crash reports): nothing here reads them; coredumpctl + asahi-debug do.
  if systemctl list-unit-files abrtd.service >/dev/null 2>&1; then
    sudo systemctl mask --now abrtd.service abrt-journal-core.service abrt-oops.service abrt-vmcore.service \
      abrt-xorg.service || { print_error "failed to mask abrt"; exit 1; }
  fi
  # Wi-Fi power save off (idle naps add latency, no gain here). NetworkManager reads it at start.
  sudo_install "$DOTFILES/asahi/NetworkManager/conf.d/asahi-wifi-powersave.conf" \
    /etc/NetworkManager/conf.d/asahi-wifi-powersave.conf
  # Connectivity probe so NM reports portal/limited/full (pane sign-in + chip warn). Same URI the pane opens.
  sudo_install "$DOTFILES/asahi/NetworkManager/conf.d/asahi-connectivity.conf" \
    /etc/NetworkManager/conf.d/asahi-connectivity.conf
  # zram is the only swap: zstd + swap-friendly VM knobs.
  print_step "zram: zstd + sysctl tuning"
  sudo_install "$DOTFILES/asahi/sysctl.d/99-asahi-zram.conf" /etc/sysctl.d/99-asahi-zram.conf
  sudo sysctl -q -p /etc/sysctl.d/99-asahi-zram.conf
  sudo_install "$DOTFILES/asahi/sysctl.d/99-asahi-hardening.conf" /etc/sysctl.d/99-asahi-hardening.conf
  sudo sysctl -q -p /etc/sysctl.d/99-asahi-hardening.conf
  if [ "$(sysctl -n dev.tty.legacy_tiocsti)" != 0 ]; then
    print_error "kernel hardening sysctl not active (want dev.tty.legacy_tiocsti=0)"
    exit 1
  fi
  if ! cmp -s "$DOTFILES/asahi/zram-generator.conf.d/90-asahi.conf" /etc/systemd/zram-generator.conf.d/90-asahi.conf; then
    sudo_install "$DOTFILES/asahi/zram-generator.conf.d/90-asahi.conf" /etc/systemd/zram-generator.conf.d/90-asahi.conf
    sudo systemctl daemon-reload
    # Restarting zram0 swaps everything back in; when it holds a lot, wait for the reboot.
    local zram_used_kib
    zram_used_kib=$(awk '$1 == "/dev/zram0" { print $4 }' /proc/swaps)
    if [ "${zram_used_kib:-0}" -lt 262144 ]; then
      if ! sudo systemctl restart systemd-zram-setup@zram0.service; then
        print_error "zram0 restart failed (systemctl status systemd-zram-setup@zram0)"
        exit 1
      fi
    else
      print_warning "zram0 holds more than 256 MiB; zstd applies after the next reboot"
    fi
  fi
  if ! cmp -s "$DOTFILES/asahi/zram-generator.conf.d/90-asahi.conf" /etc/systemd/zram-generator.conf.d/90-asahi.conf ||
    ! cmp -s "$DOTFILES/asahi/sysctl.d/99-asahi-zram.conf" /etc/sysctl.d/99-asahi-zram.conf ||
    [ "$(sysctl -n vm.page-cluster)" != 0 ]; then
    print_error "zram config not installed or sysctl tuning not active (want vm.page-cluster=0)"
    exit 1
  fi
  sudo systemctl daemon-reload
  local rebuild_initramfs=0
  # Full panel height beside the notch (appledrm). No-op without that driver.
  if modinfo appledrm >/dev/null 2>&1; then
    if [ ! -f /etc/modprobe.d/asahi-notch.conf ] || ! cmp -s "$DOTFILES/asahi/modprobe.d/asahi-notch.conf" /etc/modprobe.d/asahi-notch.conf; then
      print_step "Enabling Asahi notch area (full display height)"
      sudo_install "$DOTFILES/asahi/modprobe.d/asahi-notch.conf" /etc/modprobe.d/asahi-notch.conf
      rebuild_initramfs=1
    fi
  fi
  # Apple Silicon: media keys on the top row (hid_apple fnmode=1).
  if [ "$(uname -m)" = "aarch64" ] && grep -qi apple /proc/device-tree/compatible 2>/dev/null; then
    local hid_dst=/etc/modprobe.d/hid_apple.conf
    if [ ! -f "$hid_dst" ] || grep -q 'fnmode=2' "$hid_dst"; then
      print_step "hid_apple fnmode=1 (media keys on the top row)"
      sudo_install "$DOTFILES/asahi/modprobe.d/hid_apple.conf" "$hid_dst"
      rebuild_initramfs=1
      if [ -f /sys/module/hid_apple/parameters/fnmode ]; then
        echo 1 | sudo tee /sys/module/hid_apple/parameters/fnmode >/dev/null || true
      fi
    fi
  fi
  # Bind the internal keyboard on first registration instead of letting it
  # churn through hid-generic, which can cost the trackpad or keyboard for a
  # whole session when logind's TakeDevice loses the race.
  if [ "$(uname -m)" = "aarch64" ] && grep -qi apple /proc/device-tree/compatible 2>/dev/null; then
    local hid_dracut=/etc/dracut.conf.d/10-asahi-hid.conf kbd_rule=/etc/udev/rules.d/90-asahi-kbd-backlight.rules
    # The dracut conf ships this rule (keyboard light at the LUKS prompt), so it must exist first.
    if ! cmp -s "$DOTFILES/asahi/udev/90-asahi-kbd-backlight.rules" "$kbd_rule" 2>/dev/null; then
      sudo_install "$DOTFILES/asahi/udev/90-asahi-kbd-backlight.rules" "$kbd_rule"
      rebuild_initramfs=1
    fi
    if ! cmp -s "$DOTFILES/asahi/dracut.conf.d/10-asahi-hid.conf" "$hid_dracut" 2>/dev/null; then
      print_step "Early-loading Apple HID modules from the initramfs"
      sudo_install "$DOTFILES/asahi/dracut.conf.d/10-asahi-hid.conf" "$hid_dracut"
      rebuild_initramfs=1
    fi
  fi
  # A dracut run that failed or was interrupted left these files installed (cmp is clean on the rerun):
  # rebuild while one is newer than the running kernel's image.
  local f
  for f in /etc/modprobe.d/asahi-notch.conf /etc/modprobe.d/hid_apple.conf /etc/dracut.conf.d/10-asahi-hid.conf \
    /etc/udev/rules.d/90-asahi-kbd-backlight.rules; do
    if [ "$f" -nt "/boot/initramfs-$(uname -r).img" ]; then rebuild_initramfs=1; fi
  done
  if [ "$rebuild_initramfs" -eq 1 ]; then
    if ! have dracut; then
      print_error "dracut not found; cannot rebuild initramfs for notch/fnmode/HID"
      exit 1
    fi
    # Every kernel: the Aurora block above may have built a new one before these files changed.
    sudo dracut -f --regenerate-all || { print_error "dracut failed; initramfs not rebuilt for notch/fnmode/HID"; exit 1; }
    print_ok "initramfs rebuilt; reboot required for notch/fnmode/HID"
  fi
  comp_asahi_charge_limit
}

# Fedora enables sshd; nothing logs in remotely here, so mask both units.
comp_asahi_sshd() {
  require_linux
  print_step "Masking sshd (service, socket, local socket)"
  if [ -n "$NOSUDO" ]; then
    print_error "asahi-sshd needs systemctl mask; rerun without --no-sudo"
    exit 1
  fi
  sudo systemctl disable --now sshd.service sshd.socket 2>/dev/null || true
  sudo systemctl mask sshd.service sshd.socket
  # systemd-ssh-generator's AF_UNIX listener (/run/ssh-unix-local/socket, mode 0666: an sshd for any local process).
  sudo systemctl mask --now sshd-unix-local.socket
  # Nothing listens on 22: no ssh hole in the firewall either.
  if sudo firewall-cmd -q --permanent --query-service=ssh 2>/dev/null; then
    sudo firewall-cmd -q --permanent --remove-service=ssh && sudo firewall-cmd -q --reload
  fi
  # LocalSend (dnf.sh Flatpak; file sharing with the iPhone app) receives on 53317, opened in the `home` zone only: a trusted
  # network goes there with `nmcli connection modify <name> connection.zone home`; public stays closed.
  if sudo firewall-cmd -q --state 2>/dev/null; then
    sudo firewall-cmd -q --permanent --zone=home --add-port=53317/tcp --add-port=53317/udp && sudo firewall-cmd -q --reload ||
      { print_error "LocalSend port 53317 not opened in firewalld's home zone"; exit 1; }
  fi
  if [ "$(systemctl is-enabled sshd.service 2>/dev/null)" != masked ] ||
    [ "$(systemctl is-enabled sshd-unix-local.socket 2>/dev/null)" != masked ]; then
    print_error "sshd.service / sshd-unix-local.socket not masked"
    exit 1
  fi
  print_ok "sshd masked"
}

# Touch ID (Aurora): per-Mac calibration (aurora-touchid-setup, idempotent), authselect fingerprint, one enrolled
# finger. Needs Aurora's Stage 2 DTBs (sep alias); a converted install gets them only after a reboot.
comp_asahi_touchid() {
  require_linux
  grep -q '^VARIANT_ID=aurora' /etc/os-release || return 0
  print_step "Touch ID (Aurora SEP + fprintd)"
  if [ ! -e /proc/device-tree/aliases/sep ]; then
    print_warning "Stage 2 DTBs predate Aurora (no sep alias): reboot, then ./install.sh asahi-touchid"
    return 0
  fi
  if ! compgen -G '/proc/device-tree/soc/*/fingerprint@*' >/dev/null; then
    print_ok "no Touch ID sensor on this Mac"
    return 0
  fi
  sudo aurora-touchid-setup || { print_error "aurora-touchid-setup failed (journalctl -u aurora-sep)"; exit 1; }
  # asahi-lock restarts a fprintd that left the reader open (every claim fails until then).
  sudo_install "$DOTFILES/asahi/polkit/49-asahi-fprintd-restart.rules" /etc/polkit-1/rules.d/49-asahi-fprintd-restart.rules
  # aurora-sep-ready turns it on once the sensor attaches; Aurora's vendor profile: sudo, polkit, lock screens.
  if ! authselect current 2>/dev/null | grep -q with-fingerprint; then
    sudo authselect enable-feature with-fingerprint || { print_error "authselect with-fingerprint failed"; exit 1; }
  fi
  local prints
  prints=$(fprintd-list "$USER" 2>/dev/null)
  if grep -q ' - #' <<<"$prints"; then
    print_ok "Touch ID: $(grep -c ' - #' <<<"$prints") finger(s) enrolled"
  elif grep -q 'No devices available' <<<"$prints"; then   # libfprint hides the reader under a closed lid
    print_ok "Touch ID reader is under the closed lid: fingers not checked (enrol with the lid open)"
  elif [ -t 0 ]; then
    print_step "Enrol a finger: touch the sensor, lift, repeat until it says enroll-completed"
    # Interactive, user data (like the non-tty branch): a failed try must not stop the desktop install.
    fprintd-enroll -f right-index-finger "$USER" || print_warning "fprintd-enroll failed: rerun ./install.sh asahi-touchid"
  else
    print_warning "no finger enrolled: fprintd-enroll -f right-index-finger $USER"
  fi
  # Touch ID as a FIDO2 security key (passkeys / WebAuthn, ssh-keygen -t ecdsa-sk, pam_u2f); Aurora ships it off.
  if [ "$(systemctl is-enabled aurora-fido.service 2>/dev/null)" != enabled ]; then
    sudo dnf install -y aurora-fido && sudo aurora-fido enable || { print_error "aurora-fido enable failed"; exit 1; }
  fi
  print_ok "$(aurora-fido status 2>/dev/null | head -n 1)"   # its first line names itself ("Touch ID security key: ON …")
}

# udev + oneshot so macsmc charge thresholds are writable and reapplied at boot.
comp_asahi_charge_limit() {
  require_linux
  print_step "Installing Asahi charge-limit udev rule and oneshot"
  if [ -n "$NOSUDO" ]; then
    print_warning "asahi-charge-limit needs /etc/udev and /var/lib/asahi; skipping"
    return 0
  fi
  sudo_install "$DOTFILES/asahi/udev/99-asahi-charge-limit.rules" /etc/udev/rules.d/99-asahi-charge-limit.rules
  sudo_install "$DOTFILES/asahi/bin/asahi-charge-limit" /usr/local/libexec/asahi-charge-limit 755
  sudo_install "$DOTFILES/asahi/systemd/system/asahi-charge-limit.service" /etc/systemd/system/asahi-charge-limit.service
  sudo install -d -m 2775 -o root -g wheel /var/lib/asahi || { print_error "failed to create /var/lib/asahi"; exit 1; }
  sudo udevadm control --reload-rules
  sudo udevadm trigger -s power_supply --action=add || true
  sudo systemctl daemon-reload
  sudo systemctl enable asahi-charge-limit.service || { print_error "failed to enable asahi-charge-limit.service"; exit 1; }
  if [ -r /sys/class/power_supply/macsmc-battery/charge_control_end_threshold ]; then
    sudo systemctl start asahi-charge-limit.service || true
  fi
}

# Turn an existing dir into a btrfs subvolume: nested subvolumes are left out of the parent's snapshots.
# Reflink copy (no extra space), then an atomic swap, so the path never disappears; the old tree is removed.
subvol_dir() {
  local d="$1" tmp="$1.subvol-new"
  [ "$(stat -c %i "$d")" = 256 ] && return 0
  if ! { btrfs subvolume create "$tmp" >/dev/null && cp -a --reflink=always "$d/." "$tmp/" && mv -T --exchange "$tmp" "$d"; }; then
    rm -rf "$tmp"
    print_error "could not turn $d into a subvolume"
    return 1
  fi
  rm -rf "$tmp"
  print_ok "subvolume: ${d/#$HOME/\~}"
}

# snapper came with AsahiLocker's post-encryption-setup (root + home, stock template): hourly snapshots kept
# 10 h / 10 d / 10 months / 10 years as plain numbers, so FREE_LIMIT never deleted anything and every cache,
# Flatpak update or temp file in ~ stayed pinned for months. Ranges let cleanup go down to the minimum while
# free space is below 20 %; long-term history of ~ is restic's job (asahi-timemachine).
comp_asahi_snapper() {
  require_linux
  print_step "Tuning snapper (short retention, free-space cleanup, no caches in snapshots of ~)"
  if [ ! -f /etc/snapper/configs/root ]; then
    print_ok "no snapper configs; nothing to tune"
    return 0
  fi
  if [ -n "$NOSUDO" ]; then
    print_warning "asahi-snapper changes snapper configs; skipping"
    return 0
  fi
  sudo snapper -c root set-config TIMELINE_LIMIT_HOURLY=2-6 TIMELINE_LIMIT_DAILY=2-7 TIMELINE_LIMIT_WEEKLY=0-4 \
    TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_QUARTERLY=0 TIMELINE_LIMIT_YEARLY=0 NUMBER_LIMIT=2-10 FREE_LIMIT=0.2 \
    || { print_error "snapper set-config root failed"; exit 1; }
  sudo snapper -c root cleanup all || { print_error "snapper cleanup root failed"; exit 1; }
  [ -f /etc/snapper/configs/home ] || return 0
  # ALLOW_USERS + SYNC_ACL: list / delete snapshots of ~ without sudo.
  sudo snapper -c home set-config TIMELINE_LIMIT_HOURLY=2-12 TIMELINE_LIMIT_DAILY=2-7 TIMELINE_LIMIT_WEEKLY=0 \
    TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_QUARTERLY=0 TIMELINE_LIMIT_YEARLY=0 NUMBER_LIMIT=2-10 FREE_LIMIT=0.2 \
    ALLOW_USERS="$USER" SYNC_ACL=yes || { print_error "snapper set-config home failed"; exit 1; }
  sudo snapper -c home cleanup all || { print_error "snapper cleanup home failed"; exit 1; }
  # Only dirs restic excludes anyway: its --one-file-system skips subvolumes. Flatpak-owned trees need their
  # app closed (the runtimes dir: every app).
  local d id busy=() running
  running="$(flatpak ps --columns=application 2>/dev/null)"
  for d in "$HOME/.cache" "$HOME/.local/share/flatpak" "$HOME/Nextcloud" "$HOME"/.var/app/*/cache; do
    [ -d "$d" ] && [ "$(stat -c %i "$d")" != 256 ] || continue
    id=""
    case "$d" in
      "$HOME/.local/share/flatpak") id="$(printf '%s' "$running" | tr '\n' ' ')" ;;
      "$HOME/Nextcloud") id="$(grep -x com.nextcloud.desktopclient.nextcloud <<<"$running")" ;;
      "$HOME/.var/app/"*) id="${d#"$HOME/.var/app/"}"; id="$(grep -x "${id%/cache}" <<<"$running")" ;;
    esac
    if [ -n "$id" ]; then
      busy+=("${d/#$HOME/\~} ($id)")
      continue
    fi
    subvol_dir "$d" || exit 1
  done
  if [ ${#busy[@]} -gt 0 ]; then
    print_error "quit these Flatpak apps and rerun: ${busy[*]}"
    exit 1
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
  for script in "$DOTFILES"/asahi/bin/*; do
    # `|| continue`, not `&& chmod`: asahi/bin/lib is a directory and sorts last,
    # so a trailing `[ -f ]` would leave the loop with a non-zero status.
    [ -f "$script" ] || continue
    chmod +x "$script"
  done
  mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
  link_if_exists "$DOTFILES/asahi/systemd/user/hyprland-session.target" "$HOME/.config/systemd/user/hyprland-session.target"
  ln -sfn "$DOTFILES/asahi/bin/asahi-timemachine" "$HOME/.local/bin/asahi-timemachine"
  ln -sfn "$DOTFILES/asahi/systemd/user/asahi-timemachine.service" "$HOME/.config/systemd/user/asahi-timemachine.service"
  ln -sfn "$DOTFILES/asahi/systemd/user/asahi-timemachine.timer" "$HOME/.config/systemd/user/asahi-timemachine.timer"
  mkdir -p "$HOME/.config/systemd/user/xdg-desktop-portal-hyprland.service.d"
  link_if_exists "$DOTFILES/asahi/systemd/user/xdg-desktop-portal-hyprland.service.d/10-asahi-pipewire.conf" \
    "$HOME/.config/systemd/user/xdg-desktop-portal-hyprland.service.d/10-asahi-pipewire.conf"
  # The keyboard light is aurora-kbd-light's (asahi-system); drop our old user ALS daemon.
  systemctl --user disable --now asahi-brightness-keyboard-auto.service 2>/dev/null || true
  rm -f "$HOME/.local/bin/asahi-brightness-keyboard-auto" "$HOME/.config/systemd/user/asahi-brightness-keyboard-auto.service" \
    "$HOME/.config/systemd/user/hyprland-session.target.wants/asahi-brightness-keyboard-auto.service"
  systemctl --user daemon-reload
  replace_with_symlink "$DOTFILES/asahi/hypr"      "$HOME/.config/hypr"
  replace_with_symlink "$DOTFILES/asahi/quickshell" "$HOME/.config/quickshell"
  replace_with_symlink "$DOTFILES/asahi/ghostty"   "$HOME/.config/ghostty"
  mkdir -p "$HOME/.config/Thunar"
  link_if_exists "$DOTFILES/asahi/Thunar/uca.xml" "$HOME/.config/Thunar/uca.xml"
  # No thunar-volman: Thunar --daemon would try to spawn it on every udev add (journal spam).
  xfconf-query -c thunar -p /misc-volume-management -n -t bool -s false || true
  mkdir -p "$HOME/.config/mpv"
  link_if_exists "$DOTFILES/mpv/mpv_asahi.conf" "$HOME/.config/mpv/mpv.conf"
  # Screenshot annotation: swappy's Save lands in ~/screenshots for asahi-screenshot-annotate.
  link_if_exists "$DOTFILES/asahi/swappy/config" "$HOME/.config/swappy/config"
  # The desktop entry runs it by name; the session PATH has ~/.local/bin, not asahi/bin.
  link_if_exists "$DOTFILES/asahi/bin/asahi-apple-music" "$HOME/.local/bin/asahi-apple-music"
  link_if_exists "$DOTFILES/asahi/applications/asahi-apple-music.desktop" \
    "$HOME/.local/share/applications/asahi-apple-music.desktop"
  link_if_exists "$DOTFILES/asahi/environment.d/90-asahi.conf" "$HOME/.config/environment.d/90-asahi.conf"
  # Hyprland is not KDE: stop kwalletd/ksecretd from claiming Secret Service
  # ("Default Keyring" wallet wizard). gnome-keyring is the store instead.
  link_if_exists "$DOTFILES/asahi/kwalletrc" "$HOME/.config/kwalletrc"
  mkdir -p "$HOME/.config/autostart"
  link_if_exists "$DOTFILES/asahi/xdg-autostart/gnome-keyring-ssh.desktop" \
    "$HOME/.config/autostart/gnome-keyring-ssh.desktop"
  mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
  mkdir -p "$HOME/.config/xdg-desktop-portal"
  mkdir -p "$HOME/.local/state/asahi-theme"
  mkdir -p "$HOME/.config/wireplumber/wireplumber.conf.d"
  link_if_exists "$DOTFILES/asahi/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf" \
    "$HOME/.config/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf"
  # aurora-audio's mic graph is MONO already; drop the old relabel filter's link.
  rm -f "$HOME/.config/wireplumber/wireplumber.conf.d/asahi-mic.conf"
  # Settings portal is gtk (Hyprland does not implement appearance color-scheme).
  link_if_exists "$DOTFILES/asahi/xdg-desktop-portal/portals.conf" \
    "$HOME/.config/xdg-desktop-portal/portals.conf"
  if [ ! -f "$HOME/.local/state/asahi-theme/hyprlock.conf" ]; then
    cp -f "$DOTFILES/asahi/hypr/hyprlock-theme.conf" "$HOME/.local/state/asahi-theme/hyprlock.conf"
  fi
  # Real files (not symlinks): asahi-autotheme flips light/dark here.
  for gtkver in gtk-3.0 gtk-4.0; do
    dest="$HOME/.config/$gtkver/settings.ini"
    src="$DOTFILES/asahi/$gtkver/settings.ini"
    mkdir -p "$HOME/.config/$gtkver"
    if [ -L "$dest" ]; then
      rm -f "$dest"
    fi
    if [ -f "$src" ]; then
      cp -f "$src" "$dest"
    fi
  done
  # Flatpak Firefox live theme: CaelestiaFox (signed, AMO) <- xdg-native-messaging-proxy <- asahi-firefox-theme.
  # Host manifest lives on the host; the proxy searches ~/.config/mozilla/native-messaging-hosts.
  mkdir -p "$HOME/.config/mozilla/native-messaging-hosts"
  cat >"$HOME/.config/mozilla/native-messaging-hosts/caelestiafox.json" <<EOF
{
  "name": "caelestiafox",
  "description": "Push the Asahi palette into Firefox.",
  "path": "$DOTFILES/asahi/bin/asahi-firefox-theme",
  "type": "stdio",
  "allowed_extensions": ["caelestiafox@caelestia.org"]
}
EOF
  # Read-only grant so the user.js symlink resolves inside the sandbox (same path as the host).
  flatpak override --user --filesystem="$DOTFILES/asahi/firefox:ro" --filesystem="$HOME/Downloads" org.mozilla.firefox
  # Wake locks as Wayland idle inhibitors: Hyprland honours them only while the window is visible
  # and drops them with the surface. The default portal → org.freedesktop.ScreenSaver path left
  # stale locks in hypridle (no dim/lock/sleep for hours, nothing in `hyprctl clients`).
  flatpak override --user --env=MOZ_WAKE_LOCK_TYPE=WaylandIdleInhibit org.mozilla.firefox
  local profile found=0
  for profile in "$HOME"/.var/app/org.mozilla.firefox/config/mozilla/firefox/*.default*; do
    [ -d "$profile" ] || continue
    found=1
    ln -sfn "$DOTFILES/asahi/firefox/user.js" "$profile/user.js"
    mkdir -p "$profile/extensions"
    if [ ! -f "$profile/extensions/caelestiafox@caelestia.org.xpi" ]; then
      curl -fsSL https://addons.mozilla.org/firefox/downloads/latest/caelestiafox/latest.xpi \
        -o "$profile/extensions/caelestiafox@caelestia.org.xpi.tmp" \
        && mv "$profile/extensions/caelestiafox@caelestia.org.xpi.tmp" "$profile/extensions/caelestiafox@caelestia.org.xpi" \
        || { rm -f "$profile/extensions/caelestiafox@caelestia.org.xpi.tmp"; print_error "CaelestiaFox XPI download failed"; }
    fi
  done
  if [ "$found" = 0 ]; then
    print_warning "No Firefox profile yet; start Firefox once, then rerun for the adaptive theme"
  fi
  for profile in "$HOME"/.thunderbird/*.default*; do
    [ -d "$profile" ] || continue
    ln -sfn "$DOTFILES/asahi/thunderbird/user.js" "$profile/user.js"
  done
  # Logitech hidraw helper: pkexec runs the root-owned copy, never the user-writable checkout
  # (a swapped script would run as root). Reinstall refreshes it; BtMonitor points at this path.
  if [ -n "$NOSUDO" ]; then
    print_warning "asahi-logitech-access needs /usr/local/libexec; skipping"
  else
    sudo_install "$DOTFILES/asahi/bin/asahi-logitech-access" /usr/local/libexec/asahi-logitech-access 755
  fi
}

comp_asahi_battery_alerts() {
  print_step "Installing Asahi battery alerts"
  have notify-send || { print_error "notify-send is required (libnotify, asahi/dnf.sh)"; exit 1; }
  link_if_exists "$DOTFILES/asahi/bin/asahi-battery-alertd" "$HOME/.local/bin/asahi-battery-alertd"
  link_if_exists "$DOTFILES/asahi/systemd/user/asahi-battery-alertd.service" "$HOME/.config/systemd/user/asahi-battery-alertd.service"
  systemctl --user daemon-reload
  systemctl --user enable --now asahi-battery-alertd.service || {
    print_error "asahi-battery-alertd.service failed to enable/start"
    exit 1
  }
}

comp_asahi_wallpapers() {
  local dir="${ASAHI_WALLPAPERS_DIR:-$HOME/Pictures/wallpaper}"
  # Animated wallpapers only (2026-11-09): the old still collection (mylinuxforwork git checkout) moves to a backup once.
  if [ -d "$dir/.git" ] && [ ! -e "$dir-backup" ]; then
    print_step "Moving the still wallpapers to $dir-backup"
    mv "$dir" "$dir-backup" || { print_error "failed to move $dir to $dir-backup"; exit 1; }
    if [ -d "$dir-backup/omarchy" ]; then mv "$dir-backup/omarchy" "$dir"; fi
  fi
  # Background intros (omarchy themes): each clip + the still it ends on, as $dir/<theme>-<bg> and
  # $dir/intros/<theme>-<stem>.mp4 (WallpaperIntro.qml plays <dir>/intros/<stem>.mp4). ~86 MB.
  print_step "Downloading animated wallpapers (omarchy background intros)"
  local base=https://raw.githubusercontent.com/omacom/omarchy/quattro/themes pair theme bg stem out
  mkdir -p "$dir/intros"
  for pair in catppuccin-latte/1-color-fade.webp catppuccin/1-totoro.webp catppuccin/2-waves.webp \
    catppuccin/3-blue-eye.webp ethereal/1-cosmic.webp everforest/1-tree-tops.webp flexoki-light/1-orb.webp \
    hackerman/1-synth-scape.jpg last-horizon/1-eyes-wide.webp \
    matte-black/0-ship-at-sea.jpg miasma/01-nature-of-fear.webp nord/0-black-moon.jpg \
    ristretto/0-launch.webp rose-pine/1-funky-shapes.webp vantablack/0-dot-hands.webp \
    white/1-white.webp; do
    theme=${pair%%/*} bg=${pair#*/}
    stem=${bg%.*} out="$dir/intros/$theme-$stem.mp4"
    [ -s "$out" ] && continue
    if curl -fsSL -o "$dir/$theme-$bg.part" "$base/$theme/backgrounds/$bg" &&
      curl -fsSL -o "$out.part" "$base/$theme/backgrounds/intros/$stem.mp4"; then
      mv "$dir/$theme-$bg.part" "$dir/$theme-$bg" && mv "$out.part" "$out"
    else
      rm -f "$dir/$theme-$bg.part" "$out.part"
      print_warning "background intro $pair failed to download"
    fi
  done
  # First run: hyprpaper starts on the lock-wallpaper link, which the picker only writes on a pick.
  local state="${XDG_STATE_HOME:-$HOME/.local/state}" first
  if [ ! -s "$state/quickshell/wallpaper.conf" ]; then
    first=$(find "$dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | sort | head -n 1)
    if [ -n "$first" ]; then
      mkdir -p "$state/quickshell" "$state/asahi"
      printf '%s' "$first" >"$state/quickshell/wallpaper.conf"
      ln -sfn "$first" "$state/asahi/lock-wallpaper"
      ln -sfn "$first" "$state/asahi/lock-screen"
    fi
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
  # Agent configs are OS-agnostic (have CLI → link Nextcloud files). Do not
  # nest this under Darwin: make after on Linux/Asahi never reached it.
  comp_agents
  if [ "$OSTYPE_UNAME" = "Darwin" ]; then
    comp_services
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
    for b in Hyprland quickshell qs hypridle hyprlock hyprpaper brightnessctl nmcli bluetoothctl nm-connection-editor nmtui blueman-manager openconnect gnome-keyring-daemon wf-recorder grok-bot; do
      check_bin "$b" || true
    done
    report_check "nm-openconnect-service" test -x /usr/libexec/nm-openconnect-service
    if command -v rpm >/dev/null 2>&1; then
      if rpm -q quickshell-git >/dev/null 2>&1; then
        print_warning "quickshell-git is installed (use Fedora quickshell; COPR git breaks on Qt bumps)"
      elif rpm -q quickshell >/dev/null 2>&1; then
        print_ok "Fedora quickshell package (not -git)"
      fi
    fi
    print_step "Checking Asahi hardware/session"
    report_check "asahi-notch.conf" test -f /etc/modprobe.d/asahi-notch.conf
    report_check "hid_apple fnmode=1" grep -q 'fnmode=1' /etc/modprobe.d/hid_apple.conf
    check_bin hyprpicker || true
    if [ -f /etc/systemd/system/getty@tty1.service.d/10-asahi-autologin.conf ]; then
      print_warning "tty1 autologin drop-in is present (./install.sh asahi-getty)"
    elif systemctl cat getty@tty1.service 2>/dev/null | grep -q -- '--autologin'; then
      print_warning "getty@tty1 still has --autologin"
    else
      print_ok "tty1 getty has no autologin"
    fi
    report_check "keychain" have keychain
    report_check "logind LidSwitchIgnoreInhibited=no" grep -q '^LidSwitchIgnoreInhibited=no' /etc/systemd/logind.conf.d/90-asahi-sleep.conf
    report_check "UPower critical = PowerOff" grep -q '^CriticalPowerAction=PowerOff' /etc/UPower/UPower.conf.d/90-asahi-critical.conf
    if compgen -G '/proc/device-tree/soc/*/fingerprint@*' >/dev/null; then
      report_check "Touch ID finger enrolled (not checked under a closed lid)" \
        sh -c 'fprintd-list "$USER" 2>/dev/null | grep -q " - #\|No devices available"'
      report_check "aurora-fido (Touch ID security key) active" systemctl is-active --quiet aurora-fido.service
    fi
    if grep -q '^VARIANT_ID=aurora' /etc/os-release; then
      for u in aurora-peripherals.service aurora-sep.service aurora-touchid-rearm.socket aurora-stage2-commit.service; do
        report_check "$u active" systemctl is-active --quiet "$u"
      done
      report_check "aurora-camera-denoise (user) active" systemctl --user is-active --quiet aurora-camera-denoise.service
    fi
    report_check "hdmi lid-inhibit" test -f /etc/udev/rules.d/99-asahi-hdmi-lid-inhibit.rules -a \
      -f /etc/systemd/system/asahi-hdmi-lid-inhibit.service
    report_check "bt wake udev" test -f /etc/udev/rules.d/99-asahi-bt-wake.rules
    if [ "$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager \
      InhibitDelayMaxUSec 2>/dev/null)" = "t 15000000" ]; then
      print_ok "logind drop-in live (InhibitDelayMaxSec=15)"
    else
      print_warning "logind drop-in not live (install it + SIGHUP systemd-logind)"
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
    report_check "asahi-logitech-access libexec" test -x /usr/local/libexec/asahi-logitech-access
    if grep -q '^VARIANT_ID=aurora' /etc/os-release; then
      report_check "ALS keyboard backlight (aurora-kbd-light)" systemctl is-enabled --quiet aurora-kbd-light.service
    fi
    if [ -w /sys/class/power_supply/macsmc-battery/charge_control_end_threshold ]; then
      print_ok "macsmc charge_control_end_threshold is writable"
    else
      print_warning "macsmc charge threshold not writable (./install.sh asahi-system)"
    fi
    check_link "$HOME/.config/hypr"
    check_link "$HOME/.config/quickshell"
    check_link "$HOME/.config/kwalletrc"
    check_link "$HOME/.config/Thunar/uca.xml"
    report_check "suspend-failed unit" test -f /etc/systemd/system/asahi-suspend-failed.service
    report_check "battery-alertd unit" systemctl --user is-enabled asahi-battery-alertd.service
    report_check "timemachine timer" systemctl --user is-enabled asahi-timemachine.timer
    report_check "vconsole.conf" test -f /etc/vconsole.conf
    report_check "zram config" test -f /etc/systemd/zram-generator.conf.d/90-asahi.conf
    report_check "zram sysctl" test -f /etc/sysctl.d/99-asahi-zram.conf
    report_check "hardening sysctl" test -f /etc/sysctl.d/99-asahi-hardening.conf
    report_check "keyring-pam" grep -q '^auth.*pam_gnome_keyring' /etc/pam.d/login
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
