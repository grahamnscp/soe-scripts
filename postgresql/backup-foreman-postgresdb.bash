#!/bin/bash

# Online backup postgresql db

# 11pm every friday:
# 0 23 * * 5 /usr/local/bin/backup-foreman-postgresdb.bash

DATABASE=foreman
MAXBACKUPS=5
BACKUPDIR=/var/lib/pgsql/9.3/backups

#
HOSTNAME=`/bin/hostname`
DATE=`/bin/date +'%Y%m%d'`
TIME=`/bin/date +'%H%M'`

#
PGDUMPFILE=$BACKUPDIR/$HOSTNAME-$DATABASE-DB-online-backup-${DATE}_$TIME.pg_dump

# For SELinux we need to use 'runuser' not 'su'
if [ -x /sbin/runuser ]
then
    SU=runuser
else
    SU=su
fi

/bin/echo "-----------------------------------------------------------------"
/bin/echo "Backup started at $(date "+%Y-%m-%d %H:%M:%S")"

startTime=$(date +%s)

if (( $EUID > 0 ))
  then
     /bin/echo " * You need to be root to run this script.  Exiting"
     exit 1
fi

/bin/echo " - Backing up to: $PGDUMPFILE ..."

$SU -l postgres -c "/usr/bin/pg_dump $DATABASE --file $PGDUMPFILE"

endTime=$(date +%s)
((duration = endTime - startTime))

# Tidy up
ONLINEBACKUPS=`/bin/ls -l $BACKUPDIR | /bin/grep online-backup-| 
/usr/bin/wc -l`

if [ $ONLINEBACKUPS -gt $MAXBACKUPS ]
then
   /bin/echo "Purging online satellite db dumps (KEEP=$MAXBACKUPS).."

   while [ $ONLINEBACKUPS -gt $MAXBACKUPS ]; do
     OLDESTBACKUP=`/bin/ls -cltrh $BACKUPDIR | /bin/grep online-backup- | /usr/bin/head -1 | /bin/awk '{print $9}'`
     /bin/echo "  purging $BACKUPDIR/$OLDESTBACKUP"
     /bin/rm -rf $BACKUPDIR/$OLDESTBACKUP
     ONLINEBACKUPS=`/bin/ls -l $BACKUPDIR | /bin/grep online-backup- | /usr/bin/wc -l`
   done
   /bin/echo Purging Completed
fi

/bin/echo
/bin/echo "Backup completed at $(date "+%Y-%m-%d %H:%M:%S"). (Duration: $duration seconds)"
/bin/echo "-----------------------------------------------------------------"

exit 0

