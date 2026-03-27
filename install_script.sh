#!/bin/bash
set -Eueo pipefail

# ---- System update ----
echo "Updating and upgrading packages..."
sudo apt update && sudo apt upgrade -y

# ---- Base deps ----
sudo apt install -y curl git python3 python3-pip
python3 -m pip install -U pip

# ---- VSCode ----
echo "Installing VSCode..."
if [ ! -f /etc/apt/sources.list.d/vscode.list ]; then
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    rm -f packages.microsoft.gpg
    sudo apt update
fi
sudo apt install -y code

# ---- GitHub CLI ----
echo "Installing GitHub CLI..."
if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
fi
sudo apt install -y gh

# ---- ROS 2 Humble ----
echo "Installing ROS 2 Humble..."
sudo apt install -y software-properties-common
sudo add-apt-repository universe -y
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
sudo apt update
sudo apt install -y ros-humble-desktop ros-dev-tools nlohmann-json3-dev
if ! grep -q 'source /opt/ros/humble/setup.bash' ~/.bashrc; then
    echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
fi
sudo rosdep init 2>/dev/null || true
rosdep update

# ---- System permissions ----
echo "Adding $USER to dialout group (USB/serial device access)..."
sudo usermod -aG dialout "$USER"

# ---- GitHub login, SSH key, git config ----
echo
echo "===== GitHub Setup ====="
if ! gh auth status &>/dev/null; then
    echo "Log in to GitHub..."
    gh auth login
fi

if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "Generating SSH key..."
    GH_EMAIL=$(gh api user --jq '.email // empty')
    if [ -z "$GH_EMAIL" ]; then
        GH_EMAIL="$(gh api user --jq '.id + 0 | tostring')+$(gh api user --jq '.login')@users.noreply.github.com"
    fi
    ssh-keygen -t ed25519 -C "$GH_EMAIL" -f ~/.ssh/id_ed25519 -N ""
fi

eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

PUB_KEY=$(awk '{print $2}' ~/.ssh/id_ed25519.pub)
if ! gh ssh-key list | grep -q "$PUB_KEY"; then
    echo "Adding SSH key to your GitHub account..."
    gh ssh-key add ~/.ssh/id_ed25519.pub --title "ARV VM"
fi

echo "Configuring git from your GitHub profile..."
git config --global user.name "$(gh api user --jq '.name')"
GH_EMAIL=$(gh api user --jq '.email // empty')
if [ -z "$GH_EMAIL" ]; then
    GH_EMAIL="$(gh api user --jq '.id + 0 | tostring')+$(gh api user --jq '.login')@users.noreply.github.com"
fi
git config --global user.email "$GH_EMAIL"

echo
echo "Setup complete! Please reboot for all changes to take effect."
