#!/bin/bash

# test script to extract out a full repo
#

trap control_c SIGINT

#
# Parameters:
#
RET_STAT=0

PARAM=sat6-repos-to-export.txt

#
# Variables:
#
SAT_REPOS_EXPORT_CONF_DIR=.
KATELLO_EXPORT_DIR=/var/lib/pulp/katello-export
PUB_EXPORT_DIR=/var/www/html/pub/export
LOGDIR=/var/log/sat6-disconnected-batch
LC_ENV="Library"
#
DATE=`/bin/date +'%Y%m%d'`
TIME=`/bin/date +'%H%M'`
LOGFILE=$LOGDIR/sat6-disconnected-batch-log-${DATE}-${TIME}.log
ERRORLOGFILE=$LOGDIR/sat6-disconnected-batch-log-${DATE}-${TIME}.errorlog
EXPORT_WORK_DIR=$PUB_EXPORT_DIR/sat6-disconnected-export-${DATE}-${TIME}
MAXLOGS=4


# 
# Functions:
#
control_c()
{
  /usr/bin/echo -en "\n!Control-C Interrupt, exiting..\n"
  /usr/bin/rm -rf $EXPORT_WORK_DIR
  exit 1
}

checkmk_logdir () {
   if [ ! -d "$LOGDIR" ]; then
     /usr/bin/mkdir -p $LOGDIR
  fi
}

checkmk_exportdir () {
   if [ ! -d "$PUB_EXPORT_DIR" ]; then
     /usr/bin/mkdir -p $PUB_EXPORT_DIR
  fi
}

checkmk_exportworkdir () {
   if [ ! -d "$EXPORT_WORK_DIR" ]; then
     /usr/bin/mkdir -p $EXPORT_WORK_DIR
  fi
}

logmsg () {
  /bin/echo `date +'%Y%m%d-%H:%M:%S'` "[sat6-disconnected-batch] $1" | tee -a $LOGFILE
}

errorlogmsg () {
  /bin/echo `date +'%Y%m%d-%H:%M:%S'` "[sat6-disconnected-batch] $1" >> $ERRORLOGFILE
}

parse_spaces_to_underscores () {
  PARSED_STRING="$(echo $1 | sed 's/ /_/g' | sed 's/\./_/g')"
  /bin/echo $PARSED_STRING
}


####################################
# Main:
####################################

logmsg "Started.."

logmsg "KATELLO_EXPORT_DIR set to /var/lib/pulp/katello-export"
logmsg "PUB_EXPORT_DIR set to /var/www/html/pub/export"

checkmk_logdir
checkmk_exportdir
checkmk_exportworkdir

# Loop reading in the Org-Product-Repo names
repos=0

logmsg "Parsing repos file: [$SAT_REPOS_EXPORT_CONF_DIR/$PARAM]"

while read line
do
 case $line in
   *"REPO:"*)
     repos=$(($repos+1))
     orgs[$repos]=`echo $line | awk -F '|' '{print $2}'`
     products[$repos]=`echo $line | awk -F '|' '{print $3}'`
     repos[$repos]=`echo $line | awk -F '|' '{print $4}'`
     ;;
 esac

done < $SAT_REPOS_EXPORT_CONF_DIR/$PARAM

logmsg "Processing $repos repos.."


# Process each repo in turn..
RPM_COUNT=0
RPM_TOTAL_EXPORTED_COUNT=0
RPM_TOTAL_COMBINED_COUNT=0

for (( this_repo=1; this_repo<=$repos; this_repo++ ))
do
  ORG_NAME=$(printf "%s" "${orgs[this_repo]}")
  ORG=$(parse_spaces_to_underscores "$ORG_NAME")

  PRODUCT_NAME=$(printf "%s" "${products[this_repo]}")
  PROD=$(parse_spaces_to_underscores "$PRODUCT_NAME")

  REPO_NAME=$(printf "%s" "${repos[this_repo]}")
  REPO=$(parse_spaces_to_underscores "$REPO_NAME")

  ORGPRODREPO="$ORG-$PROD-$REPO"
  CONTENT_ROOT="$KATELLO_EXPORT_DIR/$ORGPRODREPO/$ORG/$LC_ENV"
  logmsg "Processing repo[$this_repo]: $ORGPRODREPO"

  # Save export directory name for tidy up later
  exportdirs[$this_repo]=`echo $KATELLO_EXPORT_DIR/$ORGPRODREPO`

  logmsg "Repo[$this_repo]: Exporting content.."
  #
  # $ hammer repository export --help
  # Usage:
  #     hammer repository export [OPTIONS]
  # 
  # Options:
  #  --async                                 Do not wait for the task
  #  --export-to-iso EXPORT_TO_ISO           Export to ISO format
  #                                          One of true/false, yes/no, 1/0.
  #  --id ID                                 Repository identifier
  #  --iso-mb-size ISO_MB_SIZE               maximum size of each ISO in MB
  #  --name NAME                             Repository name to search by
  #  --organization ORGANIZATION_NAME        Organization name to search by
  #  --organization-id ORGANIZATION_ID       organization ID
  #  --organization-label ORGANIZATION_LABEL Organization label to search by
  #  --product PRODUCT_NAME                  Product name to search by
  #  --product-id PRODUCT_ID                 product numeric identifier
  #  --since SINCE                           Optional date of last export (ex: 2010-01-01T12:00:00Z)
  #  -h, --help                              print help

  logmsg "Repo[$this_repo]: Running: /usr/bin/hammer repository export --organization \"$ORG_NAME\" --product \"$PRODUCT_NAME\" --name \"$REPO_NAME\" "
  EXPORT_OUTPUT=`/usr/bin/hammer repository export --organization "$ORG_NAME" --product "$PRODUCT_NAME" --name "$REPO_NAME" 2>&1`
  EXPORT_RET_STAT=$?

  if [ $EXPORT_RET_STAT != 0 ]
  then
    logmsg "ERROR!, Repo[$this_repo] hammer repository export failed!, ret_stat=$EXPORT_RET_STAT, command output is:"
    errorlogmsg "ERROR!, Repo[$this_repo] hammer repository export failed!, ret_stat=$EXPORT_RET_STAT, command output is:"
    /bin/echo $EXPORT_OUTPUT | tee -a $LOGFILE
    /bin/echo $EXPORT_OUTPUT >> $ERRORLOGFILE
    exit 1
  else
    logmsg "done."
  fi

  RPM_COUNT=`find $CONTENT_ROOT/content | grep .rpm | wc -l`
  logmsg "Repo[$this_repo]: Exported $RPM_COUNT rpms"
  RPM_TOTAL_EXPORTED_COUNT=$((RPM_TOTAL_EXPORTED_COUNT + RPM_COUNT))

  logmsg "Repo[$this_repo]: Copying content root to combined export working dir [$EXPORT_WORK_DIR].."
  /usr/bin/cp -a $CONTENT_ROOT/content $EXPORT_WORK_DIR/

