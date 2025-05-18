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
# Build Phase (only once)
# ------------------------------------------------------
cd /rAthena

if [ ! -f /data/.built ]; then
    echo "Building rAthena server from source..."

    PACKETVER=20220406
    PACKET_OBFUSCATION=1

    if [ ${PACKET_OBFUSCATION} -neq 1 ]; then sed -i "s|#define PACKET_OBFUSCATION|//#define PACKET_OBFUSCATION|g" /rAthena/src/config/packets.hpp; fi
    if [ ${PACKET_OBFUSCATION} -neq 1 ]; then sed -i "s|#define PACKET_OBFUSCATION_WARN|//#define PACKET_OBFUSCATION_WARN|g" /rAthena/src/config/packets.hpp; fi

    # Find where the libmysqlclient.so installed
    MYSQL_LIB_PATH=$(dpkg -S libmysqlclient.so | awk '{print $2}')
    ./configure  --enable-packetver=${PACKETVER} --enable-64bit --with-MYSQL_LIBS="$MYSQL_LIB_PATH"
    make clean
    make server
    chmod a+x login-server char-server map-server web-server

    # Mark as built to prevent rebuilding
    touch /data/.built
else
    echo "rAthena already built, skipping build step."
fi
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
    if ! [ -z "${SET_MOTD}" ]; then echo -e "${SET_MOTD}" > /rAthena/conf/motd.txt; fi
    setup_mysql_config
    setup_config
    enable_custom_npc
}

import_sql_files_in_order () {
    BASE_DIR="$1"
    echo "Importing SQL files from ${BASE_DIR} (top-down order, skipping 'tools')..."

    # 1. Import SQL files directly inside the base directory
    find "${BASE_DIR}" -maxdepth 1 -type f -name "*.sql" | sort | while read -r SQL_FILE; do
        echo "Importing $SQL_FILE"
        mysql -u"${MYSQL_USER}" -p"${MYSQL_PWD}" -h "${MYSQL_HOST}" -D"${MYSQL_DB}" < "$SQL_FILE"
    done

    # 2. Recursively import from subdirectories, sorted, but skip the 'tools' directory
    #find "${BASE_DIR}" -mindepth 2 -type f -name "*.sql" \
    #    ! -path "${BASE_DIR}/tools/*" | sort | while read -r SQL_FILE; do
    #    echo "Importing $SQL_FILE"
    #    mysql -u"${MYSQL_USER}" -p"${MYSQL_PWD}" -h "${MYSQL_HOST}" -D"${MYSQL_DB}" < "$SQL_FILE"
    #done
}

