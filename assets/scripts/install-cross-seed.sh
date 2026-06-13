#!/usr/bin/env bash
# cross-seed-installer.sh - Versão Corrigida (Documentação Oficial)

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# Detecta home real
REAL_HOME=$(getent passwd "$(whoami)" | cut -d: -f6)
[ -z "$REAL_HOME" ] && REAL_HOME="$HOME"

LOG_FILE="$REAL_HOME/cross-seed-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

print_header() { echo -e "\n${CYAN}========================================================================${NC}\n${CYAN} $1${NC}\n${CYAN}========================================================================${NC}"; }
timestamp() { echo -e "\n${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC}"; }

timestamp
print_header "CROSS-SEED INSTALLER (BASEADO NA DOCUMENTAÇÃO OFICIAL)"
echo -e "Usuário: ${GREEN}$(whoami)${NC}"
echo -e "Home real: ${GREEN}$REAL_HOME${NC}"
echo -e "Log: ${GREEN}$LOG_FILE${NC}"

# 1. Verificações iniciais
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ NÃO execute com sudo. Use seu usuário normal.${NC}"
    exit 1
fi

for cmd in curl git; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}❌ $cmd não instalado. Execute: sudo apt install $cmd${NC}"
        exit 1
    fi
done

# build-essential (opcional, para compilar módulos nativos)
if ! dpkg -l | grep -q build-essential; then
    echo -e "${YELLOW}⚠️  build-essential não detectado.${NC}"
    read -p "Instalar? (s/N) " -n 1; echo
    [[ $REPLY =~ ^[Ss]$ ]] && sudo apt install build-essential -y
fi

# 2. Rollback (se solicitado)
if [ -d "$REAL_HOME/.nvm" ] || command -v node &>/dev/null; then
    echo -e "${YELLOW}⚠️  Detectados vestígios de nvm/node.${NC}"
    read -p "Remover tudo e começar do zero? (s/N) " -n 1; echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        rm -rf "$REAL_HOME/.nvm" "$REAL_HOME/.npm" "$REAL_HOME/.node-gyp" 2>/dev/null || true
        sed -i '/NVM_DIR/d' "$REAL_HOME/.bashrc" 2>/dev/null || true
        sed -i '/nvm.sh/d' "$REAL_HOME/.bashrc" 2>/dev/null || true
        unset NVM_DIR
        hash -r
        echo -e "${GREEN}✅ Rollback concluído.${NC}"
    fi
fi

# 3. Instalar nvm
if [ ! -d "$REAL_HOME/.nvm" ]; then
    echo -e "📦 Instalando nvm..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

export NVM_DIR="$REAL_HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if ! command -v nvm &>/dev/null; then
    echo -e "${RED}❌ Falha ao carregar nvm.${NC}"
    exit 1
fi

# 4. Instalar Node.js 20 (obrigatório, conforme documentação)
echo -e "📦 Instalando Node.js 20 (obrigatório para cross-seed)..."
nvm install 20
nvm use 20
nvm alias default 20

NODE_VERSION=$(node --version)
NODE_PATH="$NVM_DIR/versions/node/$(nvm current)/bin"
export PATH="$NODE_PATH:$PATH"

if ! grep -q "versions/node/v20" "$REAL_HOME/.bashrc"; then
    echo "export PATH=\"$NODE_PATH:\$PATH\"" >> "$REAL_HOME/.bashrc"
fi

echo -e "${GREEN}✅ Node.js $NODE_VERSION ativo.${NC}"

# 5. Instalar cross-seed
echo -e "📦 Instalando cross-seed..."
npm install -g cross-seed 2>&1 | grep -v "deprecated" || true  # ignora warnings

# 6. Validar instalação
if ! command -v cross-seed &>/dev/null; then
    echo -e "${RED}❌ cross-seed não encontrado.${NC}"
    exit 1
fi

CROSS_VERSION=$(cross-seed --version)
echo -e "${GREEN}✅ cross-seed $CROSS_VERSION instalado.${NC}"

# 7. Gerar config.js (somente se não existir)
CONFIG_DIR="$REAL_HOME/.cross-seed"
CONFIG_FILE="$CONFIG_DIR/config.js"

mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "📝 Gerando arquivo de configuração exemplo..."
    cross-seed gen-config
    echo -e "${GREEN}✅ Configuração criada em: $CONFIG_FILE${NC}"
    echo -e "${YELLOW}⚠️  Configure manualmente: nano $CONFIG_FILE${NC}"
    echo -e "   Itens obrigatórios: torznab (Prowlarr), torrentClients (qBittorrent, etc.)"
else
    echo -e "✅ Arquivo de configuração já existe."
fi

# 8. Serviço systemd (opcional, com caminhos absolutos)
read -p "Configurar cross-seed como serviço systemd? (s/N) " -n 1; echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    NODE_ABS=$(which node)
    CROSS_ABS=$(which cross-seed)
    SERVICE_FILE="/etc/systemd/system/cross-seed.service"
    
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=cross-seed daemon
After=network.target

[Service]
User=$(whoami)
Group=$(id -gn)
Restart=always
Type=simple
ExecStart=$NODE_ABS $CROSS_ABS daemon

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable cross-seed.service
    sudo systemctl start cross-seed.service
    echo -e "${GREEN}✅ Serviço iniciado.${NC}"
else
    echo -e "Para iniciar manualmente: ${CYAN}cross-seed daemon${NC}"
fi

# 9. Final
print_header "INSTALAÇÃO CONCLUÍDA"
echo -e "🌐 Interface web: ${GREEN}http://$(hostname -I | awk '{print $1}'):2468${NC}"
echo -e "⚙️  Configure: ${CYAN}nano $CONFIG_FILE${NC}"
echo -e "🚀 Inicie o daemon: ${CYAN}cross-seed daemon${NC}"
echo -e "📋 Log do serviço: ${CYAN}journalctl -u cross-seed -f${NC}"
echo -e "📄 Log completo: ${GREEN}$LOG_FILE${NC}"
echo -e "\n${GREEN}✅ Pronto! O cross-seed está instalado.${NC}"