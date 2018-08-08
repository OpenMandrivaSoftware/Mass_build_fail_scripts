#!/bin/sh
if [ -z "$ABFAUTH" ]; then
	echo "Set ABFAUTH=YOUR_API_KEY: in /etc/sysconfig/massbuild.conf"
	exit 1
fi
cd /opt/Mass_build_fail_scripts
git pull
./generate-status.sh 155 >massbuild-new.html
mv -f massbuild-new.html massbuild.html
