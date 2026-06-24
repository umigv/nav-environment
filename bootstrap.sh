#!/usr/bin/env bash
set -Eeuo pipefail

LOCAL_BIN="$HOME/.local/bin"
# Make freshly-installed binaries visible to `command -v` within this same run.
export PATH="$LOCAL_BIN:$PATH"

RC_MARK_START="# >>> ARV environment >>>"
RC_MARK_END="# <<< ARV environment <<<"

log() { printf '\033[1;34m===>\033[0m %s\n' "$*"; }

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

case "$(detect_platform)" in
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
    command -v brew >/dev/null 2>&1 && { log "brew already installed"; return; }
    log "Installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
}

ensure_prereqs() {
    case "$(detect_platform)" in
        macos)
            # We need to have sudo authorization before brew install, since it
            # requires sudo, but cannot prompt the user for their password due
            # to being run in non-interactive mode.
            sudo -v
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
    case "$(detect_platform)" in
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
    case "$(detect_platform)" in
        macos)
            brew install --no-ask direnv ;;
        linux|wsl)
            mkdir -p "$LOCAL_BIN"
            curl -sfL https://direnv.net/install.sh | bin_path="$LOCAL_BIN" bash ;;
    esac
    assert_exists direnv
}

install_gh() {
    command -v gh >/dev/null 2>&1 && { log "gh already installed"; return; }
    log "Installing GitHub CLI"
    case "$(detect_platform)" in
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
    [ "$WANT_VSCODE" = 1 ] || return 0   # bare `return` would propagate the failed test (1) and trip `set -e`
    command -v code >/dev/null 2>&1 && { log "VSCode already installed"; return; }
    log "Installing VSCode"
    case "$(detect_platform)" in
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

configure_direnv() {
    local toml="$HOME/.config/direnv/direnv.toml"
    log "Configuring direnv"
    mkdir -p "$(dirname "$toml")"
    # We silence direnv via DIRENV_LOG_FORMAT= in the shell rc rather than
    # log_format = "-" in the toml (direnv bug: https://github.com/direnv/direnv/issues/1418).
    # The toml must exist for direnv to pick up env var overrides, so we touch it.
    touch "$toml"
}

configure_shell() {
    local rc shell_name block_file tmp
    rc="$(detect_rc)"
    shell_name="$(basename "${SHELL:-/bin/bash}")"
    [ "$shell_name" = zsh ] || shell_name=bash

    touch "$rc"
    log "Configuring $rc"

    # heredoc expansion is buggy on bash 3.2 (macOS default); use printf instead.
    # shellcheck disable=SC2016
    block_file="$(mktemp)"
    {
        printf '%s\n' "$RC_MARK_START"
        printf '%s\n' '# Added by the ARV host bootstrap. Edit/remove this whole block, not pieces.'
        printf '%s\n' 'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
        printf '%s\n' 'export DIRENV_LOG_FORMAT='
        printf 'eval "$(direnv hook %s)"\n' "$shell_name"
        printf 'source <(just --completions %s)\n' "$shell_name"
        printf '%s\n' "$RC_MARK_END"
    } > "$block_file"

    if grep -qF "$RC_MARK_START" "$rc"; then
        tmp="$(mktemp)"
        awk -v s="$RC_MARK_START" -v e="$RC_MARK_END" -v bf="$block_file" '
            $0 == s { while ((getline line < bf) > 0) print line; skip=1; next }
            skip && $0 == e { skip=0; next }
            !skip
        ' "$rc" > "$tmp" && mv "$tmp" "$rc"
    else
        printf '\n' >> "$rc"
        cat "$block_file" >> "$rc"
    fi
    rm -f "$block_file"
}

# ---- Per-user / per-machine config -----------------------------------------

add_dialout() {
    [ "$WANT_DIALOUT" = 1 ] || return 0   # bare `return` would propagate the failed test (1) and trip `set -e`
    log "Adding $USER to dialout group (USB/serial device access)"
    sudo usermod -aG dialout "$USER"
}

setup_github() {
    log "GitHub setup"
    if ! gh auth status >/dev/null 2>&1 || ! gh auth status 2>&1 | grep -q 'ssh'; then
        gh auth login --git-protocol ssh --web
    fi

    if ! git config --global user.name >/dev/null 2>&1; then
        git config --global user.name "$(gh api user --jq '.name // .login')"
    fi

    if ! git config --global user.email >/dev/null 2>&1; then
        local email
        email="$(gh api user --jq '.email // empty' 2>/dev/null || true)"
        [ -n "$email" ] || email="$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"')"
        git config --global user.email "$email"
    fi
}

finish() {
    # Wait for enter
    read
    # Delete this script now that bootstrap is done.
    rm -f "$0"
    # Close terminal by sending SIGHUP to the parent process (the terminal emulator)
    kill -HUP $PPID

}

# ---- Main ------------------------------------------------------------------

main() {
    log "ARV host bootstrap - platform: $(detect_platform)"
    ensure_prereqs
    install_just
    install_direnv
    install_gh
    install_vscode
    configure_direnv
    configure_shell
    add_dialout
    setup_github
    log "Host bootstrap complete. Press enter to close this terminal (required)."
    finish
}

main "$@"
