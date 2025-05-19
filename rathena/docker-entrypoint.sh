#!/bin/sh

# ------------------------------------------------------
# Build Phase
# ------------------------------------------------------
set -e

echo "Waiting for MySQL to become available..."

# Wait for MySQL to be reachable
until mysql -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PWD" -e "SELECT 1;" >/dev/null 2>&1; do
  echo "MySQL is unavailable - sleeping"
  sleep 3
done

echo "MySQL is up - continuing..."

# ------------------------------------------------------
# Build Phase
# ------------------------------------------------------
RATHENA_DIR="/rAthena"

# Functions
log() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

clone_repo() {
  if [ ! -d "$RATHENA_DIR/.git" ]; then
    log "📥 Initializing rAthena in existing directory..."

    # Checkout repo
    git config --global --add safe.directory "$RATHENA_DIR"
    git init "$RATHENA_DIR"
    cd "$RATHENA_DIR"
    git remote add origin "$RATHENA_REPO_URL"
    git fetch --depth 1 origin "$RATHENA_BRANCH"
    git checkout "$RATHENA_COMMIT" || git checkout "$RATHENA_BRANCH"

    # Fix server file ownership
    if [ -n "$HOST_UID" ] && [ -n "$HOST_GID" ]; then
      echo "🔧 Fixing ownership of ${RATHENA_DIR} to ${HOST_UID}:${HOST_GID}"
      chown -R "$HOST_UID:$HOST_GID" "$RATHENA_DIR"
    fi
  else
    log "✅ rAthena repo already present"
  fi
}

check_binaries() {
  for bin in char-server login-server map-server web-server; do
    if [ ! -f "$RATHENA_DIR/$bin" ]; then
      return 1
    fi
  done
  return 0
}

build_rathena() {
    log "🔧 Building rAthena..."
    cd "$RATHENA_DIR"

    PACKET_OBFUSCATION=1

    if [ "${PACKET_OBFUSCATION}" -ne 1 ]; then sed -i "s|#define PACKET_OBFUSCATION|//#define PACKET_OBFUSCATION|g" "$RATHENA_DIR/src/config/packets.hpp"; fi
    if [ "${PACKET_OBFUSCATION}" -ne 1 ]; then sed -i "s|#define PACKET_OBFUSCATION_WARN|//#define PACKET_OBFUSCATION_WARN|g" "$RATHENA_DIR/src/config/packets.hpp"; fi

    # Find where the libmysqlclient.so installed
    MYSQL_LIB_PATH=$(dpkg -S libmysqlclient.so | awk '{print $2}')

    # Actual build process
    ./configure  --enable-packetver=${RATHENA_PACKETVER} --enable-64bit --with-MYSQL_LIBS="$MYSQL_LIB_PATH"
    make clean
    make server

    # Finalize
    chmod a+x login-server char-server map-server web-server
}

build_server() {
  if check_binaries; then
    log "✅ All required binaries already exist — skipping clone/build"
  else
    log "🛠️ Required binaries missing — proceeding to clone and build"
    clone_repo
    build_rathena
  fi
}

build_server

# ------------------------------------------------------

# Proceed with MySQL setup and configuration
echo "Starting configuration and database initialization..."

# (your original logic from setup_mysql_config, setup_config, etc. stays unchanged)
# ------------------------------------------------------
# Build Phase
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
echo "Initalizing Docker container..."

check_database_exist () {
    RESULT=$(mysqlshow --user="${MYSQL_USER}" --password="${MYSQL_PWD}" --host="${MYSQL_HOST}" 2>/dev/null | grep -v Wildcard | grep -o "${MYSQL_DB}")
    if [ "$RESULT" = "${MYSQL_DB}" ]; then
        return 0
    else
        return 1
    fi
}

setup_init () {
    if ! [ -z "${SET_MOTD}" ]; then echo -e "${SET_MOTD}" > "$RATHENA_DIR/conf/motd.txt"; fi
    
    # Cleanup previous config
    rm -rf "$RATHENA_DIR/conf/import"

    # Copy import-tmpl to import
    cp -r "$RATHENA_DIR/conf/import-tmpl" "$RATHENA_DIR/conf/import"

    # Re-config everythings
    setup_mysql_config
    setup_config
    enable_custom_npc
    setup_rate
    setup_extras
}

