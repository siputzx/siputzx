#!/bin/bash

set -e

echo -e "\e[1;36m==========================================\e[0m"
echo -e "\e[1;36m🚀 Starting Installation Script\e[0m"
echo -e "\e[1;36m==========================================\e[0m"

export DEBIAN_FRONTEND=noninteractive

echo -e "\e[1;33m📦 Updating system packages...\e[0m"
sudo apt update && sudo apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

echo -e "\e[1;33m📦 Installing dependencies...\e[0m"
sudo apt install -y curl wget git build-essential unzip

echo -e "\e[1;32m⬢ Installing Node.js...\e[0m"
curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
sudo apt install -y nodejs

echo -e "\e[1;35m📦 Installing pnpm...\e[0m"
curl -fsSL https://get.pnpm.io/install.sh | sh -
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

echo -e "\e[1;34m🐰 Installing Bun...\e[0m"
if ! command -v unzip &> /dev/null; then
    echo -e "\e[1;33m📦 Installing unzip first...\e[0m"
    sudo apt install -y unzip
fi
curl -fsSL https://bun.sh/install | bash
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

echo -e "\e[1;36m⚡ Installing PM2 globally with pnpm...\e[0m"
pnpm install -g pm2@latest

echo -e "\e[1;37m☁️ Installing Cloudflared...\e[0m"
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb
rm cloudflared-linux-amd64.deb

echo -e "\e[1;34m🐚 Installing Zsh...\e[0m"
sudo apt install -y zsh

echo -e "\e[1;33m✨ Installing Oh My Zsh...\e[0m"
RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

echo -e "\e[1;32m🔌 Installing Zsh plugins...\e[0m"

git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

echo -e "\e[1;33m💾 Backing up original .zshrc...\e[0m"
cp ~/.zshrc ~/.zshrc.backup 2>/dev/null || true

echo -e "\e[1;32m🎨 Creating new .zshrc with custom prompt...\e[0m"
cat > ~/.zshrc << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
)
source $ZSH/oh-my-zsh.sh
PROMPT='%F{green}%n%f%F{white}@%f%F{blue}%m%f%F{white}:%f%F{yellow}%~%f%F{white}#%f '
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
export PATH=$(echo $PATH | sed 's|:[^:]*/node_modules/[^:]*||g')
alias npm="echo 'Use pnpm instead!' && pnpm"
alias yarn="echo 'Use pnpm instead!' && pnpm"
alias npx="echo 'Use pnpm dlx instead!' && pnpm dlx"
export npm_config_prefix="$HOME/.local/share/pnpm"
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
DISABLE_AUTO_UPDATE="true"
EOF

echo -e "\e[1;31m🗑️ Removing ALL bash files...\e[0m"
rm -f ~/.bashrc
rm -f ~/.bash_history
rm -f ~/.bash_logout
rm -f ~/.bash_profile
rm -f ~/.profile

echo -e "\e[1;33m🔧 Creating minimal .bashrc that auto-starts zsh...\e[0m"
cat > ~/.bashrc << 'EOF'
#!/bin/bash
exec zsh
EOF

echo -e "\e[1;32m🐚 Changing default shell to Zsh...\e[0m"
sudo chsh -s $(which zsh) $USER

echo -e "\e[1;33m🔕 Disabling needrestart notifications...\e[0m"
sudo sed -i 's/#$nrconf{restart} = \x27i\x27;/$nrconf{restart} = \x27a\x27;/' /etc/needrestart/needrestart.conf 2>/dev/null || true
sudo sed -i 's/$nrconf{restart} = \x27i\x27;/$nrconf{restart} = \x27a\x27;/' /etc/needrestart/needrestart.conf 2>/dev/null || true

echo -e "\e[1;35m⚙️ Setting up pnpm configuration...\e[0m"
pnpm config set auto-install-peers true
pnpm config set package-import-method clone-or-copy

echo -e "\e[1;33m🔄 Running final system update...\e[0m"
sudo apt update -y

echo -e "\e[1;31m🧹 Cleaning up...\e[0m"
sudo apt autoremove -y
sudo apt autoclean -y

echo -e "\e[1;36m==========================================\e[0m"
echo -e "\e[1;36m🎉 Installation Complete!\e[0m"
echo -e "\e[1;36m==========================================\e[0m"
echo ""
node -v >/dev/null 2>&1 && echo -e "  \e[1;32m⬢ Node.js $(node -v)\e[0m" || echo -e "  \e[1;32m⬢ Node.js (check with: node -v)\e[0m"
pnpm -v >/dev/null 2>&1 && echo -e "  \e[1;35m📦 pnpm $(pnpm -v)\e[0m" || echo -e "  \e[1;35m📦 pnpm (check with: pnpm -v)\e[0m" 
bun -v >/dev/null 2>&1 && echo -e "  \e[1;34m🐰 Bun $(bun -v)\e[0m" || echo -e "  \e[1;34m🐰 Bun (check with: bun -v)\e[0m"
echo -e "  \e[1;36m⚡ PM2 (installed with pnpm)\e[0m"
echo -e "  \e[1;37m☁️ Cloudflared\e[0m"
echo -e "  \e[1;34m🐚 Zsh with plugins\e[0m"
echo ""
echo -e "  \e[1;32m✅ pnpm is now the DEFAULT package manager\e[0m"
echo -e "  \e[1;31m❌ npm/yarn/npx commands are aliased to pnpm\e[0m"
echo ""
echo -e "  \e[1;33m🎨 Custom prompt: username@hostname:~#\e[0m"
echo ""
echo -e "  \e[1;31m🗑️ ALL bash files have been removed and replaced with zsh\e[0m"
echo -e "  \e[1;32m🔧 Zsh is now your default shell!\e[0m"
echo ""
echo -e "  \e[1;36m🔄 Please restart your terminal or run: exec zsh\e[0m"
