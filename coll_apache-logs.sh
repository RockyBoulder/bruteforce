#!/bin/bash

# Database file
#db="/root/bad_logs.db"
db=$1

# Create temporary file for the sshd logs
tempfile="/tmp/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13).txt"
touch $tempfile

# Search for all apache logs with message "script
# [...] not found or unable to stat" and pipe them to the
# temporary file
for logfile in /var/log/apache2/error.log*; do
	filename=`basename $logfile`
	extension=${filename##*.}
	if [ "$extension" == "gz" ]
	then
		zcat $logfile | grep "not found or unable to stat" >> $tempfile
	else
		cat $logfile | grep "not found or unable to stat" >> $tempfile
	fi
done
sed -i -e "s/\[//g" $tempfile
sed -i -e "s/\]//g" $tempfile

# Loop through every log message, extract the data and store
# it into database
while read line; do
	IFS=' ' read -ra data <<< "$line"

	timestr="${data[0]} ${data[1]} ${data[2]} ${data[3]} ${data[4]}"
	time_unix=`date --utc --date "$timestr" +%s`
	process_id=${data[7]}
	source_ip=`echo ${data[9]} | awk -F ":" '{print $1}'`
	source_port=`echo ${data[9]} | awk -F ":" '{print $2}'`
	script=${data[11]}

	sqlite3 $db "insert or ignore into apache_logs \
		(time,script,source_ip,source_port) values \
	       	($time_unix,\"$script\",\"$source_ip\",$source_port);"
done < $tempfile

# Delete temporary file
rm $tempfile

# SQL to set-up database for this script
# CREATE TABLE apache_logs (time real, script text, source_ip text, source_port integer);
# CREATE UNIQUE INDEX unique_time_stamp2 on apache_logs(time);