import_sql_file() {
    TARGET_PATH="$1"
    ALLOW_FAIL="${2:-false}"  # default: do not allow failures

    if [[ -z "$TARGET_PATH" ]]; then
        echo "❌ No path provided to inject_sql"
        return 1
    fi

    run_sql_file() {
        local FILE="$1"
        echo "➡️  Injecting: $FILE"

        if ! mysql -u"${MYSQL_USER}" -p"${MYSQL_PWD}" -h "${MYSQL_HOST}" -D"${MYSQL_DB}" < "$FILE"; then
            if [[ "$ALLOW_FAIL" == "true" ]]; then
                echo "⚠️  Failed to inject $FILE — continuing due to ALLOW_FAIL=true"
            else
                echo "❌ Failed to inject $FILE — aborting (ALLOW_FAIL=false)"
                return 1
            fi
        fi
    }

    if [[ -f "$TARGET_PATH" && "$TARGET_PATH" == *.sql ]]; then
        run_sql_file "$TARGET_PATH" || return 1
    elif [[ -d "$TARGET_PATH" ]]; then
        echo "📁 Injecting all SQL files in directory: $TARGET_PATH (non-recursive, sorted)"
        find "$TARGET_PATH" -maxdepth 1 -type f -name "*.sql" | sort | while read -r SQL_FILE; do
            run_sql_file "$SQL_FILE" || [[ "$ALLOW_FAIL" == "true" ]] || return 1
        done
    else
        echo "⚠️ Invalid target path or not an .sql file: $TARGET_PATH"
        return 1
    fi
}

setup_mysql_config () {
    echo "###### MySQL setup ######"
    if [ -z "${MYSQL_HOST}" ]; then echo "Missing MYSQL_HOST environment variable. Unable to continue."; exit 1; fi
    if [ -z "${MYSQL_DB}" ]; then echo "Missing MYSQL_DB environment variable. Unable to continue."; exit 1; fi
    if [ -z "${MYSQL_USER}" ]; then echo "Missing MYSQL_USER environment variable. Unable to continue."; exit 1; fi
    if [ -z "${MYSQL_PWD}" ]; then echo "Missing MYSQL_PWD environment variable. Unable to continue."; exit 1; fi

    echo "Setting up MySQL on Login Server..."

    echo -e "use_sql_db: yes" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "login_server_ip: ${MYSQL_HOST}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "login_server_db: ${MYSQL_DB}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "login_server_id: ${MYSQL_USER}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "login_server_pw: ${MYSQL_PWD}\n" >> "$RATHENA_DIR/conf/import/inter_conf.txt"

    echo "Setting up MySQL on Map Server..."
    echo -e "map_server_ip: ${MYSQL_HOST}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "map_server_db: ${MYSQL_DB}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "map_server_id: ${MYSQL_USER}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "map_server_pw: ${MYSQL_PWD}\n" >> "$RATHENA_DIR/conf/import/inter_conf.txt"

    echo "Setting up MySQL on Char Server..."
    echo -e "char_server_ip: ${MYSQL_HOST}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "char_server_db: ${MYSQL_DB}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "char_server_id: ${MYSQL_USER}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "char_server_pw: ${MYSQL_PWD}\n" >> "$RATHENA_DIR/conf/import/inter_conf.txt"

    echo "Setting up MySQL on IP ban..."
    echo -e "ipban_db_ip: ${MYSQL_HOST}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "ipban_db_db: ${MYSQL_DB}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "ipban_db_id: ${MYSQL_USER}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "ipban_db_pw: ${MYSQL_PWD}\n" >> "$RATHENA_DIR/conf/import/inter_conf.txt"

    echo "Setting up MySQL on log..."
    echo -e "log_db_ip: ${MYSQL_HOST}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "log_db_db: ${MYSQL_DB}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "log_db_id: ${MYSQL_USER}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "log_db_pw: ${MYSQL_PWD}\n" >> "$RATHENA_DIR/conf/import/inter_conf.txt"

    echo "Setting up MySQL on log..."
    echo -e "web_server_ip: ${MYSQL_HOST}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "web_server_db: ${MYSQL_DB}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "web_server_id: ${MYSQL_USER}" >> "$RATHENA_DIR/conf/import/inter_conf.txt"
    echo -e "web_server_pw: ${MYSQL_PWD}\n" >> "$RATHENA_DIR/conf/import/inter_conf.txt"

    if ! [ -z ${MYSQL_DROP_DB} ]; then
        if [ ${MYSQL_DROP_DB} -ne 0 ]; then
            if check_database_exist; then
                echo "DROP FOUND, REMOVING EXISTING DATABASE..."
                mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -e "DROP DATABASE ${MYSQL_DB};"
            fi
        fi
    fi
    echo "Checking if database already exists..."
    if ! check_database_exist; then
        echo "Creating database ${MYSQL_DB} and importing SQL schema..."

        mysql -u"${MYSQL_USER}" -p"${MYSQL_PWD}" -h "${MYSQL_HOST}" -e "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DB}\`;"

        # Import main database data
        import_sql_file "$RATHENA_DIR/sql-files" false # Fail on any error

        # Import upgrade data
        import_sql_file "$RATHENA_DIR/sql-files/upgrades" true # Continue on errors

        # Import compability data
        import_sql_file "$RATHENA_DIR/sql-files/compatibility" true # Continue on errors

        # Update 1st account, this seems is a system account it is unusable, but required by server
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} -e "UPDATE login SET userid = \"${SET_INTERSRV_USERID}\", user_pass = \"${SET_INTERSRV_PASSWD}\", group_id = 99 WHERE account_id = 1;"

        # execute the accountsandchars.sql so GM and bot accounts get precreated in the database.
        MYSQL_ACCOUNTSANDCHARS=1
        if ! [ -z "${MYSQL_ACCOUNTSANDCHARS}" ]; then
            import_sql_file "/setup/accountsandchars.sql" true
        fi

        # First account
        import_sql_file "/setup/firstaccount.sql" true
    fi
}