setup_mysql_config () {
    echo "###### MySQL setup ######"
    if [ -z "${MYSQL_HOST}" ]; then echo "Missing MYSQL_HOST environment variable. Unable to continue."; exit 1; fi
    if [ -z "${MYSQL_DB}" ]; then echo "Missing MYSQL_DB environment variable. Unable to continue."; exit 1; fi
    if [ -z "${MYSQL_USER}" ]; then echo "Missing MYSQL_USER environment variable. Unable to continue."; exit 1; fi
    if [ -z "${MYSQL_PWD}" ]; then echo "Missing MYSQL_PWD environment variable. Unable to continue."; exit 1; fi

    echo "Setting up MySQL on Login Server..."

    echo -e "use_sql_db: yes\n\n" >> /rAthena/conf/import/inter_conf.txt
    echo -e "login_server_ip: ${MYSQL_HOST}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "login_server_db: ${MYSQL_DB}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "login_server_id: ${MYSQL_USER}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "login_server_pw: ${MYSQL_PWD}\n" >> /rAthena/conf/import/inter_conf.txt


    echo -e "use_sql_db: yes\n\n" >> /rAthena/conf/import/inter_conf.txt
    echo -e "login_server_ip: ${MYSQL_HOST}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "login_server_db: ${MYSQL_DB}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "login_server_id: ${MYSQL_USER}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "login_server_pw: ${MYSQL_PWD}\n" >> /rAthena/conf/import/inter_conf.txt

    echo "Setting up MySQL on Map Server..."
    echo -e "map_server_ip: ${MYSQL_HOST}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "map_server_db: ${MYSQL_DB}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "map_server_id: ${MYSQL_USER}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "map_server_pw: ${MYSQL_PWD}\n" >> /rAthena/conf/import/inter_conf.txt

    echo "Setting up MySQL on Char Server..."
    echo -e "char_server_ip: ${MYSQL_HOST}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "char_server_db: ${MYSQL_DB}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "char_server_id: ${MYSQL_USER}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "char_server_pw: ${MYSQL_PWD}\n" >> /rAthena/conf/import/inter_conf.txt

    echo "Setting up MySQL on IP ban..."
    echo -e "ipban_db_ip: ${MYSQL_HOST}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "ipban_db_db: ${MYSQL_DB}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "ipban_db_id: ${MYSQL_USER}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "ipban_db_pw: ${MYSQL_PWD}\n" >> /rAthena/conf/import/inter_conf.txt

    echo "Setting up MySQL on log..."
    echo -e "log_db_ip: ${MYSQL_HOST}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "log_db_db: ${MYSQL_DB}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "log_db_id: ${MYSQL_USER}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "log_db_pw: ${MYSQL_PWD}\n" >> /rAthena/conf/import/inter_conf.txt

    echo "Setting up MySQL on log..."
    echo -e "web_server_ip: ${MYSQL_HOST}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "web_server_db: ${MYSQL_DB}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "web_server_id: ${MYSQL_USER}" >> /rAthena/conf/import/inter_conf.txt
    echo -e "web_server_pw: ${MYSQL_PWD}\n" >> /rAthena/conf/import/inter_conf.txt

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

        # Import each section in order
        import_sql_files_in_order "/rAthena/sql-files"


        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} -e "UPDATE login SET userid = \"${SET_INTERSRV_USERID}\", user_pass = \"${SET_INTERSRV_PASSWD}\", group_id = 99 WHERE account_id = 1;"
        
        if ! [ -z "${MYSQL_ACCOUNTSANDCHARS}" ]; then
            mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /accountsandchars.sql
        fi
    fi
}

