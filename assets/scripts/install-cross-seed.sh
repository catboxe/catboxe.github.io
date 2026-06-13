#!/usr/bin/env bash
# cross-seed-installer.sh - Versão Corrigida (com detecção do home real)

set -euo pipefail

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Detecta o diretório home real do usuário (não confia em $HOME)
REAL_HOME=$(getent passwd "$(whoami)" | cut -d: -f6)
if [ -z "$REAL_HOME" ]; then
    REAL_HOME="$HOME"
fi

LOG_FILE="$REAL_HOME/cross-seed-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

print_header() {
    echo -e "\n${CYAN}========================================================================${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}========================================================================${NC}"
}

timestamp() {
    echo -e "\n${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC}"
}

get_latest_version() {
    curl -s https://registry.npmjs.org/cross-seed/latest | grep -o '"version":"[^"]*"' | cut -d'"' -f4
}

timestamp
print_header "INICIANDO INSTALAÇÃO/ATUALIZAÇÃO DO CROSS-SEED"
echo -e "Usuário: ${GREEN}$(whoami)${NC} (UID: $EUID)"
echo -e "Diretório home REAL: ${GREEN}$REAL_HOME${NC}"
echo -e "Log: ${GREEN}$LOG_FILE${NC}"

# ----------------------------------------------------------------------
# 1. Verificações iniciais
# ----------------------------------------------------------------------
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ Não execute com sudo.${NC}"
    exit 1
fi

for cmd in curl git; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}❌ $cmd não instalado. Instale: sudo apt install $cmd${NC}"
        exit 1
    fi
done

if ! dpkg -l | grep -q build-essential; then
    echo -e "${YELLOW}⚠️  build-essential não detectado.${NC}"
    read -p "Instalar? (s/N) " -n 1; echo
    [[ $REPLY =~ ^[Ss]$ ]] && sudo apt install build-essential -y
fi

# ----------------------------------------------------------------------
# 2. Verificação de versão existente e upgrade
# ----------------------------------------------------------------------
CURRENT_VERSION=""
if command -v cross-seed &>/dev/null; then
    CURRENT_VERSION=$(cross-seed --version 2>/dev/null || echo "desconhecida")
    echo -e "Versão atual: ${CYAN}$CURRENT_VERSION${NC}"
    LATEST_VERSION=$(get_latest_version)
    if [[ -n "$LATEST_VERSION" && "$CURRENT_VERSION" != "$LATEST_VERSION" ]]; then
        echo -e "Nova versão: ${CYAN}$LATEST_VERSION${NC}"
        read -p "Atualizar? (s/N) " -n 1; echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            npm update -g cross-seed
            echo -e "${GREEN}✅ Atualizado para $(cross-seed --version)${NC}"
        fi
    fi
fi

# ----------------------------------------------------------------------
# 3. Rollback (limpeza completa) – remove apenas do REAL_HOME
# ----------------------------------------------------------------------
if [ -d "$REAL_HOME/.nvm" ] || command -v node &>/dev/null; then
    echo -e "${YELLOW}⚠️  Detectados vestígios de nvm/node.${NC}"
    read -p "Remover tudo e começar do zero? (s/N) " -n 1; echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        rm -rf "$REAL_HOME/.nvm" "$REAL_HOME/.npm" "$REAL_HOME/.node-gyp" 2>/dev/null || true
        sed -i '/NVM_DIR/d' "$REAL_HOME/.bashrc" 2>/dev/null || true
        sed -i '/nvm.sh/d' "$REAL_HOME/.bashrc" 2>/dev/null || true
        unset NVM_DIR
        hash -r
        echo -e "${GREEN}✅ Ambiente limpo.${NC}"
    fi
fi

# ----------------------------------------------------------------------
# 4. Instalar nvm e Node.js (usando REAL_HOME)
# ----------------------------------------------------------------------
if [ ! -d "$REAL_HOME/.nvm" ]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

export NVM_DIR="$REAL_HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if ! command -v nvm &>/dev/null; then
    echo -e "${RED}❌ Falha ao carregar nvm.${NC}"
    exit 1
fi

if ! nvm ls | grep -q "v20"; then
    nvm install 20
fi
nvm use 20
nvm alias default 20

NODE_PATH="$NVM_DIR/versions/node/$(nvm current)/bin"
export PATH="$NODE_PATH:$PATH"
if ! grep -q "versions/node/v20" "$REAL_HOME/.bashrc"; then
    echo "export PATH=\"$NODE_PATH:\$PATH\"" >> "$REAL_HOME/.bashrc"
fi

# ----------------------------------------------------------------------
# 5. Instalar cross-seed
# ----------------------------------------------------------------------
if ! command -v cross-seed &>/dev/null; then
    npm install -g cross-seed
fi

if ! command -v cross-seed &>/dev/null; then
    echo -e "${RED}❌ cross-seed não encontrado.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ cross-seed $(cross-seed --version) instalado.${NC}"

# ----------------------------------------------------------------------
# 6. Gerar config.js (sem edição automática)
# ----------------------------------------------------------------------
CONFIG_DIR="$REAL_HOME/.cross-seed"
CONFIG_FILE="$CONFIG_DIR/config.js"

if [ ! -f "$CONFIG_FILE" ]; then
    cross-seed gen-config
    echo -e "${GREEN}✅ Exemplo de configuração em $CONFIG_FILE${NC}"
    echo -e "${YELLOW}⚠️  Edite manualmente: nano $CONFIG_FILE${NC}"
else
    echo -e "Configuração já existe em $CONFIG_FILE"
    echo -e "Para editar: nano $CONFIG_FILE"
fi

# ----------------------------------------------------------------------
# 7. Serviço systemd (opcional)
# ----------------------------------------------------------------------
read -p "Configurar cross-seed como serviço systemd? (s/N) " -n 1; echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    SERVICE_FILE="/etc/systemd/system/cross-seed.service"
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=cross-seed daemon
After=network.target

[Service]
Type=simple
User=$(whoami)
ExecStart=$NODE_PATH/cross-seed daemon
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable cross-seed.service
    sudo systemctl start cross-seed.service
    echo -e "${GREEN}✅ Serviço iniciado.${NC}"
else
    echo -e "Início manual: ${CYAN}cross-seed daemon${NC}"
fi

# ----------------------------------------------------------------------
# 8. Final
# ----------------------------------------------------------------------
print_header "INSTALAÇÃO CONCLUÍDA"
echo -e "🌐 Interface: ${GREEN}http://$(hostname -I | awk '{print $1}'):2468${NC}"
echo -e "⚙️  Configure: ${CYAN}nano $CONFIG_FILE${NC}"
echo -e "🚀 Inicie o daemon: ${CYAN}cross-seed daemon${NC}"
echo -e "📋 Log do serviço: ${CYAN}journalctl -u cross-seed -f${NC}"
echo -e "📄 Log completo: ${GREEN}$LOG_FILE${NC}"
echo -e "\n${GREEN}✅ Pronto! O cross-seed está instalado.${NC}"