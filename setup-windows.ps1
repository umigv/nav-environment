# Run this script in PowerShell as Administrator
# Right-click PowerShell -> "Run as Administrator", then:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\setup-windows.ps1

$OVA_URL = "https://www.dropbox.com/scl/fi/c97lo3p13eqtymeln936g/ARV.ova?rlkey=hgnlqha2vothicvs0z39g5nrn&st=kr1w9lco&dl=1"
$VDI_URL = "https://www.dropbox.com/scl/fi/9aj39pm5ehdvefnsbkxyf/ARV.vdi?rlkey=5wv4p5qs71ox8bj9n56x9x4fv&st=9xlfqsej&dl=1"

$DEST = "$HOME\Documents\ARV VM"

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

$ovaPath = "$DEST\ARV.ova"
$vdiPath = "$DEST\ARV.vdi"

Write-Host "==> Downloading ARV.ova..."
aria2c -x 8 -s 8 -o "ARV.ova" -d $DEST $OVA_URL

Write-Host "==> Downloading ARV.vdi..."
aria2c -x 8 -s 8 -o "ARV.vdi" -d $DEST $VDI_URL

# ---- Import VM ----
Write-Host "==> Importing VM into VirtualBox..."
VBoxManage import $ovaPath

# ---- Attach VDI ----
Write-Host "==> Attaching storage..."
$vmName = "ARV VM"
VBoxManage storageattach $vmName --storagectl "SATA" --port 1 --device 0 --type hdd --medium $vdiPath

Write-Host ""
Write-Host "VM imported! Open VirtualBox and start the ARV VM."
Write-Host "Login: arvuser | Password: arvrules"
Write-Host ""
Write-Host "Once booted, open a terminal and run:"
Write-Host "  wget -O ~/install_script.sh https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/main/install_script.sh && bash ~/install_script.sh"
