#!/bin/bash

GITBACKUPDIR=/root/backups/git-repos
MAXBACKUPS=200

BACKUPLIST=`/bin/ls -l $GITBACKUPDIR | /bin/grep git-repos-backup-| /bin/grep .tgz | /usr/bin/wc -l`

if [ $BACKUPLIST -gt $MAXBACKUPS ]
then
  while [ $BACKUPLIST -gt $MAXBACKUPS ]; do
    OLDESTBACKUP=`/bin/ls -cltrh $GITBACKUPDIR | /bin/grep git-repos-backup- | /bin/grep .tgz | /usr/bin/head -1 | /bin/awk '{print $9}'`
    /bin/rm -rf $GITBACKUPDIR/$OLDESTBACKUP
    BACKUPLIST=`/bin/ls -l $GITBACKUPDIR | /bin/grep git-repos-backup-| /bin/grep .tgz | /usr/bin/wc -l`
  done
fi

