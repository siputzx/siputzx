#!/bin/bash

# by siputzx
# bash <(curl -fsSL https://raw.githubusercontent.com/siputzx/siputzx/main/install.sh)

set -e

if [ "$EUID" -eq 0 ]; then
    SUDO=""
    CURRENT_USER=$SUDO_USER
    [ -z "$CURRENT_USER" ] && CURRENT_USER="root"
else
    SUDO="sudo"
    CURRENT_USER=$USER
fi

CURRENT_SHELL=$(getent passwd "$CURRENT_USER" | cut -d: -f7)

OS_NAME=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -s)
KERNEL=$(uname -r)
ARCH=$(uname -m)
CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ //')
CPU_CORES=$(nproc 2>/dev/null || echo "?")
RAM_TOTAL=$(awk '/MemTotal/ {printf "%.1f GB", $2/1024/1024}' /proc/meminfo 2>/dev/null)
RAM_FREE=$(awk '/MemAvailable/ {printf "%.1f GB", $2/1024/1024}' /proc/meminfo 2>/dev/null)
DISK_TOTAL=$(df -h / 2>/dev/null | awk 'NR==2{print $2}')
DISK_FREE=$(df -h / 2>/dev/null | awk 'NR==2{print $4}')
UPTIME_STR=$(uptime -p 2>/dev/null | sed 's/up //')
PUBLIC_IP=$(curl -fsSL --max-time 3 https://api.ipify.org 2>/dev/null || echo "Unavailable")

echo -e "\n\e[1;36m  System Information\e[0m"
echo -e "\e[90m  ─────────────────────────────────────\e[0m"
echo -e "  \e[90mOS      \e[0m  $OS_NAME"
echo -e "  \e[90mKernel  \e[0m  $KERNEL"
echo -e "  \e[90mArch    \e[0m  $ARCH"
echo -e "  \e[90mCPU     \e[0m  $CPU_MODEL ($CPU_CORES cores)"
echo -e "  \e[90mRAM     \e[0m  $RAM_FREE free / $RAM_TOTAL total"
echo -e "  \e[90mDisk    \e[0m  $DISK_FREE free / $DISK_TOTAL total"
echo -e "  \e[90mUptime  \e[0m  $UPTIME_STR"
echo -e "  \e[90mIP      \e[0m  $PUBLIC_IP"
echo -e "  \e[90mShell   \e[0m  $CURRENT_SHELL"
echo -e "\e[90m  ─────────────────────────────────────\e[0m\n"

case "$ARCH" in
    x86_64)        ARCH_GO="amd64";  ARCH_CF="amd64"; RUST_TARGET="x86_64-unknown-linux-gnu" ;;
    aarch64|arm64) ARCH_GO="arm64";  ARCH_CF="arm64"; RUST_TARGET="aarch64-unknown-linux-gnu" ;;
    armv7l)        ARCH_GO="armv6l"; ARCH_CF="arm";   RUST_TARGET="armv7-unknown-linux-gnueabihf" ;;
    armv6l)        ARCH_GO="armv6l"; ARCH_CF="arm";   RUST_TARGET="arm-unknown-linux-gnueabihf" ;;
    i386|i686)     ARCH_GO="386";    ARCH_CF="386";   RUST_TARGET="i686-unknown-linux-gnu" ;;
    *)
        echo -e "\e[31m✗\e[0m Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo -e "\e[1;36m  Setup\e[0m\n"

while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
      fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
      fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
    sleep 3
done

export DEBIAN_FRONTEND=noninteractive

$SUDO apt update > /dev/null 2>&1
$SUDO apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" > /dev/null 2>&1
echo -e "\e[32m✓\e[0m System updated"

$SUDO apt install -y curl wget git build-essential unzip zsh > /dev/null 2>&1
echo -e "\e[32m✓\e[0m Dependencies installed"

curl -fsSL https://deb.nodesource.com/setup_lts.x | $SUDO bash - > /dev/null 2>&1
$SUDO apt install -y nodejs > /dev/null 2>&1
echo -e "\e[32m✓\e[0m Node.js installed"

npm install -g pnpm@latest > /dev/null 2>&1
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME/bin:$PATH"
echo -e "\e[32m✓\e[0m pnpm installed"

curl -fsSL https://bun.sh/install -o /tmp/bun-install.sh
bash /tmp/bun-install.sh > /dev/null 2>&1
rm -f /tmp/bun-install.sh
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
echo -e "\e[32m✓\e[0m Bun installed"

GO_VERSION=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1)
curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-${ARCH_GO}.tar.gz" -o /tmp/go.tar.gz
$SUDO rm -rf /usr/local/go
$SUDO tar -C /usr/local -xzf /tmp/go.tar.gz
rm -f /tmp/go.tar.gz
export GOPATH="$HOME/go"
export PATH="/usr/local/go/bin:$GOPATH/bin:$PATH"
echo -e "\e[32m✓\e[0m Go installed (${GO_VERSION})"

export RUSTUP_HOME="$HOME/.rustup"
export CARGO_HOME="$HOME/.cargo"
curl -fsSL "https://static.rust-lang.org/rustup/dist/${RUST_TARGET}/rustup-init" -o /tmp/rustup-init
chmod +x /tmp/rustup-init
/tmp/rustup-init -y --no-modify-path --default-toolchain stable --profile default > /dev/null 2>&1
rm -f /tmp/rustup-init
export PATH="$CARGO_HOME/bin:$PATH"
echo -e "\e[32m✓\e[0m Rust installed ($(rustc --version 2>/dev/null | cut -d' ' -f2))"

npm install -g pm2@latest > /dev/null 2>&1
echo -e "\e[32m✓\e[0m PM2 installed"

CF_DEB="cloudflared-linux-${ARCH_CF}.deb"
wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/${CF_DEB}"
$SUDO dpkg -i "$CF_DEB" > /dev/null 2>&1 || $SUDO apt install -f -y > /dev/null 2>&1
rm -f "$CF_DEB"
echo -e "\e[32m✓\e[0m Cloudflared installed"

ZSH_PATH=$(which zsh)
echo -e "\e[32m✓\e[0m Zsh installed"

rm -rf ~/.oh-my-zsh

RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended > /dev/null 2>&1 || true

mkdir -p ~/.oh-my-zsh/custom/plugins

echo -e "\e[32m✓\e[0m Oh My Zsh installed"

git clone --depth=1 -q https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions 2>/dev/null || true
git clone --depth=1 -q https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting 2>/dev/null || true

echo -e "\e[32m✓\e[0m Zsh plugins installed"

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
export PATH="$PNPM_HOME/bin:$PATH"

export GOPATH="$HOME/go"
export PATH="/usr/local/go/bin:$GOPATH/bin:$PATH"

export RUSTUP_HOME="$HOME/.rustup"
export CARGO_HOME="$HOME/.cargo"
export PATH="$CARGO_HOME/bin:$PATH"

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

DISABLE_AUTO_UPDATE="true"
EOF

if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
    grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | $SUDO tee -a /etc/shells > /dev/null
    $SUDO chsh -s "$ZSH_PATH" "$CURRENT_USER" > /dev/null 2>&1
    echo -e "\e[32m✓\e[0m Default shell changed: bash → zsh"
else
    echo -e "\e[32m✓\e[0m Default shell already zsh"
fi

rm -f ~/.bash_history

[ -f ~/.bashrc ] && mv ~/.bashrc ~/.bashrc.bak
[ -f ~/.bash_profile ] && mv ~/.bash_profile ~/.bash_profile.bak

cat > ~/.bashrc << 'EOF'
[ -n "$ZSH_VERSION" ] && return
[ -t 1 ] && exec zsh
EOF

cat > ~/.bash_profile << 'EOF'
[ -f ~/.bashrc ] && . ~/.bashrc
EOF

echo -e "\e[32m✓\e[0m Shell migration configured"

if [ -f /etc/needrestart/needrestart.conf ]; then
    sed -i "s/#\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf || true
    sed -i "s/\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf || true
fi

pnpm config set package-import-method clone-or-copy > /dev/null 2>&1 || true
echo "auto-install-peers=true" >> ~/.npmrc

echo -e "\e[32m✓\e[0m pnpm configured"

$SUDO apt autoremove -y > /dev/null 2>&1
$SUDO apt autoclean -y > /dev/null 2>&1

echo -e "\e[32m✓\e[0m Cleanup done"

echo -e "\n\e[1;32m  Done\e[0m\n"

echo -e "\e[1;33m  Change Password\e[0m\n"

passwd

echo -e "\n\e[1;36m  Rebooting in 5 seconds...\e[0m"

sleep 5

$SUDO reboot
