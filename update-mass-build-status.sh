#!/bin/sh
[ -e /etc/sysconfig/massbuild.conf ] && . /etc/sysconfig/massbuild.conf
if [ -z "$ABFAUTH" ]; then
	printf '%s\n' "Set ABFAUTH=YOUR_API_KEY: in /etc/sysconfig/massbuild.conf"
	exit 1
fi
if [ -z "$MASSBUILD_ID" ]; then
	printf '%s\n' "Set MASSBUILD_ID= in /etc/sysconfig/massbuild.conf to run scripts"
	exit 1
fi
cd /opt/Mass_build_fail_scripts
git pull
if [ -e massbuild.lock ]; then
	printf '%s\n'  "Previous iteration still running" >&2
	exit 1
fi
touch massbuild.lock
[ -e /home/omv/massbuild/massbuild-new.html ] && rm -rf /home/omv/massbuild/massbuild-new.html
[ ! -e /home/omv/massbuild/massbuild-new.html ] && touch /home/omv/massbuild/massbuild-new.html && chown massbuild:massbuild /home/omv/massbuild/massbuild-new.html

. /etc/sysconfig/massbuild.conf
./generate-status.sh "$MASSBUILD_ID" >/home/omv/massbuild/massbuild-new.html
mv -f /home/omv/massbuild/massbuild-new.html /home/omv/massbuild/massbuild.html
rm -f massbuild.lock
