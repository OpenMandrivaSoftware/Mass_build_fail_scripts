#abf-logger-v2.sh
#!/bin/bash
# projects_list = The failed mass build list of files
projects_list=$1
platform=cooker
# Empty the file we are appending to before starting
touch	./failed_mass_rebuilds.txt
echo "" > failed_mass_rebuilds.txt
#touch ./log_links.txt
#set -x 
#while read -u "$fd_num" LINE
while read  LINE
do
    project_id=`echo "$LINE" | awk '{print $2}' | sed s,";",,`
    project_name=`echo "$LINE" | awk '{print $4}' | sed s,";",,`
    project_arch=`echo "$LINE" | awk '{print $6}' | sed s,";",,`
    project_log_list_file=`curl -L https://abf.openmandriva.org/api/v1/build_lists/$project_id.json`
  if [ -z "$project_log_list_file" ]; then
	status="expired"
	echo "https://abf.openmandriva.org/build_lists/$project_id;$project_name;$project_arch;32;$status" >> failed_mass_rebuilds.txt
	continue
  else
	if [  `echo "$project_log_list_file" |  python -m json.tool | grep -A 2 publish_build | grep url | awk '{print $2}'` ]; then
    	    status="published"
	    echo "https://abf.openmandriva.org/build_lists/$project_id;$project_name;$project_arch;33;$status" >> failed_mass_rebuilds.txt
	    continue
	elif [  `echo "$project_log_list_file" |  python -m json.tool | grep -A 2 build\.log | grep size | tail -n1 |  awk '{print $2}'| sed s,\",,g  | grep ^0.0,$` ]; then
	    status="Dependency Error" #Missing or zero byte build.log indicates a catastrophic dependency error'
	    echo "https://abf.openmandriva.org/build_lists/$project_id;$project_name;$project_arch;34;$status" >> failed_mass_rebuilds.txt
	    continue
#	else #Get the script_output.log file
	else
    project_log_file=`echo "$project_log_list_file" | python -m json.tool | grep -A 2 script_output | grep url | awk '{print $2}' | sed s,\",,g`
    project_log_number=$project_id
	fi
 fi

#project_filter=`curl -L $project_log_file` 
project_log=`curl -L $project_log_file` 
#    project_filter1=`echo $project_filter | sed -n 'N;N;N;N;N;N;N;N;N;N;N;s/\n/ /; /^Traceback.*build-changelog.py.*UnicodeDecodeError:.*/p' | sed -n 'N;N;N;N;N;N;N;N;N;N;N;s/\n/ /; /^Traceback.*build-changelog.py.*UnicodeDecodeError:.*/p'`
#    echo $project_filter
#    exit
    
#    project_log=`echo $project_filter | pcregrep -Mv '.*build-changelog.py.*\n.*\n^UnicodeEncodeError:.*'` 
#set -x    
#     project_log=`echo $project_filter | pcregrep -Mv --buffer-size=1500k '^Traceback.*\n.*build-changelog.py.*\n.*\n.*build-changelog.py.*\n.*\n.*build-changelog.py.*\n.*\n.*build-changelog.py.*\n.*\n.*build-changelog.py.*\n.*\n^UnicodeEncodeError:.*'`
#    project_log=`echo "$project_filter" | pcregrep -M -v --buffer-size=40k '.*Error:.*'`
#    project_log=`echo "$project_filter" | pcregrep -Mv '.*Error:.*'`
#exit 
    error_java=`echo "$project_log" | egrep '(.*\[java.*)|(.*java\-.*)'`
    #1
    error_autotools=`echo "$project_log" | grep -E 'aclocal(.*)required but not defined|error:(.*)automatic de-ANSI-fication support'` 
    #2
    error_api=`echo "$project_log" | grep -E 'error:(.*)field(.*)has incomplete type'`
    #3
    error_conflicting_types=`echo "$project_log" | grep -E 'error:(.*)conflicting types for'`
    #4
    error_segfault=`echo "$project_log" | grep 'Segmentation fault'`
    #5
    error_bad_file=`echo "$project_log" | grep 'Bad file'`
    #6
    error_git=`echo "$project_log" | grep '404 Not Found'`
    #7
    error_deps=`echo "$project_log" | grep 'is needed by'`
    #8
    error_deps2=`echo "$project_log" | grep 'due to unsatisfied'`
    #9
    error_deps_pkg=`echo "$project_log" | grep 'not found in the pkg-config search path.' | tail -n1`
    #10
