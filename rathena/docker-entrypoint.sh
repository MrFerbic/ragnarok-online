#!/bin/sh

# ------------------------------------------------------
# Inicialização e Build do Servidor rAthena
# ------------------------------------------------------
set -e  # Faz o script parar em caso de erro

echo "Waiting for MySQL to become available..."

# Espera o MySQL estar disponível antes de continuar
until mysql -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PWD" -e "SELECT 1;" >/dev/null 2>&1; do
  echo "MySQL is unavailable - sleeping"
  sleep 3
done

echo "MySQL is up - continuing..."

RATHENA_DIR="/rAthena"

# Função para logar mensagens com timestamp
log() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Função para clonar o repositório rAthena se ainda não existir
clone_repo() {
  if [ ! -d "$RATHENA_DIR/.git" ]; then
    log "📥 Inicializando rAthena no diretório..."

    git config --global --add safe.directory "$RATHENA_DIR"
    git init "$RATHENA_DIR"
    cd "$RATHENA_DIR"
    git remote add origin "$RATHENA_REPO_URL"
    git fetch --depth 1 origin "$RATHENA_BRANCH"
    git checkout "$RATHENA_COMMIT" || git checkout "$RATHENA_BRANCH"

    # Ajusta permissões conforme UID/GID do host
    if [ -n "$HOST_UID" ] && [ -n "$HOST_GID" ]; then
      echo "🔧 Ajustando propriedade para ${HOST_UID}:${HOST_GID}"
      chown -R "$HOST_UID:$HOST_GID" "$RATHENA_DIR"
    fi
  else
    log "✅ Repositório rAthena já presente"
  fi
}

# Função que verifica se os binários essenciais já existem
check_binaries() {
  for bin in char-server login-server map-server web-server; do
    if [ ! -f "$RATHENA_DIR/$bin" ]; then
      return 1
    fi
  done
  return 0
}

# Função para compilar o rAthena
build_rathena() {
  log "🔧 Compilando rAthena..."
  cd "$RATHENA_DIR"

  PACKET_OBFUSCATION=1

  if [ "${PACKET_OBFUSCATION}" -ne 1 ]; then
    sed -i "s|#define PACKET_OBFUSCATION|//#define PACKET_OBFUSCATION|g" "$RATHENA_DIR/src/config/packets.hpp"
    sed -i "s|#define PACKET_OBFUSCATION_WARN|//#define PACKET_OBFUSCATION_WARN|g" "$RATHENA_DIR/src/config/packets.hpp"
  fi

  MYSQL_LIB_PATH=$(dpkg -S libmysqlclient.so | awk '{print $2}')

  ./configure --enable-packetver=${RATHENA_PACKETVER} --enable-64bit --with-MYSQL_LIBS="$MYSQL_LIB_PATH"
  make clean
  make server

  chmod a+x login-server char-server map-server web-server
}

# Função principal que verifica e executa build
build_server() {
  if check_binaries; then
    log "✅ Binários já existem - pulando build"
  else
    log "🛠️ Binários faltando - clonando e compilando"
    clone_repo
    build_rathena
  fi
}

build_server

# ------------------------------------------------------
# Configuração do MySQL e banco de dados
# ------------------------------------------------------

echo "rAthena Development Team presents"
echo "           ___   __  __"
echo "     _____/   | / /_/ /_  ___  ____  ____ _"
echo "    / ___/ /| |/ __/ __ \/ _ \/ __ \/ __  /"
echo "   / /  / ___ / /_/ / / /  __/ / / / /_/ /"
echo "  /_/  /_/  |_\__/_/ /_/\___/_/ /_/\__,_/"
echo ""
echo "http://rathena.org/board/"
echo ""
DATE=$(date '+%Y-%m-%d %H:%M:%S')
echo "Iniciando container Docker em $DATE..."

# Verifica se o banco de dados existe
check_database_exist () {
  RESULT=$(mysqlshow --user="${MYSQL_USER}" --password="${MYSQL_PWD}" --host="${MYSQL_HOST}" 2>/dev/null | grep -v Wildcard | grep -o "${MYSQL_DB}")
  if [ "$RESULT" = "${MYSQL_DB}" ]; then
    return 0
  else
    return 1
  fi
}

