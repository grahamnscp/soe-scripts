#!/bin/bash

###########################
# backupup-git-repos.bash #
###########################

GITBACKUPDIR=/root/backups/git-repos
GITREPODIR=/opt/git

DATE=`/bin/date +'%Y%m%d'`
TIME=`/bin/date +'%H%M'`
HOSTNAME=`/bin/hostname`
THISBACKUP=$HOSTNAME-git-repos-backup-${DATE}_$TIME
/bin/mkdir -p $GITBACKUPDIR/$THISBACKUP

/bin/echo "[$(date "+%Y-%m-%d %H:%M:%S")] Backing up all GIT repos to $GITBACKUPDIR/${THISBACKUP}.tgz"
cd $GITBACKUPDIR
/bin/cp -rp $GITREPODIR/* $GITBACKUPDIR/$THISBACKUP/
/bin/tar -cf $THISBACKUP.tar $THISBACKUP
/bin/gzip $THISBACKUP.tar
/bin/mv $THISBACKUP.tar.gz $THISBACKUP.tgz
/bin/rm -rf $THISBACKUP


# Copy backup to DR server
REMOTESERVER=git-backup-server.my-domain.com
REMOTEBACKUPDIR=/root/backups/git-repos
/bin/echo "[$(date "+%Y-%m-%d %H:%M:%S")] Pushing backup to remote server ($REMOTESERVER).."
/usr/bin/rsync -avzh $THISBACKUP.tgz $REMOTESERVER:${REMOTEBACKUPDIR}/


# Purge backup files
MAXBACKUPS=100
BACKUPLIST=`/bin/ls -l $GITBACKUPDIR | /bin/grep git-repos-backup-| /bin/grep .tgz | /usr/bin/wc -l`

if [ $BACKUPLIST -gt $MAXBACKUPS ]
then
  /bin/echo "[$(date "+%Y-%m-%d %H:%M:%")] Purging local backups (MAXBACKUPS=$MAXBACKUPS).."
  while [ $BACKUPLIST -gt $MAXBACKUPS ]; do
    OLDESTBACKUP=`/bin/ls -cltrh $GITBACKUPDIR | /bin/grep git-repos-backup- | /bin/grep .tgz | /usr/bin/head -1 | /bin/awk '{print $9}'`
    /bin/echo "  purging $GITBACKUPDIR/$OLDESTBACKUP"
    /bin/rm -rf $GITBACKUPDIR/$OLDESTBACKUP
    BACKUPLIST=`/bin/ls -l $GITBACKUPDIR | /bin/grep git-repos-backup-| /bin/grep .tgz | /usr/bin/wc -l`
  done
fi

/bin/echo "[$(date "+%Y-%m-%d %H:%M:%S")] Backup Complete"
