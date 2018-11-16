#!/bin/sh
[ -e /etc/sysconfig/massbuild.conf ] && . /etc/sysconfig/massbuild.conf
if [ -z "$ABFAUTH" ]; then
	echo "Set ABFAUTH=YOUR_API_KEY: in /etc/sysconfig/massbuild.conf"
	exit 1
fi
cd /opt/Mass_build_fail_scripts
git pull
if [ -e massbuild.lock ]; then
	echo "Previous iteration still running" >&2
	exit 1
fi
touch massbuild.lock
[ -e /home/omv/massbuild/massbuild-new.html ] && rm -rf /home/omv/massbuild/massbuild-new.html
[ ! -e /home/omv/massbuild/massbuild-new.html ] && touch /home/omv/massbuild/massbuild-new.html && chown massbuild:massbuild /home/omv/massbuild/massbuild-new.html

./generate-status.sh 182 >/home/omv/massbuild/massbuild-new.html
mv -f /home/omv/massbuild/massbuild-new.html /home/omv/massbuild/massbuild.html
rm -f massbuild.lock
