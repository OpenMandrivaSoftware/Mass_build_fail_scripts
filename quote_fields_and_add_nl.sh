#Add quotes then remove + and add new line
gawk --field-separator=";" '{ OFS=";"; print $1 ";" $2 ";" $3";"$4";"  "\"" $5 "\""}' ./failed_mass_rebuilds1.txt >mssrbld.txt
#sed ':a;N;$!ba;s/+/\n/g' mssrbld.txt >final.txt

