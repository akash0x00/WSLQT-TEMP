#!/usr/bin/env bash
#
# install-zsh.sh — Quick zsh + plugins + starship setup for WSL (Debian/Ubuntu).
#
# Installs: zsh, git, curl, starship
# Plugins (cloned to ~/.zsh/plugins, sourced from ~/.zshrc):
#   - zsh-completions            (fpath only, NOT sourced)
#   - zsh-autosuggestions
#   - zsh-you-should-use
#   - zsh-syntax-highlighting
#   - zsh-history-substring-search
#
# Idempotent: re-running updates plugins and refreshes config (existing
# ~/.zshrc / ~/.config/starship.toml are backed up before being replaced).
#
# Usage:
#   chmod +x install-zsh.sh
#   ./install-zsh.sh

set -euo pipefail

# ---- helpers ---------------------------------------------------------------
c_info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
c_ok()    { printf '\033[1;32mok\033[0m %s\n' "$*"; }
c_warn()  { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()     { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] && die "Run as a normal user, not root (the script uses sudo where needed)."

SUDO=""
if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; fi

PLUGIN_DIR="${HOME}/.zsh/plugins"

# ---- 1. system packages ----------------------------------------------------
command -v apt-get >/dev/null 2>&1 \
  || die "This script targets Debian/Ubuntu WSL (apt-get not found)."

c_info "Updating package lists & installing base packages..."
$SUDO apt-get update -y
$SUDO apt-get install -y zsh git curl
c_ok "zsh, git, curl installed."

# ---- 2. starship -----------------------------------------------------------
if command -v starship >/dev/null 2>&1; then
  c_ok "starship already installed ($(starship --version | head -n1))."
else
  c_info "Installing starship prompt..."
  curl -fsSL https://starship.rs/install.sh | $SUDO sh -s -- --yes
  c_ok "starship installed."
fi

# ---- 3. plugins ------------------------------------------------------------
declare -A PLUGINS=(
  [zsh-completions]="https://github.com/zsh-users/zsh-completions"
  [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions"
  [zsh-you-should-use]="https://github.com/MichaelAquilina/zsh-you-should-use"
  [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting"
  [zsh-history-substring-search]="https://github.com/zsh-users/zsh-history-substring-search"
)

mkdir -p "$PLUGIN_DIR"
for name in "${!PLUGINS[@]}"; do
  dest="${PLUGIN_DIR}/${name}"
  if [ -d "${dest}/.git" ]; then
    c_info "Updating ${name}..."
    git -C "$dest" pull --ff-only --quiet || c_warn "Could not update ${name}, keeping existing copy."
  else
    c_info "Cloning ${name}..."
    git clone --depth=1 --quiet "${PLUGINS[$name]}" "$dest"
  fi
done
c_ok "Plugins ready in ${PLUGIN_DIR}."

# ---- 4. config files -------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ts="$(date +%Y%m%d-%H%M%S)"

install_config() {
  local src="$1" dst="$2"
  [ -f "$src" ] || die "Missing source config: $src"
  mkdir -p "$(dirname "$dst")"
  if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
    cp "$dst" "${dst}.bak.${ts}"
    c_warn "Backed up existing $(basename "$dst") -> ${dst}.bak.${ts}"
  fi
  cp "$src" "$dst"
  c_ok "Installed $(basename "$dst")."
}

install_config "${SCRIPT_DIR}/.zshrc"         "${HOME}/.zshrc"
install_config "${SCRIPT_DIR}/starship.toml"  "${HOME}/.config/starship.toml"

# ---- 5. default shell ------------------------------------------------------
zsh_path="$(command -v zsh)"
if [ "${SHELL:-}" != "$zsh_path" ]; then
  c_info "Setting zsh as your default login shell..."
  if chsh -s "$zsh_path"; then
    c_ok "Default shell set to zsh (takes effect on next login)."
  else
    c_warn "chsh failed. Set it manually:  chsh -s $zsh_path"
  fi
else
  c_ok "zsh is already your default shell."
fi

echo
c_ok "Done! Start zsh now with:  exec zsh"