# Inicialização das configs
setup_init () {
  if ! [ -z "${SET_MOTD}" ]; then echo -e "${SET_MOTD}" > "$RATHENA_DIR/conf/motd.txt"; fi

  rm -rf "$RATHENA_DIR/conf/import"
  cp -r "$RATHENA_DIR/conf/import-tmpl" "$RATHENA_DIR/conf/import"

  setup_mysql_config
  setup_config
  enable_custom_npc
  setup_rate
  setup_extras
}

# Importa arquivos SQL, aceita diretório ou arquivo único
import_sql_file() {
  TARGET_PATH="$1"
  ALLOW_FAIL="${2:-false}"  # padrão: falhar em erro

  if [[ -z "$TARGET_PATH" ]]; then
    echo "❌ Nenhum caminho para SQL foi fornecido"
    return 1
  fi

  run_sql_file() {
    local FILE="$1"
    echo "➡️  Importando: $FILE"
    if ! mysql -u"${MYSQL_USER}" -p"${MYSQL_PWD}" -h "${MYSQL_HOST}" -D"${MYSQL_DB}" < "$FILE"; then
      if [[ "$ALLOW_FAIL" == "true" ]]; then
        echo "⚠️  Falha ao importar $FILE — continuando devido a ALLOW_FAIL=true"
      else
        echo "❌ Falha ao importar $FILE — abortando"
        return 1
      fi
    fi
  }

  if [[ -f "$TARGET_PATH" && "$TARGET_PATH" == *.sql ]]; then
    run_sql_file "$TARGET_PATH" || return 1
  elif [[ -d "$TARGET_PATH" ]]; then
    echo "📁 Importando todos arquivos SQL em: $TARGET_PATH (não recursivo, ordenado)"
    find "$TARGET_PATH" -maxdepth 1 -type f -name "*.sql" | sort | while read -r SQL_FILE; do
      run_sql_file "$SQL_FILE" || [[ "$ALLOW_FAIL" == "true" ]] || return 1
    done
  else
    echo "⚠️ Caminho inválido ou não é um arquivo .sql: $TARGET_PATH"
    return 1
  fi
}

# Configurações do MySQL (criação e importação de banco)
setup_mysql_config () {
  echo "###### Configurando MySQL ######"
  if [ -z "${MYSQL_HOST}" ] || [ -z "${MYSQL_DB}" ] || [ -z "${MYSQL_USER}" ] || [ -z "${MYSQL_PWD}" ]; then
    echo "Faltam variáveis de ambiente MYSQL_* necessárias."
    exit 1
  fi

  # Escreve configurações para diversos componentes do servidor rAthena
  for conf in inter_conf.txt; do
    echo -e "use_sql_db: yes" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "login_server_ip: ${MYSQL_HOST}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "login_server_db: ${MYSQL_DB}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "login_server_id: ${MYSQL_USER}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "login_server_pw: ${MYSQL_PWD}\n" >> "$RATHENA_DIR/conf/import/$conf"

    echo -e "map_server_ip: ${MYSQL_HOST}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "map_server_db: ${MYSQL_DB}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "map_server_id: ${MYSQL_USER}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "map_server_pw: ${MYSQL_PWD}\n" >> "$RATHENA_DIR/conf/import/$conf"

    echo -e "char_server_ip: ${MYSQL_HOST}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "char_server_db: ${MYSQL_DB}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "char_server_id: ${MYSQL_USER}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "char_server_pw: ${MYSQL_PWD}\n" >> "$RATHENA_DIR/conf/import/$conf"

    echo -e "ipban_db_ip: ${MYSQL_HOST}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "ipban_db_db: ${MYSQL_DB}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "ipban_db_id: ${MYSQL_USER}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "ipban_db_pw: ${MYSQL_PWD}\n" >> "$RATHENA_DIR/conf/import/$conf"

    echo -e "log_db_ip: ${MYSQL_HOST}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "log_db_db: ${MYSQL_DB}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "log_db_id: ${MYSQL_USER}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "log_db_pw: ${MYSQL_PWD}\n" >> "$RATHENA_DIR/conf/import/$conf"

    echo -e "web_server_ip: ${MYSQL_HOST}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "web_server_db: ${MYSQL_DB}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "web_server_id: ${MYSQL_USER}" >> "$RATHENA_DIR/conf/import/$conf"
    echo -e "web_server_pw: ${MYSQL_PWD}\n" >> "$RATHENA_DIR/conf/import/$conf"
  done

  # Se solicitado, apaga o banco existente
  if ! [ -z ${MYSQL_DROP_DB} ]; then
    if [ ${MYSQL_DROP_DB} -ne 0 ]; then
      if check_database_exist; then
        echo "DROP DB habilitado, removendo banco existente..."
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -e "DROP DATABASE ${MYSQL_DB};"
      fi
    fi
  fi

  echo "Verificando se banco ${MYSQL_DB} já existe..."
  if ! check_database_exist; then
    echo "Criando banco ${MYSQL_DB} e importando schema..."

    mysql -u"${MYSQL_USER}" -p"${MYSQL_PWD}" -h "${MYSQL_HOST}" -e "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DB}\`;"

    import_sql_file "$RATHENA_DIR/sql-files" false
    import_sql_file "$RATHENA_DIR/sql-files/upgrades" true
    import_sql_file "$RATHENA_DIR/sql-files/compatibility" true

    # Atualiza conta de sistema (account_id=1)
    mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} -e "UPDATE login SET userid = \"${SET_INTERSRV_USERID}\", user_pass = \"${SET_INTERSRV_PASSWD}\", group_id = 99 WHERE account_id = 1;"

    # Importa contas e chars pré-criados
    MYSQL_ACCOUNTSANDCHARS=1
    if ! [ -z "${MYSQL_ACCOUNTSANDCHARS}" ]; then
      import_sql_file "/setup/accountsandchars.sql" true
    fi

    # Importa conta inicial
    import_sql_file "/setup/firstaccount.sql" true
  fi
}

