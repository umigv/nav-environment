# ARV Navigation Environment Setup

Before you start, if you don't have a GitHub account, make one.

We used to run ROS in a shared Linux VM. We now run **natively** — environments
are managed by [pixi](https://pixi.sh), so the same repo works on Linux, WSL, and
macOS with no VM.

Setup is two layers:

1. **Host bootstrap** (this repo's `bootstrap.sh`) — installs the host-level
   tools pixi can't manage: `just`, `direnv` (+ shell hooks), `gh`, your SSH
   key / git identity, and (on native machines) VSCode.
2. **Project setup** (`just setup` in the [maverick](https://github.com/umigv/maverick)
   repo) — runs `pixi install`, `direnv allow`, git hooks, etc. ROS, compilers,
   and all build deps come from pixi.

Follow the directions for your system:

- [macOS](#macos)
- [Windows (WSL)](#windows-wsl)
- [Linux](#linux)

---

## macOS

Run the following in your terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/main/bootstrap.sh -o ~/bootstrap.sh && bash ~/bootstrap.sh
```

This installs Homebrew (if needed), `just`, `direnv`, `gh`, and VSCode, and wires
up the shell hooks. Then continue to [Project setup](#project-setup).

---

## Windows (WSL)

Open PowerShell **as Administrator**, then run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Invoke-WebRequest -Uri https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/main/setup-windows.ps1 -OutFile "$env:TEMP\setup-windows.ps1"; & "$env:TEMP\setup-windows.ps1"
```

This installs WSL2 + Ubuntu and `usbipd-win` (for USB serial passthrough). If it
was a first-time WSL install, **reboot**, then launch **Ubuntu** from the Start
menu and create your Linux username/password.

Inside the Ubuntu terminal, run:

```bash
wget -O ~/bootstrap.sh https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/main/bootstrap.sh && bash ~/bootstrap.sh
```

To pass a USB device (ODrive, VectorNav, …) into WSL, from an admin PowerShell:

```powershell
usbipd list                          # find the device's BUSID
usbipd bind   --busid <BUSID>        # one-time, per device
usbipd attach --wsl --busid <BUSID>  # each time you plug it in
```

Then continue to [Project setup](#project-setup).

---

## Linux

Run the following in your terminal:

```bash
wget -O ~/bootstrap.sh https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/main/bootstrap.sh && bash ~/bootstrap.sh
```

Then continue to [Project setup](#project-setup).

---

## Project setup

After the host bootstrap finishes, **open a new terminal** (so the `direnv` and
`just` hooks load), then:

```bash
git clone git@github.com:umigv/maverick.git
cd maverick
just setup
```

`just setup` installs the ROS / build environment via pixi, allows `direnv`, and
configures git hooks. `direnv` auto-activates the environment whenever you `cd`
into the repo. See the [maverick README](https://github.com/umigv/maverick) for
how to build and run the stack.
