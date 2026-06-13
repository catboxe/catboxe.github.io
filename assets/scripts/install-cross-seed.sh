#!/usr/bin/env bash
# cross-seed-installer.sh
# Instalação robusta, segura e com rollback inteligente
# Modo de uso: curl -fsSL https://catboxe.github.io/assets/scripts/install-cross-seed.sh | bash

set -euo pipefail
trap 'echo -e "\n❌ Operação interrompida pelo usuário."; exit 1' INT

# Cores
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Funções de logging
error()  { echo -e "${RED}❌ $*${NC}" >&2; }
warn()   { echo -e "${YELLOW}⚠️  $*${NC}"; }
info()   { echo -e "${BLUE}ℹ️  $*${NC}"; }
success(){ echo -e "${GREEN}✅ $*${NC}"; }

# Função de rollback – remove tudo o que foi instalado
rollback() {
    warn "Iniciando rollback completo (remoção de nvm, node, npm e cross-seed)."
    rm -rf "$HOME/.nvm" "$HOME/.npm" "$HOME/.node-gyp" 2>/dev/null || true
    sed -i '/NVM_DIR/d' "$HOME/.bashrc" 2>/dev/null || true
    sed -i '/nvm.sh/d' "$HOME/.bashrc" 2>/dev/null || true
    unset NVM_DIR
    hash -r
    success "Rollback concluído. Nenhum resquício permanece."
}

# Verifica se o script está sendo executado como root (proibido)
if [ "$EUID" -eq 0 ]; then
    error "Este script NÃO deve ser executado com sudo ou como root."
    echo "Execute como seu usuário normal:"
    echo "  bash -c \"\$(curl -fsSL https://catboxe.github.io/assets/scripts/install-cross-seed.sh)\""
    exit 1
fi

# =============================================================================
# 1. ANÁLISE PRÉVIA DO AMBIENTE (sem modificar nada)
# =============================================================================
info "Realizando análise prévia do sistema..."

# Verifica dependências essenciais
DEPS_OK=true
for cmd in curl git; do
    if ! command -v "$cmd" &>/dev/null; then
        error "$cmd não está instalado. Instale com: sudo apt install $cmd"
        DEPS_OK=false
    fi
done
if [ "$DEPS_OK" = false ]; then
    exit 1
fi

# Verifica se há restos de instalações anteriores e pergunta o que fazer
if [ -d "$HOME/.nvm" ] || command -v node &>/dev/null || command -v cross-seed &>/dev/null; then
    warn "Foram detectados vestígios de nvm, Node.js ou cross-seed no sistema."
    echo "   - Diretório ~/.nvm: $( [ -d "$HOME/.nvm" ] && echo "EXISTE" || echo "não existe" )"
    echo "   - Node.js: $( command -v node &>/dev/null && node --version || echo "não instalado" )"
    echo "   - cross-seed: $( command -v cross-seed &>/dev/null && cross-seed --version || echo "não instalado" )"
    echo ""
    echo "Deseja remover completamente essas instalações e começar do zero?"
    echo "Isso é recomendado para evitar conflitos. (s/N)"
    read -r -n 1 resposta
    echo
    if [[ $resposta =~ ^[Ss]$ ]]; then
        rollback
        success "Ambiente limpo. Agora prosseguiremos com a instalação."
    else
        warn "Continuando com possíveis conflitos... Se falhar, execute o script novamente e escolha 's'."
    fi
fi

# =============================================================================
# 2. INSTALAÇÃO PROPRIAMENTE DITA (agora sim)
# =============================================================================
info "Iniciando instalação do cross-seed para o usuário $(whoami)..."

# Instala nvm
install_nvm() {
    info "Baixando e instalando nvm..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    if ! command -v nvm &>/dev/null; then
        error "Falha ao instalar ou carregar nvm. Tente reiniciar o terminal e executar novamente."
        return 1
    fi
    success "nvm instalado."
}

# Instala Node.js 20
install_node() {
    info "Instalando Node.js v20 via nvm..."
    nvm install 20 || { error "Falha na instalação do Node.js"; return 1; }
    nvm use 20
    nvm alias default 20
    if ! node --version | grep -q "v20"; then
        error "Node.js v20 não está ativo."
        return 1
    fi
    success "Node.js v20 instalado."
}

# Instala cross-seed
install_cross_seed() {
    info "Instalando cross-seed globalmente via npm..."
    npm install -g cross-seed || { error "Falha na instalação do cross-seed"; return 1; }
    # Garante que o binário esteja no PATH
    export PATH="$NVM_DIR/versions/node/$(nvm current)/bin:$PATH"
    if ! command -v cross-seed &>/dev/null; then
        error "cross-seed instalado, mas não encontrado no PATH."
        return 1
    fi
    success "cross-seed instalado."
}

# =============================================================================
# 3. VALIDAÇÃO PÓS-INSTALAÇÃO (com chance de rollback)
# =============================================================================
validate_installation() {
    info "Validando instalação..."
    local version
    version=$(cross-seed --version 2>&1)
    if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        success "cross-seed versão $version está funcionando perfeitamente."
        return 0
    else
        error "cross-seed não respondeu com uma versão válida. Saída: $version"
        warn "Isso pode indicar um problema de ambiente ou dependências."
        echo "Deseja desfazer TODA a instalação (rollback) e tentar novamente mais tarde? (s/N)"
        read -r -n 1 resposta
        echo
        if [[ $resposta =~ ^[Ss]$ ]]; then
            rollback
            error "Instalação desfeita. Execute o script novamente quando quiser tentar de novo."
            exit 1
        else
            error "Instalação comprometida, mas o rollback foi recusado. Considere reinstalar manualmente."
            exit 1
        fi
    fi
}

# =============================================================================
# 4. EXECUÇÃO PRINCIPAL COM TRATAMENTO DE ERROS
# =============================================================================
main() {
    echo -e "\n${GREEN}🚀 Instalador Automático do cross-seed (modo seguro)${NC}"
    echo "Este script fará uma análise completa e só instalará se tudo estiver correto."
    echo "Em caso de falha, você terá a opção de desfazer completamente a instalação."
    echo ""

    if ! install_nvm; then exit 1; fi
    if ! install_node; then exit 1; fi
    if ! install_cross_seed; then exit 1; fi
    validate_installation

    # Sucesso final
    echo ""
    success "🎉 cross-seed está pronto para uso!"
    echo "   🌐 Interface web: http://$(hostname -I | awk '{print $1}'):2468"
    echo "   ⚙️  Configure com: cross-seed gen-config"
    echo "   📝 Edite ~/.cross-seed/config.js com seus dados"
    echo "   🚀 Inicie o daemon: cross-seed daemon"
    echo ""
    info "Caso o comando 'cross-seed' não seja encontrado em novos terminais, adicione ao ~/.bashrc:"
    echo "   export PATH=\"\$HOME/.nvm/versions/node/$(nvm current)/bin:\$PATH\""
}

# Executa o programa principal
main