# Configura várias configurações do servidor rAthena a partir das variáveis de ambiente
setup_config () {
  if ! [ -z "${SET_INTERSRV_USERID}" ]; then 
    echo -e "userid: ${SET_INTERSRV_USERID}" >> "$RATHENA_DIR/conf/import/map_conf.txt"
    echo -e "userid: ${SET_INTERSRV_USERID}" >> "$RATHENA_DIR/conf/import/char_conf.txt"
  fi
  if ! [ -z "${SET_INTERSRV_PASSWD}" ]; then 
    echo -e "passwd: ${SET_INTERSRV_PASSWD}" >> "$RATHENA_DIR/conf/import/map_conf.txt"
    echo -e "passwd: ${SET_INTERSRV_PASSWD}" >> "$RATHENA_DIR/conf/import/char_conf.txt"
  fi

  # IPs e Bindings
  if ! [ -z "${SET_CHAR_TO_LOGIN_IP}" ]; then echo -e "login_ip: ${SET_CHAR_TO_LOGIN_IP}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
  if ! [ -z "${SET_CHAR_PUBLIC_IP}" ]; then echo -e "char_ip: ${SET_CHAR_PUBLIC_IP}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
  if ! [ -z "${BIND_IP}" ]; then echo -e "bind_ip: ${BIND_IP}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi

  if ! [ -z "${SET_MAP_TO_CHAR_IP}" ]; then echo -e "char_ip: ${SET_MAP_TO_CHAR_IP}" >> "$RATHENA_DIR/conf/import/map_conf.txt"; fi
  if ! [ -z "${SET_MAP_PUBLIC_IP}" ]; then echo -e "map_ip: ${SET_MAP_PUBLIC_IP}" >> "$RATHENA_DIR/conf/import/map_conf.txt"; fi
  if ! [ -z "${BIND_IP}" ]; then echo -e "bind_ip: ${BIND_IP}" >> "$RATHENA_DIR/conf/import/map_conf.txt"; fi

  if ! [ -z "${BIND_IP}" ]; then echo -e "bind_ip: ${BIND_IP}" >> "$RATHENA_DIR/conf/import/web_conf.txt"; fi

  # Subnet additions
  for i in 1 2 3 4 5; do
    eval subnet_var=\$ADD_SUBNET_MAP${i}
    if ! [ -z "${subnet_var}" ]; then
      echo -e "subnet: ${subnet_var}" >> "$RATHENA_DIR/conf/subnet_athena.conf"
    fi
  done

  # Server name, max users, start config
  if ! [ -z "${SET_SERVER_NAME}" ]; then echo -e "server_name: ${SET_SERVER_NAME}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
  if ! [ -z "${SET_MAX_CONNECT_USER}" ]; then echo -e "max_connect_user: ${SET_MAX_CONNECT_USER}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
  if ! [ -z "${SET_START_ZENNY}" ]; then echo -e "start_zenny: ${SET_START_ZENNY}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
  if ! [ -z "${SET_START_POINT}" ]; then echo -e "start_point: ${SET_START_POINT}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
  if ! [ -z "${SET_START_POINT_PRE}" ]; then echo -e "start_point_pre: ${SET_START_POINT_PRE}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
  if ! [ -z "${SET_START_POINT_DORAM}" ]; then echo -e "start_point_doram: ${SET_START_POINT_DORAM}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
  if ! [ -z "${SET_START_ITEMS}" ]; then echo -e "start_items: ${SET_START_ITEMS}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
  if ! [ -z "${SET_START_ITEMS_DORAM}" ]; then echo -e "start_items_doram: ${SET_START_ITEMS_DORAM}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
  if ! [ -z "${SET_PINCODE_ENABLED}" ]; then echo -e "pincode_enabled: ${SET_PINCODE_ENABLED}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi

  # Login restrictions
  if ! [ -z "${SET_ALLOWED_REGS}" ]; then echo -e "allowed_regs: ${SET_ALLOWED_REGS}" >> "$RATHENA_DIR/conf/import/login_conf.txt"; fi
  if ! [ -z "${SET_TIME_ALLOWED}" ]; then echo -e "time_allowed: ${SET_TIME_ALLOWED}" >> "$RATHENA_DIR/conf/import/login_conf.txt"; fi

  # Battle config (arrow decrement)
  if ! [ -z "${SET_ARROW_DECREMENT}" ]; then echo -e "arrow_decrement: ${SET_ARROW_DECREMENT}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"; fi
}

