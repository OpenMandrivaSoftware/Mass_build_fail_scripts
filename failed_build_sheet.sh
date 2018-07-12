#abf-logger-v2.sh
#!/bin/bash
set -x
set -e
projects_list=$1
platform=cooker

echo "" > failed_mass_rebuild2.txt

while read LINE
do
    project_id=`echo "$LINE" | awk '{print $2}' | sed s,";",,`
    project_name=`echo "$LINE" | awk '{print $4}' | sed s,";",,`
    project_arch=`echo "$LINE" | awk '{print $6}' | sed s,";",,`
    # project_log_file=`lynx --dump https://abf.rosalinux.ru/api/v1/build_lists/$project_id.json | python -m json.tool | grep -A 2 rpm-worker | tail -n 1 | awk '{print $2}' | sed s,\",,g`
    project_log_file=`curl -L https://abf.openmandriva.org/api/v1/build_lists/$project_id.json | python -m json.tool | grep -A 2 rpm-worker | tail -n 1 | awk '{print $2}' | sed s,\",,g`

    if [ -z $project_log_file ]
    then
        project_log_file="none"
        continue
    fi
    # project_log=`dog $project_log_file`
    project_log=`curl -L $project_log_file`
    error_java=`echo "$project_log" | grep '\[java'`
    error_autotools=`echo "$project_log" | grep -E 'aclocal(.*)required but not defined|error:(.*)automatic de-ANSI-fication support'`
    error_api=`echo "$project_log" | grep -E 'error:(.*)field(.*)has incomplete type'`
    error_conflicting_types=`echo "$project_log" | grep -E 'error:(.*)conflicting types for'`
    error_segfault=`echo "$project_log" | grep 'Segmentation fault'`
    error_bad_file=`echo "$project_log" | grep 'Bad file'`
    error_git=`echo "$project_log" | grep '404 Not Found'`
    error_deps=`echo "$project_log" | grep 'is needed by'`
    error_deps2=`echo "$project_log" | grep 'due to unsatisfied'`
    error_deps_pkg=`echo "$project_log" | grep 'PKG_CONFIG_PATH'`
    error_files=`echo "$project_log" | grep 'File not found'`
    error_linkage=`echo "$project_log" | grep 'could not read symbols'`
    error_undeclared=`echo "$project_log" | grep 'was not declared in this scope'`
    error_twice=`echo "$project_log" | grep 'File listed twice'`
    error_sfmt=`echo "$project_log" | grep 'format not a string literal'`
    error_arch=`echo "$project_log" | grep 'Architecture is not included: x86_64'`
    error_automake13=`echo "$project_log" | grep -E 'configure(.*)AM_CONFIG_HEADER(.*)obsolete'`
    error_uclibc=`echo "$project_log" | grep 'cannot run C compiled programs'`
    error_chroot=`echo "$project_log" | grep -E 'You may need to update your urpmi database'`
    error_rpmlint=`echo "$project_log" | grep -E 'badness(.*)exceeds threshold'`
    error_clang=`echo "$project_log" | awk '/Traceback/{exit};/clang: error:(.*)/'`
    error_clang1=`echo "$project_log" | awk '/Traceback{exit}/;/error: unknown type name/'`
    error_python=`echo "$project_log" | awk '/clang: error:(.*)/{exit};/Traceback/'`
    error_cplusplus=`echo "$project_log"| grep -E 'error: private field'`
