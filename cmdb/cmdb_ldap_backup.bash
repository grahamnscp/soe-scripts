#!/bin/bash
#
# Script to back up the contents of the CMDB database
#
#(root crontab: )
#10 23 *  *  * /usr/local/bin/cmdb_ldap_backup.bash
#
HOSTNAME=`hostname`
DATE=`date +%Y%m%d`
BACKUPSDIR=/root/backups
CMDBBACKUPDIR=$BACKUPSDIR/cmdb

mkdir -p $CMDBBACKUPDIR
cd $BACKUPSDIR ; chown -R ldap:ldap cmdb

# Stop the LDAP Services as offline backup is required
/sbin/service slapd stop

# Back up the LDAP configuration and content to LDIF file format
echo "Backing up CMDB LDAP databases to $CMDBBACKUPDIR/.."
/usr/sbin/slapcat -n 0 -l $BACKUPSDIR/cmdb/$HOSTNAME-backup-cmdb_ldap_0_config-$DATE.ldif
/usr/sbin/slapcat -n 2 -l $BACKUPSDIR/cmdb/$HOSTNAME-backup-cmdb_ldap_2_bdb-$DATE.ldif
echo "Done."

# Restart the LDAP services
/sbin/service slapd start

exit 0


