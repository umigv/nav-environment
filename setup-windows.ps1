# Run this in PowerShell as Administrator:
#   Right-click PowerShell -> "Run as Administrator", then:
#     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#     .\setup-windows.ps1
#
# Native Windows is no longer used. The dev environment runs natively inside
# WSL2 (Ubuntu). This script installs WSL2 + Ubuntu and usbipd-win (so USB
# serial devices can be passed into WSL), then you run bootstrap.sh INSIDE Ubuntu.

#Requires -RunAsAdministrator

Write-Host "==> Installing WSL2 + Ubuntu..."
# Installs the WSL2 platform and the Ubuntu distro. On a machine without WSL
# this enables features and requires a reboot before Ubuntu can launch.
wsl --install -d Ubuntu

Write-Host "==> Installing usbipd-win (USB passthrough into WSL)..."
if (-not (Get-Command usbipd -ErrorAction SilentlyContinue)) {
    winget install --exact --id dorssel.usbipd-win --silent `
        --accept-package-agreements --accept-source-agreements
}

Write-Host ""
Write-Host "WSL + usbipd installed."
Write-Host "If this was a first-time WSL install, REBOOT, then launch 'Ubuntu' from the Start menu"
Write-Host "and finish creating your Linux username/password."
Write-Host ""
Write-Host "Inside the Ubuntu terminal, run:"
Write-Host "  wget -O ~/bootstrap.sh https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/main/bootstrap.sh && bash ~/bootstrap.sh"
Write-Host ""
Write-Host "To use a USB device (ODrive / VectorNav / etc.) inside WSL, from an admin PowerShell:"
Write-Host "  usbipd list                          # find the device's BUSID"
Write-Host "  usbipd bind   --busid <BUSID>        # one-time, per device"
Write-Host "  usbipd attach --wsl --busid <BUSID>  # each time you plug it in"