done

logmsg "Finished exporting and Combining repos, total Exported rpm count: $RPM_TOTAL_EXPORTED_COUNT"

# check combined result okay and delete original exports..
RPM_TOTAL_COMBINED_COUNT=`/usr/bin/find $EXPORT_WORK_DIR/content | grep .rpm | wc -l`
logmsg "Total Combined rpm count: $RPM_TOTAL_COMBINED_COUNT"

# Check combined count equals exported rpm count
if ! [ $RPM_TOTAL_COMBINED_COUNT -eq $RPM_TOTAL_EXPORTED_COUNT ]
then
  logmsg "ERROR!, Total Combined rpm count does not match Total Exported rpm count, something went wrong!?, Exiting.."
  errorlogmsg "ERROR!, Total Combined rpm count does not match Total Exported rpm count, something went wrong!?, Exiting.."
  exit 1
fi

# create content listing file..
echo content > $EXPORT_WORK_DIR/listing

# okay to delete original exports..
logmsg "Cleaning up repos exported by this script run from KATELLO_EXPORT_DIR.."
for (( this_repo=1; this_repo<=$repos; this_repo++ ))
do
  THIS_EXPORT_DIR=$(printf "%s" "${exportdirs[this_repo]}")
  /usr/bin/rm -rf $THIS_EXPORT_DIR
done

# create tar file..
logmsg "Creating CDN export archive.."
TAR_OUTPUT=`cd $EXPORT_WORK_DIR && /bin/tar -czpf sat6-content-export_$DATE-$TIME.tgz content listing 2>&1`

if [ $? -eq 0 ]; then
  logmsg "done."
else
  logmsg "ERROR!, creating CDN archive failed, command output is:"
  errorlogmsg "ERROR!, creating CDN archive failed, command output is:"
  /bin/echo $TAR_OUTPUT | tee -a $LOGFILE
  /bin/echo $TAR_OUTPUT >> $ERRORLOGFILE
  exit 1
fi

# split into chuncked files..
logmsg "Splitting CDN archive into chuncks.."
SPLIT_OUTPUT=`cd $EXPORT_WORK_DIR && /usr/bin/split -d -b 3800M $EXPORT_WORK_DIR/sat6-content-export_${DATE}-${TIME}.tgz $EXPORT_WORK_DIR/sat6-content-export_${DATE}-${TIME}- 2>&1`

if [ $? -eq 0 ]; then
  logmsg "done."
else
  logmsg "ERROR!, splitting CDN archive failed, command output is:"
  errorlogmsg "ERROR!, splitting CDN archive failed, command output is:"
  /bin/echo $SPLIT_OUTPUT | tee -a $LOGFILE
  /bin/echo $SPLIT_OUTPUT >> $ERRORLOGFILE
  exit 1
fi

# create sha256sum entries for split files
logmsg "Creating export checksum.."
if [ -f $EXPORT_WORK_DIR/sat6-content-export_${DATE}-${TIME}-00 ]; then

  CHKSUM_OUTPUT=`cd $EXPORT_WORK_DIR && /bin/sha256sum sat6-content-export_${DATE}-${TIME}-* > sat6-content-export_${DATE}-${TIME}.sha256 2>&1`

  if [ $? -eq 0 ]; then
    logmsg "done."
  else
    logmsg "ERROR!, generating sha256sum failed, command output is:"
    errorlogmsg "ERROR!, generating sha256sum failed, command output is:"
    /bin/echo $CHKSUM_OUTPUT | tee -a $LOGFILE
    /bin/echo $CHKSUM_OUTPUT >> $ERRORLOGFILE
    exit 1
  fi
fi

logmsg "Creating sat6-content-export-expand.sh script.."
cat << EOF > $EXPORT_WORK_DIR/sat6-content-export-expand.sh
#!/bin/bash
if [ -f sat6-content-export_${DATE}-${TIME}-00 ]; then
  /usr/bin/sha256sum -c sat6-content-export_${DATE}-${TIME}.sha256
  if [ \$? -eq 0 ]; then
    cat sat6-content-export_${DATE}-${TIME}-* | tar xzpf -
  else
    echo "ERROR!, sat6-content-export_${DATE}-${TIME} checksum failure"
  fi
fi
echo "*** Expanding CDN archives complete ***"
EOF
/usr/bin/chmod 755 $EXPORT_WORK_DIR
/usr/bin/chmod 755 $EXPORT_WORK_DIR/sat6-content-export-expand.sh
logmsg "done."


# hook into synchost-push-export commands.. #################################

#
# done
#
logmsg "Complete."
exit 0