#    error_package_check=`echo "$project_log"| grep -E 'error: Package check'`
#    error_syntax=`echo "$project_log" | grep -E 'error: private field'`
    status=''
    if [ -n "$error_java" ]; then
  status="Java package"
    fi
    if [ -n "$error_autotools" ]; then
  status="Autotools issue"
    fi
    if [ -n "$error_api" ]; then
  status="API issue"
    fi
    if [ -n "$error_conflicting_types" ]; then
  status="Conflicting types"
    fi
    if [ -n "$error_segfault" ]; then
  status="Compiler segfault"
    fi
    if [ -n "$error_bad_file" ]; then
  status="Missing source"
    fi
    if [ -n "$error_git" ]; then
  status="git issues"
    fi
    if [ -n "$error_deps" ]; then
  status=`echo "$project_log" | grep 'is needed by' | head -n 1 | sed -e 's/^[ \t]*//'`
    fi
    if [ -n "$error_deps2" ]; then
  status=`echo "$project_log" | grep 'due to unsatisfied' | head -n 1 | sed -e 's/^[ \t]*//'`
    fi
    if [ -n "$error_deps_pkg" ]; then
  status=`echo "$project_log" | grep -E 'No package(.*)found' | awk '{print "BR issue ("$3" not detected by pkgconfig)"}' | head -n 1`
    fi
    if [ -n "$error_files" ]; then
  status="file not found"
    fi
    if [ -n "$error_linkage" ]; then
  status="linkage issues"
    fi
    if [ -n "$error_undeclared" ]; then
  status="not declared in this scope"
    fi
    if [ -n "$error_twice" ]; then
  status="file listed twice"
    fi
    if [ -n "$error_sfmt" ]; then
  status="format not a string literal"
    fi
    if [ -n "$error_arch" ]; then
  status="Architecture is not included: x86_64"
    fi
    if [ -n "$error_automake13" ]; then
  status="Automake 1.13 issues"
    fi
    if [ -n "$error_uclibc" ]; then
  status="ABF uclibc issues"
    fi
    if [ -n "$error_chroot" ]; then
  status="ABF chroot issues"
    fi
    if [ -n "$error_rpmlint" ]; then
  status="Rpmlint issue"
  #status=`echo "$project_log"  | awk '{lines[NR] = $0} /^error: Package check/ {{print "Error: Package Check:"} for (i=(NR-5); i<=(NR-2); i++) {print lines[i]}}' | sed '/^$/d' | sed ':a;N;$!ba;s/\n/+/g'`
    fi
    if [ -n "$error_cplusplus" ]; then
  status=`echo "$project_log" | grep -E 'error: private field'`
    fi
    if [ -n "$error_clang" ]; then
  status=`echo "$project_log" | awk 'BEGIN{FS=":"; a=""} /clang: error:(.*)/{a=$0" #";printf a}'`
    fi
    if [ -n "$error_clang1" ]; then
  status=`echo "$project_log" |  awk '/error: unknown type name/{print;exit}'`
    fi
    #if [ -n "$error_package_check" ]; then
    #status=`echo "$project_log"  | awk '{lines[NR] = $0} /^error: Package check/ {{print "Error: Package Check:"} for (i=(NR-5); i<=(NR-2); i++) {print lines[i]}}' | sed '/^$/d' | sed ':a;N;$!ba;s/\n/+/g'`
    #fi
    if [ -n "$error_python" ]; then
  status=`echo "$project_log" | awk '/UnicodeEncodeError:/||/error: unknown type name/||/^SyntaxError: invalid syntax/||/error: Package check/ {print;exit};/^error:/||/^ImportError:/||/$SyntaxError/||/UnicodeDecodeError:/||/AttributeError:/||/SysyemError:/||/UnicodeEncodeError:/{print;exit}flag;/^Traceback \(most recent call last\):/{flag=1;print}'| sed '/^$/d' | sed ':a;N;$!ba;s/\n/+/g'` 
       if [ -n "`echo "$status" | grep -E '^SyntaxError: invalid syntax$'`" ]; then 
  status=`echo "$project_log" | awk '{lines[NR] = $0} /^SyntaxError: invalid syntax/ {count++;{if (count <=1) {for (i=(NR-5); i<=(NR+1); i++) {print lines[i]}} else {c=count}}} END {if (c >0) {print "There are "(c-1)" more Syntax Errors"}}'| sed '/^$/d' | sed ':a;N;$!ba;s/\n/+/g'` 
       fi
    fi
    echo "https://abf.openmandriva.org/build_lists/$project_id;$project_name;$project_arch;;;"
    echo "https://abf.openmandriva.org/build_lists/$project_id;$project_name;$project_arch;;$status" >> failed_mass_rebuild.txt
done < $projects_list

