#!/usr/bin/env bash
# cross-seed-installer.sh - Versão Super Completa

set -euo pipefail

# Atalhos de cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configura o log para ser telegrafado para o terminal e salvo em arquivo
LOG_FILE="$HOME/cross-seed-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Função para exibir cabeçalhos
print_header() {
    echo -e "\n${CYAN}========================================================================${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}========================================================================${NC}"
}

# Função para exibir data/hora
timestamp() {
    echo -e "\n${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC}"
}

timestamp
print_header "INICIANDO INSTALAÇÃO DO CROSS-SEED"
echo -e "Usuário: ${GREEN}$(whoami)${NC} (UID: $EUID)"
echo -e "Diretório home: ${GREEN}$HOME${NC}"
echo -e "Log completo será salvo em: ${GREEN}$LOG_FILE${NC}"

# ----------------------------------------------------------------------
# Bloco de Verificações
# ----------------------------------------------------------------------
print_header "ANALISANDO O AMBIENTE"

# 1. Verifica se está rodando como root (proibido)
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ Este script NÃO deve ser executado com sudo ou como root.${NC}"
    echo -e "Execute como seu usuário normal: ${CYAN}bash install-cross-seed.sh${NC}"
    exit 1
fi

# 2. Verifica dependências essenciais
DEPS_OK=true
for cmd in curl git; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}❌ $cmd não está instalado.${NC} Instale com: ${CYAN}sudo apt install $cmd${NC}"
        DEPS_OK=false
    fi
done

# 3. Verifica se build-essential está instalado (necessário para compilar módulos nativos)
if ! dpkg -l | grep -q build-essential; then
    echo -e "${YELLOW}⚠️  build-essential não detectado. Isso é necessário para compilar módulos nativos.${NC}"
    echo -e "   Deseja instalar build-essential agora? (s/N)"
    read -r -n 1 resposta
    echo
    if [[ $resposta =~ ^[Ss]$ ]]; then
        echo -e "sudo apt install build-essential -y"
        sudo apt install build-essential -y
    else
        echo -e "${YELLOW}⚠️  Continuando sem build-essential. A instalação do cross-seed pode falhar!${NC}"
    fi
fi

if [ "$DEPS_OK" = false ]; then
    exit 1
fi

# 4. Detecta instalações existentes
print_header "IDENTIFICANDO VESTÍGIOS ANTERIORES"
if [ -d "$HOME/.nvm" ]; then
    echo -e "✅ Diretório ${CYAN}~/.nvm${NC} encontrado"
else
    echo -e "✅ Diretório ${CYAN}~/.nvm${NC} NÃO existe"
fi

if command -v node &>/dev/null; then
    NODE_VER=$(node --version 2>/dev/null || echo "desconhecida")
    echo -e "✅ Node.js detectado: ${CYAN}$NODE_VER${NC}"
else
    echo -e "✅ Node.js NÃO detectado"
fi

if command -v cross-seed &>/dev/null; then
    CROSS_VER=$(cross-seed --version 2>/dev/null || echo "desconhecida")
    echo -e "✅ cross-seed detectado: ${CYAN}$CROSS_VER${NC}"
else
    echo -e "✅ cross-seed NÃO detectado"
fi

if [ -d "$HOME/.nvm" ] || command -v node &>/dev/null || command -v cross-seed &>/dev/null; then
    echo ""
    echo -e "${YELLOW}⚠️  Foram detectados vestígios de instalações anteriores.${NC}"
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
# Instalação do NVM
# ----------------------------------------------------------------------
print_header "INSTALANDO NVM (Node Version Manager)"
echo -e "Baixando e executando instalador do nvm..."
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

echo -e "Carregando nvm na sessão atual..."
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

if ! command -v nvm &>/dev/null; then
    echo -e "${RED}❌ Falha ao carregar nvm. Tente reiniciar o terminal e executar novamente.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ nvm instalado com sucesso!${NC}"

# ----------------------------------------------------------------------
# Instalação do Node.js 20
# ----------------------------------------------------------------------
print_header "INSTALANDO NODE.JS V20"
echo -e "Executando: ${CYAN}nvm install 20${NC}"
nvm install 20

echo -e "Executando: ${CYAN}nvm use 20${NC}"
nvm use 20

echo -e "Executando: ${CYAN}nvm alias default 20${NC}"
nvm alias default 20

