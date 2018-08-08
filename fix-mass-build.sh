#!/bin/sh
# Automatically fix some common errors detected during mass build
# (C) 2018 Bernhard "Bero" Rosenkraenzer <bero@lindev.ch>
# Released under the GPLv3

OURDIR="$(realpath $(dirname $0))"

. ${OURDIR}/abftools.sh

# Check out a package from git
checkout() {
	rm -rf "$1"
	git clone git@github.com:OpenMandrivaAssociation/"$1".git
}

# Commit changes to git and remove the checkout
commit() {
	cd "$1"
	git commit -am "Fix build failure"
#	git show HEAD
	git push origin master
	cd ..
	rm -rf "$1"
	abf chain_build -a znver1 -a x86_64 -a i686 -a aarch64 -a armv7hnl -b master --auto-publish --update-type enhancement openmandriva/$PACKAGE
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
		cd ..
		return
	fi
	# Let's see if there's any other BuildRequires so we can match indentation...
	if grep -qiE '^BuildRequires[[:space:]]*:.*' *.spec; then
		local BR="$(grep -iE '^BuildRequires[[:space:]]*:[[:space:]]*' *.spec |head -n1)"
		local DEP="$(echo $BR |cut -d: -f2- |sed -e 's,^[[:space:]]*,,')"
		local OLDIFS="$IFS"
		export IFS=@
		echo $BR |sed -e "s,$DEP,$@," >ND.$$; NEWDEP="$(cat ND.$$)"; rm -f ND.$$
		sed -i -e "0,/^BuildRequires/Is//$NEWDEP\n&/" *.spec
		export IFS=$OLDIFS
	else
		echo "No previous BuildRequires"
	fi
	cd ..
}

