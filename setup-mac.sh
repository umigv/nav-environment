#!/usr/bin/env bash
set -euo pipefail

VM_DATA_URL="https://www.dropbox.com/scl/fi/ayn6m7l54pohwll7s352y/VM_Data.qcow2?rlkey=qf8lpqbj9qwrx6b613fjr9jdp&st=yr2p3cdm&dl=1"
EFI_VARS_URL="https://www.dropbox.com/scl/fi/hbt60wx5k2hyy6x65rj9c/efi_vars.fd?rlkey=9gt81don729qrf7jqd5vk4lm2&st=ultbkp2v&dl=1"
CONFIG_URL="https://www.dropbox.com/scl/fi/k6y4t8mrm0f9x9i5twf7t/config.plist?rlkey=8cx9l6xh7jojhaxai6550aoms&st=f5p4vhvc&dl=1"
SCREENSHOT_URL="https://www.dropbox.com/scl/fi/w6yx81mr1ymn31ui9bkvx/screenshot.png?rlkey=kkweak3fuc76r5whg5tmjh9r5&st=0lqon211&dl=1"

UTM_BUNDLE="$(pwd)/ARV VM macOS.utm"

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

# ---- Assemble UTM bundle ----
echo "==> Creating UTM bundle at: ${UTM_BUNDLE}"
mkdir -p "${UTM_BUNDLE}/Data"

echo "==> Downloading VM_Data.qcow2 (~3.6 GB, this will take a while)..."
aria2c -x 8 -s 8 -o "VM_Data.qcow2" -d "${UTM_BUNDLE}/Data" "${VM_DATA_URL}"

echo "==> Downloading efi_vars.fd..."
aria2c -x 8 -s 8 -o "efi_vars.fd" -d "${UTM_BUNDLE}/Data" "${EFI_VARS_URL}"

echo "==> Downloading config.plist..."
aria2c -x 8 -s 8 -o "config.plist" -d "${UTM_BUNDLE}" "${CONFIG_URL}"

echo "==> Downloading screenshot.png..."
aria2c -x 8 -s 8 -o "screenshot.png" -d "${UTM_BUNDLE}" "${SCREENSHOT_URL}"

# ---- Open the VM in UTM ----
echo "==> Opening VM in UTM..."
open "${UTM_BUNDLE}"

echo ""
echo "The ARV VM has been imported into UTM."
echo "Once it appears, press the play button to start it."
echo ""
echo "Login: ARV Member | Password: arvrules"
echo ""
echo "Once booted, open a terminal and run:"
echo "  wget -O ~/install_script.sh https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/main/install_script.sh && bash ~/install_script.sh"
