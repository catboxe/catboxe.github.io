#!/usr/bin/env bash
# cross-seed-installer.sh - Versão Super Completa com Upgrade e Validação de Config

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Arquivo de log
LOG_FILE="$HOME/cross-seed-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Funções auxiliares
print_header() {
    echo -e "\n${CYAN}========================================================================${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}========================================================================${NC}"
}

timestamp() {
    echo -e "\n${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC}"
}

# Verifica a versão mais recente do cross-seed no npm
get_latest_version() {
    curl -s https://registry.npmjs.org/cross-seed/latest | grep -o '"version":"[^"]*"' | cut -d'"' -f4
}

timestamp
print_header "INICIANDO INSTALAÇÃO/ATUALIZAÇÃO DO CROSS-SEED"
echo -e "Usuário: ${GREEN}$(whoami)${NC} (UID: $EUID)"
echo -e "Diretório home: ${GREEN}$HOME${NC}"
echo -e "Log completo será salvo em: ${GREEN}$LOG_FILE${NC}"

# ----------------------------------------------------------------------
# 1. Verificações iniciais e dependências
# ----------------------------------------------------------------------
print_header "ANALISANDO O AMBIENTE"

if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ Este script NÃO deve ser executado com sudo ou como root.${NC}"
    echo -e "Execute como seu usuário normal: ${CYAN}bash install-cross-seed.sh${NC}"
    exit 1
fi

# Dependências
DEPS_OK=true
for cmd in curl git; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}❌ $cmd não está instalado.${NC} Instale com: ${CYAN}sudo apt install $cmd${NC}"
        DEPS_OK=false
    fi
done

if ! dpkg -l | grep -q build-essential; then
    echo -e "${YELLOW}⚠️  build-essential não detectado. Necessário para compilar módulos nativos.${NC}"
    echo -e "   Deseja instalar build-essential agora? (s/N)"
    read -r -n 1 resposta
    echo
    if [[ $resposta =~ ^[Ss]$ ]]; then
        sudo apt install build-essential -y
    else
        echo -e "${YELLOW}⚠️  Continuando sem build-essential. A instalação pode falhar!${NC}"
    fi
fi

if [ "$DEPS_OK" = false ]; then
    exit 1
fi

# ----------------------------------------------------------------------
# 2. Verificação de versão existente e oferta de upgrade
# ----------------------------------------------------------------------
print_header "VERIFICANDO VERSÃO ATUAL DO CROSS-SEED"

CURRENT_VERSION=""
if command -v cross-seed &>/dev/null; then
    CURRENT_VERSION=$(cross-seed --version 2>/dev/null || echo "desconhecida")
    echo -e "Versão instalada: ${CYAN}$CURRENT_VERSION${NC}"
    echo -e "Buscando versão mais recente no npm..."
    LATEST_VERSION=$(get_latest_version)
    if [[ -n "$LATEST_VERSION" ]]; then
        echo -e "Versão mais recente: ${CYAN}$LATEST_VERSION${NC}"
        if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
            echo -e "${YELLOW}⚠️  Há uma nova versão disponível!${NC}"
            echo -e "Deseja atualizar o cross-seed? (s/N)"
            read -r -n 1 resposta
            echo
            if [[ $resposta =~ ^[Ss]$ ]]; then
                print_header "ATUALIZANDO CROSS-SEED"
                npm update -g cross-seed
                NEW_VERSION=$(cross-seed --version)
                echo -e "${GREEN}✅ Atualizado de $CURRENT_VERSION para $NEW_VERSION${NC}"
            else
                echo -e "Mantendo a versão atual. Se quiser reinstalar do zero, escolha rollback na próxima etapa."
            fi
        else
            echo -e "${GREEN}✅ Você já está com a versão mais recente.${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Não foi possível verificar a versão mais recente. Continuando...${NC}"
    fi
else
    echo -e "cross-seed não está instalado."
fi

# ----------------------------------------------------------------------
# 3. Opção de rollback (limpeza completa)
# ----------------------------------------------------------------------
if [ -d "$HOME/.nvm" ] || command -v node &>/dev/null || command -v cross-seed &>/dev/null; then
    echo ""
    echo -e "${YELLOW}⚠️  Detectados vestígios de nvm/node/cross-seed.${NC}"
    echo -e "Deseja removê-los completamente e começar do zero? (s/N)"
    read -r -n 1 resposta
    echo
    if [[ $resposta =~ ^[Ss]$ ]]; then
        print_header "REMOVENDO INSTALAÇÕES ANTERIORES (ROLLBACK)"
        rm -rf "$HOME/.nvm" "$HOME/.npm" "$HOME/.node-gyp" 2>/dev/null || true
        sed -i '/NVM_DIR/d' "$HOME/.bashrc" 2>/dev/null || true
        sed -i '/nvm.sh/d' "$HOME/.bashrc" 2>/dev/null || true
        unset NVM_DIR
        hash -r
        echo -e "${GREEN}✅ Rollback concluído. Ambiente limpo!${NC}"
    else
        echo -e "${YELLOW}⚠️  Continuando com possíveis conflitos...${NC}"
    fi
fi

# ----------------------------------------------------------------------
# 4. Instalação do nvm (se não existir)
# ----------------------------------------------------------------------
print_header "INSTALANDO NVM (Node Version Manager)"
if [ ! -d "$HOME/.nvm" ]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

if ! command -v nvm &>/dev/null; then
    echo -e "${RED}❌ Falha ao carregar nvm.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ nvm pronto.${NC}"

