#!/bin/bash

# Echo script name and time (start)
echo -n "$0, start at "
date
echo ""

# Read config file
conffile=$1
if test -r "$conffile" -a -f "$conffile"
then
	. $conffile
else
	echo "Call: $0 <conffile>"
	exit
fi

# Check the parameter read from the config file and set
# default values if necessary
host=${host:-"localhost"}
port=${port:-3306}
database=${database:-"bruteforce"}
user=${user:-"bruteforce"}
password=${password:-""}

# MySQL command string
mysqlcmd="mysql -h $host -P $port -u $user -p$password \
        -D $database"

# Create temporary file for the sshd logs
tempfile="/tmp/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13).txt"
touch $tempfile

# Ask journalctl for all sshd logs with "Invalid user" and
# pipe them to the temporary file
echo "Scanning journalctl . . ."
journalctl -o short-unix -u ssh | grep "Invalid user" > $tempfile
echo "  Completed."
echo ""

# Loop through every log message, extract the data and store
# it into database
echo -n "Processing "
while read line; do
	IFS=' ' read -ra data <<< "$line"
	#echo ${data[@]}
	time_unix=${data[0]}
	proc_id=${data[2]}
	user=${data[5]}
	source_ip=${data[7]}
	source_port=${data[9]}

	$mysqlcmd -e "insert ignore into ssh_logs \
		(time,user,source_ip,source_port) values \
		($time_unix,\"$user\",\"$source_ip\", \
		$source_port);"

	echo -n "."

done < $tempfile
echo " finished."

# Delete temporary file
rm $tempfile

# Echo script name and time (end)
echo -n "$0, end at "
date
echo ""

# SQL to set-up database for this script
# CREATE TABLE ssh_logs (time real, user text, source_ip text, source_port integer);
# CREATE UNIQUE INDEX unique_time_stamp on ssh_logs(time);

