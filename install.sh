#!/bin/bash

set -e

if [ "$EUID" -eq 0 ]; then
    SUDO=""
    CURRENT_USER="root"
else
    SUDO="sudo"
    CURRENT_USER=$USER
fi

export DEBIAN_FRONTEND=noninteractive

$SUDO apt update > /dev/null 2>&1 && $SUDO apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" > /dev/null 2>&1
$SUDO apt install -y curl wget git build-essential unzip > /dev/null 2>&1

curl -fsSL https://deb.nodesource.com/setup_lts.x | $SUDO bash - > /dev/null 2>&1
$SUDO apt install -y nodejs > /dev/null 2>&1

curl -fsSL https://get.pnpm.io/install.sh | sh - > /dev/null 2>&1
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

curl -fsSL https://bun.sh/install | bash > /dev/null 2>&1
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH_GO="amd64" ;;
    aarch64|arm64) ARCH_GO="arm64" ;;
    *) ARCH_GO="386" ;;
esac
GO_VERSION=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1)
curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-${ARCH_GO}.tar.gz" -o /tmp/go.tar.gz
$SUDO rm -rf /usr/local/go && $SUDO tar -C /usr/local -xzf /tmp/go.tar.gz
export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path > /dev/null 2>&1
export PATH="$HOME/.cargo/bin:$PATH"

$PNPM_HOME/pnpm install -g pm2@latest > /dev/null 2>&1

wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
$SUDO dpkg -i cloudflared-linux-amd64.deb > /dev/null 2>&1
rm cloudflared-linux-amd64.deb

$SUDO apt install -y zsh > /dev/null 2>&1
RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended > /dev/null 2>&1
git clone --depth=1 -q https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions 2>/dev/null
git clone --depth=1 -q https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 2>/dev/null

cat > ~/.zshrc << EOF
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source \$ZSH/oh-my-zsh.sh
PROMPT='%F{green}%n%f%F{white}@%f%F{blue}%m%f%F{white}:%f%F{yellow}%~%f%F{white}#%f '
export PNPM_HOME="\$HOME/.local/share/pnpm"
export BUN_INSTALL="\$HOME/.bun"
export PATH="/usr/local/go/bin:\$HOME/go/bin:\$HOME/.cargo/bin:\$PNPM_HOME:\$BUN_INSTALL/bin:\$PATH"
alias ll='ls -alF'
DISABLE_AUTO_UPDATE="true"
EOF

$SUDO chsh -s \$(which zsh) $CURRENT_USER > /dev/null 2>&1
rm -f ~/.bashrc ~/.bash_history
cat > ~/.bashrc << 'EOF'
#!/bin/bash
exec zsh
EOF

$SUDO apt autoremove -y > /dev/null 2>&1

echo -e "\e[1;32mDONE!\e[0m"
passwd $CURRENT_USER

sleep 5
$SUDO reboot
