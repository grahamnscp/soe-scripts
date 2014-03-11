#!/bin/bash


# Purge satellite-config backups pushed from production
# Tidy up backup directory, keep MAXBACKUPS satellite-config directories
#
BACKUPDIR=/root/backups
MAXBACKUPS=5
SATCONFBACKUPS=`/bin/ls -l ${BACKUPDIR}/ | /bin/grep satellite-config- | /usr/bin/wc -l`

if [ $SATCONFBACKUPS -gt $MAXBACKUPS ] 
then
  /bin/echo Purging satellite directories..

  while [ $SATCONFBACKUPS -gt $MAXBACKUPS ]; do
    OLDESTBACKUP=`/bin/ls -cltrh ${BACKUPDIR}/ | /bin/grep satellite-config- | /usr/bin/head -1 | /bin/awk '{print $9'}`
    echo "  purging $BACKUPDIR/$OLDESTBACKUP"
    /bin/rm -rf $BACKUPDIR/$OLDESTBACKUP
    SATCONFBACKUPS=`/bin/ls -l ${BACKUPDIR}/ | /bin/grep satellite-config- | /usr/bin/wc -l`
  done
  /bin/echo Config Purging Completed
fi

# Purge satellite Backups
# online
BACKUPDIR=/var/lib/pgsql/backups
MAXBACKUPS=5
ONLINEBACKUPS=`/bin/ls -l $BACKUPDIR | /bin/grep online-backup-| /usr/bin/wc -l`

if [ $ONLINEBACKUPS -gt $MAXBACKUPS ]
then
  /bin/echo "Purging online satellite db dumps (KEEP=$MAXBACKUPS).."

  while [ $ONLINEBACKUPS -gt $MAXBACKUPS ]; do
    OLDESTBACKUP=`/bin/ls -cltrh $BACKUPDIR | /bin/grep online-backup- | /usr/bin/head -1 | /bin/awk '{print $9}'`
    /bin/echo "  purging $BACKUPDIR/$OLDESTBACKUP"
    /bin/rm -rf $BACKUPDIR/$OLDESTBACKUP 
    ONLINEBACKUPS=`/bin/ls -l $BACKUPDIR | /bin/grep online-backup-| /usr/bin/wc -l`
  done
  /bin/echo Online DB Backup Purging Completed
fi

# offline
BACKUPDIR=/var/lib/pgsql/backups
MAXBACKUPS=10
OFFLINEBACKUPS=`/bin/ls -l $BACKUPDIR | /bin/grep offline-backup-| /bin/grep .tgz | /usr/bin/wc -l`

if [ $OFFLINEBACKUPS -gt $MAXBACKUPS ]
then
  /bin/echo "Purging offline satellite db dumps (KEEP=$MAXBACKUPS).."

  while [ $OFFLINEBACKUPS -gt $MAXBACKUPS ]; do
    OLDESTBACKUP=`/bin/ls -cltrh $BACKUPDIR | /bin/grep offline-backup- | /bin/grep .tgz | /usr/bin/head -1 | /bin/awk '{print $9}'`
    /bin/echo "  purging $BACKUPDIR/$OLDESTBACKUP"
    /bin/rm -rf $BACKUPDIR/$OLDESTBACKUP
    OFFLINEBACKUPS=`/bin/ls -l $BACKUPDIR | /bin/grep offline-backup-| /bin/grep .tgz | /usr/bin/wc -l`
  done
  /bin/echo Offline DB Backup Purging Completed
fi

exit 0
