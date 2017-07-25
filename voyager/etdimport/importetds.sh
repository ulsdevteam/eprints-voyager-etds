#!/bin/bash
# This script will poll the d-scholarship server for newly exported MARC files of ETDs.
# No parameters are used; must be run as user "voyager"
# If new ETD MARC files are found, these will be imported into Voyager via bulkimport
# Only one MARC file will be processed at a time to ensure changes are serialized...
#   ...this script can (should) be cron'd multiple times daily
if [ "$USER" != 'voyager' ]
then
	>&2 echo 'This script must be run as user voyager'
	exit 1
fi
# There is a directory which holds the incoming and processed files
ETDIMPORT=/opt/local/etdimport
# New files to be processed are delivered here
PROCESSING=$ETDIMPORT/processing
# Files which have been processed are archived here
PROCESSED=$ETDIMPORT/processed
# The server is set to d-scholarship development, unless our hostname is production
SERVER=d-scholarship-dev.library.pitt.edu
if [ `hostname` = 'voy-web-prod-01.cssd.pitt.edu' -o `hostname` = 'voy-web-prod-02.cssd.pitt.edu' ]
then
	SERVER=d-scholarship.pitt.edu
fi
# This is where the to-be-processed files live on the remote server
PICKUP=/var/local/marc_etd
echo 'Copying any new marc files from '$SERVER
NEWFILES=`ssh $SERVER "echo $PICKUP/*.mrc"`
if [ "$NEWFILES" != $PICKUP/'*.mrc' ]
then
	scp -q voyager@$SERVER:$PICKUP/*.mrc $PROCESSING
fi
echo 'Removing captured marc files, if needed'
for marc in $PROCESSING/*.mrc
do
	if [ "$marc" != $PROCESSING/'*.mrc' ]
	then
		marcfile=`basename $marc`
		echo '... '$marcfile
		ssh $SERVER "if [ -e $PICKUP/$marcfile ]; then rm -f $PICKUP/$marcfile; fi"
	fi
done
echo 'Selecting earliest file for processing'
for marc in $PROCESSING/*.mrc
do
	if [ "$marc" != $PROCESSING/'*.mrc' ]
	then
		marcfile=`basename $marc`
		echo '... '$marcfile
		mv $marc $PROCESSED/$marcfile
		/m1/voyager/pittdb/sbin/Pbulkimport -Nulsimports@mail.pitt.edu -iETD -oETD -f$PROCESSED/$marcfile
		if [ "$!?" = "1" ]
		then
			echo 'The Pbulkimport processed aborted with a trappable error, resetting '$marcfile
			mv $PROCESSED/$marcfile $marc
		fi
		exit
	else
		echo '... Nothing to do.'
	fi
done
