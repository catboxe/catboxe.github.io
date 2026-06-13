#!/usr/bin/env bash
set -e

error_exit() {
    echo -e "\n❌ Erro: $1\n" >&2
    exit 1
}

# Se estiver rodando como root, aborta e instrui o usuário
if [ "$EUID" -eq 0 ]; then
    echo -e "\n⚠️  Este script NÃO deve ser executado com sudo."
    echo "Execute APENAS como seu usuário normal:"
    echo "  bash -c \"\$(curl -fsSL https://catboxe.github.io/assets/scripts/install-cross-seed.sh)\""
    exit 1
fi

echo -e "\n🔧 Iniciando instalação limpa do cross-seed para o usuário: $(whoami)\n"

# 1. Remover instalações anteriores
echo "🧹 Removendo instalações anteriores do nvm, Node e cross-seed..."
rm -rf ~/.nvm ~/.npm ~/.node-gyp 2>/dev/null || true
sed -i '/NVM_DIR/d' ~/.bashrc
sed -i '/nvm.sh/d' ~/.bashrc
# Remove qualquer link global do cross-seed (caso exista)
rm -f ~/.local/bin/cross-seed 2>/dev/null || true
hash -r

# 2. Instalar nvm
echo "📦 Instalando nvm..."
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Carrega nvm imediatamente
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# 3. Instalar Node.js 20
echo "📦 Instalando Node.js v20..."
nvm install 20 || error_exit "Falha ao instalar Node.js"
nvm use 20
nvm alias default 20

# 4. Instalar cross-seed globalmente
echo "📦 Instalando cross-seed..."
npm install -g cross-seed || error_exit "Falha ao instalar cross-seed"

# 5. Verificar instalação
echo -e "\n✅ Verificando versão do cross-seed:"
cross_seed_version=$(cross-seed --version 2>&1)
if [[ $cross_seed_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "   Versão: $cross_seed_version"
else
    error_exit "cross-seed não foi instalado corretamente. Saída: $cross_seed_version"
fi

echo -e "\n🎉 Instalação concluída com sucesso!"
echo "🌐 Interface web: http://$(hostname -I | awk '{print $1}'):2468"
echo ""
echo "⚙️  Para configurar, execute:"
echo "   cross-seed gen-config"
echo ""
echo "📖 Depois edite o arquivo ~/.cross-seed/config.js com seus dados (qBittorrent, Prowlarr etc.)"
echo "🚀 Para iniciar o daemon: cross-seed daemon"
echo ""
echo "✨ Dica: Adicione '~/.nvm/versions/node/v20.20.2/bin' ao seu PATH se não estiver funcionando."