# ----------------------------------------------------------------------
# 5. Instalação/atualização do Node.js 20
# ----------------------------------------------------------------------
print_header "CONFIGURANDO NODE.JS V20"
if ! nvm ls | grep -q "v20"; then
    echo -e "Instalando Node.js v20..."
    nvm install 20
fi
nvm use 20
nvm alias default 20

NODE_PATH="$NVM_DIR/versions/node/$(nvm current)/bin"
if [ ! -x "$NODE_PATH/node" ]; then
    echo -e "${RED}❌ Node.js não encontrado em $NODE_PATH${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Node.js $(node --version) ativo.${NC}"

# ----------------------------------------------------------------------
# 6. Instalação/atualização do cross-seed (garantindo que esteja instalado)
# ----------------------------------------------------------------------
print_header "INSTALANDO/ATUALIZANDO CROSS-SEED"
if ! command -v cross-seed &>/dev/null; then
    echo -e "Instalando cross-seed globalmente..."
    npm install -g cross-seed
else
    echo -e "cross-seed já instalado. Pulando instalação (use upgrade se desejar)."
fi

# Ajusta PATH
if ! grep -q "versions/node/v20" "$HOME/.bashrc"; then
    echo "export PATH=\"$NODE_PATH:\$PATH\"" >> "$HOME/.bashrc"
    echo -e "${GREEN}✅ PATH adicionado ao ~/.bashrc${NC}"
fi
export PATH="$NODE_PATH:$PATH"

if ! command -v cross-seed &>/dev/null; then
    echo -e "${RED}❌ cross-seed não encontrado no PATH.${NC}"
    exit 1
fi

CROSS_VERSION=$(cross-seed --version)
echo -e "${GREEN}✅ cross-seed versão $CROSS_VERSION pronto.${NC}"

# ----------------------------------------------------------------------
# 7. Geração e validação do config.js
# ----------------------------------------------------------------------
print_header "CONFIGURAÇÃO DO CROSS-SEED (config.js)"
CONFIG_DIR="$HOME/.cross-seed"
CONFIG_FILE="$CONFIG_DIR/config.js"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "Arquivo de configuração não encontrado. Gerando exemplo..."
    cross-seed gen-config
    echo -e "${GREEN}✅ Exemplo de configuração criado em $CONFIG_FILE${NC}"
fi

echo -e "Deseja validar/editar o arquivo de configuração agora? (s/N)"
read -r -n 1 resposta
echo
if [[ $resposta =~ ^[Ss]$ ]]; then
    # Abre o arquivo com o editor padrão (nano se disponível)
    EDITOR=${EDITOR:-nano}
    $EDITOR "$CONFIG_FILE"

    # Validação básica (se contém pelo menos as chaves essenciais)
    if grep -q "torrentClient" "$CONFIG_FILE" && grep -q "prowlarr" "$CONFIG_FILE"; then
        echo -e "${GREEN}✅ Configuração parece válida (contém torrentClient e prowlarr).${NC}"
    else
        echo -e "${YELLOW}⚠️  Atenção: O arquivo pode estar incompleto. Certifique-se de preencher:${NC}"
        echo -e "   - torrentClient (ex: qbittorrent, transmission)"
        echo -e "   - prowlarr (URL e API key)"
    fi
else
    echo -e "Você pode configurar depois editando manualmente: ${CYAN}nano $CONFIG_FILE${NC}"
fi

# ----------------------------------------------------------------------
# 8. Configuração opcional como serviço systemd
# ----------------------------------------------------------------------
print_header "CONFIGURAR SERVIÇO SYSTEMD?"
read -p "Deseja configurar o cross-seed como um serviço do sistema (systemd)? (s/N) " -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    SERVICE_FILE="/etc/systemd/system/cross-seed.service"
    echo -e "Criando ${CYAN}$SERVICE_FILE${NC}..."

    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=cross-seed daemon
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$NODE_PATH/cross-seed daemon
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable cross-seed.service
    sudo systemctl start cross-seed.service
    echo -e "${GREEN}✅ Serviço cross-seed configurado e iniciado!${NC}"
else
    echo -e "Pulando serviço. Para iniciar manualmente: ${CYAN}cross-seed daemon${NC}"
fi

# ----------------------------------------------------------------------
# 9. Validação final e conclusão
# ----------------------------------------------------------------------
print_header "VALIDAÇÃO FINAL"
if cross-seed --version &>/dev/null; then
    echo -e "${GREEN}✅ cross-seed $(cross-seed --version) está funcionando!${NC}"
else
    echo -e "${RED}❌ cross-seed não responde. Tente: source ~/.bashrc${NC}"
fi

echo -e "\n🌐 Interface web: ${GREEN}http://$(hostname -I | awk '{print $1}'):2468${NC}"
echo -e "⚙️  Gerar/editar config: ${CYAN}cross-seed gen-config && nano ~/.cross-seed/config.js${NC}"
echo -e "🚀 Iniciar daemon manual: ${CYAN}cross-seed daemon${NC}"
echo -e "📋 Ver logs do serviço: ${CYAN}journalctl -u cross-seed -f${NC}"

print_header "INSTALAÇÃO/CONFIGURAÇÃO CONCLUÍDA"
echo -e "Log completo: ${GREEN}$LOG_FILE${NC}"
echo -e "Caso o comando 'cross-seed' não seja encontrado, execute: ${CYAN}source ~/.bashrc${NC}"
echo -e "\n${GREEN}✅ Tudo pronto! O cross-seed está instalado e configurado.${NC}\n"