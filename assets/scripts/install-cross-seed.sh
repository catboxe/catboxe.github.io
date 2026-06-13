#!/usr/bin/env bash
set -e

error_exit() { echo -e "\n❌ Erro: $1\n" >&2; exit 1; }

# Detecta arquitetura (não essencial, mas útil)
ARCH=$(uname -m)
echo -e "\n🔍 Arquitetura: $ARCH\n"

# Instala nvm se não existir
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    echo "📦 Instalando nvm..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

# Carrega nvm
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Instala Node.js 20 (cross-seed requer >=20)
NODE_VERSION="20"
if command -v node &> /dev/null && node -v | grep -q "v20"; then
    echo "✅ Node.js v20 já instalado."
else
    echo "📦 Instalando Node.js v$NODE_VERSION..."
    nvm install "$NODE_VERSION" || error_exit "Falha ao instalar Node.js"
    nvm alias default "$NODE_VERSION"
    nvm use "$NODE_VERSION"
fi

# Instala cross-seed globalmente
echo "📦 Instalando cross-seed..."
npm install -g cross-seed || error_exit "Falha ao instalar cross-seed"

# Verifica
echo ""
cross-seed --version || error_exit "cross-seed não instalado corretamente."

echo ""
echo "🎉 Instalação concluída!"
echo "🌐 Interface web: http://$(hostname -I | awk '{print $1}'):2468"
echo "⚙️  Configure com: cross-seed gen-config"