#    error_files=`echo "$project_log" | grep -E 'error: File not found|No such file or directory'`
    #11
    error_linkage=`echo "$project_log" | grep 'could not read symbols'`
    #12
    error_undeclared=`echo "$project_log" | grep 'was not declared in this scope'`
    #13
    error_twice=`echo "$project_log" | grep 'File listed twice'`
    #14
    error_sfmt=`echo "$project_log" | grep 'format not a string literal'`
    #15
    error_arch=`echo "$project_log" | grep 'Architecture is not included: x86_64'`
    #16
    error_automake13=`echo "$project_log" | grep -E 'configure(.*)AM_CONFIG_HEADER(.*)obsolete'`
    #17
    error_uclibc=`echo "$project_log" | grep 'cannot run C compiled programs'`
    #18
    error_chroot=`echo "$project_log" | grep -E 'You may need to update your urpmi database'`
    #19
    error_rpmlint=`echo "$project_log" | grep -E 'badness(.*)exceeds threshold'`
    #20
    error_cplusplus=`echo "$project_log"| grep -E 'error: private field'`
    #21
    error_clang=`echo "$project_log" | awk '/Traceback/{exit};/clang: error:(.*)/'`
    #22
    error_clang1=`echo "$project_log" | awk '/Traceback{exit}/;/error: unknown type name/'`
    #23
    error_syntax=`echo "$project_log" | awk '/Traceback/{exit};/^SyntaxError: invalid syntax$/'`
    #24
    error_command=`echo "$project_log" | awk '/^error: command/'`
    #25
    error_python=`echo "$project_log" | awk '/clang: error:(.*)/{exit};/Traceback/'`
    #26
    error_no_proj=`echo "$project_log" | grep 'expired'`
    #27
#    error_published=`echo "$project_log" | grep 'published'`
    #28
    error_make=`echo "$project_log" | grep 'Makefile.am:.*error:'`
    #29
    error_package_check=`echo "$project_log"| grep -E 'error: Package check'`
#    error_syntax=`echo "$project_log" | grep -E 'error: private field'`
    #30
    error_undefined_sym=`echo "$project_log"| grep -E 'error: undefined reference to'`
    #31
#    error_chroot_deps=
#error: Package check (need to add this one)


#    if [ -n "$error_java" ]; then
#    see=1
     if [ -n "$error_autotools" ]; then
    see=2
      elif [ -n "$error_api" ]; then
    see=3
      elif [ -n "$error_conflicting_types" ]; then
    see=4
      elif [ -n "$error_segfault" ]; then
    see=5
      elif [ -n "$error_bad_file" ]; then
    see=6
      elif [ -n "$error_git" ]; then
    see=7
      elif [ -n "$error_deps" ]; then
    see=8
      elif [ -n "$error_deps2" ]; then
    see=9
      elif [ -n "$error_deps_pkg" ]; then
    see=10
      elif [ -n "$error_files" ]; then
    see=11
      elif [ -n "$error_linkage" ]; then
    see=12
      elif [ -n "$error_undeclared" ]; then
    see=13
      elif [ -n "$error_twice" ]; then
    see=14
      elif [ -n "$error_sfmt" ]; then
    see=15
      elif [ -n "$error_arch" ]; then
    see=16
      elif [ -n "$error_automake13" ]; then
    see=17
      elif [ -n "$error_uclibc" ]; then
    see=18
      elif [ -n "$error_chroot" ]; then
    see=19
      elif [ -n "$error_rpmlint" ]; then
    see=20
      elif [ -n "$error_cplusplus" ]; then
    see=21
      elif [ -n "$error_clang" ]; then
    see=22
      elif [ -n "$error_clang1" ]; then
    see=23
      elif [ -n "$error_syntax" ]; then 
    see=24
      elif [ -n "$error_command" ]; then
    see=25  
      elif [ -n "$error_python" ]; then
    see=26
      elif [ -n "$error_no_proj" ]; then
    see=27
      elif [ -n "$published" ]; then
    see=28
      elif [ -n "$error_make" ]; then
    see=29
      elif [ -n "$error_pkg_check" ]; then
    see=30
      elif [ -n "$error_undefined_sym" ]; then
    see=31
#      elif [ -n "$error_chroot_deps" ]; then
#    see=31
      fi
