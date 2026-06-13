#!/usr/bin/env bash
# cross-seed-installer.sh - Com criação de pastas essenciais (output e qbit_link)

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# Detecta home real (normalmente /config)
REAL_HOME=$(getent passwd "$(whoami)" | cut -d: -f6)
[ -z "$REAL_HOME" ] && REAL_HOME="$HOME"

LOG_FILE="$REAL_HOME/cross-seed-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

print_header() { echo -e "\n${CYAN}========================================================================${NC}\n${CYAN} $1${NC}\n${CYAN}========================================================================${NC}"; }
timestamp() { echo -e "\n${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC}"; }

timestamp
print_header "CROSS-SEED INSTALLER (COM PASTAS QBIT_LINK E OUTPUT)"
echo -e "Usuário: ${GREEN}$(whoami)${NC}"
echo -e "Home real: ${GREEN}$REAL_HOME${NC}"
echo -e "Log: ${GREEN}$LOG_FILE${NC}"

# 1. Verificações
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

# 2. Rollback (limpeza)
if [ -d "$REAL_HOME/.nvm" ] || command -v node &>/dev/null; then
    echo -e "${YELLOW}⚠️  Detectados vestígios.${NC}"
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

# 4. Instalar Node.js 20
echo -e "📦 Instalando Node.js 20..."
nvm install 20
nvm use 20
nvm alias default 20

NODE_VERSION=$(node --version)
NODE_PATH="$NVM_DIR/versions/node/$(nvm current)/bin"
export PATH="$NODE_PATH:$PATH"

if ! grep -q "versions/node/v20" "$REAL_HOME/.bashrc"; then
    echo "export PATH=\"$NODE_PATH:\$PATH\"" >> "$REAL_HOME/.bashrc"
fi

echo -e "${GREEN}✅ Node.js $NODE_VERSION ativo e PATH configurado.${NC}"

# 5. Instalar cross-seed
echo -e "📦 Instalando cross-seed..."
npm install -g cross-seed 2>&1 | grep -v "deprecated" || true

if ! command -v cross-seed &>/dev/null; then
    echo -e "${RED}❌ cross-seed não encontrado.${NC}"
    exit 1
fi

CROSS_VERSION=$(cross-seed --version)
echo -e "${GREEN}✅ cross-seed $CROSS_VERSION instalado.${NC}"

# 6. Configuração
CONFIG_DIR="$REAL_HOME/.cross-seed"
CONFIG_FILE="$CONFIG_DIR/config.js"

mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "📝 Gerando arquivo de configuração exemplo..."
    cross-seed gen-config
    echo -e "${GREEN}✅ Exemplo criado em: $CONFIG_FILE${NC}"
    echo -e "${YELLOW}⚠️  Configure manualmente: nano $CONFIG_FILE${NC}"
else
    echo -e "✅ Arquivo de configuração já existe."
fi

# 7. Criar pastas essenciais (output e qbit_link) e ajustar permissões
print_header "CRIANDO DIRETÓRIOS ESSENCIAIS E AJUSTANDO PERMISSÕES"

# Define os caminhos absolutos (ajuste se necessário)
CROSS_SEED_BASE="/APPBOX_DATA/apps/ubuntu.pandinha3.appboxes.co/.cross-seed"
OUTPUT_DIR="$CROSS_SEED_BASE/output"
QBIT_LINK_DIR="$CROSS_SEED_BASE/qbit_link"

echo -e "📁 Criando diretório de saída (outputDir): $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo -e "📁 Criando diretório de links (qbit_link): $QBIT_LINK_DIR"
mkdir -p "$QBIT_LINK_DIR"

# Ajusta permissões (755 = rwxr-xr-x)
echo -e "🔧 Ajustando permissões para $CROSS_SEED_BASE e subpastas..."
chmod -R 755 "$CROSS_SEED_BASE"

echo -e "${GREEN}✅ Diretórios criados e permissões ajustadas.${NC}"

# 8. Serviço systemd (opcional)
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
echo -e "\n${GREEN}✅ Pronto! O cross-seed está instalado e as pastas essenciais foram criadas.${NC}"
echo -e "${YELLOW}ℹ️  Caso abra um novo terminal, o comando 'cross-seed' estará disponível automaticamente.${NC}"