NODE_PATH="$NVM_DIR/versions/node/$(nvm current)/bin"
if [ ! -x "$NODE_PATH/node" ]; then
    echo -e "${RED}❌ Node.js não foi encontrado no caminho esperado: $NODE_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Node.js $(node --version) instalado em: ${CYAN}$NODE_PATH${NC}"

# ----------------------------------------------------------------------
# Instalação do cross-seed
# ----------------------------------------------------------------------
print_header "INSTALANDO CROSS-SEED GLOBALMENTE"
echo -e "Executando: ${CYAN}npm install -g cross-seed${NC}"
npm install -g cross-seed

# Ajusta o PATH
echo -e "\nAjustando PATH..."
if ! grep -q "versions/node/v20" "$HOME/.bashrc"; then
    echo "export PATH=\"$NODE_PATH:\$PATH\"" >> "$HOME/.bashrc"
    echo -e "${GREEN}✅ PATH adicionado ao ~/.bashrc${NC}"
fi
export PATH="$NODE_PATH:$PATH"

# Verifica se cross-seed foi instalado com sucesso
if ! command -v cross-seed &>/dev/null; then
    echo -e "${RED}❌ cross-seed instalado, mas não encontrado no PATH.${NC}"
    echo -e "Tentativa de localização manual:"
    find "$NVM_DIR" -name "cross-seed" -type f 2>/dev/null || echo "Não encontrado."
    exit 1
fi

CROSS_VERSION=$(cross-seed --version)
echo -e "${GREEN}✅ cross-seed versão $CROSS_VERSION instalado!${NC}"

# ----------------------------------------------------------------------
# Configuração do Daemon (systemd) - Opcional
# ----------------------------------------------------------------------
print_header "CONFIGURANDO SERVIÇO (systemd)"
read -p "Deseja configurar o cross-seed como um serviço do sistema (systemd)? (s/N) " -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    SERVICE_FILE="/etc/systemd/system/cross-seed.service"
    echo -e "Criando arquivo de serviço em ${CYAN}$SERVICE_FILE${NC}..."

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

    echo -e "Habilitando e iniciando o serviço..."
    sudo systemctl daemon-reload
    sudo systemctl enable cross-seed.service
    sudo systemctl start cross-seed.service
    echo -e "${GREEN}✅ Serviço cross-seed configurado e iniciado!${NC}"
    echo -e "   Para ver o status: ${CYAN}systemctl status cross-seed${NC}"
    echo -e "   Para ver os logs: ${CYAN}journalctl -u cross-seed -f${NC}"
else
    echo -e "Pulando configuração do serviço. Você pode iniciar o cross-seed manualmente com: ${CYAN}cross-seed daemon${NC}"
fi

# ----------------------------------------------------------------------
# Validação Final e Conclusão
# ----------------------------------------------------------------------
print_header "VALIDAÇÃO FINAL"
echo -e "Verificando se o comando 'cross-seed' está acessível..."
if cross-seed --version &>/dev/null; then
    echo -e "${GREEN}✅ cross-seed $(cross-seed --version) está funcionando perfeitamente!${NC}"
else
    echo -e "${RED}❌ Falha na validação final. cross-seed não responde.${NC}"
    echo -e "   Tente executar manualmente: ${CYAN}source ~/.bashrc${NC} e depois ${CYAN}cross-seed --version${NC}"
    exit 1
fi

echo -e "\n🌐 Interface web disponível em: ${GREEN}http://$(hostname -I | awk '{print $1}'):2468${NC}"
echo -e "⚙️  Para gerar a configuração inicial, execute: ${CYAN}cross-seed gen-config${NC}"
echo -e "📝 Em seguida, edite o arquivo ${CYAN}~/.cross-seed/config.js${NC} com seus dados (qBittorrent, Prowlarr, etc.)"
echo -e "🚀 Para iniciar o daemon manualmente, execute: ${CYAN}cross-seed daemon${NC}"

print_header "INSTALAÇÃO CONCLUÍDA COM SUCESSO"
echo -e "Log completo salvo em: ${GREEN}$LOG_FILE${NC}"
echo -e "Se o comando 'cross-seed' não for encontrado neste terminal, execute: ${CYAN}source ~/.bashrc${NC}"
echo -e "\n${GREEN}✅ Tudo pronto! O cross-seed está instalado e configurado.${NC}\n" 