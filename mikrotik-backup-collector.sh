#!/bin/bash

# -------------------------------------------------------
#   Mikrotik Backup Collector
# -------------------------------------------------------

## Exit if any statement returns a non-true value
set -e

## Initialize Variables
WORKDIR="$(dirname "$(readlink -f "$0")")" 
HOSTS="$WORKDIR/hosts.txt"
PRIVKEY="$WORKDIR/.ssh/id_rsa"
FILENAME=`date +\%Y\%m\%d`
SSH_PORT="22"
KNOCK01=""
KNOCK02=""
CONNECT_TIMEOUT=5 # Timeout in Seconds while initiating the connection

## Load your custom Variables, if provided
[ -r "$WORKDIR/.env" ] && source "$WORKDIR/.env"

## Loop to load arguments
while [[ $# -gt 0 ]]
do
  case "$1" in
	--initial )      INIT=true; shift; ;;	# To add hosts to SSH known hosts file
	--parallel )     PARA=true; shift; ;;	# To run backup tasks simultaneously
	-- )             shift; break ;;
    * )              shift; ;;
  esac
done

# Create/Append logfile
date | tee -a $WORKDIR/backup.log

## Main Backup Task
function backup {
	backup_dir="${WORKDIR}/${alias}/`date +\%Y\%m`"
	mkdir -p $backup_dir

	# echo "---------------"
	# echo "Starting Backup of" $alias

	# Export Compact
	# Use SSH -n and SCP </dev/null to prevent eating up the actionlist
	ssh -n backup@${ip} -o ConnectTimeout=${CONNECT_TIMEOUT} -i $PRIVKEY -p ${SSH_PORT} /export compact > $backup_dir/$FILENAME.rsc

	# Backup Unencrypted
	ssh -n -o ConnectTimeout=${CONNECT_TIMEOUT} -i $PRIVKEY backup@${ip} -p ${SSH_PORT} /system backup save dont-encrypt=yes name=last.backup > /dev/null
	scp -q -o ConnectTimeout=${CONNECT_TIMEOUT} -i $PRIVKEY -P ${SSH_PORT} backup@${ip}:/last.backup $backup_dir/$FILENAME.backup </dev/null

	# Check the files ...
	#	-s			... exist and are not empty
	#   -nmin 5		... are not older than 5 Minutes
	test -s $backup_dir/$FILENAME.rsc && test `find "$backup_dir/$FILENAME.rsc" -mmin -5` \
		&& echo "[Success] $alias: Export-Compact ✓" \
		| tee -a $WORKDIR/backup.log \
		|| { echo "[Error] Something's wrong with export compact of $alias"; exit 1; } \
		| tee -a $WORKDIR/backup.log

	test -s $backup_dir/$FILENAME.backup && test `find "$backup_dir/$FILENAME.backup" -mmin -5` \
		&& echo "[Success] $alias: Backup ✓" \
		| tee -a $WORKDIR/backup.log \
		|| { echo "[Error] Something's wrong with the backup of $alias"; exit 1; } \
		| tee -a $WORKDIR/backup.log
}

# Read the provided file
grep -v '^#' ${HOSTS} | while read ip alias
do
	[ -z "$alias" ] && { echo "Missing Alias of ${ip}. Stopping Backup now."; exit 1; }
	
	# Knock Knock
	curl --silent --connect-timeout ${CONNECT_TIMEOUT} --fail ${ip}:${KNOCK01} ${ip}:${KNOCK02} | :

	if [ "$INIT" = true ]
	then
		# Add SSH Fingerprint to the list of known hosts
		ssh backup@${ip} -n -i $PRIVKEY -o StrictHostKeyChecking=no -o ConnectTimeout=${CONNECT_TIMEOUT} -p ${SSH_PORT} /system resource print
	fi

	if [ "$PARA" = true ]
	then
		# Start backups in parallel. Output will be printed with some delay.
		backup &
	else
		# Normal / Sequential runs
		backup
	fi
done
