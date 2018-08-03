#!/bin/sh
# Determine which mass build failures have already been fixed
# (C) 2018 Bernhard "Bero" Rosenkraenzer <bero@lindev.ch>
# Released under the GPLv3

OURDIR="$(realpath $(dirname $0))"

. ${OURDIR}/abftools.sh

if [ -z "$1" -o -n "$2" ]; then
	echo "Usage: $0 mass-build-number"
	exit 1
fi
rm -f failed_builds_list.txt *.json
wget https://abf.openmandriva.org/platforms/cooker/mass_builds/$1/failed_builds_list.txt
if ! [ -e failed_builds_list.txt ]; then
	echo "Mass build $1 doesn't seem to exist"
	exit 1
fi

cat failed_builds_list.txt |while read r; do
	ID="$(echo $r |cut -d';' -f1 |cut -d':' -f2 |xargs echo)"
	PROJECT="$(echo $r |cut -d';' -f2 |cut -d':' -f2 |xargs echo)"
	ARCH="$(echo $r |cut -d';' -f3 |cut -d':' -f2 |xargs echo)"
	echo -n "ID $ID, Project $PROJECT, Arch $ARCH: "
	LATEST="$(latestSuccessfulBuild cooker $PROJECT $ARCH)"
	if [ -n "$LATEST" ]; then
		if [ "$LATEST" -ge "$ID" ]; then
			echo "FIXED"
		else
			echo "Likely still broken"
		fi
	else
		echo "Likely still broken"
	fi
done
