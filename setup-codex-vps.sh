#!/usr/bin/env bash
# Prepara a VPS (Ubuntu/Debian) para rodar o Codex CLI 24h dentro do tmux.
# Rode como root:  bash setup-codex-vps.sh
set -euo pipefail

DEV_USER="${DEV_USER:-dev}"

echo "==> Pacotes do sistema"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y git tmux curl build-essential ripgrep ufw mosh

echo "==> Usuario $DEV_USER"
if ! id "$DEV_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$DEV_USER"
  usermod -aG sudo "$DEV_USER"
  echo "$DEV_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$DEV_USER"
fi
# Reaproveita as chaves SSH do root, se existirem
if [ -f /root/.ssh/authorized_keys ]; then
  install -d -m 700 -o "$DEV_USER" -g "$DEV_USER" "/home/$DEV_USER/.ssh"
  install -m 600 -o "$DEV_USER" -g "$DEV_USER" /root/.ssh/authorized_keys "/home/$DEV_USER/.ssh/authorized_keys"
fi

echo "==> Firewall (SSH + mosh)"
ufw allow OpenSSH
ufw allow 60000:61000/udp
ufw --force enable

echo "==> Node 22 + Codex CLI para $DEV_USER"
sudo -iu "$DEV_USER" bash <<'EOF'
set -e
if [ ! -d "$HOME/.nvm" ]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"
nvm install 22
nvm alias default 22
npm install -g @openai/codex@latest

# chave SSH para o GitHub
[ -f "$HOME/.ssh/id_ed25519" ] || ssh-keygen -t ed25519 -N "" -C "vps-codex" -f "$HOME/.ssh/id_ed25519"

# tmux: mouse, historico grande
cat > "$HOME/.tmux.conf" <<'TMUX'
set -g mouse on
set -g history-limit 50000
TMUX

# atalho: "cx" abre/volta para a sessao do Codex
grep -q "alias cx=" "$HOME/.bashrc" || echo "alias cx='tmux new -A -s codex'" >> "$HOME/.bashrc"
mkdir -p "$HOME/projetos"
EOF

echo
echo "================ PRONTO ================"
echo "1) Adicione esta chave no GitHub (Settings > SSH and GPG keys):"
cat "/home/$DEV_USER/.ssh/id_ed25519.pub"
echo
echo "2) Entre como $DEV_USER:   su - $DEV_USER"
echo "3) Faca login no Codex:   codex login --device-auth"
echo "4) Clone o projeto:       cd ~/projetos && git clone git@github.com:SEU_USUARIO/SEU_REPO.git"
echo "5) Abra a sessao:         cx    (dentro dela rode: codex)"
echo "   Sair sem fechar: Ctrl+b depois d.  Voltar: ssh $DEV_USER@IP e digite cx"