# Habilita custom NPC
enable_custom_npc () {
  echo -e "npc: npc/custom/gab_npc.txt" >> "$RATHENA_DIR/npc/scripts_custom.conf"
}

# Configura taxas do servidor
setup_rate () {
  echo "Configurando rates do servidor..."

  # Base EXP
  if ! [ -z "${RATE_BASE_EXP}" ]; then
    echo -e "base_exp_rate: ${RATE_BASE_EXP}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
  fi
  if ! [ -z "${RATE_JOB_EXP}" ]; then
    echo -e "job_exp_rate: ${RATE_JOB_EXP}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
  fi
  if ! [ -z "${ENABLE_MULTI_LEVEL_UP}" ]; then 
    echo -e "multi_level_up: ${ENABLE_MULTI_LEVEL_UP}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
  fi

  # Drop rates em várias categorias
  for type in common heal usable equip card misc treasure; do
    varname=RATE_ITEM_DROP_$(echo $type | tr 'a-z' 'A-Z')
    value=$(eval echo \$$varname)
    if ! [ -z "${value}" ]; then
      for suffix in "" _boss _mvp _min _max; do
        echo -e "item_rate_${type}${suffix}: ${value}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
      done
    fi
  done
}

# Configurações extras (logs, mensagens)
setup_extras () {
  echo "Configurando extras..."

  # Reduz mensagens de erro no console
  echo -e "console_msg_log: 0" >> "$RATHENA_DIR/conf/import/map_conf.txt"
  echo -e "console_silent: 16" >> "$RATHENA_DIR/conf/import/map_conf.txt"

  # Logs de itens e chats
  echo -e "log_filter: 1" >> "$RATHENA_DIR/conf/import/log_conf.txt"
  echo -e "log_chat: 63" >> "$RATHENA_DIR/conf/import/log_conf.txt"

  # Mostra status da caixa postal ao logar
  echo -e "mail_show_status: 2" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
}

# Roda a inicialização completa
setup_init

# Finalmente, executa o comando padrão do container (normalmente start-server.sh)
exec "$@"
