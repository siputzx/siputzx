#!/bin/bash

set -e

if [ "$EUID" -eq 0 ]; then
    SUDO=""
    CURRENT_USER=$SUDO_USER
    if [ -z "$CURRENT_USER" ]; then
        CURRENT_USER="root"
    fi
else
    SUDO="sudo"
    CURRENT_USER=$USER
fi

echo -e "\n\e[1;36m🚀 System Setup\e[0m\n"

export DEBIAN_FRONTEND=noninteractive

$SUDO apt update > /dev/null 2>&1 && $SUDO apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" > /dev/null 2>&1
echo -e "\e[32m✓\e[0m System updated"

$SUDO apt install -y curl wget git build-essential unzip > /dev/null 2>&1
echo -e "\e[32m✓\e[0m Dependencies installed"

curl -fsSL https://deb.nodesource.com/setup_lts.x | $SUDO bash - > /dev/null 2>&1
$SUDO apt install -y nodejs > /dev/null 2>&1
echo -e "\e[32m✓\e[0m Node.js installed"

curl -fsSL https://get.pnpm.io/install.sh | sh - > /dev/null 2>&1
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
echo -e "\e[32m✓\e[0m pnpm installed"

curl -fsSL https://bun.sh/install | bash > /dev/null 2>&1
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
echo -e "\e[32m✓\e[0m Bun installed"

$PNPM_HOME/pnpm install -g pm2@latest > /dev/null 2>&1
echo -e "\e[32m✓\e[0m PM2 installed"

wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
$SUDO dpkg -i cloudflared-linux-amd64.deb > /dev/null 2>&1
rm cloudflared-linux-amd64.deb
echo -e "\e[32m✓\e[0m Cloudflared installed"

$SUDO apt install -y zsh > /dev/null 2>&1
echo -e "\e[32m✓\e[0m Zsh installed"

RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended > /dev/null 2>&1
echo -e "\e[32m✓\e[0m Oh My Zsh installed"

git clone --depth=1 -q https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions 2>/dev/null
git clone --depth=1 -q https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 2>/dev/null
echo -e "\e[32m✓\e[0m Zsh plugins installed"

cp ~/.zshrc ~/.zshrc.backup 2>/dev/null || true

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

rm -f ~/.bashrc ~/.bash_history ~/.bash_logout ~/.bash_profile ~/.profile

cat > ~/.bashrc << 'EOF'
#!/bin/bash
exec zsh
EOF

$SUDO chsh -s $(which zsh) $CURRENT_USER > /dev/null 2>&1
echo -e "\e[32m✓\e[0m Zsh configured"

$SUDO sed -i 's/#$nrconf{restart} = \x27i\x27;/$nrconf{restart} = \x27a\x27;/' /etc/needrestart/needrestart.conf 2>/dev/null || true
$SUDO sed -i 's/$nrconf{restart} = \x27i\x27;/$nrconf{restart} = \x27a\x27;/' /etc/needrestart/needrestart.conf 2>/dev/null || true

$PNPM_HOME/pnpm config set auto-install-peers true > /dev/null 2>&1
$PNPM_HOME/pnpm config set package-import-method clone-or-copy > /dev/null 2>&1
echo -e "\e[32m✓\e[0m pnpm configured"

$SUDO apt autoremove -y > /dev/null 2>&1
$SUDO apt autoclean -y > /dev/null 2>&1
echo -e "\e[32m✓\e[0m Cleanup completed"

echo -e "\n\e[1;32m✅ Installation Complete!\e[0m\n"

echo -e "\e[1;33m🔐 Change Password Required\e[0m\n"
passwd

echo -e "\n\e[1;36m🔄 Rebooting in 5 seconds...\e[0m"
sleep 5
$SUDO reboot
