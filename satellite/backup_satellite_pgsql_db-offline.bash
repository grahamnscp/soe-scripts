#!/bin/bash

##########################################
# backup_satellite_pgsql_db-offline.bash #
##########################################
#

MAXBACKUPS=3
BACKUPDIR=/var/lib/pgsql/backups

DATE=`/bin/date +'%Y%m%d'`
TIME=`/bin/date +'%H%M'`
HOSTNAME=`/bin/hostname`
THISPGBACKUP=$HOSTNAME-offline-backup-${DATE}_$TIME
PGBACKUPDIR=$BACKUPDIR/$THISPGBACKUP
/bin/mkdir -p $PGBACKUPDIR
/bin/chown -R postgres:postgres $PGBACKUPDIR
#
DRSATSERVER=dr-satellite.my-domain.com
REMOTEBACKUPDIR=/var/lib/pgsql/backups
#
LOGDIR=/var/log/rsync
if [ ! -d "$LOGDIR" ]; then
  /bin/mkdir -p /var/log/rsync
fi
LOGFILE=$LOGDIR/backup-offline-satellite-db-${DATE}.log

/bin/echo "-----------------------------------------------------------------" >> $LOGFILE
/bin/echo "Backup started at $(date "+%Y-%m-%d %H:%M:%S")" >> $LOGFILE
/bin/echo >> $LOGFILE

startTime=$(date +%s)

if (( $EUID > 0 ))
 then
    /bin/echo " * You need to be root to run this script.  Exiting" >> $LOGFILE
    exit 1
fi

# Stop satellite services..
SERVICE=/usr/sbin/rhn-satellite
/bin/echo " - Stopping Satellite services.." >> $LOGFILE
$SERVICE stop >> $LOGFILE 2>&1

/bin/echo " - Offline backing up to: $PGBACKUPDIR" >> $LOGFILE
###########################################
#
/usr/bin/db-control backup $PGBACKUPDIR >> $LOGFILE 2>&1
#
###########################################

endTime=$(date +%s)
(( duration = endTime - startTime))

#restart Satellite services..
/bin/echo " - Restarting satellite services.." >> $LOGFILE
$SERVICE start >> $LOGFILE 2>&1


# Package up backup
/bin/echo "Packaging up backup directory.." >> $LOGFILE
cd $BACKUPDIR
/bin/tar -cvf $THISPGBACKUP.tar $THISPGBACKUP >> $LOGFILE
/bin/gzip $THISPGBACKUP.tar >> $LOGFILE
/bin/mv $THISPGBACKUP.tar.gz $THISPGBACKUP.tgz >> $LOGFILE
/bin/rm -rf $THISPGBACKUP >> $LOGFILE


# Copy backup to DR server
/bin/echo Pushing satellite db backup to DR satellite.. >> $LOGFILE
##############################################
#
/usr/bin/rsync -avzh $THISPGBACKUP.tgz $DRSATSERVER:${REMOTEBACKUPDIR}/ >> $LOGFILE
#
##############################################
/bin/echo rsync complete. >> $LOGFILE


# Purge backup files
OFFLINEBACKUPS=`/bin/ls -l $BACKUPDIR | /bin/grep offline-backup-| /bin/grep .tgz | /usr/bin/wc -l`

if [ $OFFLINEBACKUPS -gt $MAXBACKUPS ] 
then
  /bin/echo "Purging offline satellite db dumps (KEEP=$MAXBACKUPS).." >> $LOGFILE

  while [ $OFFLINEBACKUPS -gt $MAXBACKUPS ]; do
    OLDESTBACKUP=`/bin/ls -cltrh $BACKUPDIR | /bin/grep offline-backup- | /bin/grep .tgz | /usr/bin/head -1 | /bin/awk '{print $9}'`
    /bin/echo "  purging $BACKUPDIR/$OLDESTBACKUP" >> $LOGFILE
    /bin/rm -rf $BACKUPDIR/$OLDESTBACKUP >> $LOGFILE
    OFFLINEBACKUPS=`/bin/ls -l $BACKUPDIR | /bin/grep offline-backup-| /bin/grep .tgz | /usr/bin/wc -l`
  done
  /bin/echo Purging Completed >> $LOGFILE
fi

/bin/echo >> $LOGFILE
/bin/echo "Backup completed at $(date "+%Y-%m-%d %H:%M:%S").  (Duration: $duration seconds)" >> $LOGFILE
/bin/echo "-----------------------------------------------------------------" >> $LOGFILE

exit 0

