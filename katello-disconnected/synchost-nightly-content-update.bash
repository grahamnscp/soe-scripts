#!/bin/bash

# NOTE! This script uses a custom target implemented in katello-disconnected called publish-watch.
# If auto publish is not required then this section can be taken out.  

# Script: synchost-nightly-content-update.bash
#
# example crontab entry:
#10 01 * * *  /usr/local/bin/synchost-nightly-content-update.bash > /dev/null 2>&1

# Periodically sync CDN content and publish in pulp
#

# Variables:
SYNC_CMD="/usr/bin/katello-disconnected sync"
SYNC_WATCH_CMD="/usr/bin/katello-disconnected watch"
PUBLISH_CMD="/usr/bin/katello-disconnected publish"
#
LOGDIR=/var/log/synchost-batch
DATE=`/bin/date +'%Y%m%d'`
TIME=`/bin/date +'%H%M'`
LOGFILE=$LOGDIR/synchost-nightly-content-update-${DATE}-${TIME}.log
SYNC_LOGFILE=$LOGDIR/synchost-nightly-sync-output-${DATE}-${TIME}.log
PUBLISH_LOGFILE=$LOGDIR/synchost-nightly-publish-output-${DATE}-${TIME}.log
#
MAXLOGS=3


# Functions:
check_logdir () {
   if [ ! -d "$LOGDIR" ]; then
     mkdir -p /var/log/synchost-batch
  fi
}

logmsg () {
  /bin/echo `date +'%Y%m%d-%H:%M:%S'` "[synchost-batch] $1" >> $LOGFILE
}

check_already_running () {
   SATSYNCRUNNING=`/bin/ps -ef | grep "synchost-nightly-content-update" | grep -v grep | grep -v vi | wc -l`
   if [ $SATSYNCRUNNING -gt 1 ] 
   then
     logmsg "  Detected synchost-nightly-content-update running, exiting 1.."
     exit 1
   fi
}

disconnected_sync () {
   /bin/echo `date +'%Y%m%d-%H:%M:%S'` "[synchost-batch] sync started.." >> $SYNC_LOGFILE
   $SYNC_CMD >> $SYNC_LOGFILE
   SYNC_RETSTAT=$?
   /bin/echo `date +'%Y%m%d-%H:%M:%S'` "[synchost-batch] sync initialised (RETSTAT=$SYNC_RETSTAT)" >> $SYNC_LOGFILE
   logmsg "  sync initialised (RETSTAT=$SYNC_RETSTAT)"

   # Note sync does not have a watch as part of it so run a (sync) watch which wll exit when content sync complete
   /bin/echo `date +'%Y%m%d-%H:%M:%S'` "[synchost-batch] sync watch started.." >> $SYNC_LOGFILE
   $SYNC_WATCH_CMD >> $SYNC_LOGFILE
   SYNC_WATCH_RETSTAT=$?
   /bin/echo `date +'%Y%m%d-%H:%M:%S'` "[synchost-batch] sync finished (RETSTAT=$SYNC_WATCH_RETSTAT)" >> $SYNC_LOGFILE
   logmsg "  sync finished (SYNC_RETSTAT=$SYNC_RETSTAT, SYNC_WATCH_RETSTAT=$SYNC_WATCH_RETSTAT)"
}

disconnected_publish () {
   # Note publish has a publish_watch at the end
   /bin/echo `date +'%Y%m%d-%H:%M:%S'` "[synchost-batch] publish started.." >> $PUBLISH_LOGFILE
   $PUBLISH_CMD >> $PUBLISH_LOGFILE
   PUBLISH_RETSTAT=$?
   /bin/echo `date +'%Y%m%d-%H:%M:%S'` "[synchost-batch] publish finished (RETSTAT=$PUBLISH_RETSTAT)" >> $PUBLISH_LOGFILE
   logmsg "  publish finished (RETSTAT=$PUBLISH_RETSTAT)"
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



# Main:
# =====

# Check logdir exists, if not create it
check_logdir

logmsg "Started.."

# Abort if katello-disconnected already running
#####check_already_running

TIME_START=`date +"%s"`


# Disconnected sync
logmsg "Launching katello-disconnected sync.."
disconnected_sync
logmsg "sync complete."

# Content sync download duration
TIME_SYNC_COMPLETE=`date +"%s"`
DURATION_SYNC=`date -u -d "0 $TIME_SYNC_COMPLETE seconds - $TIME_START seconds" +"%H:%M:%S"`
logmsg "Duration for content sync download: $DURATION_SYNC"


# Disconnected publish (dummy out mkisofs to save ~2.5 hours in nightly batch)
logmsg "Launching katello-disconnected publish.."
disconnected_publish
logmsg "publish complete."

# Durations
TIME_PUBLISH_COMPLETE=`date +"%s"`
DURATION_PUBLISH=`date -u -d "0 $TIME_PUBLISH_COMPLETE seconds - $TIME_SYNC_COMPLETE seconds" +"%H:%M:%S"`
DURATION_BATCH=`date -u -d "0 $TIME_PUBLISH_COMPLETE seconds - $TIME_START seconds" +"%H:%M:%S"`
logmsg "Duration for content publish: $DURATION_PUBLISH"
logmsg "Duration for total nightly content batch cycle: $DURATION_BATCH"


# Tidy up sync log directory, keep MAXLOGS log files for each type
purge_log_files "synchost-nightly-content-update-"
purge_log_files "synchost-nightly-sync-output-"
purge_log_files "synchost-nightly-publish-output-"


# All done
logmsg "All done, exiting 0.."
exit 0

