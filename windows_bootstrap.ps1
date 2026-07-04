#Requires -RunAsAdministrator

function Install-IfMissing($Command, $WingetId, $Description) {
    Write-Host "==> $Description..."
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Write-Host "$Command already installed."
    } else {
        winget install --exact --id $WingetId --silent `
            --accept-package-agreements --accept-source-agreements
    }
}

Install-IfMissing git    Git.Git         "Git"
Install-IfMissing pixi   prefix-dev.pixi "pixi (per-repo toolchain manager)"
Install-IfMissing just   Casey.Just      "just (command runner)"
Install-IfMissing gh     GitHub.cli      "GitHub CLI"
Install-IfMissing usbipd dorssel.usbipd-win "usbipd-win (USB passthrough into WSL2, for the ROS stack)"

Write-Host "==> Visual Studio Code..."
if (Get-Command code -ErrorAction SilentlyContinue) {
    Write-Host "VSCode already installed."
} else {
    $reply = Read-Host "VSCode not found. Install it? Choose 'n' if you have another editor. [Y/n]"
    if ($reply -notmatch '^[Nn]') {
        winget install --exact --id Microsoft.VisualStudioCode --silent `
            --accept-package-agreements --accept-source-agreements
    } else {
        Write-Host "Skipping VSCode install (using your own editor)."
    }
}

# Fresh winget installs are not on this session's PATH yet; reload it so gh/git below resolve.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')

# The ssh-agent service is disabled by default on Windows; without it a passphrase-protected
# key prompts on every push.
Write-Host "==> Enabling ssh-agent service..."
Set-Service -Name ssh-agent -StartupType Automatic
Start-Service ssh-agent

Write-Host "==> GitHub setup..."
gh auth status *> $null
if ($LASTEXITCODE -ne 0 -or -not (gh auth status 2>&1 | Select-String -Quiet 'ssh')) {
    gh auth login --git-protocol ssh --web
}

if (-not (git config --global user.name)) {
    git config --global user.name (gh api user --jq '.name // .login')
}
if (-not (git config --global user.email)) {
    $email = gh api user --jq '.email // empty'
    if (-not $email) {
        $email = gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"'
    }
    git config --global user.email $email
}

Write-Host "Windows bootstrap complete. Open a NEW terminal so PATH changes take effect."