setup_config () {
    if ! [ -z "${SET_INTERSRV_USERID}" ]; then 
        echo -e "userid: ${SET_INTERSRV_USERID}" >> /rAthena/conf/import/map_conf.txt
        echo -e "userid: ${SET_INTERSRV_USERID}" >> /rAthena/conf/import/char_conf.txt
    fi
    if ! [ -z "${SET_INTERSRV_PASSWD}" ]; then 
        echo -e "passwd: ${SET_INTERSRV_PASSWD}" >> /rAthena/conf/import/map_conf.txt
        echo -e "passwd: ${SET_INTERSRV_PASSWD}" >> /rAthena/conf/import/char_conf.txt
    fi

    if ! [ -z "${BIND_IP}" ]; then echo -e "bind_ip: ${BIND_IP}" >> /rAthena/conf/web_athena.conf; fi
    
    
    if ! [ -z "${SET_CHAR_TO_LOGIN_IP}" ]; then echo -e "login_ip: ${SET_CHAR_TO_LOGIN_IP}" >> /rAthena/conf/import/char_conf.txt; fi
    if ! [ -z "${SET_CHAR_PUBLIC_IP}" ]; then echo -e "char_ip: ${SET_CHAR_PUBLIC_IP}" >> /rAthena/conf/import/char_conf.txt; fi
    if ! [ -z "${BIND_IP}" ]; then echo -e "bind_ip: ${BIND_IP}" >> /rAthena/conf/import/char_conf.txt; fi
    
    if ! [ -z "${SET_MAP_TO_CHAR_IP}" ]; then echo -e "char_ip: ${SET_MAP_TO_CHAR_IP}" >> /rAthena/conf/import/map_conf.txt; fi
    if ! [ -z "${SET_MAP_PUBLIC_IP}" ]; then echo -e "map_ip: ${SET_MAP_PUBLIC_IP}" >> /rAthena/conf/import/map_conf.txt; fi
    if ! [ -z "${BIND_IP}" ]; then echo -e "bind_ip: ${BIND_IP}" >> /rAthena/conf/import/map_conf.txt; fi


    if ! [ -z "${ADD_SUBNET_MAP1}" ]; then echo -e "subnet: ${ADD_SUBNET_MAP1}" >> /rAthena/conf/subnet_athena.conf; fi
    if ! [ -z "${ADD_SUBNET_MAP2}" ]; then echo -e "subnet: ${ADD_SUBNET_MAP2}" >> /rAthena/conf/subnet_athena.conf; fi
    if ! [ -z "${ADD_SUBNET_MAP3}" ]; then echo -e "subnet: ${ADD_SUBNET_MAP3}" >> /rAthena/conf/subnet_athena.conf; fi
    if ! [ -z "${ADD_SUBNET_MAP4}" ]; then echo -e "subnet: ${ADD_SUBNET_MAP4}" >> /rAthena/conf/subnet_athena.conf; fi
    if ! [ -z "${ADD_SUBNET_MAP5}" ]; then echo -e "subnet: ${ADD_SUBNET_MAP5}" >> /rAthena/conf/subnet_athena.conf; fi

    if ! [ -z "${SET_SERVER_NAME}" ]; then echo -e "server_name: ${SET_SERVER_NAME}" >> /rAthena/conf/import/char_conf.txt; fi
    if ! [ -z "${SET_MAX_CONNECT_USER}" ]; then echo -e "max_connect_user: ${SET_MAX_CONNECT_USER}" >> /rAthena/conf/import/char_conf.txt; fi
    if ! [ -z "${SET_START_ZENNY}" ]; then echo -e "start_zenny: ${SET_START_ZENNY}" >> /rAthena/conf/import/char_conf.txt; fi
    if ! [ -z "${SET_START_POINT}" ]; then echo -e "start_point: ${SET_START_POINT}" >> /rAthena/conf/import/char_conf.txt; fi
    if ! [ -z "${SET_START_POINT_PRE}" ]; then echo -e "start_point_pre: ${SET_START_POINT_PRE}" >> /rAthena/conf/import/char_conf.txt; fi
    if ! [ -z "${SET_START_POINT_DORAM}" ]; then echo -e "start_point_doram: ${SET_START_POINT_DORAM}" >> /rAthena/conf/import/char_conf.txt; fi
    if ! [ -z "${SET_START_ITEMS}" ]; then echo -e "start_items: ${SET_START_ITEMS}" >> /rAthena/conf/import/char_conf.txt; fi
    if ! [ -z "${SET_START_ITEMS_DORAM}" ]; then echo -e "start_items_doram: ${SET_START_ITEMS_DORAM}" >> /rAthena/conf/import/char_conf.txt; fi
    if ! [ -z "${SET_PINCODE_ENABLED}" ]; then echo -e "pincode_enabled: ${SET_PINCODE_ENABLED}" >> /rAthena/conf/import/char_conf.txt; fi

    if ! [ -z "${SET_ALLOWED_REGS}" ]; then echo -e "allowed_regs: ${SET_ALLOWED_REGS}" >> /rAthena/conf/import/login_conf.txt; fi
    if ! [ -z "${SET_TIME_ALLOWED}" ]; then echo -e "time_allowed: ${SET_TIME_ALLOWED}" >> /rAthena/conf/import/login_conf.txt; fi

    if ! [ -z "${SET_ARROW_DECREMENT}" ]; then echo -e "arrow_decrement: ${SET_ARROW_DECREMENT}" >> /rAthena/conf/import/battle_conf.txt; fi
}

enable_custom_npc () {
    echo -e "npc: npc/custom/gab_npc.txt" >> /rAthena/npc/scripts_custom.conf
}

#PUBLICIP=$(dig +short myip.opendns.com @resolver1.opendns.com)

cd /rAthena

setup_init

exec "$@"