#!/bin/bash

set +e

# Script trace mode
if [ "${DEBUG_MODE}" == "true" ]; then
    set -o xtrace
fi

# Type of Zabbix component
# Possible values: [server, proxy, agent, web, dev]

# !! zbx_type="$1"
zbx_type="server"

# Type of Zabbix database
# Possible values: [mysql, postgresql]
# !! zbx_db_type="$2"
zbx_db_type="postgresql"

# Type of web-server. Valid only with zbx_type = web
# Possible values: [apache, nginx]
# !! zbx_opt_type="$3"
zbx_opt_type="nginx"

# Default Zabbix installation name
# Used only by Zabbix web-interface
ZBX_SERVER_NAME=${ZBX_SERVER_NAME:-"Zabbix docker"}
# Default Zabbix server host
ZBX_SERVER_HOST=${ZBX_SERVER_HOST:-"zabbix-server"}
# Default Zabbix server port number
ZBX_SERVER_PORT=${ZBX_SERVER_PORT:-"10051"}

# Default timezone for web interface
TZ=${TZ:-"Europe/Riga"}

# Default directories
# User 'zabbix' home directory
ZABBIX_USER_HOME_DIR="/var/lib/zabbix"
# Configuration files directory
ZABBIX_ETC_DIR="/etc/zabbix"
# Web interface www-root directory
ZBX_FRONTEND_PATH="/usr/share/zabbix"

prepare_system() {
    local type=$1
    local web_server=$2

    # !!
    echo "** Preparing the system '$type'"

    if [ "$type" != "dev" ]; then
        return
    fi
}

