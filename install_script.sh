#!/bin/bash


# Exit immediately on error
set -Eueo pipefail


echo "Updating and upgrading packages..."
sudo apt update && sudo apt upgrade -y


# ---- VSCode ----
echo "Installing VSCode..."
if [ ! -f /etc/apt/sources.list.d/vscode.list ]; then
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    rm -f packages.microsoft.gpg
fi
sudo apt update
sudo apt install code # or code-insiders

# ---- Git Config ----
echo
echo "===== Git Setup ====="
read -p "Enter a name for git. THIS WILL BE PUBLIC. People usually use their GitHub username or full name: " git_name
read -p "Enter an email for git. THIS WILL BE PUBLIC. You can use your github anonymous email (found under GitHub Email Settings), or your school email if you don't care about being anonymous: " git_email


echo "Configuring Git with your information..."
git config --global user.name "$git_name"
git config --global user.email "$git_email"


echo "Generating SSH key..."
ssh-keygen -t ed25519 -C "$git_email" -f ~/.ssh/id_ed25519 -N ""
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519


# ---- ROS 2 Humble Gazebo and RViz ----
echo "Installing ROS 2 Humble + Gazebo + RViz..."
sudo apt install software-properties-common
sudo add-apt-repository universe


sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
sudo apt update


sudo apt install ros-humble-desktop ros-dev-tools nlohmann-json3-dev -y
echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc

# ---- GitKraken ----
echo "Installing GitKraken..."
sudo snap install gitkraken --classic


# ---- Node Version Manager (nvm) + Node.js LTS + Yarn ----
echo "Installing Node Version Manager (nvm)..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm


echo "Installing Node.js LTS and Yarn..."
nvm install --lts
npm install -g yarn


echo
echo "Development environment setup complete!"
echo "Don't forget to restart your terminal or run: source ~/.bashrc"
