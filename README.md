# ARV Navigation Host Environment Bootstrap

> ⚠️ **Before merging to `main`:** the download URLs below point at the `ryanliao/docker`
> branch for testing. Switch every `refs/heads/ryanliao/docker/` back to `refs/heads/main/`
> before merging, or the published instructions will fetch from this branch.

This repo maintains host-level tools used across all ARV repos.

Before you start, if you don't have a GitHub account, make one, then follow the guide based on your operating system.

## What this does
Before you run it, the bootstrap script makes a few persistent changes on your machine:
- **Installs CLI tools:** [just](https://github.com/casey/just), [direnv](https://direnv.net/), and the [GitHub CLI](https://cli.github.com/).
- **Edits your shell rc file** (`~/.bashrc` or `~/.zshrc`). It adds a clearly marked block (between `# >>> ARV environment >>>` and `# <<< ARV environment <<<`) that puts `~/.local/bin` on your PATH, silences direnv, and configures direnv and just.
- **Adds you to the `dialout` group** (Linux/WSL only) for non-root access to USB/serial devices.
- **Sets your global git identity**: `user.name` / `user.email` if they aren't already configured.

The script is idempotent and thus safe to rerun.

---

## MacOS (Apple Silicon)

Run the following in your terminal:
```bash
curl -fsSL https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/ryanliao/docker/bootstrap.sh -o ~/bootstrap.sh && bash ~/bootstrap.sh
```

Follow the prompts. If you encounter anything related to SSH keys just press enter.

---

## Windows
Firstly, if you don't have WSL2, install it by following [this tutorial](https://eecs280staff.github.io/tutorials/setup_wsl.html).

Open PowerShell **as Administrator**, then run:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Invoke-WebRequest -Uri https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/ryanliao/docker/windows_bootstrap.ps1 -OutFile "$env:TEMP\windows_bootstrap.ps1"; & "$env:TEMP\windows_bootstrap.ps1"
```

Inside the WSL2 terminal, run:
```bash
wget -O ~/bootstrap.sh https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/ryanliao/docker/bootstrap.sh && bash ~/bootstrap.sh
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
wget -O ~/bootstrap.sh https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/ryanliao/docker/bootstrap.sh && bash ~/bootstrap.sh
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
- [Just](https://github.com/casey/just) installed. We use it as a centralized way to run commands across our repos.
- [Direnv](https://direnv.net/) >=2.36 installed. We use it to load environment variables automatically in our repos which is especially useful for ROS2.
- An SSH key added to your GitHub account.
- An empty `direnv.toml` file created in `~/.config/direnv`. This is used to configure direnv silencing.
- The equivalent `.<shell>rc` block in `bootstrap.sh` configured for your desired shell. This is used to configure just autocompletions and direnv hook + silencing.
- Non-root access to serial devices (equivalent of `dialout` group on Ubuntu).
