#!/bin/bash

# Script: synchost-content-export.bash
#
# Periodically export CDN content since last successful run
#
# example crontab entry: 
# 1. Entry: Minute when the process will be started [0-60]
# 2. Entry: Hour when the process will be started [0-23]
# 3. Entry: Day of the month when the process will be started [1-28/29/30/31]
# 4. Entry: Month of the year when the process will be started [1-12]
# 5. Entry: Weekday when the process will be started [0-6] [0 is Sunday]
#
# Sunday morning at 03:10
#10 03 * * 0  /usr/local/bin/synchost-content-export.bash > /dev/null 2>&1

###### test start date
#echo "2016-01-15 00:00:00" > /var/tmp/synchost-content-exported-to-date.txt


# Variables:
DATE=`/bin/date +'%Y%m%d'`
TIME=`/bin/date +'%H%M'`
DOM=`/bin/date +'%d'`
#
LOGDIR=/var/log/synchost-batch
LOGFILE=$LOGDIR/synchost-content-export-${DATE}-${TIME}.log
MAXLOGS=2
#
#EXPORT_DIR=/export/katello-export
EXPORT_DIR=/var/lib/pulp/export
LAST_EXPORT_DATE_FILE=/var/tmp/synchost-content-exported-to-date.txt
EXPORT_START_TIME=`cat $LAST_EXPORT_DATE_FILE`
EXPORT_END_TIME=`/bin/date +'%Y-%m-%d 12:00:00'`
THIS_EXPORT_DATE=`/bin/date +'%Y-%m-%d 00:00:00'`
#
# Example usage: katello-disconnected export -t $EXPORT_DIR -r repo1,repo2 -o -s $EXPORT_START_TIME -n $EXPORT_END_TIME
#EXPORT_CMD="/usr/bin/katello-disconnected export -t $EXPORT_DIR -r rhel-7-server-rh-common-rpms-7Server-x86_64 -o -s \"$EXPORT_START_TIME\" -n \"$EXPORT_END_TIME\""
EXPORT_CMD="/usr/bin/katello-disconnected export -t $EXPORT_DIR -o -s \"$EXPORT_START_TIME\" -n \"$EXPORT_END_TIME\""
#

# Functions:
check_logdir () {
   if [ ! -d "$LOGDIR" ]; then
     mkdir -p $LOGDIR
  fi
}

logmsg () {
  /bin/echo `date +'%Y%m%d-%H:%M:%S'` "[synchost-export] $1" | tee $LOGFILE
}

purge_log_files () {
   SYNCLOGS=`/bin/ls -l $LOGDIR | /bin/grep $1 | /usr/bin/wc -l`
   if [ $SYNCLOGS -gt $MAXLOGS ] 
   then
     while [ $SYNCLOGS -gt $MAXLOGS ]; do
       OLDESTLOG=`/bin/ls -cltrh $LOGDIR | /bin/grep $1 | /usr/bin/head -1 | /bin/awk '{print $9}'`
       logmsg "MAXLOGS=$MAXLOGS, purging $LOGDIR/$OLDESTLOG"
       /bin/rm -rf $LOGDIR/$OLDESTLOG
       SYNCLOGS=`/bin/ls -l $LOGDIR | /bin/grep $1 | /usr/bin/wc -l`
     done
   fi
}

disconnected_export () {
   logmsg "  export started (EXPORT_CMD=$EXPORT_CMD).."
   $EXPORT_CMD | tee $LOGFILE
   RETSTAT=$?
   logmsg "  export finished (RETSTAT=$RETSTAT)"
}



# Main:
# =====

# Check logdir exists, if not create it
check_logdir

logmsg "Started.."

TIME_START=`date +"%s"`

logmsg "Launching katello-disconnected export.."
disconnected_export

if [ $RETSTAT = 0 ]
then
  logmsg "export completed successfully."

  # Create SUCCESS flag file
  touch $EXPORT_DIR/synchost-export-SUCCESS.${DATE}-${TIME}

  # Update last SUCCESSFULLY exported date file
  echo $THIS_EXPORT_DATE > $LAST_EXPORT_DATE_FILE

  # Durations
  TIME_COMPLETE=`date +"%s"`
  DURATION=`date -u -d "0 $TIME_COMPLETE seconds - $TIME_START seconds" +"%H:%M:%S"`
  logmsg "Duration for extract content batch: $DURATION"

  # Tidy up log directory, keep MAXLOGS log files
  purge_log_files "synchost-content-export-"

else
  logmsg "export failed!"

  # Create FAILED flag file
  touch $EXPORT_DIR/synchost-export-FAILED.${DATE}-${TIME}
fi


# All done
logmsg "All done, exiting (RETSTAT=$RETSTAT).."
exit $RETSTAT

