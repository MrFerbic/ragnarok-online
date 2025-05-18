#!/bin/bash

APP_CONFIG="/var/www/html/config/application.php"
SERVERS_CONFIG="/var/www/html/config/servers.php"

echo "🔧 Starting FluxCP entrypoint setup..."

# --- application.php ---
if [[ -f "$APP_CONFIG" ]]; then
  # Set ServerAddress
  if [[ -n "$FLUXCP_HOST" ]]; then
    echo "🛠️ Setting ServerAddress to '$FLUXCP_HOST'"
    sed -i "s/\('ServerAddress'\s*=>\s*\).*/\1'$FLUXCP_HOST',/" "$APP_CONFIG"
  else
    echo "⚠️ FLUXCP_HOST not set"
  fi

  # Set BaseURI to root
  echo "🛠️ Setting BaseURI to '' (root)"
  sed -i "s/\('BaseURI'\s*=>\s*\).*/\1'',/" "$APP_CONFIG"

  # Set InstallerPassword
  if [[ -n "$FLUXCP_INSTALLER_PASSWORD" ]]; then
    echo "🛠️ Setting InstallerPassword"
    sed -i "s/\('InstallerPassword'\s*=>\s*\).*/\1'$FLUXCP_INSTALLER_PASSWORD',/" "$APP_CONFIG"
  else
    echo "⚠️ FLUXCP_INSTALLER_PASSWORD not set"
  fi
else
  echo "❌ $APP_CONFIG not found!"
fi

# --- servers.php ---
if [[ -f "$SERVERS_CONFIG" ]]; then
  echo "🛠️ Updating DB credentials in servers.php..."

  if [[ -n "$MYSQL_HOST" ]]; then
    sed -i "s/\('Hostname'\s*=>\s*\).*/\1'$MYSQL_HOST',/" "$SERVERS_CONFIG"
  else
    echo "⚠️ MYSQL_HOST not set"
  fi

  if [[ -n "$MYSQL_DB" ]]; then
    sed -i "s/\('Database'\s*=>\s*\).*/\1'$MYSQL_DB',/" "$SERVERS_CONFIG"
  else
    echo "⚠️ MYSQL_DB not set"
  fi

  if [[ -n "$MYSQL_USER" ]]; then
    sed -i "s/\('Username'\s*=>\s*\).*/\1'$MYSQL_USER',/" "$SERVERS_CONFIG"
  else
    echo "⚠️ MYSQL_USER not set"
  fi

  if [[ -n "$MYSQL_PWD" ]]; then
    sed -i "s/\('Password'\s*=>\s*\).*/\1'$MYSQL_PWD',/" "$SERVERS_CONFIG"
  else
    echo "⚠️ MYSQL_PWD not set"
  fi
else
  echo "❌ $SERVERS_CONFIG not found!"
fi

# --- Start Apache ---
echo "🚀 Launching Apache..."
exec apache2-foreground