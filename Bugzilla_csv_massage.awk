#!/bin/sh
#Clean up Bugzilla csv output to make it suitable for google sheets
#The tr -d '"' is not really necessary also an extra command is needed to remove the Bugzilla header and in the case of a new bug list replace it with our own or else leave it off entirely.

cat bugs-2015-04-22.csv | tr -d '"' |  awk -F , 'BEGIN {OFS = ","} {printf $1","; ($1 = "https://issues.opennmandriva.org/show_bug.cgi?id="$1); print "\""$1"\""","  $4"," $5"," $6"," $3"," $8}' >bugs-20-08-2014.csv

