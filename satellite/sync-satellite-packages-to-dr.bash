#!/bin/bash

# Periodically sync contents of satellite tree under /var/satellite to DR system to keep instep for speedy DR failover
#

DRSATSERVER=dr-satellite.my-domain.com

# Abort if satellite-sync running
SATSYNCRUNNING=`/bin/ps -ef | grep "satellite-sync" | grep -v grep | wc -l`
if [ $SATSYNCRUNNING -eq 1 ] 
then
  /bin/echo "Detected satellite-sync running, exiting.."
  exit 0
fi

#
LOGDIR=/var/log/rsync
if [ ! -d "$LOGDIR" ]; then
  mkdir -p /var/log/rsync
fi

#
DATE=`/bin/date +'%Y%m%d'`
TIME=`/bin/date +'%H%M'`


# Main

# Break down into two parts:
#  - /var/satellite/rhn    - Kickstart trees and channel comps (small)
#  - /var/satellite/redhat - Redhat Hosted Packages (large but relatively static once synced)

# rhn
/bin/echo "Rsyncing /var/satellite/rhn.." >> $LOGDIR/rsync-satellite-rhn-${DATE}.log

/usr/bin/time /usr/bin/rsync -auzh --log-file=$LOGDIR/rsync-satellite-rhn-${DATE}.log \
                             /var/satellite/rhn $DRSATSERVER:/var/satellite/ >> $LOGDIR/rsync-satellite-rhn-${DATE}.log 2>&1

/bin/echo "complete." >> $LOGDIR/rsync-satellite-rhn-${DATE}.log


# redhat
/bin/echo "Rsynching /var/satellite/redhat.." >> $LOGDIR/rsync-satellite-redhat-${DATE}.log

/usr/bin/time /usr/bin/rsync -auzh --log-file=$LOGDIR/rsync-satellite-redhat-${DATE}.log \
                             /var/satellite/redhat $DRSATSERVER:/var/satellite/ >> $LOGDIR/rsync-satellite-redhat-${DATE}.log 2>&1

/bin/echo "complete." >> $LOGDIR/rsync-satellite-redhat-${DATE}.log



# Tidy up rsync log directory, keep MAXLOGS log files for each type
MAXLOGS=7

# rhn
RSYNCLOGS=`/bin/ls -l $LOGDIR | /bin/grep rsync-satellite-rhn- | /usr/bin/wc -l`
if [ $RSYNCLOGS -gt $MAXLOGS ] 
then
  while [ $RSYNCLOGS -gt $MAXLOGS ]; do
    OLDESTLOG=`/bin/ls -cltrh $LOGDIR | /bin/grep rsync-satellite-rhn- | /usr/bin/head -1 | /bin/awk '{print $9}'`
    echo "  purging $LOGDIR/$OLDESTLOG"
    /bin/rm -rf $LOGDIR/$OLDESTLOG
    RSYNCLOGS=`/bin/ls -l $LOGDIR | /bin/grep rsync-satellite-rhn- | /usr/bin/wc -l`
  done
fi

# redhat
RSYNCLOGS=`/bin/ls -l $LOGDIR | /bin/grep rsync-satellite-redhat- | /usr/bin/wc -l`
if [ $RSYNCLOGS -gt $MAXLOGS ] 
then
  while [ $RSYNCLOGS -gt $MAXLOGS ]; do
    OLDESTLOG=`/bin/ls -cltrh $LOGDIR | /bin/grep rsync-satellite-redhat- | /usr/bin/head -1 | /bin/awk '{print $9}'`
    echo "  purging $LOGDIR/$OLDESTLOG"
    /bin/rm -rf $LOGDIR/$OLDESTLOG
    RSYNCLOGS=`/bin/ls -l $LOGDIR | /bin/grep rsync-satellite-redhat- | /usr/bin/wc -l`
  done
fi

# All done
exit 0

