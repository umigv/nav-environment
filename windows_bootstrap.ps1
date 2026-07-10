#Requires -RunAsAdministrator

function Install-IfMissing($Command, $WingetId, $Description, $Prompt) {
    Write-Host "==> $Description..."
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Write-Host "$Command already installed."
        return
    }
    if ($Prompt) {
        $reply = Read-Host $Prompt
        if ($reply -match '^[Nn]') {
            Write-Host "Skipping $Description install."
            return
        }
    }
    winget install --exact --id $WingetId --silent `
        --accept-package-agreements --accept-source-agreements
}

Install-IfMissing git    Git.Git         "Git"
Install-IfMissing pixi   prefix-dev.pixi "pixi"
Install-IfMissing just   Casey.Just      "just"
Install-IfMissing gh     GitHub.cli      "GitHub CLI"
Install-IfMissing usbipd dorssel.usbipd-win "usbipd-win (USB passthrough into WSL2)"

Install-IfMissing code Microsoft.VisualStudioCode "Visual Studio Code" `
    -Prompt "VSCode not found. Install it? Choose 'n' if you have another editor. [Y/n]"

# Fresh winget installs are not on this session's PATH yet; reload it so gh/git below resolve.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')

# The ssh-agent service is disabled by default on Windows; without it a passphrase-protected key prompts on every push.
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
