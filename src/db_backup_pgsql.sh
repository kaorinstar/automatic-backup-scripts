#!/bin/sh
# Automatic Backup Scripts.
#
# Change to permission 705 on this file.
# The .pgpass file must be set in user home directory with change to permission 600.
# cron 30 2 * * * /bin/sh -f /path/to/db_backup_pgsql.sh >/dev/null 2>&1
#
# Copyright 2014, Kaoru Ishikura
# Released under the MIT license.
# http://opensource.org/licenses/mit-license.php

# Project environment variables.
##################################################
# Specifies the path to the backup directory.
BACKUP_DIR="${HOME}/path/to/backups/db"
# Specifies the retention period for backups.
RETENTION_PERIOD=21
##################################################

# PostgreSQL environment variables.
##################################################
# Specifies the path to the PostgreSQL binary directory.
PGSQL_BIN_DIR=/usr/local/pgsql/bin
# Specifies the name of the database.
PGSQL_DATABASE_NAME=dbname
# User name to connect as.
PGSQL_USER_NAME=username
# Specifies the host name of the machine.
PGSQL_HOST_NAME=localhost
# Specifies the TCP port.
PGSQL_PORT_NUMBER=5432
##################################################

PATH="${PATH}:${PGSQL_BIN_DIR}"

ERROR_CODE=0
START_TIME=`date +'%s'`
TODAYS_DATE=`date +'%y%m%d'`
LOG_FILE=`echo ${BACKUP_DIR}/pgsql-${PGSQL_DATABASE_NAME}-${TODAYS_DATE}.log | sed -e 's/\/\//\//g'`

if [ ! -e "${BACKUP_DIR}" ]; then
    mkdir -p -m 701 "${BACKUP_DIR}"
fi

#
# Output the first message to the log file.
echo "["`date +'%d-%b-%y %H:%M:%S'`"] Starting buckup." >"${LOG_FILE}"

#
# Delete old backup files.
find "${BACKUP_DIR}" -type f \
\( -name "pgsql-${PGSQL_DATABASE_NAME}-*.sql.gz" -o -name "pgsql-${PGSQL_DATABASE_NAME}-*.log" \) \
-mtime +${RETENTION_PERIOD} -exec rm -rf {} \;

if [ $? -eq 0 ]; then
    MESSAGE="Old backup files has been deleted successfully."
else
    MESSAGE="Failed to delete old backup files."
    ERROR_CODE=1
fi
CUR_TIME=`date +'%s'`
echo "["`date +'%d-%b-%y %H:%M:%S'`"] ${MESSAGE} (Elapsed Time: "$((${CUR_TIME} - ${START_TIME}))" sec.)" >>"${LOG_FILE}"

#
# Cleaning and analysis the database.
vacuumdb --analyze \
--host=${PGSQL_HOST_NAME} --port=${PGSQL_PORT_NUMBER} \
--username=${PGSQL_USER_NAME} --dbname=${PGSQL_DATABASE_NAME}

if [ $? -eq 0 ]; then
    MESSAGE="Cleaning and analysis has been completed successfully."
else
    MESSAGE="Failed to cleaning and/or analysis."
    ERROR_CODE=1
fi
CUR_TIME=`date +'%s'`
echo "["`date +'%d-%b-%y %H:%M:%S'`"] ${MESSAGE} (Elapsed Time: "$((${CUR_TIME} - ${START_TIME}))" sec.)" >>"${LOG_FILE}"

#
# Rebuild all indexes in the database. To use PostgreSQL 8.1.2 or later is required.
if type reindexdb >/dev/null 2>&1; then
    reindexdb \
    --host=${PGSQL_HOST_NAME} --port=${PGSQL_PORT_NUMBER} \
    --username=${PGSQL_USER_NAME} --dbname=${PGSQL_DATABASE_NAME}

    if [ $? -eq 0 ]; then
        MESSAGE="Rebuild all indexes has been completed successfully."
    else
        MESSAGE="Failed to rebuild indexes."
        ERROR_CODE=1
    fi
    CUR_TIME=`date +'%s'`
    echo "["`date +'%d-%b-%y %H:%M:%S'`"] ${MESSAGE} (Elapsed Time: "$((${CUR_TIME} - ${START_TIME}))" sec.)" >>"${LOG_FILE}"
fi

#
# The database backup into the sql file.
BACKUP_FILE=`echo ${BACKUP_DIR}/pgsql-${PGSQL_DATABASE_NAME}-${TODAYS_DATE}.sql | sed -e 's/\/\//\//g'`
if [ -e "${BACKUP_FILE}.gz" ]; then
    rm -f "${BACKUP_FILE}.gz"
fi

pg_dump --column-inserts \
--host=${PGSQL_HOST_NAME} --port=${PGSQL_PORT_NUMBER} \
--username=${PGSQL_USER_NAME} ${PGSQL_DATABASE_NAME} >"${BACKUP_FILE}"

if [ $? -eq 0 ]; then
    MESSAGE="The backup has been completed successfully."
else
    MESSAGE="Failed to the backup."
    ERROR_CODE=1
fi
CUR_TIME=`date +'%s'`
echo "["`date +'%d-%b-%y %H:%M:%S'`"] ${MESSAGE} (Elapsed Time: "$((${CUR_TIME} - ${START_TIME}))" sec.)" >>"${LOG_FILE}"

#
# Compress the sql file, And change the permissions on the compressed file.
gzip "${BACKUP_FILE}" >/dev/null 2>&1

if [ $? -eq 0 -a -e "${BACKUP_FILE}.gz" ]; then
    chmod -f 600 "${BACKUP_FILE}.gz"
    MESSAGE="The sql file has been compressed successfully."
else
    MESSAGE="Failed to compress the sql file into the gzip file."
    ERROR_CODE=1
fi
CUR_TIME=`date +'%s'`
echo "["`date +'%d-%b-%y %H:%M:%S'`"] ${MESSAGE} (Elapsed Time: "$((${CUR_TIME} - ${START_TIME}))" sec.)" >>"${LOG_FILE}"


exit ${ERROR_CODE}
