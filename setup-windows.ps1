# Run this script in PowerShell as Administrator
# Right-click PowerShell -> "Run as Administrator", then:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\setup-windows.ps1

$BASE_URL = "https://downloads.umarv.com/windows"

$DEST = (Get-Location).Path

# ---- Install VirtualBox if missing ----
if (-not (Get-Command VBoxManage -ErrorAction SilentlyContinue)) {
    Write-Host "==> Downloading VirtualBox installer..."
    $vboxInstaller = "$env:TEMP\VirtualBox-installer.exe"
    Invoke-WebRequest -Uri "https://download.virtualbox.org/virtualbox/7.0.14/VirtualBox-7.0.14-161095-Win.exe" -OutFile $vboxInstaller
    Write-Host "==> Installing VirtualBox..."
    Start-Process -FilePath $vboxInstaller -ArgumentList "--silent" -Wait
    Remove-Item $vboxInstaller
}

# ---- Install aria2 if missing ----
if (-not (Get-Command aria2c -ErrorAction SilentlyContinue)) {
    Write-Host "==> Installing aria2..."
    winget install aria2.aria2 --silent --accept-package-agreements --accept-source-agreements
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
}

# ---- Download VM files ----
Write-Host "==> Downloading VM files (this may take a while)..."
New-Item -ItemType Directory -Force -Path $DEST | Out-Null

function Download-IfNeeded($dir, $file, $url) {
    if ((Test-Path "$dir\$file") -and -not (Test-Path "$dir\$file.aria2")) {
        Write-Host "==> Skipping $file (already downloaded)"
    } else {
        aria2c -x 8 -s 8 -d $dir -o $file $url
    }
}

Download-IfNeeded $DEST "ARV.ova" "$BASE_URL/ARV.ova"
Download-IfNeeded $DEST "ARV.vdi" "$BASE_URL/ARV.vdi"

# ---- Import VM ----
Write-Host "==> Importing VM into VirtualBox..."
VBoxManage import "$DEST\ARV.ova"

# ---- Attach VDI ----
Write-Host "==> Attaching storage..."
$vmName = "ARV VM"
VBoxManage storageattach $vmName --storagectl "SATA" --port 1 --device 0 --type hdd --medium "$DEST\ARV.vdi"

Write-Host ""
Write-Host "VM imported! Open VirtualBox and start the ARV VM."
Write-Host "Login: arvuser | Password: arvrules"
Write-Host ""
Write-Host "Once booted, open a terminal and run:"
Write-Host "  wget -O ~/install_script.sh https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/main/install_script.sh && bash ~/install_script.sh"
