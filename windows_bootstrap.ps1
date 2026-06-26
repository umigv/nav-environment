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
    $reply = Read-Host "VSCode not found. Install it? Choose 'n' if you have another editor. [Y/n]"
    if ($reply -notmatch '^[Nn]') {
        winget install --exact --id Microsoft.VisualStudioCode --silent `
            --accept-package-agreements --accept-source-agreements
    } else {
        Write-Host "Skipping VSCode install (using your own editor)."
    }
}

Write-Host "Windows bootstrap complete."
