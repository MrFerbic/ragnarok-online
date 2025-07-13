#!/bin/bash
set -e

# Caminhos principais
APP_CONFIG="/var/www/html/config/application.php"
SERVERS_CONFIG="/var/www/html/config/servers.php"
FLUXCP_DIR="/var/www/html"

# Função: clona ou sincroniza o repositório do FluxCP
init_fluxcp_repo() {
  if [ ! -d "$FLUXCP_DIR/.git" ]; then
    echo "📥 Iniciando repositório do FluxCP..."

    cd "$FLUXCP_DIR"
    git config --global --add safe.directory "$FLUXCP_DIR"

    REMOTE_URL="${FLUXCP_REPO_URL:-https://github.com/rathena/FluxCP.git}"
    echo "🔗 Adicionando repositório remoto: $REMOTE_URL"
    git init
    git remote add origin "$REMOTE_URL"

    echo "📡 Buscando repositório..."
    git fetch origin

    BRANCH="${FLUXCP_BRANCH:-master}"
    echo "🌿 Alternando para o branch: $BRANCH"
    git checkout -b "$BRANCH" "origin/$BRANCH"

    if [ -n "$FLUXCP_COMMIT" ]; then
      echo "🔢 Usando commit específico: $FLUXCP_COMMIT"
      git checkout "$FLUXCP_COMMIT"
    fi

    echo "🔐 Ajustando permissões"
    chown -R www-data:www-data "$FLUXCP_DIR"
    chmod -R 755 "$FLUXCP_DIR"
  else
    echo "✅ Repositório do FluxCP já inicializado"
  fi
}

# Função: aplica as configurações do FluxCP automaticamente via ENV
configure_fluxcp() {
  echo "⚙️ Configurando FluxCP..."

  # Configura o application.php
  if [[ -f "$APP_CONFIG" ]]; then
    [[ -n "$FLUXCP_HOST" ]] && \
      echo "🌐 Definindo ServerAddress: $FLUXCP_HOST" && \
      sed -i "s/\('ServerAddress'\s*=>\s*\).*/\1'$FLUXCP_HOST',/" "$APP_CONFIG" || \
      echo "⚠️ FLUXCP_HOST não definido"

    echo "🛠️ Definindo BaseURI como raiz ('')"
    sed -i "s/\('BaseURI'\s*=>\s*\).*/\1'',/" "$APP_CONFIG"

    [[ -n "$FLUXCP_INSTALLER_PASSWORD" ]] && \
      echo "🔒 Definindo InstallerPassword" && \
      sed -i "s/\('InstallerPassword'\s*=>\s*\).*/\1'$FLUXCP_INSTALLER_PASSWORD',/" "$APP_CONFIG" || \
      echo "⚠️ FLUXCP_INSTALLER_PASSWORD não definido"
  else
    echo "❌ Arquivo $APP_CONFIG não encontrado!"
  fi

  # Configura o servers.php
  if [[ -f "$SERVERS_CONFIG" ]]; then
    echo "🧩 Aplicando credenciais de banco em servers.php"

    [[ -n "$MYSQL_HOST" ]] && \
      sed -i "s/\('Hostname'\s*=>\s*\).*/\1'$MYSQL_HOST',/" "$SERVERS_CONFIG" || \
      echo "⚠️ MYSQL_HOST não definido"

    [[ -n "$MYSQL_DB" ]] && \
      sed -i "s/\('Database'\s*=>\s*\).*/\1'$MYSQL_DB',/" "$SERVERS_CONFIG" || \
      echo "⚠️ MYSQL_DB não definido"

    [[ -n "$MYSQL_USER" ]] && \
      sed -i "s/\('Username'\s*=>\s*\).*/\1'$MYSQL_USER',/" "$SERVERS_CONFIG" || \
      echo "⚠️ MYSQL_USER não definido"

    [[ -n "$MYSQL_PWD" ]] && \
      sed -i "s/\('Password'\s*=>\s*\).*/\1'$MYSQL_PWD',/" "$SERVERS_CONFIG" || \
      echo "⚠️ MYSQL_PWD não definido"
  else
    echo "❌ Arquivo $SERVERS_CONFIG não encontrado!"
  fi
}

# ========================
# Execução principal
# ========================
init_fluxcp_repo
configure_fluxcp

# Inicializa o Apache
echo "🚀 Iniciando Apache..."
exec apache2-foreground
