#!/usr/bin/env bash
set -Eeuo pipefail

LOCAL_BIN="$HOME/.local/bin"
# Make freshly-installed binaries visible to `command -v` within this same run.
export PATH="$LOCAL_BIN:$PATH"

log() { printf '\033[1;34m===> %s\033[0m\n' "$*"; }
trap 'printf "\033[1;31mERROR at line %s: %s (exit %s)\033[0m\n" "$LINENO" "$BASH_COMMAND" "$?" >&2' ERR

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

install_brew() {
    command -v brew >/dev/null 2>&1 && { log "brew already installed"; return; }
    log "Installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
}

ensure_prereqs() {
    case "$(detect_platform)" in
        macos)
            # We need to have sudo authorization before brew install, since it requires sudo, but cannot prompt the user
            # for their password due to being run in non-interactive mode.
            sudo -v
            install_brew ;;
        linux|wsl)
            log "Updating apt and installing base tools"
            sudo apt update
            sudo apt install -y curl wget git ca-certificates gnupg ;;
    esac
}

# ---- Tools -----------------------------------------------------------------------------------------------------------

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
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of="$keyring"
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
    local reply
    read -r -p "VSCode not found. Install it? Choose 'n' if you have another editor. [Y/n] " reply
    case "$reply" in
        [Nn]*) log "Skipping VSCode install (using your own editor)"; return 0 ;;
    esac
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

# ---- Shell integration -----------------------------------------------------------------------------------------------

configure_direnv() {
    local toml="$HOME/.config/direnv/direnv.toml"
    log "Configuring direnv"
    mkdir -p "$(dirname "$toml")"
    # We silence direnv via DIRENV_LOG_FORMAT= in the shell rc rather than log_format = "-" in the toml (direnv bug:
    # https://github.com/direnv/direnv/issues/1418). The toml must exist for direnv to pick up env var overrides, so we
    # touch it.
    touch "$toml"
}

update_or_append_block() {
    local rc_path="$1" body="$2" rc_name="${1##*/}"
    local mark_start='# >>> ARV environment >>>'
    local mark_end='# <<< ARV environment <<<'
    local block="$mark_start
$body
$mark_end"

    if grep -qF "$mark_start" "$rc_path"; then
        log "Updating configuration in ~/$rc_name"
        local tmp_block tmp_out
        tmp_block=$(mktemp)
        tmp_out=$(mktemp)
        printf '%s\n' "$block" > "$tmp_block"
        awk -v s="$mark_start" -v e="$mark_end" -v bf="$tmp_block" '
            $0 == s { while ((getline line < bf) > 0) print line; inside = 1; next }
            inside && $0 == e { inside = 0; next }
            !inside { print }
        ' "$rc_path" > "$tmp_out"
        mv "$tmp_out" "$rc_path"
        rm -f "$tmp_block"
    else
        log "Installing configuration in ~/$rc_name"
        printf '\n%s\n' "$block" >> "$rc_path"
    fi
}

# Single-quoted so $PATH/$HOME/$(...) stay literal for the user's shell to evaluate.
# shellcheck disable=SC2016
BASH_BODY='# Added by the ARV host bootstrap. Edit/remove this whole block, not pieces.
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
export DIRENV_LOG_FORMAT=
eval "$(direnv hook bash)"
source <(just --completions bash)'

# shellcheck disable=SC2016
ZSH_BODY='# Added by the ARV host bootstrap. Edit/remove this whole block, not pieces.
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
export DIRENV_LOG_FORMAT=
eval "$(direnv hook zsh)"
# Register completions and initialize
fpath=("$HOME/.zsh/completions" $fpath)
command -v compdef >/dev/null 2>&1 || { autoload -Uz compinit && compinit; }'

install_zsh_completion() {
    local dir="$HOME/.zsh/completions"
    log "Installing zsh completion for just in ~/.zsh/completions"
    mkdir -p "$dir"
    { printf '#compdef just\n'; just --completions zsh; } > "$dir/_just"
}

configure_shell() {
    local rc body
    case "$(basename "${SHELL:-/bin/bash}")" in
        zsh) rc="$HOME/.zshrc";  body="$ZSH_BODY"; install_zsh_completion ;;
        *)   rc="$HOME/.bashrc"; body="$BASH_BODY" ;;
    esac
    touch "$rc"
    update_or_append_block "$rc" "$body"
}

# ---- Per-user / per-machine config -----------------------------------------------------------------------------------

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

# SIGHUP the terminal emulator so its window closes, forcing a fresh login shell so the rc changes we just wrote take
# effect. We climb the process tree by ancestor *name* rather than a fixed number of hops, since the launch chain
# between this script and the terminal can gain or lose layers.
close_terminal() {
    local pid=$PPID name
    while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
        name=$(ps -o comm= -p "$pid" 2>/dev/null) || break
        case "$name" in
            *gnome-terminal*|*konsole*|*xterm*|*alacritty*|*kitty*|*tilix*|\
            *terminator*|*wezterm*|*foot*|*ptyxis*|*xfce4-terminal*|login*)
                kill -HUP "$pid"
                return 0 ;;
        esac
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    done
    # No known terminal in the ancestry. Leave for manual close rather than risk killing the wrong process.
    return 0
}

# ---- Main ------------------------------------------------------------------------------------------------------------

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
    read -r
    rm -f "$0"
    close_terminal
}

main "$@"
