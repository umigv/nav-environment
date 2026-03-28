# ARV Navigation Environment Setup

Before you start, if you don't have a GitHub account, make one.

We run ROS in a virtualized Linux environment. Follow the directions for your system:

- [macOS (Apple Silicon)](#macos-apple-silicon)
- [Windows](#windows)
- [macOS (Intel)](#macos-intel)

---

## macOS (Apple Silicon)

Run the following in your terminal:

```bash
wget -O ~/setup-mac.sh https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/main/setup-mac.sh && bash ~/setup-mac.sh
```

This will install UTM, download the ARV VM, and open it automatically.

Once the VM is running:

1. Select **ARV Member** on the login screen
2. Password: `arvrules`

---

## Windows

Open PowerShell as Administrator, then run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Invoke-WebRequest -Uri https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/main/setup-windows.ps1 -OutFile "$env:TEMP\setup-windows.ps1"; & "$env:TEMP\setup-windows.ps1"
```

This will install VirtualBox, download the ARV VM files, and import them automatically.

Once the VM is running:

1. Select **arvuser** on the login screen
2. Password: `arvrules`

---

## macOS (Intel)

Talk to Ethan.

---

## Ubuntu

No setup needed — proceed to [Linux Setup](#linux-setup) below.

---

## Linux Setup

Once logged in, open a terminal and run:

```bash
wget -O ~/install_script.sh https://raw.githubusercontent.com/umigv/nav-environment/refs/heads/main/install_script.sh && bash ~/install_script.sh
```

Follow the prompts — the script will set up ROS, VSCode, and your GitHub account automatically. Reboot when it finishes.
