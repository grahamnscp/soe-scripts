#!/bin/sh

#50 01 1 * * /usr/local/bin/optimize-dashboard-db.sh > /dev/null 2>&1

# Prune the dashboard mysql database
DBOARD_DIR=/usr/share/puppet-dashboard

cd $DBOARD_DIR
#rake RAILS_ENV=production reports:prune upto=1 unit=mon
rake RAILS_ENV=production db:raw:optimize


