# Run this in PowerShell as Administrator:
#   Right-click PowerShell -> "Run as Administrator", then:
#     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#     .\windows_bootstrap.ps1

#Requires -RunAsAdministrator

Write-Host "==> Installing usbipd-win (USB passthrough into WSL)..."
if (-not (Get-Command usbipd -ErrorAction SilentlyContinue)) {
    winget install --exact --id dorssel.usbipd-win --silent `
        --accept-package-agreements --accept-source-agreements
}

Write-Host "==> Visual Studio Code..."
if (Get-Command code -ErrorAction SilentlyContinue) {
    Write-Host "VS Code already installed."
} else {
    $reply = Read-Host "VS Code not found. Install it? Choose 'n' if you have another editor. [Y/n]"
    if ($reply -notmatch '^[Nn]') {
        winget install --exact --id Microsoft.VisualStudioCode --silent `
            --accept-package-agreements --accept-source-agreements
    } else {
        Write-Host "Skipping VS Code install (using your own editor)."
    }
}

Write-Host "==> Installing VS Code WSL extension..."
if (Get-Command code -ErrorAction SilentlyContinue) {
    code --install-extension ms-vscode-remote.remote-wsl --force
} else {
    Write-Host "VS Code 'code' command not found; skipping extension install."
}

Write-Host "usbipd installed."
Write-Host "Make sure WSL2 + Ubuntu are set up first (EECS 280 tutorial):"
Write-Host "  https://github.com/eecs280staff/tutorials/blob/main/docs/setup_wsl.md"
