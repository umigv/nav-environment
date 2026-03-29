#!/usr/bin/env bash
set -euo pipefail

BASE_URL="https://downloads.umarv.com/mac"

# ---- Check for Apple Silicon ----
if [[ "$(uname -m)" != "arm64" ]]; then
    echo "ERROR: This script is for Apple Silicon Macs only."
    echo "If you have an Intel Mac, contact a lead for help."
    exit 1
fi

# ---- Install Homebrew if missing ----
if ! command -v brew &>/dev/null; then
    echo "==> Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ---- Install UTM if missing ----
if ! brew list --cask utm &>/dev/null; then
    echo "==> Installing UTM..."
    brew install --cask utm
fi

# ---- Install aria2 if missing ----
if ! command -v aria2c &>/dev/null; then
    echo "==> Installing aria2..."
    brew install aria2
fi

# ---- Download UTM bundle files ----
echo "==> Downloading ARV VM (~17 GB, this will take a while)..."
mkdir -p "ARV-VM.utm/Data"
download_if_needed() {
    local dir="$1" file="$2" url="$3"
    if [[ -f "$dir/$file" && ! -f "$dir/$file.aria2" ]]; then
        echo "==> Skipping $file (already downloaded)"
    else
        aria2c -x 8 -s 8 -d "$dir" -o "$file" "$url"
    fi
}

download_if_needed "ARV-VM.utm"      "config.plist"   "${BASE_URL}/config.plist"
download_if_needed "ARV-VM.utm"      "screenshot.png" "${BASE_URL}/screenshot.png"
download_if_needed "ARV-VM.utm/Data" "VM_Data.qcow2"  "${BASE_URL}/Data/VM_Data.qcow2"
download_if_needed "ARV-VM.utm/Data" "efi_vars.fd"    "${BASE_URL}/Data/efi_vars.fd"

# ---- Open the VM in UTM ----
echo "==> Opening VM in UTM..."
open "$(pwd)/ARV-VM.utm"

echo ""
echo "The ARV VM has been imported into UTM."
echo "Once it appears, press the play button to start it."
echo ""
echo "Login: ARV Member | Password: arvrules"
echo ""
echo "Once booted, open a terminal and run:"
echo "  wget -O ~/install_script.sh https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/main/install_script.sh && bash ~/install_script.sh"