setup_config () {
    if ! [ -z "${SET_INTERSRV_USERID}" ]; then 
        echo -e "userid: ${SET_INTERSRV_USERID}" >> "$RATHENA_DIR/conf/import/map_conf.txt"
        echo -e "userid: ${SET_INTERSRV_USERID}" >> "$RATHENA_DIR/conf/import/char_conf.txt"
    fi
    if ! [ -z "${SET_INTERSRV_PASSWD}" ]; then 
        echo -e "passwd: ${SET_INTERSRV_PASSWD}" >> "$RATHENA_DIR/conf/import/map_conf.txt"
        echo -e "passwd: ${SET_INTERSRV_PASSWD}" >> "$RATHENA_DIR/conf/import/char_conf.txt"
    fi
    
    if ! [ -z "${SET_CHAR_TO_LOGIN_IP}" ]; then echo -e "login_ip: ${SET_CHAR_TO_LOGIN_IP}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
    if ! [ -z "${SET_CHAR_PUBLIC_IP}" ]; then echo -e "char_ip: ${SET_CHAR_PUBLIC_IP}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
    if ! [ -z "${BIND_IP}" ]; then echo -e "bind_ip: ${BIND_IP}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
    
    if ! [ -z "${SET_MAP_TO_CHAR_IP}" ]; then echo -e "char_ip: ${SET_MAP_TO_CHAR_IP}" >> "$RATHENA_DIR/conf/import/map_conf.txt"; fi
    if ! [ -z "${SET_MAP_PUBLIC_IP}" ]; then echo -e "map_ip: ${SET_MAP_PUBLIC_IP}" >> "$RATHENA_DIR/conf/import/map_conf.txt"; fi
    if ! [ -z "${BIND_IP}" ]; then echo -e "bind_ip: ${BIND_IP}" >> "$RATHENA_DIR/conf/import/map_conf.txt"; fi

    if ! [ -z "${BIND_IP}" ]; then echo -e "bind_ip: ${BIND_IP}" >> "$RATHENA_DIR/conf/import/web_conf.txt"; fi

    if ! [ -z "${ADD_SUBNET_MAP1}" ]; then echo -e "subnet: ${ADD_SUBNET_MAP1}" >> "$RATHENA_DIR/conf/subnet_athena.conf"; fi
    if ! [ -z "${ADD_SUBNET_MAP2}" ]; then echo -e "subnet: ${ADD_SUBNET_MAP2}" >> "$RATHENA_DIR/conf/subnet_athena.conf"; fi
    if ! [ -z "${ADD_SUBNET_MAP3}" ]; then echo -e "subnet: ${ADD_SUBNET_MAP3}" >> "$RATHENA_DIR/conf/subnet_athena.conf"; fi
    if ! [ -z "${ADD_SUBNET_MAP4}" ]; then echo -e "subnet: ${ADD_SUBNET_MAP4}" >> "$RATHENA_DIR/conf/subnet_athena.conf"; fi
    if ! [ -z "${ADD_SUBNET_MAP5}" ]; then echo -e "subnet: ${ADD_SUBNET_MAP5}" >> "$RATHENA_DIR/conf/subnet_athena.conf"; fi

    if ! [ -z "${SET_SERVER_NAME}" ]; then echo -e "server_name: ${SET_SERVER_NAME}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
    if ! [ -z "${SET_MAX_CONNECT_USER}" ]; then echo -e "max_connect_user: ${SET_MAX_CONNECT_USER}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
    if ! [ -z "${SET_START_ZENNY}" ]; then echo -e "start_zenny: ${SET_START_ZENNY}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
    if ! [ -z "${SET_START_POINT}" ]; then echo -e "start_point: ${SET_START_POINT}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
    if ! [ -z "${SET_START_POINT_PRE}" ]; then echo -e "start_point_pre: ${SET_START_POINT_PRE}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
    if ! [ -z "${SET_START_POINT_DORAM}" ]; then echo -e "start_point_doram: ${SET_START_POINT_DORAM}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
    if ! [ -z "${SET_START_ITEMS}" ]; then echo -e "start_items: ${SET_START_ITEMS}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
    if ! [ -z "${SET_START_ITEMS_DORAM}" ]; then echo -e "start_items_doram: ${SET_START_ITEMS_DORAM}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi
    if ! [ -z "${SET_PINCODE_ENABLED}" ]; then echo -e "pincode_enabled: ${SET_PINCODE_ENABLED}" >> "$RATHENA_DIR/conf/import/char_conf.txt"; fi

    if ! [ -z "${SET_ALLOWED_REGS}" ]; then echo -e "allowed_regs: ${SET_ALLOWED_REGS}" >> "$RATHENA_DIR/conf/import/login_conf.txt"; fi
    if ! [ -z "${SET_TIME_ALLOWED}" ]; then echo -e "time_allowed: ${SET_TIME_ALLOWED}" >> "$RATHENA_DIR/conf/import/login_conf.txt"; fi

    if ! [ -z "${SET_ARROW_DECREMENT}" ]; then echo -e "arrow_decrement: ${SET_ARROW_DECREMENT}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"; fi
}