#echo $see
  case $see in
	"1")
		  #status="Java package"
		  status=| awk '{lines[NR] = $0} /^error: Bad exit status.*/ {{print "error: Bad exit status"} for (i=(NR-5); i<=(NR-2); i++) {print lines[i]}}' | sed '/^$/d' | sed ':a;N;$!ba;s/\n/+!/g'
		  ;;
	"2")
		  status="Autotools issue"
		  ;;
	"3")
		  status="API issue"
		  ;;
	"4")
		  status="Conflicting types"
		  ;;
	"5")
		  status="Compiler segfault"
		  ;;
	"6")
		  status="Missing source"
		  ;;
	"7")
		  status="git issues"
		  ;;
	"8")
		  status=`echo curl -L $project_log_file | grep 'is needed by' | head -n 1 | sed -e 's/^[ \t]*//'`
		  ;;
	"9")
		    if [ -z  status=`curl -L $project_log_file | grep 'due to unsatisfied' | head -n 1 | sed -e 's/^[ \t]*//'` ]; then
		    status=$(error_deps2)
		    fi
		  ;;
  	"10")
		    if [ -z alt_status=`curl -L $project_log_file | grep -E 'No package(.*)found' | awk '{print "BR issue ("$3" not detected by pkgconfig)"}' | head -n 1` ]; then
			status="$alt_status"
		    else 
			status=$error_deps_pkg
		    fi
		  ;;
	"11")
		  status="File not found"configure.ac: error:`curl -L $project_log_file | grep -E 'configure.ac\: error\:' | awk '{print "BR issue ("$3" not detected by pkgconfig)"}' | head -n 1`
		  ;;
	"12")
		  status="linkage issues"
		  ;;
  	"13")
		  status="not declared in this scope"
		  ;;
	"14")
		  status="file listed twice"
		  ;;
	"15")
		  status="format not a string literal"
		  ;; 
	"16")
		  status="Architecture is not included: x86_64"
		  ;;
	"17")
		  status="Automake 1.13 issues"
		  ;;
	"18")
		  status="ABF uclibc issues"
		  ;;
	"19")
		  status="ABF chroot issues"
		  ;;
	"20")
		  #status="Rpmlint issue"
		  status=`curl -L $project_log_file  | awk '{lines[NR] = $0} /^error: Package check/ {{print "Error: Package Check:"} for (i=(NR-5); i<=(NR-2); i++) {print lines[i]}}' | sed '/^$/d'| sed ':a;N;$!ba;s/\n/+!/g'`
		  ;;
	"21")
		  status=`curl -L $project_log_file | grep -E 'error: private field' | sed '/^$/d' | sed ':a;N;$!ba;s/\n/+/g'`
		  ;;
 	"22")
		  status=`curl -L $project_log_file | awk 'BEGIN{FS=":"; a=""} /clang: error:(.*)/{a=$0" \n";printf a}' | sed ':a;N;$!ba;s/\n/+!/g'`
		  ;;
	"23")
		  status=`curl -L $project_log_file |  awk '/error: unknown type name/{print;exit}' | sed '/^$/d' | sed ':a;N;$!ba;s/\n/+!/g'`
		  ;;
	"24")		#Invalid Syntax
		  status=`curl -L $project_log_file |  awk '{lines[NR] = $0} /^SyntaxError: invalid syntax/ {count++;{if (count <=1) {for (i=(NR-5); i<=(NR+1); i++) {print lines[i]}} else {c=count}}} END {if (c >0) {print "There are "(c-1)" more Syntax Errors"}}'| sed '/^$/d' | sed ':a;N;$!ba;s/\n/+!/g'`
		  ;;
	"25")
		  status=`curl -L $project_log_file | awk '{lines[NR] = $0} /^error: command/ {count++;{if (count <=1) {for (i=(NR-5); i<=(NR+1); i++) {print lines[i]}} else {c=count}}} END {if (c >0) {print "There are "(c-1)" more Syntax Errors"}}'| sed '/^$/d' | sed ':a;N;$!ba;s/\n/+!/g'` 
		  ;;
	"26")
		  status=`curl -L $project_log_file | awk '/UnicodeEncodeError:/||/error: unknown type name/||/^SyntaxError: invalid syntax/||/error: Package check/ {print;exit};/^error:/||/^ImportError:/||/UnicodeDecodeError:/||/AttributeError:/||/SystemError:/||/UnicodeEncodeError:/{print;exit}flag;/^Traceback \(most recent call last\):/{flag=1;print}'| sed '/^$/d' | sed ':a;N;$!ba;s/\n/+!/g'`
		    if [ -n `echo "$status" | grep -E '^SyntaxError: invalid syntax$'` ]; then
		  status=`curl -L $project_log_file | awk '{lines[NR] = $0} /^SyntaxError: invalid syntax/ {count++;{if (count <=1) {for (i=(NR-5); i<=(NR+1); i++) {print lines[i]}} else {c=count}}} END {if (c >0) {print "There are "(c-1)" more Syntax Errors"}}'| sed '/^$/d'`
		    fi
		  ;;
	"27")		
		  status=`echo "No Project Found"`
#		  status=`echo "$project_log" | awk '{lines[NR] = $0} /^SyntaxError: invalid syntax/ {count++;{if (count <=1) {for (i=(NR-5); i<=(NR+1); i++) {print lines[i]}} else {c=count}}} END {if (c >0) {print "There are "(c-1)" more Syntax Errors"}}'| sed '/^$/d' | sed ':a;N;$!ba;s/\n/+/g'` 
		  ;;
	"28")
		  status=`echo "Project Published"`
		  ;;
	"29")
		  status=`echo "Make Error"`
		  ;;
	"30")
		  status="Rpmlint Error"
		  ;;
        "31")
                  status=`curl -L $project_log_file | grep -E 'error: undefined reference to .*'`
                  ;;
 esac

    echo "https://abf.openmandriva.org/build_lists/$project_id;$project_name;$project_arch;;;"
    echo "https://abf.openmandriva.org/build_lists/$project_id;$project_name;$project_arch;$see;$status" >> failed_mass_rebuilds.txt
#done {fd_num}<$projects_list
done <$projects_list

#| sed ':a;N;$!ba;s/\n/""\n""/g'
