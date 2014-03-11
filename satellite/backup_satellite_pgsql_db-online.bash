#!/bin/bash

#########################################
# backup_satellite_pgsql_db-online.bash #
#########################################
#

MAXBACKUPS=5
BACKUPDIR=/var/lib/pgsql/backups
DATE=`/bin/date +'%Y%m%d'`
TIME=`/bin/date +'%H%M'`
HOSTNAME=`/bin/hostname`
PGDUMPFILE=$BACKUPDIR/$HOSTNAME-online-backup-${DATE}_$TIME.pg_dump
#
DRSATSERVER=dr-satellite-1.my-domain.com
REMOTEBACKUPDIR=/var/lib/pgsql/backups
#
LOGDIR=/var/log/rsync
if [ ! -d "$LOGDIR" ]; then
  mkdir -p /var/log/rsync
fi
LOGFILE=$LOGDIR/backup-online-satellite-db-${DATE}.log


/bin/echo "-----------------------------------------------------------------" >> $LOGFILE
/bin/echo "Backup started at $(date "+%Y-%m-%d %H:%M:%S")" >> $LOGFILE
/bin/echo >> $LOGFILE

startTime=$(date +%s)

if (( $EUID > 0 ))
 then
    /bin/echo " * You need to be root to run this script.  Exiting" >> $LOGFILE
    exit 1
fi

/bin/echo " - Backing up to: $PGDUMPFILE" >> $LOGFILE
##############################################
#
/usr/bin/db-control online-backup $PGDUMPFILE >> $LOGFILE 2>&1
#
##############################################

endTime=$(date +%s)
(( duration = endTime - startTime))


# Copy backup to DR server
/bin/echo Pushing satellite db backup to DR satellite.. >> $LOGFILE
##############################################
#
/usr/bin/rsync -avzh $PGDUMPFILE $DRSATSERVER:${REMOTEBACKUPDIR}/ >> $LOGFILE
#
##############################################
/bin/echo rsync complete. >> $LOGFILE


# Tidy up
ONLINEBACKUPS=`/bin/ls -l $BACKUPDIR | /bin/grep online-backup-| /usr/bin/wc -l`

if [ $ONLINEBACKUPS -gt $MAXBACKUPS ] 
then
  /bin/echo "Purging online satellite db dumps (KEEP=$MAXBACKUPS).." >> $LOGFILE

  while [ $ONLINEBACKUPS -gt $MAXBACKUPS ]; do
    OLDESTBACKUP=`/bin/ls -cltrh $BACKUPDIR | /bin/grep online-backup- | /usr/bin/head -1 | /bin/awk '{print $9}'`
    /bin/echo "  purging $BACKUPDIR/$OLDESTBACKUP" >> $LOGFILE
    /bin/rm -rf $BACKUPDIR/$OLDESTBACKUP >> $LOGFILE
    ONLINEBACKUPS=`/bin/ls -l $BACKUPDIR | /bin/grep online-backup-| /usr/bin/wc -l`
  done
  /bin/echo Purging Completed >> $LOGFILE
fi

/bin/echo >> $LOGFILE
/bin/echo "Backup completed at $(date "+%Y-%m-%d %H:%M:%S").  (Duration: $duration seconds)" >> $LOGFILE
/bin/echo "-----------------------------------------------------------------" >> $LOGFILE

exit 0


