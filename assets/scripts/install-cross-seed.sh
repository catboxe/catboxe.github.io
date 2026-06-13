#!/usr/bin/env bash
# cross-seed-installer.sh
# Versão ultra verbosa com log completo

set -euo pipefail

# Cores (sempre úteis)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Arquivo de log
LOG_FILE="$HOME/cross-seed-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "================================================================================"
echo "🚀 Instalador do cross-seed - Modo VERBOSE (log em: $LOG_FILE)"
echo "Data: $(date)"
echo "Usuário: $(whoami) (UID: $EUID)"
echo "Diretório home: $HOME"
echo "================================================================================"

# Funções de logging
log_info()    { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_warn()    { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_error()   { echo -e "${RED}❌ $*${NC}" >&2; }

# Rollback
rollback() {
    log_warn "Iniciando rollback completo..."
    rm -rf "$HOME/.nvm" "$HOME/.npm" "$HOME/.node-gyp" 2>/dev/null || true
    sed -i '/NVM_DIR/d' "$HOME/.bashrc" 2>/dev/null || true
    sed -i '/nvm.sh/d' "$HOME/.bashrc" 2>/dev/null || true
    unset NVM_DIR
    hash -r
    log_success "Rollback concluído. Nenhum resquício restante."
}

# Verifica se está rodando como root (proibido)
if [ "$EUID" -eq 0 ]; then
    log_error "Este script NÃO deve ser executado com sudo ou como root."
    echo "Execute como seu usuário normal:"
    echo "  bash -c \"\$(curl -fsSL https://catboxe.github.io/assets/scripts/install-cross-seed.sh)\""
    exit 1
fi

# ============================================================================
# 1. ANÁLISE PRÉVIA DO AMBIENTE
# ============================================================================
log_info "Realizando análise prévia do sistema..."

# Dependências essenciais
DEPS_OK=true
for cmd in curl git; do
    if ! command -v "$cmd" &>/dev/null; then
        log_error "$cmd não está instalado. Instale com: sudo apt install $cmd"
        DEPS_OK=false
    fi
done
if [ "$DEPS_OK" = false ]; then
    exit 1
fi

log_success "Dependências mínimas satisfeitas (curl e git)."

# Detecta Node.js existente
if command -v node &>/dev/null; then
    NODE_VER=$(node --version 2>/dev/null || echo "desconhecida")
    log_warn "Node.js detectado: $NODE_VER"
else
    log_info "Node.js não detectado."
fi

# Detecta nvm
if [ -d "$HOME/.nvm" ]; then
    log_warn "Diretório ~/.nvm encontrado."
else
    log_info "Diretório ~/.nvm não existe."
fi

# Detecta cross-seed
if command -v cross-seed &>/dev/null; then
    CROSS_VER=$(cross-seed --version 2>/dev/null || echo "desconhecida")
    log_warn "cross-seed detectado: $CROSS_VER"
else
    log_info "cross-seed não detectado."
fi

# Pergunta se deseja limpar
if [ -d "$HOME/.nvm" ] || command -v node &>/dev/null || command -v cross-seed &>/dev/null; then
    echo ""
    log_warn "Foram detectados vestígios de instalações anteriores."
    echo "Deseja removê-los completamente e começar do zero? (s/N)"
    read -r -n 1 resposta
    echo
    if [[ $resposta =~ ^[Ss]$ ]]; then
        rollback
        log_success "Ambiente limpo. Prosseguindo com instalação nova."
    else
        log_warn "Continuando com possíveis conflitos. Se falhar, execute novamente e escolha 's'."
    fi
fi

# ============================================================================
# 2. INSTALAÇÃO DO NVM
# ============================================================================
log_info "Baixando e instalando nvm..."
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

if ! command -v nvm &>/dev/null; then
    log_error "Falha ao carregar nvm. Tente reiniciar o terminal e executar novamente."
    exit 1
fi
log_success "nvm instalado e carregado."

# ============================================================================
# 3. INSTALAÇÃO DO NODE.JS 20
# ============================================================================
log_info "Instalando Node.js v20 via nvm..."
nvm install 20
nvm use 20
nvm alias default 20

NODE_PATH="$NVM_DIR/versions/node/$(nvm current)/bin"
if [ ! -x "$NODE_PATH/node" ]; then
    log_error "Node.js não foi encontrado no caminho esperado: $NODE_PATH"
    exit 1
fi
log_success "Node.js v20 instalado: $($NODE_PATH/node --version)"

# ============================================================================
# 4. INSTALAÇÃO DO CROSS-SEED
# ============================================================================
log_info "Instalando cross-seed globalmente via npm..."
npm install -g cross-seed

# Adiciona o binário do Node ao PATH (permanentemente)
if ! grep -q "versions/node/v20" "$HOME/.bashrc"; then
    echo "export PATH=\"$NODE_PATH:\$PATH\"" >> "$HOME/.bashrc"
    log_info "PATH adicionado ao ~/.bashrc"
fi

# Adiciona à sessão atual
export PATH="$NODE_PATH:$PATH"

# Verifica se cross-seed está acessível
if ! command -v cross-seed &>/dev/null; then
    log_error "cross-seed instalado, mas não encontrado no PATH mesmo após ajuste."
    echo "Tentativa de localizar o binário:"
    find "$NVM_DIR" -name "cross-seed" -type f 2>/dev/null || echo "Não encontrado."
    exit 1
fi

CROSS_VERSION=$(cross-seed --version)
log_success "cross-seed versão $CROSS_VERSION instalado."

# ============================================================================
# 5. VALIDAÇÃO FINAL E INSTRUÇÕES
# ============================================================================
echo ""
log_success "🎉 cross-seed instalado com sucesso!"
echo "   🌐 Interface web: http://$(hostname -I | awk '{print $1}'):2468"
echo "   ⚙️  Configure com: cross-seed gen-config"
echo "   📝 Edite ~/.cross-seed/config.js com seus dados"
echo "   🚀 Inicie o daemon: cross-seed daemon"
echo ""
log_info "Log completo salvo em: $LOG_FILE"
log_info "Se o comando 'cross-seed' não funcionar neste terminal, execute: source ~/.bashrc"
echo "================================================================================"