update_config_var() {
    local config_path=$1
    local var_name=$2
    local var_value=$3
    local is_multiple=$4

    if [ ! -f "$config_path" ]; then
        echo "**** Configuration file '$config_path' does not exist"
        return
    fi

    echo -n "** Updating '$config_path' parameter \"$var_name\": '$var_value'... "

    # Remove configuration parameter definition in case of unset parameter value
    if [ -z "$var_value" ]; then
        sed -i -e "/$var_name=/d" "$config_path"
        echo "removed"
        return
    fi

    # Remove value from configuration parameter in case of double quoted parameter value
    if [ "$var_value" == '""' ]; then
        sed -i -e "/^$var_name=/s/=.*/=/" "$config_path"
        echo "undefined"
        return
    fi

    # Use full path to a file for TLS related configuration parameters
    if [[ $var_name =~ ^TLS.*File$ ]]; then
        var_value=$ZABBIX_USER_HOME_DIR/enc/$var_value
    fi

    # Escaping "/" character in parameter value
    var_value=${var_value//\//\\/}

    if [ "$(grep -E "^$var_name=" $config_path)" ] && [ "$is_multiple" != "true" ]; then
        sed -i -e "/^$var_name=/s/=.*/=$var_value/" "$config_path"
        echo "updated"
    elif [ "$(grep -Ec "^# $var_name=" $config_path)" -gt 1 ]; then
        sed -i -e  "/^[#;] $var_name=$/i\\$var_name=$var_value" "$config_path"
        echo "added first occurrence"
    else
        sed -i -e "/^[#;] $var_name=/s/.*/&\n$var_name=$var_value/" "$config_path"
        echo "added"
    fi

}

update_config_multiple_var() {
    local config_path=$1
    local var_name=$2
    local var_value=$3

    var_value="${var_value%\"}"
    var_value="${var_value#\"}"

    local IFS=,
    local OPT_LIST=($var_value)

    for value in "${OPT_LIST[@]}"; do
        update_config_var $config_path $var_name $value true
    done
}

# Check prerequisites for MySQL database
# !! check_variables_mysql() {}

# Check prerequisites for PostgreSQL database
check_variables_postgresql() {
    local type=$1

    DB_SERVER_HOST=${DB_SERVER_HOST:-"postgres-server"}
    DB_SERVER_PORT=${DB_SERVER_PORT:-"5432"}
    CREATE_ZBX_DB_USER=${CREATE_ZBX_DB_USER:-"false"}
    # !!
    USE_DB_ROOT_USER=false

    DB_SERVER_ROOT_USER=${POSTGRES_USER:-"postgres"}
    DB_SERVER_ROOT_PASS=${POSTGRES_PASSWORD:-""}

    DB_SERVER_ZBX_USER=${POSTGRES_USER:-"zabbix"}
    DB_SERVER_ZBX_PASS=${POSTGRES_PASSWORD:-"zabbix"}

    # !! ->
    # if [ "$type" == "proxy" ]; then
    #     DB_SERVER_DBNAME=${POSTGRES_DB:-"zabbix_proxy"}
    # else
    #    DB_SERVER_DBNAME=${POSTGRES_DB:-"zabbix"}
    # fi
    # !! <-
    DB_SERVER_DBNAME=${POSTGRES_DB:-"zabbix"}
}

# !! check_db_connect_mysql() {}

check_db_connect_postgresql() {
    echo "********************"
    echo "* DB_SERVER_HOST: ${DB_SERVER_HOST}"
    echo "* DB_SERVER_PORT: ${DB_SERVER_PORT}"
    echo "* DB_SERVER_DBNAME: ${DB_SERVER_DBNAME}"
    echo "* DB_SERVER_ZBX_USER: ${DB_SERVER_ZBX_USER}"

    # !!
    if [ ! -n "${DB_SERVER_ZBX_PASS}" ]; then
        echo "* DB_SERVER_ZBX_PASS: undefined!"
    else
        echo "* DB_SERVER_ZBX_PASS: ******"
    fi

    echo "********************"

    if [ -n "${DB_SERVER_ZBX_PASS}" ]; then
        export PGPASSWORD="${DB_SERVER_ZBX_PASS}"
    fi

    # !! WAIT_TIMEOUT=5
    WAIT_TIMEOUT=60

    # while [ ! "$(psql -h ${DB_SERVER_HOST} -p ${DB_SERVER_PORT} -U ${DB_SERVER_ROOT_USER} -l -q 2>/dev/null)" ]; do
    while [ ! "$(psql -h ${DB_SERVER_HOST} -p ${DB_SERVER_PORT} -U ${DB_SERVER_ZBX_USER} --version 2>/dev/null)" ]; do
        echo "**** PostgreSQL server is not available. Waiting $WAIT_TIMEOUT seconds..."
        sleep $WAIT_TIMEOUT
    done

    unset PGPASSWORD
}

# !! mysql_query() {}

# !! psql_query() {}

# !! create_db_user_mysql() {}

# !! create_db_user_postgresql() {}

# !! create_db_database_mysql() {}

# !! create_db_database_postgresql() {}

# !! create_db_schema_mysql() {}

# !! create_db_schema_postgresql() {}
#
# /usr/share/doc/zabbix-server-postgresql/schema.sql
# /usr/share/doc/zabbix-server-postgresql/images.sql
# /usr/share/doc/zabbix-server-postgresql/data.sql


# !! prepare_web_server_apache() {}

# !! prepare_web_server_nginx() {}


clear_deploy() {
    local type=$1
    echo "** Cleaning the system"

    [ "$type" != "dev" ] && return
}

update_zbx_config() {
    local type=$1
    local db_type=$2

    echo "** Preparing Zabbix $type configuration file"

    ZBX_CONFIG=$ZABBIX_ETC_DIR/zabbix_$type.conf

    if [ "$type" == "proxy" ]; then
        update_config_var $ZBX_CONFIG "ProxyMode" "${ZBX_PROXYMODE}"
        update_config_var $ZBX_CONFIG "Server" "${ZBX_SERVER_HOST}"
        update_config_var $ZBX_CONFIG "ServerPort" "${ZBX_SERVER_PORT}"
        update_config_var $ZBX_CONFIG "Hostname" "${ZBX_HOSTNAME:-"zabbix-proxy-"$db_type}"
        update_config_var $ZBX_CONFIG "HostnameItem" "${ZBX_HOSTNAMEITEM}"
    fi

    if [ $type == "proxy" ] && [ "${ZBX_ADD_SERVER}" = "true" ]; then
        update_config_var $ZBX_CONFIG "ListenPort" "10061"
    else
        update_config_var $ZBX_CONFIG "ListenPort"
    fi
    update_config_var $ZBX_CONFIG "SourceIP"
    update_config_var $ZBX_CONFIG "LogType" "console"
    update_config_var $ZBX_CONFIG "LogFile"
    update_config_var $ZBX_CONFIG "LogFileSize"
    update_config_var $ZBX_CONFIG "PidFile"

    update_config_var $ZBX_CONFIG "DebugLevel" "${ZBX_DEBUGLEVEL}"

    if [ "$db_type" == "sqlite3" ]; then
        update_config_var $ZBX_CONFIG "DBHost"
        update_config_var $ZBX_CONFIG "DBName" "/var/lib/zabbix/zabbix_proxy_db"
        update_config_var $ZBX_CONFIG "DBUser"
        update_config_var $ZBX_CONFIG "DBPort"
        update_config_var $ZBX_CONFIG "DBPassword"
    else
        update_config_var $ZBX_CONFIG "DBHost" "${DB_SERVER_HOST}"
        update_config_var $ZBX_CONFIG "DBName" "${DB_SERVER_DBNAME}"
        update_config_var $ZBX_CONFIG "DBUser" "${DB_SERVER_ZBX_USER}"
        update_config_var $ZBX_CONFIG "DBPort" "${DB_SERVER_PORT}"
        update_config_var $ZBX_CONFIG "DBPassword" "${DB_SERVER_ZBX_PASS}"
    fi

    if [ "$type" == "proxy" ]; then
        update_config_var $ZBX_CONFIG "ProxyLocalBuffer" "${ZBX_PROXYLOCALBUFFER}"
        update_config_var $ZBX_CONFIG "ProxyOfflineBuffer" "${ZBX_PROXYOFFLINEBUFFER}"
        update_config_var $ZBX_CONFIG "HeartbeatFrequency" "${ZBX_PROXYHEARTBEATFREQUENCY}"
        update_config_var $ZBX_CONFIG "ConfigFrequency" "${ZBX_CONFIGFREQUENCY}"
        update_config_var $ZBX_CONFIG "DataSenderFrequency" "${ZBX_DATASENDERFREQUENCY}"
    fi

    update_config_var $ZBX_CONFIG "StartPollers" "${ZBX_STARTPOLLERS}"
    update_config_var $ZBX_CONFIG "StartIPMIPollers" "${ZBX_IPMIPOLLERS}"
    update_config_var $ZBX_CONFIG "StartPollersUnreachable" "${ZBX_STARTPOLLERSUNREACHABLE}"
    update_config_var $ZBX_CONFIG "StartTrappers" "${ZBX_STARTTRAPPERS}"
    update_config_var $ZBX_CONFIG "StartPingers" "${ZBX_STARTPINGERS}"
    update_config_var $ZBX_CONFIG "StartDiscoverers" "${ZBX_STARTDISCOVERERS}"
    update_config_var $ZBX_CONFIG "StartHTTPPollers" "${ZBX_STARTHTTPPOLLERS}"

    if [ "$type" == "server" ]; then
        update_config_var $ZBX_CONFIG "StartTimers" "${ZBX_STARTTIMERS}"
        update_config_var $ZBX_CONFIG "StartEscalators" "${ZBX_STARTESCALATORS}"
    fi

    ZBX_JAVAGATEWAY_ENABLE=${ZBX_JAVAGATEWAY_ENABLE:-"false"}
    if [ "${ZBX_JAVAGATEWAY_ENABLE}" == "true" ]; then
        update_config_var $ZBX_CONFIG "JavaGateway" "${ZBX_JAVAGATEWAY:-"zabbix-java-gateway"}"
        update_config_var $ZBX_CONFIG "JavaGatewayPort" "${ZBX_JAVAGATEWAYPORT}"
        update_config_var $ZBX_CONFIG "StartJavaPollers" "${ZBX_STARTJAVAPOLLERS:-"5"}"
    else
        update_config_var $ZBX_CONFIG "JavaGateway"
        update_config_var $ZBX_CONFIG "JavaGatewayPort"
        update_config_var $ZBX_CONFIG "StartJavaPollers"
    fi

    update_config_var $ZBX_CONFIG "StartVMwareCollectors" "${ZBX_STARTVMWARECOLLECTORS}"
    update_config_var $ZBX_CONFIG "VMwareFrequency" "${ZBX_VMWAREFREQUENCY}"
    update_config_var $ZBX_CONFIG "VMwarePerfFrequency" "${ZBX_VMWAREPERFFREQUENCY}"
    update_config_var $ZBX_CONFIG "VMwareCacheSize" "${ZBX_VMWARECACHESIZE}"
    update_config_var $ZBX_CONFIG "VMwareTimeout" "${ZBX_VMWARETIMEOUT}"

    ZBX_ENABLE_SNMP_TRAPS=${ZBX_ENABLE_SNMP_TRAPS:-"false"}
    if [ "${ZBX_ENABLE_SNMP_TRAPS}" == "true" ]; then
        update_config_var $ZBX_CONFIG "SNMPTrapperFile" "${ZABBIX_USER_HOME_DIR}/snmptraps/snmptraps.log"
        update_config_var $ZBX_CONFIG "StartSNMPTrapper" "1"
    else
        update_config_var $ZBX_CONFIG "SNMPTrapperFile"
        update_config_var $ZBX_CONFIG "StartSNMPTrapper"
    fi

    update_config_var $ZBX_CONFIG "HousekeepingFrequency" "${ZBX_HOUSEKEEPINGFREQUENCY}"
    if [ "$type" == "server" ]; then
        update_config_var $ZBX_CONFIG "MaxHousekeeperDelete" "${ZBX_MAXHOUSEKEEPERDELETE}"
        update_config_var $ZBX_CONFIG "SenderFrequency" "${ZBX_SENDERFREQUENCY}"
    fi

    update_config_var $ZBX_CONFIG "CacheSize" "${ZBX_CACHESIZE}"

    if [ "$type" == "server" ]; then
        update_config_var $ZBX_CONFIG "CacheUpdateFrequency" "${ZBX_CACHEUPDATEFREQUENCY}"
    fi

    update_config_var $ZBX_CONFIG "StartDBSyncers" "${ZBX_STARTDBSYNCERS}"
    update_config_var $ZBX_CONFIG "HistoryCacheSize" "${ZBX_HISTORYCACHESIZE}"
    update_config_var $ZBX_CONFIG "HistoryIndexCacheSize" "${ZBX_HISTORYINDEXCACHESIZE}"

    if [ "$type" == "server" ]; then
        update_config_var $ZBX_CONFIG "TrendCacheSize" "${ZBX_TRENDCACHESIZE}"
        update_config_var $ZBX_CONFIG "ValueCacheSize" "${ZBX_VALUECACHESIZE}"
    fi

    update_config_var $ZBX_CONFIG "Timeout" "${ZBX_TIMEOUT}"
    update_config_var $ZBX_CONFIG "TrapperTimeout" "${ZBX_TRAPPERIMEOUT}"
    update_config_var $ZBX_CONFIG "UnreachablePeriod" "${ZBX_UNREACHABLEPERIOD}"
    update_config_var $ZBX_CONFIG "UnavailableDelay" "${ZBX_UNAVAILABLEDELAY}"
    update_config_var $ZBX_CONFIG "UnreachableDelay" "${ZBX_UNREACHABLEDELAY}"

    update_config_var $ZBX_CONFIG "AlertScriptsPath" "/usr/lib/zabbix/alertscripts"
    update_config_var $ZBX_CONFIG "ExternalScripts" "/usr/lib/zabbix/externalscripts"

    # Possible few fping locations
    if [ -f "/usr/bin/fping" ]; then
        update_config_var $ZBX_CONFIG "FpingLocation" "/usr/bin/fping"
    else
        update_config_var $ZBX_CONFIG "FpingLocation" "/usr/sbin/fping"
    fi
    if [ -f "/usr/bin/fping6" ]; then
        update_config_var $ZBX_CONFIG "Fping6Location" "/usr/bin/fping6"
    else
        update_config_var $ZBX_CONFIG "Fping6Location" "/usr/sbin/fping6"
    fi

    update_config_var $ZBX_CONFIG "SSHKeyLocation" "$ZABBIX_USER_HOME_DIR/ssh_keys"
    update_config_var $ZBX_CONFIG "LogSlowQueries" "${ZBX_LOGSLOWQUERIES}"

    if [ "$type" == "server" ]; then
        update_config_var $ZBX_CONFIG "StartProxyPollers" "${ZBX_STARTPROXYPOLLERS}"
        update_config_var $ZBX_CONFIG "ProxyConfigFrequency" "${ZBX_PROXYCONFIGFREQUENCY}"
        update_config_var $ZBX_CONFIG "ProxyDataFrequency" "${ZBX_PROXYDATAFREQUENCY}"
    fi

    update_config_var $ZBX_CONFIG "SSLCertLocation" "$ZABBIX_USER_HOME_DIR/ssl/certs/"
    update_config_var $ZBX_CONFIG "SSLKeyLocation" "$ZABBIX_USER_HOME_DIR/ssl/keys/"
    update_config_var $ZBX_CONFIG "SSLCALocation" "$ZABBIX_USER_HOME_DIR/ssl/ssl_ca/"
    update_config_var $ZBX_CONFIG "LoadModulePath" "$ZABBIX_USER_HOME_DIR/modules/"
    update_config_multiple_var $ZBX_CONFIG "LoadModule" "${ZBX_LOADMODULE}"

    if [ "$type" == "proxy" ]; then
        update_config_var $ZBX_CONFIG "TLSConnect" "${ZBX_TLSCONNECT}"
        update_config_var $ZBX_CONFIG "TLSAccept" "${ZBX_TLSACCEPT}"
    fi
    update_config_var $ZBX_CONFIG "TLSCAFile" "${ZBX_TLSCAFILE}"
    update_config_var $ZBX_CONFIG "TLSCRLFile" "${ZBX_TLSCRLFILE}"

    if [ "$type" == "proxy" ]; then
        update_config_var $ZBX_CONFIG "TLSServerCertIssuer" "${ZBX_TLSSERVERCERTISSUER}"
        update_config_var $ZBX_CONFIG "TLSServerCertSubject" "${ZBX_TLSSERVERCERTSUBJECT}"
    fi

    update_config_var $ZBX_CONFIG "TLSCertFile" "${ZBX_TLSCERTFILE}"
    update_config_var $ZBX_CONFIG "TLSKeyFile" "${ZBX_TLSKEYFILE}"

    if [ "$type" == "proxy" ]; then
        update_config_var $ZBX_CONFIG "TLSPSKIdentity" "${ZBX_TLSPSKIDENTITY}"
        update_config_var $ZBX_CONFIG "TLSPSKFile" "${ZBX_TLSPSKFILE}"
    fi
}


# !! prepare_zbx_web_config() {}

# !! prepare_zbx_agent_config() {}

# !! prepare_java_gateway_config() {}


prepare_server() {
    local db_type=$1

    # !!
    echo "** Preparing Zabbix server:"

    # !!check_variables_$db_type "server"
    check_variables_postgresql "server"

    # !! check_db_connect_$db_type
    check_db_connect_postgresql

    # !! create_db_user_$db_type

    # !! create_db_database_$db_type
    # !! create_db_schema_$db_type "server"

    # !! update_zbx_config "server" "$db_type"
    update_zbx_config "server" "postgresql"
}

# !! prepare_agent() {}

# !! prepare_proxy() {}

# !! prepare_web() {}

# !! prepare_java_gateway() {}


#################################################

if [ ! -n "$zbx_type" ]; then
    echo "**** Type of Zabbix component is not specified"
    exit 1
elif [ "$zbx_type" == "dev" ]; then
    echo "** Deploying Zabbix installation from SVN"
else
    if [ ! -n "$zbx_db_type" ]; then
        echo "**** Database type of Zabbix $zbx_type is not specified"
        exit 1
    fi

    if [ -n "$zbx_db_type" ]; then
        if [ -n "$zbx_opt_type" ]; then
            echo "** Deploying Zabbix $zbx_type ($zbx_opt_type) with $zbx_db_type database"
        else
            echo "** Deploying Zabbix $zbx_type with $zbx_db_type database"
        fi
    else
        echo "** Deploying Zabbix $zbx_type"
    fi
fi

prepare_system "$zbx_type" "$zbx_opt_type"

[ "$zbx_type" == "server" ] && prepare_server $zbx_db_type
#[ "${ZBX_ADD_SERVER}" == "true" ] && prepare_server ${ZBX_MAIN_DB}


# [ "$zbx_type" == "proxy" ] && prepare_proxy $zbx_db_type
# [ "${ZBX_ADD_PROXY}" == "true" ] && prepare_proxy ${ZBX_PROXY_DB}

# [ "$zbx_type" == "frontend" ] && prepare_web $zbx_opt_type $zbx_db_type
# [ "${ZBX_ADD_WEB}" == "true" ] && prepare_web ${ZBX_WEB_SERVER} ${ZBX_MAIN_DB}

# [ "$zbx_type" == "agentd" ] && prepare_agent
# [ "${ZBX_ADD_AGENT}" == "true" ] && prepare_agent

# [ "$zbx_type" == "java-gateway" ] && prepare_java_gateway
# [ "${ZBX_ADD_JAVA_GATEWAY}" == "true" ] && prepare_java_gateway

clear_deploy "$zbx_type"

echo "########################################################"

echo "** Executing supervisord"
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf

#################################################
