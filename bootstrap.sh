#!/usr/bin/env bash

set -Eeuo pipefail

LOCAL_BIN="$HOME/.local/bin"
# Make freshly-installed binaries visible to `command -v` within this same run.
export PATH="$LOCAL_BIN:$PATH"

RC_MARK_START="# >>> maverick environment >>>"
RC_MARK_END="# <<< maverick environment <<<"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

assert_exists() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: '$1' not on PATH after install" >&2; exit 1; } }

detect_platform() {
    case "$(uname -s)" in
        Darwin) 
            echo macos ;;
        Linux)
            if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
                echo wsl
            else
                echo linux
            fi ;;
        *) 
        echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
    esac
}

PLATFORM="$(detect_platform)"

case "$PLATFORM" in
    macos) WANT_VSCODE=1; WANT_DIALOUT=0 ;;  # dialout doesn't exist on mac
    wsl)   WANT_VSCODE=0; WANT_DIALOUT=1 ;;  # editor lives on the Windows host
    linux) WANT_VSCODE=1; WANT_DIALOUT=1 ;;
esac

detect_rc() {
    case "$(basename "${SHELL:-/bin/bash}")" in
        zsh) echo "$HOME/.zshrc" ;;
        *)   echo "$HOME/.bashrc" ;;
    esac
}

install_brew() {
    command -v brew >/dev/null 2>&1 && return
    log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
}

ensure_prereqs() {
    case "$PLATFORM" in
        macos) 
            install_brew ;;
        linux|wsl)
            log "Updating apt and installing base tools"
            sudo apt update
            sudo apt install -y curl wget git ca-certificates gnupg ;;
    esac
}

# ---- Tools -----------------------------------------------------------------

install_just() {
    command -v just >/dev/null 2>&1 && { log "just already installed"; return; }
    log "Installing just"
    case "$PLATFORM" in
        macos) 
            brew install just ;;
        linux|wsl)
            mkdir -p "$LOCAL_BIN"
            curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to "$LOCAL_BIN" ;;
    esac
    assert_exists just
}

install_direnv() {
    command -v direnv >/dev/null 2>&1 && { log "direnv already installed"; return; }
    log "Installing direnv"
    case "$PLATFORM" in
        macos) 
            brew install direnv ;;
        linux|wsl)
            mkdir -p "$LOCAL_BIN"
            curl -sfL https://direnv.net/install.sh | bin_path="$LOCAL_BIN" bash ;;
    esac
    assert_exists direnv
}

install_gh() {
    command -v gh >/dev/null 2>&1 && { log "gh already installed"; return; }
    log "Installing GitHub CLI"
    case "$PLATFORM" in
        macos) 
            brew install gh ;;
        linux|wsl)
            if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
                keyring=/usr/share/keyrings/githubcli-archive-keyring.gpg
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                    | sudo dd of="$keyring"
                sudo chmod go+r "$keyring"
                arch=$(dpkg --print-architecture)
                echo "deb [arch=$arch signed-by=$keyring] https://cli.github.com/packages stable main" \
                    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
                sudo apt update
            fi
            sudo apt install -y gh ;;
    esac
    assert_exists gh
}

install_vscode() {
    [ "$WANT_VSCODE" = 1 ] || return
    command -v code >/dev/null 2>&1 && { log "VSCode already installed"; return; }
    log "Installing VSCode"
    case "$PLATFORM" in
        macos) 
            brew install --cask visual-studio-code ;;
        linux)
            if [ ! -f /etc/apt/sources.list.d/vscode.list ]; then
                keyring=/usr/share/keyrings/microsoft.gpg
                repo=https://packages.microsoft.com/repos/code
                wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
                sudo install -D -o root -g root -m 644 /tmp/microsoft.gpg "$keyring"
                echo "deb [arch=amd64,arm64,armhf signed-by=$keyring] $repo stable main" \
                    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
                rm -f /tmp/microsoft.gpg
                sudo apt update
            fi
            sudo apt install -y code ;;
    esac
}

# ---- Shell integration -----------------------------------------------------

configure_direnv_silence() {
    local toml="$HOME/.config/direnv/direnv.toml"
    log "Writing $toml"
    mkdir -p "$(dirname "$toml")"
    cat > "$toml" <<'EOF'
# Managed by the maverick host bootstrap - edits here will be overwritten.
# Silence direnv's per-directory load/unload chatter.
[global]
log_format = ""
EOF
}

configure_shell() {
    local rc shell_name block tmp
    rc="$(detect_rc)"
    shell_name="$(basename "${SHELL:-/bin/bash}")"
    [ "$shell_name" = zsh ] || shell_name=bash

    touch "$rc"
    log "Writing maverick block to $rc"

    # Drop any previous block AND the blank line right before it, so re-runs
    # neither leave a stale copy nor accumulate blanks. (Also normalizes the
    # trailing newline, so the appended block always starts on its own line.)
    tmp="$(mktemp)"
    awk -v s="$RC_MARK_START" -v e="$RC_MARK_END" '
        skip    { if ($0 == e) skip = 0; next }                            # inside block: drop through end marker
        $0 == s { if (held && prev != "") print prev; held = 0; skip = 1; next }  # at start: drop the blank we held
                { if (held) print prev; prev = $0; held = 1 }              # 1-line lookbehind
        END     { if (held) print prev }
    ' "$rc" > "$tmp" && mv "$tmp" "$rc"

    # Quoted heredoc keeps $PATH / $(...) literal; only __SHELL__ is substituted.
    block="$(cat <<'EOF'
# >>> maverick environment >>>
# Added by the maverick host bootstrap. Edit/remove this whole block, not pieces.
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
eval "$(direnv hook __SHELL__)"
source <(just --completions __SHELL__)
# <<< maverick environment <<<
EOF
)"
    block="${block//__SHELL__/$shell_name}"
    # Always prepend a blank separator; the awk above removes it again on re-run.
    printf '\n%s\n' "$block" >> "$rc"
}

# ---- Per-user / per-machine config -----------------------------------------

add_dialout() {
    [ "$WANT_DIALOUT" = 1 ] || return
    log "Adding $USER to dialout group (USB/serial device access)"
    sudo usermod -aG dialout "$USER"
}

setup_github() {
    log "GitHub setup"
    if ! gh auth status >/dev/null 2>&1; then
        gh auth login
    fi

    if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
        log "Generating SSH key and adding it to your GitHub account"
        ssh-keygen -t ed25519 -C "$USER@$(hostname) (maverick)" -f "$HOME/.ssh/id_ed25519" -N ""
        gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "$(hostname) (maverick)" || true
    fi

    if ! git config --global user.name >/dev/null 2>&1; then
        git config --global user.name "$(gh api user --jq '.name // .login')"
    fi

    if ! git config --global user.email >/dev/null 2>&1; then
        local gemail
        gemail="$(gh api user --jq '.email // empty' 2>/dev/null || true)"
        [ -n "$gemail" ] || gemail="$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"')"
        git config --global user.email "$gemail"
    fi
}

# ---- Main ------------------------------------------------------------------

main() {
    log "Maverick host bootstrap - platform: $PLATFORM"
    ensure_prereqs
    install_just
    install_direnv
    install_gh
    install_vscode
    configure_direnv_silence
    configure_shell
    add_dialout
    setup_github
    log "Host bootstrap complete. Open a NEW terminal (or run: source $(detect_rc)) so the changes take effect"
}

main "$@"
