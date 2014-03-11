#!/bin/bash

# Periodically sync contents of foreman certs tree under /var/lib/puppet/ssl to DR system to keep instep for speedy DR failover
#

# crontab
# */5 * * * * /usr/local/bin/sync-certs-to-dr-ca-server.bash


DRSERVER=drserver.my-domain.com
# Logs are appended to for 1 day
MAXLOGS=7

#
LOGDIR=/var/log/rsync
if [ ! -d "$LOGDIR" ]; then
  mkdir -p /var/log/rsync
fi

#
LOGFILENAME=rsync-puppet-ssl-
DATE=`/bin/date +'%Y%m%d'`
TIME=`/bin/date +'%H%M'`
DATETIME=`date +'%d-%m-%Y %H:%M:%S'`
LOGFILE=$LOGDIR/${LOGFILENAME}${DATE}.log

# Main
#
/bin/echo >> $LOGFILE
/bin/echo "[$DATETIME] rsync /var/lib/puppet/ssl to $DRSERVER ..." >> $LOGFILE

/usr/bin/time su -l puppet -c "/usr/bin/rsync -auzh -e 'ssh -q' --log-file=$LOGFILE /var/lib/puppet/ssl $DRSERVER:/var/lib/puppet/ >> $LOGFILE 2>&1"

/bin/echo "complete." >> $LOGFILE


# Tidy up rsync log directory, keep MAXLOGS log files for each type
RSYNCLOGS=`/bin/ls -l $LOGDIR | /bin/grep $LOGFILENAME | /usr/bin/wc -l`
if [ $RSYNCLOGS -gt $MAXLOGS ] 
then
  while [ $RSYNCLOGS -gt $MAXLOGS ]; do
    OLDESTLOG=`/bin/ls -cltrh $LOGDIR | /bin/grep $LOGFILENAME | /usr/bin/head -1 | /bin/awk '{print $9}'`
    echo "  purging $LOGDIR/$OLDESTLOG"
    /bin/rm -rf $LOGDIR/$OLDESTLOG
    RSYNCLOGS=`/bin/ls -l $LOGDIR | /bin/grep $LOGFILENAME | /usr/bin/wc -l`
  done
fi

# All done
exit 0