# Try to fix a build
# Usage:
#	fixBuild buildId
fixBuild() {
	local build="$1"
	local PACKAGE=$(cat failed_builds_list.txt |grep "^ID: $build;" |cut -d';' -f2 |cut -d' ' -f3)
	local i
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
	elif grep -q "Could not find suitable distribution for Requirement.parse(" $build.log; then
		echo "Missing python dependency"
		checkout $PACKAGE
		while read r; do
			local DEP=$(echo $r |cut -d'(' -f2 |cut -d')' -f1 |sed -e "s,['\"]*,,g")
			if echo $DEP |grep -qE '[<=>]'; then
				local COMPARE=$(echo $DEP |sed -e 's,[^<=>]*,,;s,[^<=>].*,,')
				local VER=$(echo $DEP |sed -e 's,.*[<=>],,')
				DEP="$(echo $DEP |sed -e 's,[<=>].*,,')"
			else
				local COMPARE=""
				local VER=""
			fi
			DEP="$(echo python3egg\($DEP\) $COMPARE $VER)"
			addBuildDep $PACKAGE "$DEP"
		done <<<"$(grep 'Could not find suitable distribution for Requirement.parse(' $build.log)"
		commit $PACKAGE
		echo $build >>presumed-fixed.list
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
		echo $build >>presumed-fixed.list
	elif grep -q "\(you may need to install the .* module\)" $build.log; then
		echo -n "Missing perl dependencies: "
		BD=""
		while read r; do
			BD="$BD perl($r)"
		done  <<<"$(grep '(you may need to install the .* module)' $build.log |sed -E 's,.*\(you may need to install the (.*) module\).*,\1,g' |sort -r |uniq)"
		echo "$BD -- auto-fixing"
		checkout $PACKAGE
		for i in $BD; do
			addBuildDep $PACKAGE $i
		done
		commit $PACKAGE
		echo $build >>presumed-fixed.list
	elif grep -q "error: cannot find -l" $build.log; then
		LIBS=" "
		while read r; do
			local DEP="$(echo $r |sed -e 's,.*error: cannot find -l,,;s, .*,,;s,:.*,,')"
			LIBS="$LIBS $DEP"
		done <<<"$(grep 'error: cannot find -l' $build.log)"
		LIBS="$(echo $LIBS |sed -e 's, ,\n,g' |sort -r |uniq)"
		echo "Missing libs: $LIBS -- auto-fixing"
		checkout $PACKAGE
		for i in $LIBS; do
			if [ -n "$(dnf repoquery --whatprovides pkgconfig\($i\) 2>/dev/null)" ]; then
				addBuildDep $PACKAGE "pkgconfig($i)"
			elif [ -n "$(dnf repoquery --whatprovides pkgconfig\(lib$i\) 2>/dev/null)" ]; then
				addBuildDep $PACKAGE "pkgconfig(lib$i)"
			elif [ -n "$(dnf repoquery --whatprovides pkgconfig\(${i}lib\) 2>/dev/null)" ]; then
				addBuildDep $PACKAGE "pkgconfig(${i}lib)"
			else
				local lc="`echo $i |tr A-Z a-z`"
				if [ -n "$(dnf repoquery --whatprovides pkgconfig\($lc\) 2>/dev/null)" ]; then
					addBuildDep $PACKAGE "pkgconfig($lc)"
				elif [ -n "$(dnf repoquery --whatprovides pkgconfig\(lib$lc\) 2>/dev/null)" ]; then
					addBuildDep $PACKAGE "pkgconfig(lib$lc)"
				elif [ -n "$(dnf repoquery --whatprovides pkgconfig\(${lc}lib\) 2>/dev/null)" ]; then
					addBuildDep $PACKAGE "pkgconfig(${lc}lib)"
				else
					# Let's find SOME way to drag this in...
					local PROVIDER="$(dnf repoquery --whatprovides /usr/lib64/lib${i}.so 2>/dev/null |head -n1)"
					[ -z "$PROVIDER" ] && PROVIDER="$(dnf repoquery --whatprovides /lib64/lib${i}.so 2>/dev/null |head -n1)"
					[ -z "$PROVIDER" ] && PROVIDER="$(dnf repoquery --whatprovides /usr/lib/lib${i}.so 2>/dev/null |head -n1)"
					[ -z "$PROVIDER" ] && PROVIDER="$(dnf repoquery --whatprovides /lib/lib${i}.so 2>/dev/null |head -n1)"
					[ -z "$PROVIDER" ] && PROVIDER="$(dnf repoquery --whatprovides /usr/lib64/lib${i}.a 2>/dev/null |head -n1)"
					[ -z "$PROVIDER" ] && PROVIDER="$(dnf repoquery --whatprovides /lib64/lib${i}.a 2>/dev/null |head -n1)"
					[ -z "$PROVIDER" ] && PROVIDER="$(dnf repoquery --whatprovides /usr/lib/lib${i}.a 2>/dev/null |head -n1)"
					[ -z "$PROVIDER" ] && PROVIDER="$(dnf repoquery --whatprovides /lib/lib${i}.a 2>/dev/null |head -n1)"
					[ -z "$PROVIDER" ] && continue # Let's give up on this one...
					local FOUND=0
					local pc
					while read pc; do
						addBuildDep $PACKAGE "$(echo $pc |sed -e 's, .*,,')"
						FOUND=1
					done <<<"$(dnf repoquery --provides $PROVIDER |grep -E '^pkgconfig\(')"
					if [ "$FOUND" = "0" ]; then
						# Last resort... Let's try to be reasonable
						local dep
						while read dep; do
							addBuildDep $PACKAGE "$(echo $dep |sed -e 's, .*,,')"
						done <<<"$(dnf repoquery --provides $PROVIDER |grep -vE '^(devel\(|\(x86-64\)|^lib64)')"
					fi
				fi
			fi
		done
		commit $PACKAGE
	elif grep -q "/mdv/build-rpm.sh: No such file or directory" $build.log; then
		echo "Infra error --rebuilding"
		abf chain_build -a znver1 -a x86_64 -a i686 -a aarch64 -a armv7hnl -b master --auto-publish --update-type enhancement openmandriva/$PACKAGE
	else
		echo "Unknown error -- needs manual attention"
	fi
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
	grep -qE "^$build$" presumed-fixed.list 2>/dev/null && continue
	fixBuild $build
done
