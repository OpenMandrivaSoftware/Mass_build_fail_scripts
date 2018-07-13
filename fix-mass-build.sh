#!/bin/sh
# Automatically fix some common errors detected during mass build
# (C) 2018 Bernhard "Bero" Rosenkraenzer <bero@lindev.ch>
# Released under the GPLv3


# Get the build log URL from an ABF build id
# Example:
#	buildlog 193516
#	Returns URL to build.log for build 193516
buildlog() {
	cat $build.json |python -c '
import sys,json
logs=json.load(sys.stdin)["build_list"]["logs"]
for i in logs:
	if i["file_name"] == "build.log":
		print(i["url"])
'
}

# Check out a package from git
checkout() {
	rm -rf "$1"
	git clone git@github.com:OpenMandrivaAssociation/"$1".git
}

# Commit changes to git and remove the checkout
commit() {
	cd "$1"
	git commit -am "Fix build failure"
	git push origin master
	cd ..
	rm -rf "$1"
}

# Add build dependency to a package
# Example:
#	addBuildDep kfilemetadata 'cmake(Qt5Core)'
#	Adds
#		BuildRequires: cmake(Qt5Core)
#	to the kfilemetadata spec file and commits the result
addBuildDep() {
	local PKG="$1"
	cd "$PKG"
	shift
	if grep -qiE "^BuildRequires:[[:space:]]*`echo $@ |sed -e 's,(,\\\(,g;s,),\\\),g'`[[:space:]]*" *.spec; then
		echo "	$PKG already requires $@ -- probably fixed earlier"
		return
	fi
	# Let's see if there's any other BuildRequires so we can match indentation...
	if grep -qiE '^BuildRequires[[:space:]]*:.*' *.spec; then
		local BR="$(grep -iE '^BuildRequires[[:space:]]*:[[:space:]]*' *.spec |head -n1)"
		echo "BR: $BR"
		local DEP="$(echo $BR |cut -d: -f2- |sed -e 's,^[[:space:]]*,,')"
		echo "DEP: $DEP"
		local OLDIFS="$IFS"
		export IFS=@
		echo $BR |sed -e "s,$DEP,$@," >ND.$$; NEWDEP="$(cat ND.$$)"; rm -f ND.$$
		echo "NEWDEP: $NEWDEP"
		#sed -i -e "/^BuildRequires/Ii$NEWDEP" *.spec
		sed -i -e "0,/^BuildRequires/Is//$NEWDEP\n&/" *.spec
		export IFS=$OLDIFS
	else
		echo "No previous BuildRequires"
	fi
	cd ..
}

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

for build in $(cat failed_builds_list.txt |cut -d';' -f1 |cut -d' ' -f2 |sort |uniq); do
	PACKAGE=$(cat failed_builds_list.txt |grep "^ID: $build;" |cut -d';' -f2 |cut -d' ' -f3)
	echo -n "$build: $PACKAGE: "
	if ! [ -e $build.log ]; then
		wget https://abf.openmandriva.org/api/v1/build_lists/$build.json
		buildlog="$(buildlog $build)"
		if [ -z "$buildlog" ]; then
			echo "$build: No build log --> infra error?"
			continue
		fi
		wget -O $build.log $buildlog
	fi
	if grep -q "Only garbage was found in the patch input" $build.log; then
		echo "Uses compressed patch, not supported by rpm4"
		# TODO uncompress patches, adapt spec, commit, rebuild
	elif grep -q "Could not find suitable distribution for Requirement" $build.log; then
		echo "Missing python dependency"
		# TODO identify dependency, add to spec, commit, rebuild
	elif grep -q "Command not found" $build.log; then
		echo "Missing tool dependency"
		# TODO identify dependency, add to spec, commit, rebuild
	elif grep -q "hunk FAILED" $build.log; then
		echo "Patch failed to apply -- needs manual attention"
	elif grep -q "Could not find the zlib library" $build.log; then
		echo "Missing zlib dependency"
		checkout $PACKAGE
		addBuildDep $PACKAGE 'pkgconfig(zlib)'
		commit $PACKAGE
	elif grep -q "\(you may need to install the .* module\)" $build.log; then
		echo -n "Missing perl dependencies: "
		BD=""
		while read r; do
			BD="$BD perl($r)"
		done  <<<"$(grep '(you may need to install the .* module)' $build.log |sed -E 's,.*\(you may need to install the (.*) module\).*,\1,g' |sort |uniq)"
		echo "$BD -- auto-fixing"
		checkout $PACKAGE
		for i in $BD; do
			addBuildDep $PACKAGE $i
		done
		commit $PACKAGE
	else
		echo "Unknown error -- needs manual attention"
	fi
done
