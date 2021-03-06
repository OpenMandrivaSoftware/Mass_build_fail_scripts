# Library of shell functions for working with ABF
# (C) 2018 Bernhard "Bero" Rosenkraenzer <bero@lindev.ch>
# Released under the GPLv3

abfAuth() {
	if [ -z "$ABFAUTH" ]; then
		local user="$(cat ~/.abfcfg |grep '^login =' |cut -d= -f2 |xargs echo)"
		local pass="$(cat ~/.abfcfg |grep '^password =' |cut -d= -f2 |xargs echo)"
		if [ -z "$user" -o -z "$pass" ]; then
			local auth
			. ~/.abbrc
			user="$(echo $auth |cut -d: -f1)"
			pass="$(echo $auth |cut -d: -f2)"
			if [ -z "$user" -o -z "$pass" ]; then
				echo "You need to set up your ABF login in ~/.abfcfg or ~/.abbrc"
				exit 1
			fi
		fi
		export ABFAUTH="$user:$pass"
	fi
	echo -n $ABFAUTH
}

# Parse a simple json fragment
# Example:
#	curl https://abf.openmandriva.org/api/v1/arches |parseJson '["architectures"]' name id aarch64
#	Looks up the architecture ID of aarch64
parseJson() {
	python -c "
import sys,json
entries=json.load(sys.stdin)$1
for i in entries:
	if str(i[\"$2\"]) == str(\"$4\"):
		print(i[\"$3\"])
"
}

# Get the build log URL from an ABF build id
# Example:
#	buildlog 193516
#	Returns URL to build.log for build 193516
#	buildlog 193516 script_output.log
#	Returns URL to script_output.log for build 193516
buildlog() {
	local LOGFILE="$2"
	[ -z "$LOGFILE" ] && LOGFILE="build.log"
	if [ -e $1.json ]; then
		cat $1.json |parseJson '["build_list"]["logs"]' file_name url build.log |head -n1
	else
		curl -m 120 --retry 5 --user $(abfAuth) -s https://abf.openmandriva.org/api/v1/build_lists/$1.json |parseJson '["build_list"]["logs"]' file_name url "$LOGFILE" |head -n1
	fi
}

# Get the ID for an arch
#	archId znver1
# --> returns znver1's arch ID (currently 7)
archId() {
	curl -m 120 --retry 5 --user $(abfAuth) -s https://abf.openmandriva.org/api/v1/arches |parseJson '["architectures"]' name id $1
}

# Get the ID for an arch
#	platformId cooker
# --> returns Cooker's arch ID (currently 28)
platformId() {
	curl -m 120 --retry 5 -s --user $(abfAuth) https://abf.openmandriva.org/api/v1/platforms.json?type=main |parseJson '["platforms"]' name id $1
}

# Get the latest successful (== published) ID of a build
#	latestSuccessfulBuild platform packagename arch
# e.g.
#	latestSuccessfulBuild cooker boost znver1
# Gets the build ID for the last successful build of boost
# on cooker for znver1
latestSuccessfulBuild() {
	local platform=$(platformId $1)
	local arch=$(archId $3)
	curl -m 120 --retry 5 -s --user $(abfAuth) "https://abf.openmandriva.org/api/v1/build_lists.json?filter\\[status\\]=6000&filter\\[project_name\\]=$2&filter\\[arch_id\\]=$arch&filter\\[build_for_platform_id\\]=$platform" |parseJson '["build_lists"]' status id 6000 |head -n1
}