enable_custom_npc () {
    echo -e "npc: npc/custom/gab_npc.txt" >> "$RATHENA_DIR/npc/scripts_custom.conf"
}

setup_rate () {
    echo "Configuring server rates..."

    # EXP rates
    if ! [ -z "${RATE_BASE_EXP}" ]; then
        echo -e "base_exp_rate: ${RATE_BASE_EXP}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
    fi
    if ! [ -z "${RATE_JOB_EXP}" ]; then
        echo -e "job_exp_rate: ${RATE_JOB_EXP}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
    fi
    if ! [ -z "${ENABLE_MULTI_LEVEL_UP}" ]; then 
        echo -e "multi_level_up: ${ENABLE_MULTI_LEVEL_UP}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
    fi

    # Drop rates
    if ! [ -z "${RATE_ITEM_DROP_COMMON}" ]; then
        echo -e "item_rate_common: ${RATE_ITEM_DROP_COMMON}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_common_boss: ${RATE_ITEM_DROP_COMMON}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_common_mvp: ${RATE_ITEM_DROP_COMMON}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_common_min: ${RATE_ITEM_DROP_COMMON}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_common_max: ${RATE_ITEM_DROP_COMMON}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
    fi
    if ! [ -z "${RATE_ITEM_DROP_HEAL}" ]; then
        echo -e "item_rate_heal: ${RATE_ITEM_DROP_HEAL}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_heal_boss: ${RATE_ITEM_DROP_HEAL}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_heal_mvp: ${RATE_ITEM_DROP_HEAL}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_heal_min: ${RATE_ITEM_DROP_HEAL}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_heal_max: ${RATE_ITEM_DROP_HEAL}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
    fi
    if ! [ -z "${RATE_ITEM_DROP_USABLE}" ]; then
        echo -e "item_rate_usable: ${RATE_ITEM_DROP_USABLE}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_usable_boss: ${RATE_ITEM_DROP_USABLE}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_usable_mvp: ${RATE_ITEM_DROP_USABLE}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_usable_min: ${RATE_ITEM_DROP_USABLE}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_usable_max: ${RATE_ITEM_DROP_USABLE}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
    fi
    if ! [ -z "${RATE_ITEM_DROP_EQUIP}" ]; then
        echo -e "item_rate_equip: ${RATE_ITEM_DROP_EQUIP}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_equip_boss: ${RATE_ITEM_DROP_EQUIP}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_equip_mvp: ${RATE_ITEM_DROP_EQUIP}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_equip_min: ${RATE_ITEM_DROP_EQUIP}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_equip_max: ${RATE_ITEM_DROP_EQUIP}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
    fi
    if ! [ -z "${RATE_ITEM_DROP_CARD}" ]; then
        echo -e "item_rate_card: ${RATE_ITEM_DROP_CARD}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_card_boss: ${RATE_ITEM_DROP_CARD}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_card_mvp: ${RATE_ITEM_DROP_CARD}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_card_min: ${RATE_ITEM_DROP_CARD}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_card_max: ${RATE_ITEM_DROP_CARD}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
    fi
    if ! [ -z "${RATE_ITEM_DROP_MISC}" ]; then
        echo -e "item_rate_misc: ${RATE_ITEM_DROP_MISC}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_misc_boss: ${RATE_ITEM_DROP_MISC}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_misc_mvp: ${RATE_ITEM_DROP_MISC}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_misc_min: ${RATE_ITEM_DROP_MISC}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_misc_max: ${RATE_ITEM_DROP_MISC}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
    fi
    if ! [ -z "${RATE_ITEM_DROP_TREASURE}" ]; then
        echo -e "item_rate_treasure: ${RATE_ITEM_DROP_TREASURE}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_treasure_boss: ${RATE_ITEM_DROP_TREASURE}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_treasure_mvp: ${RATE_ITEM_DROP_TREASURE}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_treasure_min: ${RATE_ITEM_DROP_TREASURE}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
        echo -e "item_rate_treasure_max: ${RATE_ITEM_DROP_TREASURE}" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
    fi
}

setup_extras () {
    echo "Configuring extra configs"
    # https://rathena.github.io/user-guides/configuration/imports/

    # hide all error messages
    echo -e "console_msg_log: 0" >> "$RATHENA_DIR/conf/import/map_conf.txt"
    echo -e "console_silent: 16" >> "$RATHENA_DIR/conf/import/map_conf.txt"

    
    # log all items and all chat messages.
    echo -e "log_filter: 1" >> "$RATHENA_DIR/conf/import/log_conf.txt"
    echo -e "log_chat: 63" >> "$RATHENA_DIR/conf/import/log_conf.txt"

    # mail box status is displayed upon login when there are unread mails
    echo -e "mail_show_status: 2" >> "$RATHENA_DIR/conf/import/battle_conf.txt"
}

setup_init

exec "$@"