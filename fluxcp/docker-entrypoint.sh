#!/bin/bash
set -e

APP_CONFIG="/var/www/html/config/application.php"
SERVERS_CONFIG="/var/www/html/config/servers.php"
FLUXCP_DIR="/var/www/html"

init_fluxcp_repo() {
  if [ ! -d "$FLUXCP_DIR/.git" ]; then
    echo "📥 Initializing FluxCP repository..."

    cd "$FLUXCP_DIR"

    git config --global --add safe.directory "$FLUXCP_DIR"
    echo "🔧 git init"
    git init

    REMOTE_URL="${FLUXCP_REPO_URL:-https://github.com/rathena/FluxCP.git}"
    echo "🔗 Adding remote $REMOTE_URL"
    git remote add origin "$REMOTE_URL"

    echo "📡 Fetching repo..."
    git fetch origin

    BRANCH="${FLUXCP_BRANCH:-master}"
    echo "🌿 Checking out branch $BRANCH"
    git checkout -b "$BRANCH" "origin/$BRANCH"

    if [ -n "$FLUXCP_COMMIT" ]; then
      echo "🔢 Checking out specific commit $FLUXCP_COMMIT"
      git checkout "$FLUXCP_COMMIT"
    fi

    echo "🔐 Setting permissions"

    chown -R www-data:www-data "$FLUXCP_DIR"
    chmod -R 777 "$FLUXCP_DIR"
  else
    echo "✅ FluxCP repo already initialized"
  fi
}

configure_fluxcp() {
  echo "🔧 Starting FluxCP entrypoint setup..."

  # --- application.php ---
  if [[ -f "$APP_CONFIG" ]]; then
    [[ -n "$FLUXCP_HOST" ]] && \
      echo "🛠️ Setting ServerAddress to '$FLUXCP_HOST'" && \
      sed -i "s/\('ServerAddress'\s*=>\s*\).*/\1'$FLUXCP_HOST',/" "$APP_CONFIG" || \
      echo "⚠️ FLUXCP_HOST not set"

    echo "🛠️ Setting BaseURI to '' (root)"
    sed -i "s/\('BaseURI'\s*=>\s*\).*/\1'',/" "$APP_CONFIG"

    [[ -n "$FLUXCP_INSTALLER_PASSWORD" ]] && \
      echo "🛠️ Setting InstallerPassword" && \
      sed -i "s/\('InstallerPassword'\s*=>\s*\).*/\1'$FLUXCP_INSTALLER_PASSWORD',/" "$APP_CONFIG" || \
      echo "⚠️ FLUXCP_INSTALLER_PASSWORD not set"
  else
    echo "❌ $APP_CONFIG not found!"
  fi

  # --- servers.php ---
  if [[ -f "$SERVERS_CONFIG" ]]; then
    echo "🛠️ Updating DB credentials in servers.php..."

    [[ -n "$MYSQL_HOST" ]] && \
      sed -i "s/\('Hostname'\s*=>\s*\).*/\1'$MYSQL_HOST',/" "$SERVERS_CONFIG" || \
      echo "⚠️ MYSQL_HOST not set"

    [[ -n "$MYSQL_DB" ]] && \
      sed -i "s/\('Database'\s*=>\s*\).*/\1'$MYSQL_DB',/" "$SERVERS_CONFIG" || \
      echo "⚠️ MYSQL_DB not set"

    [[ -n "$MYSQL_USER" ]] && \
      sed -i "s/\('Username'\s*=>\s*\).*/\1'$MYSQL_USER',/" "$SERVERS_CONFIG" || \
      echo "⚠️ MYSQL_USER not set"

    [[ -n "$MYSQL_PWD" ]] && \
      sed -i "s/\('Password'\s*=>\s*\).*/\1'$MYSQL_PWD',/" "$SERVERS_CONFIG" || \
      echo "⚠️ MYSQL_PWD not set"
  else
    echo "❌ $SERVERS_CONFIG not found!"
  fi
}

# Main logic
init_fluxcp_repo
configure_fluxcp

# --- Start Apache ---
echo "🚀 Launching Apache..."
exec apache2-foreground