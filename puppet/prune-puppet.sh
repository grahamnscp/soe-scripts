#!/bin/sh

#05 23 * * 5 /usr/local/bin/prune-puppet.sh > /dev/null 2>&1

# Prune Puppet reports directory on disk
DAYS="+30"

cd /var/lib/puppet/reports

for d in `find /var/lib/puppet/reports -mindepth 1 -maxdepth 1 -type d`
do
  /bin/find $d -type f -name \*.yaml -mtime $DAYS | sort -r | tail -n +2 | xargs -n50 /bin/rm -f
done


# Prune the Puppet Dashboard mysql database tables as once file grows it doesn't shrink!
DBOARD_DIR=/usr/share/puppet-dashboard

cd $DBOARD_DIR
rake RAILS_ENV=production reports:prune upto=1 unit=mon
#rake RAILS_ENV=production db:raw:optimize


exit 0
