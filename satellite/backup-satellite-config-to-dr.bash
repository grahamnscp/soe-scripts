#!/bin/bash

DRSATSERVER=dr-satellite.my-domain.com
BACKUPBASE=/root/backups
REMOTEBACKUPDIR=/root/backups
MAXBACKUPS=5

LOGDIR=/var/log/rsync
if [ ! -d "$LOGDIR" ]; then
  mkdir -p /var/log/rsync
fi

#
DATE=`/bin/date +'%Y%m%d'`
TIME=`/bin/date +'%H%M'`

LOGFILE=$LOGDIR/rsync-satellite-config-${DATE}.log
#
BACKUPDIR=$BACKUPBASE/satellite-config-$DATE-$TIME


# Main
#
/bin/echo Backing up Satellite configuration files to $BACKUPDIR.. >> $LOGFILE

/bin/mkdir $BACKUPDIR >> $LOGFILE
/bin/mkdir $BACKUPDIR/etcsysconfigrhn >> $LOGFILE
/bin/cp -rp /etc/sysconfig/rhn/* $BACKUPDIR/etcsysconfigrhn/ >> $LOGFILE

/bin/mkdir $BACKUPDIR/etcrhn >> $LOGFILE
/bin/cp -rp /etc/rhn/* $BACKUPDIR/etcrhn/ >> $LOGFILE

/bin/mkdir $BACKUPDIR/etc >> $LOGFILE
/bin/cp -p /etc/sudoers $BACKUPDIR/etc/ >> $LOGFILE

/bin/mkdir $BACKUPDIR/varwwwhtmlpub >> $LOGFILE
/bin/cp -rp /var/www/html/pub/* $BACKUPDIR/varwwwhtmlpub/ >> $LOGFILE

/bin/mkdir $BACKUPDIR/root >> $LOGFILE
/bin/cp -rp /root/.gnupg $BACKUPDIR/root/ >> $LOGFILE
/bin/cp -rp /root/ssl-build $BACKUPDIR/root/ >> $LOGFILE

/bin/mkdir $BACKUPDIR/etchttpd >> $LOGFILE
/bin/cp -rp /etc/httpd/* $BACKUPDIR/etchttpd/ >> $LOGFILE

/bin/mkdir $BACKUPDIR/varlibtftpboot >> $LOGFILE
/bin/cp -rp /var/lib/tftpboot/* $BACKUPDIR/varlibtftpboot/ >> $LOGFILE

/bin/mkdir $BACKUPDIR/varlibcobbler >> $LOGFILE
/bin/cp -rp /var/lib/cobbler/* $BACKUPDIR/varlibcobbler/ >> $LOGFILE

/bin/mkdir $BACKUPDIR/varwwwcobbler >> $LOGFILE
/bin/cp -rp /var/www/cobbler/* $BACKUPDIR/varwwwcobbler/ >> $LOGFILE

/bin/mkdir $BACKUPDIR/varlibrhnkickstarts >> $LOGFILE
/bin/cp -rp /var/lib/rhn/kickstarts/* $BACKUPDIR/varlibrhnkickstarts/ >> $LOGFILE

/bin/mkdir $BACKUPDIR/varlibnocpulse >> $LOGFILE
/bin/cp -rp /var/lib/nocpulse/* $BACKUPDIR/varlibnocpulse/ >> $LOGFILE

/bin/echo File copy complete. >> $LOGFILE


# rsync to DR server
#
/bin/echo Pushing directory to DR satellite.. >> $LOGFILE

/usr/bin/rsync -avzh $BACKUPDIR $DRSATSERVER:${REMOTEBACKUPDIR}/ >> $LOGFILE

/bin/echo rsync complete. >> $LOGFILE


# Tidy up backup directory, keep MAXBACKUPS satellite-config directories
#
SATCONFBACKUPS=`/bin/ls -l ${BACKUPBASE}/ | /bin/grep satellite-config- | /usr/bin/wc -l`

if [ $SATCONFBACKUPS -gt $MAXBACKUPS ] 
then
  /bin/echo Purging satellite directories.. >> $LOGFILE

  while [ $SATCONFBACKUPS -gt $MAXBACKUPS ]; do
    OLDESTBACKUP=`/bin/ls -cltrh ${BACKUPBASE}/ | /bin/grep satellite-config- | /usr/bin/head -1 | /bin/awk '{print $9}'`
    echo "  purging $BACKUPBASE/$OLDESTBACKUP" >> $LOGFILE
    /bin/rm -rf $BACKUPBASE/$OLDESTBACKUP >> $LOGFILE
    SATCONFBACKUPS=`/bin/ls -l /backups/ | /bin/grep satellite-config- | /usr/bin/wc -l`
  done
  /bin/echo Purging Completed >> $LOGFILE

else
  /bin/echo Done >> $LOGFILE
fi

exit 0

