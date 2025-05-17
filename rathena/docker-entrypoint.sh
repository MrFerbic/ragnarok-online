#!/bin/sh

# ------------------------------------------------------
# Build Phase
# ------------------------------------------------------
cd /rAthena

PACKETVER=20151029
PACKET_OBFUSCATION=1

if [ ${PACKET_OBFUSCATION} -neq 1 ]; then sed -i "s|#define PACKET_OBFUSCATION|//#define PACKET_OBFUSCATION|g" /rAthena/src/config/packets.hpp; fi
if [ ${PACKET_OBFUSCATION} -neq 1 ]; then sed -i "s|#define PACKET_OBFUSCATION_WARN|//#define PACKET_OBFUSCATION_WARN|g" /rAthena/src/config/packets.hpp; fi

./configure --enable-packetver=${PACKETVER}
make clean
make server
chmod a+x login-server char-server map-server web-server
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
    RESULT=`mysqlshow --user=${MYSQL_USER} --password=${MYSQL_PWD} --host=${MYSQL_HOST} ${MYSQL_DB} | grep -v Wildcard | grep -o ${MYSQL_DB}`
    if [ "$RESULT" == "${MYSQL_DB}" ]; then
        return 0;
    else
        return 1;
    fi
}

setup_init () {
    if ! [ -z "${SET_MOTD}" ]; then echo -e "${SET_MOTD}" > /rAthena/conf/motd.txt; fi
    setup_mysql_config
    setup_config
    enable_custom_npc
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

    echo "DROP FOUND, REMOVING EXISTING DATABASE..."
    if ! [ -z ${MYSQL_DROP_DB} ]; then
        if [ ${MYSQL_DROP_DB} -ne 0 ]; then
            mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -e "DROP DATABASE ${MYSQL_DB};"
        fi
    fi
    echo "Checking if database already exists..."
    if ! check_database_exist; then
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -e "CREATE DATABASE ${MYSQL_DB};"
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /rAthena/sql-files/main.sql
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /rAthena/sql-files/logs.sql
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /rAthena/sql-files/item_db.sql
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /rAthena/sql-files/item_db2.sql
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /rAthena/sql-files/item_db_re.sql
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /rAthena/sql-files/item_db2_re.sql
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /rAthena/sql-files/item_cash_db.sql
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /rAthena/sql-files/item_cash_db2.sql
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /rAthena/sql-files/mob_db.sql
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /rAthena/sql-files/mob_db2.sql
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /rAthena/sql-files/mob_db_re.sql
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /rAthena/sql-files/mob_db2_re.sql
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /rAthena/sql-files/mob_skill_db.sql
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /rAthena/sql-files/mob_skill_db2.sql
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /rAthena/sql-files/mob_skill_db_re.sql
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /rAthena/sql-files/mob_skill_db2_re.sql
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /rAthena/sql-files/roulette_default_data.sql
        mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} -e "UPDATE login SET userid = \"${SET_INTERSRV_USERID}\", user_pass = \"${SET_INTERSRV_PASSWD}\" WHERE account_id = 1;"
        if ! [ -z "${MYSQL_ACCOUNTSANDCHARS}" ]; then
            mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D${MYSQL_DB} < /root/accountsandchars.sql
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
    
    if ! [ -z "${SET_CHAR_TO_LOGIN_IP}" ]; then echo -e "login_ip: ${SET_CHAR_TO_LOGIN_IP}" >> /rAthena/conf/import/char_conf.txt; fi
    if ! [ -z "${SET_CHAR_PUBLIC_IP}" ]; then echo -e "char_ip: ${SET_CHAR_PUBLIC_IP}" >> /rAthena/conf/import/char_conf.txt; fi
    if ! [ -z "${SET_MAP_TO_CHAR_IP}" ]; then echo -e "char_ip: ${SET_MAP_TO_CHAR_IP}" >> /rAthena/conf/import/map_conf.txt; fi
    if ! [ -z "${SET_MAP_PUBLIC_IP}" ]; then echo -e "map_ip: ${SET_MAP_PUBLIC_IP}" >> /rAthena/conf/import/map_conf.txt; fi
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

cd /opt/rAthena
if ! [ -z ${DOWNLOAD_OVERRIDE_CONF_URL} ]; then 
    wget -q ${DOWNLOAD_OVERRIDE_CONF_URL} -O /tmp/rathena_import_conf.zip
    if [ $? -eq 0 ]; then
        unzip /tmp/rathena_import_conf.zip -d /rAthena/conf/import/
        if ! [ $? -eq 0 ]; then
            setup_init
        fi
    else
        setup_init
    fi
else
    setup_init
fi

exec "$@"