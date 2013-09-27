#!/bin/sh
# Automatic Server Backup Scripts.
#
# Change to permission 705 on this file.
# cron 0 4 * * 1 /bin/sh -f /path/to/server_backup.sh >/dev/null 2>&1
#
# Copyright 2013, Kaoru Ishikura
# Released under the MIT license.
# http://opensource.org/licenses/mit-license.php

# Project environment variables.
##################################################
# Specifies the path to the backup directory.
BACKUP_DIR="${HOME}/backup/server"
# Specifies the retention period for backups.
RETENTION_PERIOD=21
# Specifies the maximum capacity.
MAX_CAPACITY=512m
# Specifies the relative paths of include from the home directory.
INCLUDE_PATHS=" \
  ./public_html \
  ./logs \
  "
# Specifies the relative paths of exclude from the home directory.
EXCLUDE_PATHS=" \
  ./public_html/test \
  "
##################################################

ERROR_CODE=1
START_TIME=`date +'%s'`
TODAYS_DATE=`date +'%y%m%d'`
TODAYS_DATE_DIR=`echo ${BACKUP_DIR}/${TODAYS_DATE} | sed -e 's/\/\//\//g'`
LOG_FILE="${TODAYS_DATE_DIR}/server-${USER}-${TODAYS_DATE}.log"

if [ ! -e "${BACKUP_DIR}" ]; then
    mkdir -p -m 701 "${BACKUP_DIR}"
fi

#
# Make the directory of today's date.
if [ -e "${TODAYS_DATE_DIR}" ]; then
    rm -rf ${TODAYS_DATE_DIR}
fi
mkdir -p "${TODAYS_DATE_DIR}"

#
# Output the first message to the log file.
echo "["`date +'%d-%b-%y %H:%M:%S'`"] Starting data buckup." >>"${LOG_FILE}"

#
# Delete old backup files.
find "${BACKUP_DIR}" -type d -mtime +${RETENTION_PERIOD} -exec rm -rf {} \;

if [ $? -eq 0 -a -n "${INCLUDE_PATHS}" ]; then
    #
    # Make the string of include options.
    INCLUDES=""
    TEMP=""
    for TEMP in ${INCLUDE_PATHS}; do
        INCLUDES="${INCLUDES} ${TEMP}"
    done

    #
    # Make the string of exclude options.
    EXCLUDES=""
    TEMP=""
    for TEMP in ${EXCLUDE_PATHS}; do
        EXCLUDES="${EXCLUDES} --exclude ${TEMP}"
    done

    #
    # Compress specified directories into the gzip file.
    tar -C ~ ${EXCLUDES} -cpzf - ${INCLUDES} | \
    split -b ${MAX_CAPACITY} - "${TODAYS_DATE_DIR}/server-${USER}-${TODAYS_DATE}.tar.gz.part-"

    if [ $? -eq 0 ]; then
        find "${TODAYS_DATE_DIR}" -type f -name "server-${USER}-${TODAYS_DATE}.tar.gz.part-*" -exec chmod -f 600 {} \;
        MESSAGE="The backup has been completed successfully."
        ERROR_CODE=0
    else
        MESSAGE="Failed to compress specified directories into the gzip file."
    fi
else
    MESSAGE="Failed to delete old backup files."
fi

#
# Output the result message to the log file.
CUR_TIME=`date +'%s'`
echo "["`date +'%d-%b-%y %H:%M:%S'`"] ${MESSAGE} (Elapsed Time: "`expr ${CUR_TIME} - ${START_TIME}`" sec.)" >>"${LOG_FILE}"


exit ${ERROR_CODE}
