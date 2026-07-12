# ARV Navigation Host Environment Bootstrap

This repo maintains host-level tools used across all ARV repos.

## Getting started
Before you start, make a GitHub account if you don't have one. Then, follow the guide based on your operating system. If something goes wrong, check [Troubleshooting](#troubleshooting). 

---

## MacOS (Apple Silicon)
Run the following in your terminal:
```bash
curl -fsSLO https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/main/bootstrap.sh && bash bootstrap.sh
```

Follow the prompts. If you encounter anything related to SSH keys just press enter.

---

## Windows
Open PowerShell **as Administrator**, then run:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Invoke-WebRequest -Uri https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/main/windows_bootstrap.ps1 -OutFile "$env:TEMP\windows_bootstrap.ps1"; & "$env:TEMP\windows_bootstrap.ps1"
```

Follow the prompts. If you encounter anything related to SSH keys just press enter.

**For ROS2 code, you also need WSL2.** If you don't have it, install it by following [this tutorial](https://eecs280staff.github.io/tutorials/setup_wsl.html), then inside the WSL2 terminal run:
```bash
wget https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/main/bootstrap.sh && bash bootstrap.sh
```

Follow the prompts. If you encounter anything related to SSH keys just press enter.

To pass a USB device into WSL2, from an admin PowerShell:
```powershell
usbipd list                          # find the device's BUSID
usbipd bind --busid <BUSID>          # one-time, per device
usbipd attach --wsl --busid <BUSID>  # each time you plug it in
```

---

## Debian / Ubuntu
Run the following in your terminal:
```bash
wget https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/main/bootstrap.sh && bash bootstrap.sh
```

Follow the prompts. If you encounter anything related to SSH keys just press enter.

---

## MacOS (Intel)
Talk with Caitlyn.

---

## None of the above
If you don't use any of the above systems, we assume you are using some other Linux distro. We don't offer first class support for this due to the sheer number of possibilities and because we believe you know what you're doing.

We need these things:
- A text editor or IDE installed. We offer first class support for [VSCode](https://code.visualstudio.com/) but you're free to use whatever.
- [Pixi](https://pixi.sh) installed. Our repos use it to install their locked toolchains.
- [Just](https://github.com/casey/just) and [Direnv](https://direnv.net/) >=2.36 installed. Just is our centralized way to run commands across our repos; direnv loads environment variables automatically in our repos, which is especially useful for ROS2. Once Pixi is installed, `pixi global install just direnv` gets you both (this is what `bootstrap.sh` does), but any install method works.
- An SSH key added to your GitHub account.
- An empty `direnv.toml` file created in `~/.config/direnv`. This is used to configure direnv silencing.
- The equivalent of `configure_shell` in `bootstrap.sh` configured for your shell. **This also applies if you run a supported OS but a shell other than bash or zsh.**
- Non-root access to serial devices (equivalent of `dialout` group on Ubuntu).

---

## Troubleshooting

### "Permission denied" on a directory
A directory (often `~/.config`) is owned by root, usually because an installer was run with `sudo` at some point. Take ownership back:
```bash
sudo chown -R "$USER" <directory>
```
Replace `<directory>` with the directory from the error message, then retry whatever failed.

### Git errors when cloning or pushing (e.g. `Permission denied (publickey)`)
Your SSH key isn't set up correctly with GitHub. Reset the GitHub login and let the setup script redo it:
```bash
gh auth logout
```
Then run the setup script for your OS again and follow the GitHub prompts.

### Conda is installed and Pixi isn't working
Conda auto-activates its `base` environment in every new shell, which interferes with Pixi. Turn the autoload off:
```bash
conda config --set auto_activate_base false
```
Then open a new terminal and try again.

### Still stuck?
If none of the above solves your problem, ask a lead.
