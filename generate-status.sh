#!/bin/sh
# Generate a HTML page indicating the current status of mass build fixing
# (C) 2018 Bernhard "Bero" Rosenkraenzer <bero@lindev.ch>
# Released under the GPLv3

OURDIR="$(realpath $(dirname $0))"

. ${OURDIR}/abftools.sh

if [ -z "$1" -o -n "$2" ]; then
	echo "Usage: $0 mass-build-number"
	exit 1
fi

cat <<EOF
<html>
	<head>
		<title>OpenMandriva mass build $1 status</title>
		<style type="text/css">
tr:nth-child(even) { background-color: #d0d0d0; }
tr:nth-child(odd) { background-color: white; }
tr.fixed { background-color: green; }
		</style>
	</head>
	<body>
EOF

rm -f failed_builds_list.txt
wget https://abf.openmandriva.org/platforms/cooker/mass_builds/$1/failed_builds_list.txt
if ! [ -e failed_builds_list.txt ]; then
	echo "Mass build $1 doesn't seem to exist"
	echo '</body></html>'
	exit 1
fi

echo '		<table>'
echo '			<tr><th>Build</th><th>Project</th><th>Arch</th><th>Status</th></tr>'
cat failed_builds_list.txt |while read r; do
	ID="$(echo $r |cut -d';' -f1 |cut -d':' -f2 |xargs echo)"
	PROJECT="$(echo $r |cut -d';' -f2 |cut -d':' -f2 |xargs echo)"
	ARCH="$(echo $r |cut -d';' -f3 |cut -d':' -f2 |xargs echo)"
	LATEST="$(latestSuccessfulBuild cooker $PROJECT $ARCH)"
	LOG="$(buildlog $ID)"
	FIXED=false
	if [ -n "$LATEST" ]; then
		if [ "$LATEST" -ge "$ID" ]; then
			FIXED=true
		fi
	fi
	if $FIXED; then
		echo "			<tr class=\"fixed\">"
	else
		echo "			<tr>"
	fi
	echo "				<th><a href=\"http://abf.openmandriva.org/build_lists/$ID\">$ID</a></th>"
	echo "				<td><a href=\"http://github.com/OpenMandrivaAssociation/$PROJECT\">$PROJECT</a></td>"
	echo "				<td>$ARCH</td>"
	if $FIXED; then
		echo "				<td><a href=\"http://abf.openmandriva.org/build_lists/$LATEST\">FIXED</a></td>"
	else
		if [ -z "$LOG" ]; then
			echo -n "				<td>Log not found, infra error?</td>"
		else
			wget -O build.log $LOG
			echo -n "				<td><a href=\"$LOG\">"
			if grep -q "Only garbage was found in the patch input" build.log; then
				echo -n "Uses compressed patch, not supported by rpm4"
			elif grep -q "Could not find suitable distribution for Requirement" build.log; then
				echo -n "Missing python dependency"
			elif grep -q "Command not found" build.log; then
				echo -n "Missing tool dependency"
			elif grep -q "hunk FAILED" build.log; then
				echo -n "Patch failed to apply"
			elif grep -q "Could not find the zlib library" build.log; then
				echo -n "Missing zlib dependency"
			elif grep -q "\(you may need to install the .* module\)" build.log; then
				echo -n "Missing perl dependency"
			elif grep -q "error: cannot find -l" build.log; then
				echo -n "Missing library dependency"
			else
				echo -n "Unknown failure"
			fi
			echo "</a></td>"
		fi
	fi
	echo "			</tr>"
done
echo '		</table>'
echo '	</body>'
echo '</html>'
