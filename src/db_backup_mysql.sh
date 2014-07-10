#!/bin/sh
# Automatic Backup Scripts.
#
# Change to permission 705 on this file.
# cron 30 2 * * * /bin/sh -f /path/to/db_backup_mysql.sh >/dev/null 2>&1
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
# Specifies the optimize day of the week for optimize tables.
OPTIMIZE_DAY_OF_THE_WEEK="Sun"
##################################################

# MySQL environment variables.
##################################################
# Specifies the path to the MySQL binary directory.
MYSQL_BIN_DIR=/usr/local/mysql/bin
# Specifies the name of the database.
MYSQL_DATABASE_NAME=dbname
# User name to connect as.
MYSQL_USER_NAME=username
# User password to connect as.
MYSQL_USER_PASSWORD=password
# Specifies the host name of the machine.
MYSQL_HOST_NAME=localhost
# Specifies the TCP port.
MYSQL_PORT_NUMBER=3306
##################################################

PATH="${PATH}:${MYSQL_BIN_DIR}"

ERROR_CODE=0
START_TIME=`date +'%s'`
TODAYS_DATE=`date +'%y%m%d'`
TODAYS_DAY_OF_THE_WEEK=`date +'%a'`
LOG_FILE=`echo ${BACKUP_DIR}/mysql-${MYSQL_DATABASE_NAME}-${TODAYS_DATE}.log | sed -e 's/\/\//\//g'`

if [ ! -e "${BACKUP_DIR}" ]; then
    mkdir -p -m 701 "${BACKUP_DIR}"
fi

#
# Output the first message to the log file.
echo "["`date +'%d-%b-%y %H:%M:%S'`"] Starting buckup." >"${LOG_FILE}"

#
# Delete old backup files.
find "${BACKUP_DIR}" -type f \
\( -name "mysql-${MYSQL_DATABASE_NAME}-*.sql.gz" -o -name "mysql-${MYSQL_DATABASE_NAME}-*.log" \) \
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
# Table maintenance: It checks, repairs, optimizes.
if [ "${OPTIMIZE_DAY_OF_THE_WEEK}" = "${TODAYS_DAY_OF_THE_WEEK}" ]; then
    mysqlcheck --check --auto-repair --optimize --compress \
    --host=${MYSQL_HOST_NAME} --port=${MYSQL_PORT_NUMBER} \
    --user=${MYSQL_USER_NAME} --password=${MYSQL_USER_PASSWORD} \
    --databases ${MYSQL_DATABASE_NAME}

    if [ $? -eq 0 ]; then
        MESSAGE="Table maintenance has been completed successfully."
    else
        MESSAGE="Failed to table maintenance."
        ERROR_CODE=1
    fi
    CUR_TIME=`date +'%s'`
    echo "["`date +'%d-%b-%y %H:%M:%S'`"] ${MESSAGE} (Elapsed Time: "$((${CUR_TIME} - ${START_TIME}))" sec.)" >>"${LOG_FILE}"
fi

#
# The database backup into the sql file.
BACKUP_FILE=`echo ${BACKUP_DIR}/mysql-${MYSQL_DATABASE_NAME}-${TODAYS_DATE}.sql | sed -e 's/\/\//\//g'`
if [ -e "${BACKUP_FILE}.gz" ]; then
    rm -f "${BACKUP_FILE}.gz"
fi

mysqldump --quote-names --compress \
--host=${MYSQL_HOST_NAME} --port=${MYSQL_PORT_NUMBER} \
--user=${MYSQL_USER_NAME} --password=${MYSQL_USER_PASSWORD} \
--databases ${MYSQL_DATABASE_NAME} >"${BACKUP_FILE}"

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
