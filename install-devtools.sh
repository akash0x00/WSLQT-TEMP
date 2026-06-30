#!/usr/bin/env bash
#
# install-devtools.sh — Dev/CTF tooling for WSL (Debian/Ubuntu).
#
# Installs: golang, python3 + pip + pipx, bat, jq, htop, tree, build-essential,
#           nmap, whois, dnsenum, openvpn, php-cli, unzip/zip/7z/tar, gdebi.
# Configures (idempotently, in ~/.zshrc):
#   - GOPATH + go bin on PATH
#   - pipx PATH + zsh argcomplete
#   - `bat` alias (Ubuntu ships the binary as `batcat`)
#
# Run AFTER install-zsh.sh (it appends to the ~/.zshrc that script generates).
# Idempotent: re-running won't duplicate lines.
#
# Usage:
#   chmod +x install-devtools.sh && ./install-devtools.sh

set -euo pipefail

# ---- helpers ---------------------------------------------------------------
c_info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
c_ok()    { printf '\033[1;32mok\033[0m %s\n' "$*"; }
c_warn()  { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()     { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] && die "Run as a normal user, not root (the script uses sudo where needed)."
command -v apt-get >/dev/null 2>&1 || die "This script targets Debian/Ubuntu WSL (apt-get not found)."

SUDO=""
command -v sudo >/dev/null 2>&1 && SUDO="sudo"

ZSHRC="${HOME}/.zshrc"
touch "$ZSHRC"

# Append a marked block to ~/.zshrc only if its marker isn't already there.
ensure_block() {
  local marker="$1" content="$2"
  if grep -qF "$marker" "$ZSHRC"; then
    c_ok "Already configured: ${marker#\# }"
  else
    printf '\n%s\n' "$content" >> "$ZSHRC"
    c_ok "Configured: ${marker#\# }"
  fi
}

# ---- 1. system packages ----------------------------------------------------
c_info "Updating package lists..."
$SUDO apt-get update -y

c_info "Installing dev/CTF packages..."
$SUDO apt-get install -y \
  golang-go python3 python3-pip pipx python3-argcomplete \
  bat jq htop tree build-essential \
  nmap whois dnsenum openvpn php-cli \
  unzip zip p7zip-full tar gdebi \
  perl libnet-ssleay-perl openssl libauthen-pam-perl libio-pty-perl apt-show-versions
c_ok "Packages installed."

# ---- 2. Go environment -----------------------------------------------------
ensure_block "# >>> go env (devtools) >>>" '# >>> go env (devtools) >>>
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"
# <<< go env (devtools) <<<'

# ---- 3. pipx ---------------------------------------------------------------
c_info "Ensuring pipx is on PATH..."
pipx ensurepath >/dev/null 2>&1 || c_warn "pipx ensurepath reported an issue (usually harmless)."

ensure_block "# >>> pipx argcomplete (devtools) >>>" '# >>> pipx argcomplete (devtools) >>>
autoload -U bashcompinit && bashcompinit && eval "$(register-python-argcomplete pipx)"
# <<< pipx argcomplete (devtools) <<<'

# ---- 4. bat alias (Debian/Ubuntu install the binary as `batcat`) -----------
if command -v bat >/dev/null 2>&1; then
  : # already named bat, nothing to do
elif command -v batcat >/dev/null 2>&1; then
  ensure_block "# >>> bat alias (devtools) >>>" '# >>> bat alias (devtools) >>>
alias bat="batcat"
# <<< bat alias (devtools) <<<'
fi

# ---- 5. Python security tools (pipx) ---------------------------------------
c_info "Installing Python security tools via pipx..."
pipx_install() {
  local pkg="$1"
  if pipx list 2>/dev/null | grep -q "package ${pkg} "; then
    c_ok "${pkg} already installed (pipx)."
  else
    pipx install "$pkg" && c_ok "${pkg} installed (pipx)." \
      || c_warn "pipx install ${pkg} failed."
  fi
}
pipx_install sqlmap
pipx_install wafw00f

# ---- 6. verify -------------------------------------------------------------
echo
c_info "Versions:"
go version       2>/dev/null || c_warn "go not found on PATH (open a new shell)."
python3 --version
pipx --version   | sed 's/^/pipx /'

echo
c_ok "Done. Reload your shell to pick up the new config:  exec zsh"
