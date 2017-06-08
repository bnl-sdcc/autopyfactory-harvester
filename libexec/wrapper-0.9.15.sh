#!/bin/env bash 

WRAPPERVERSION="0.9.15"

# 
# A generic wrapper with minimal functionalities
#
# input options:
#   - wrappervo
#   - wrapperwmsqueue
#   - wrapperbatchqueue
#   - wrappergrid
#   - wrapperpurpose
#   - wrappertarballurl
#   - wrapperpilotcodeurl
#   - wrapperspecialcmd 
#   - wrapperplugin 
#   - wrapperpilotcode
#   - wrapperloglevel
#   - wrappermode
#   - wrappertarballchecksum
#   - wrapperpilotcodechecksum
#
# where
#
#     - wrappervo is the VO
#
#     - wrapperwmsqueue is the wms queue (e.g. the panda siteid)
#    
#     - wrapperbatchqueue is the batch queue (e.g. the panda queue)
#    
#     - wrappergrid is the grid flavor, i.e. OSG or EGEE (or gLite). 
#     The reason to include it as an input option,
#     instead of letting the wrapper to discover by itself
#     the current platform is to be able to distinguish
#     between these two scenarios:
#    
#       (a) running on local cluster
#       (b) running on grid, but the setup file is missing
#     
#     (b) is a failure and should be reported, whereas (a) is fine.
#    
#     A reason to include wrappergrid as an option in this very first wrapper
#     is that for sites running condor as local batch system, 
#     the $PATH environment variable is setup only after sourcing the 
#     OSG setup file. And only with $PATH properly setup 
#     is possible to perform actions as curl/wget 
#     to download the rest of files, or python to execute them.
#    
#     - wrapperpurpose will be the VO in almost all cases,
#     but not necessarily when several groups share
#     the same VO. An example is VO OSG, shared by 
#     CHARMM, Daya, OSG ITB testing group...
#    
#     - wrappertarballurl is the complete url with the wrapper tarball to be downloaded
#     including the name of the actual tarball file.
#     DEFAULT: http://dev.racf.bnl.gov/dist/wrapper/wrapper.tar.gz
#
#     - wrapperpilotcodeurl is the base url with the pilot code to be downloaded.
#     It can be a single value, or a list of values split by comma.
#    
#     - wrapperspecialcmd is special command to be performed, 
#     for some specific reason, just after sourcing the Grid environment,
#     but before doing anything else.
#     This has been triggered by the need to execute command
#          $ module load <module_name>
#     at NERSC after sourcing the OSG grid environment. 
#    
#     - wrapperplugin is the plug-in module with the code corresponding to the final wrapper flavor.
#    
#     - wrapperpilotcode is the actual pilot code to be executed at the end.
#     Each VO plugin is supposed to understand the format:
#     for example, it could just be the basename of an executable to be run as it is,
#     or it can be the name of tarball, and the plugin will add the ".tar.gz" suffix. 
#
#     - wrapperloglevel is a flag to activate high verbosity mode.
#     Accepted values are debug or info.  
#     
#     - wrappermode allows performing all steps but querying and running a real job.
#     
#     - wrappertarballchecksum is the checksum of the wrapper tarball
#     
#     - wrapperpilotcodechecksum is the checksum of the pilot tarball
#     
# ----------------------------------------------------------------------------
#
# Note:
#       before the input options are parsed, they must be re-tokenized
#       so whitespaces as part of the value 
#       (i.e. --wrapperspecialcmd='module load osg')
#       create no confussion and are not taken as they are splitting 
#       different input options.
#
#       The format in the condor submission file (or JDL) to address 
#       the multi-words values is:
#
#          arguments = "--in1=val1 ... --inN=valN --cmd=""module load osg"""
#
# ----------------------------------------------------------------------------
#
# This first wrapper perform basic actions:
#      (1)  check the environment, and the availability of basic programs
#               - curl
#               - python            
#               - tar
#               - zip
#       (2) downloads a first tarball with python code
#           as passes all input options to this code.
#           With passed options, the python code will download
#           a second tarball with the final pilot code.
#
# Author jcaballero (AT) bnl.gov
#    
# ----------------------------------------------------------------------------
#

# ------------------------------------------------------------------------- #  
#                 A U X I L I A R Y       F U N C T I O N S                 #
# ------------------------------------------------------------------------- # 

f_print_line(){
        echo "------------------------------------------------------------"
}

f_print_info_msg(){
        INFOMSG="$@"
        f_formatted_msg '[ INFO ]: ' "$INFOMSG"
        echo "$FORMATTEDMSG" 
}

f_print_warning_msg(){
        WARNINGMSG="$@"
        f_formatted_msg '[ WARNING ]: ' "$WARNINGMSG"
        echo "$FORMATTEDMSG" 
}

f_print_error_msg(){
        ERRORMSG="$@"
        f_formatted_msg '[ ERROR ]: ' "$ERRORMSG"
        echo "$FORMATTEDMSG" | tee /dev/stderr
}

f_formatted_msg(){
        MSG="$@"

        #T=`date -u +"%Y-%m-%d %H:%M:%S (UTC) - wrapper.sh: "`
        T=`date -u +"%Y-%m-%d %H:%M:%S,%N"`
        T=${T:0:23}
        T=$T" (UTC) - wrapper.sh: "
        
        FORMATTEDMSG=$T"$MSG"
}


# ------------------------------------------------------------------------- #  
#                 C H E C K     E N V I R O N M E N T                       #
# ------------------------------------------------------------------------- # 

f_init(){
        f_print_line
        echo "wrapper version:  "$WRAPPERVERSION
        echo "date (UTC):      " `date --utc`
        echo "hostname:        " `hostname -f`
        if test -f /proc/version ; then
                echo "OS information:  " `cat /proc/version`
        fi
        echo "working dir:     " `pwd`
        echo "user:            " `id`
        echo "                 " `getent passwd \`whoami\``
        f_print_line
}

f_check(){
        # function to check the environment 
        # and the basic programs needed to download the tarball
        f_print_packages
        f_check_env
        f_check_python
        f_check_python32
        f_check_curl
        f_check_tar
        f_check_gzip

        # if everything went fine...
        return 0
}

f_print_packages(){
        # function to print out the list of RPM packages installed
        f_print_info_msg "List of installed RPM packages:"
        rpm -qa | sort
}

f_check_env(){
        # function to print out the environment
        msg="Environment: "`printenv | sort`
        f_print_info_msg "$msg"
}
f_check_python(){
        # function to check if program python is installed
        f_check_program python
        rc=$?
        if [ $rc -eq 0 ]; then
                python -V 2>&1
                PYTHON=python
        fi
}
f_check_python32(){
        # function to check if program python32 is installed
        f_check_program python32
        rc=$?
        if [ $rc -eq 0 ]; then
                python32 -V 2>&1
                PYTHON=python32
        fi
}
f_check_curl(){
        # function to check if program curl is installed
        # curl is needed to download the tarball
        f_check_program curl FORCEQUIT
        rc=$?
        if [ $rc -eq 0 ]; then
                curl -V 
        fi
}
f_check_tar(){
        # function to check if program tar is installed
        # tar is needed to untar the tarball
        f_check_program tar FORCEQUIT
}
f_check_gzip(){
        # function to check if program gzip is installed
        # gzip is needed to untar the tarball
        f_check_program gzip FORCEQUIT
}
f_check_program(){
        # generic function to check if a given program is installed
        PROGRAM=$1
        f_print_info_msg "Checking program $PROGRAM"        

        which $PROGRAM 2> /dev/null
        rc=$?
        if [ $rc -ne 0 ]; then
                f_print_warning_msg "program $PROGRAM not installed or not in the PATH"
                if [ "$2" == "FORCEQUIT" ]; then
                        f_exit 1 #FIXME: RC=1 is just a temporary solution
                fi
        fi
        return $rc 
}

# ------------------------------------------------------------------------- #  
#                 S E T      U P          F U N C T I O N S                 #
# ------------------------------------------------------------------------- # 

f_setup_grid(){
        # Function to source the corresponding 
        # source file, depending on the grid flavor
        # The input option is the grid flavor

        GRID=$1
        case $GRID in
                OSG)
                        f_setup_osg
                        return $?
                        ;;
                local|LOCAL|Local)
                        f_print_warning_msg "GRID value setup to LOCAL, doing nothing."
                        return 0
                        ;;
                *) 
                        f_print_warning_msg "GRID value not defined or not recognized"
                        return 0
                        ;;
        esac
}

f_setup_osg(){
        # If OSG setup script exists, run it
        if test ! $OSG_GRID = ""; then
                f_print_info_msg "setting up OSG environment"
                if test -f $OSG_GRID/setup.sh ; then
                        echo "Running OSG setup from $OSG_GRID/setup.sh"

                        source $OSG_GRID/setup.sh
                        return 0 
                else
                        #echo "OSG_GRID defined but setup file $OSG_GRID/setup.sh does not exist"
                        f_print_error_msg "OSG_GRID defined but setup file $OSG_GRID/setup.sh does not exist"
                        return 1
                fi
        else
                echo "No OSG setup script found. OSG_GRID='$OSG_GRID'"
                return 2
        fi
        return 0
}

f_special_cmd(){
        # special setup commands to be performed just after
        # sourcing the grid environment, 
        # but before doing anything else,
        # following instructions from the input options

        if [ "$1" != "" ]; then
                msg='Executing special setup command: '"$@"
                f_print_info_msg "$msg" 
                $@
                return $?
        fi 
}


# ------------------------------------------------------------------------- #  
#                P A R S I N G    I N P U T    O P T I O N S                #
# ------------------------------------------------------------------------- # 

f_usage(){
        f_print_line
        echo
        echo "wrapper.sh Usage:" 
        echo
        echo " ./wrapper.sh --wrappervo=<vo> --wrapperwmsqueue=<site_name> --wrapperbatchqueue=<queue_name> \
[--wrappergrid=<grid_flavor> ] \
[--wrapperpurpose=<application_type>] \
[--wrappertarballurl=<wrapper_tarball_url>] \
[--wrapperpilotcodeurl=<wrapper_pilot_tarball_url>] \
[--wrapperspecialcmd=<special_setup_command>] \
[--wrapperplugin=<plugin_name>]\
[--wrapperpilotcode=<pilot_code]\
[--wrapperloglevel=debug|info]\
[--wrappermode=<operation mode>]\
[--wrappertarballchecksum=<checksum of the wrapper tarball>]\
[--wrapperpilotcodechecksum=<checksum of the pilot tarball>]"
}

f_setup_defaults_inputs(){
        # setups default values for the input options. 
        # They can then be overriden by the values
        # provided as input. 

        WRAPPERTARBALLURL=http://dev.racf.bnl.gov/dist/wrapper/wrapper.tar.gz
}

f_parse_arguments(){
        # Function to parse the command line input options.
        #         --wrappervo=...
        #         --wrapperwmsqueue=...
        #         --wrapperbatchqueue=...
        #         --wrappergrid=...
        #         --wrapperpurpose=...
        #         --wrappertarballurl=...
        #         --wrapperpilotcodeurl=...
        #         --wrapperspecialcmd=...
        #         --wrapperplugin=...
        #         --wrapperpilotcode=...
        #         --wrapperloglevel=...
        #         --wrappermode=...
        #         --wrappertarballchecksum=...
        #         --wrapperpilotcodechecksum=...
        # An error/warning message is displayed in case a different 
        # An error/warning message is displayed in case a different 
        # An error/warning message is displayed in case a different 
        # input option is passed
        #
        # Before parsing the inputs, possible defaults values are setup. 
        #

        # NOTE:
        # when the input is not one of the expected 
        # a warning message is displayed, and that is. 
        # These unexpected input option can be specific for the pilot.
        # If finally a dedicated input option to pass info 
        # to the pilots (i.e. pythonwrapperopts), then the warning message
        # will be replaced by an error message and the function
        # will return a RC != 0

        f_setup_defaults_inputs

        # first, the input options are re-tokenized to parse properly whitespaces
        items=
        for i in "$@"
        do
            items="$items \"$i\""
        done
        eval set -- $items

        # all unrecognized options are collected in a single variable
        unexpectedopts=""

        for WORD in "$@" ; do
                case $WORD in
                        --*)  true ;
                                case $WORD in
                                        --wrappervo=*) 
                                                WRAPPERVO=${WORD/--wrappervo=/}
                                                shift ;;
                                        --wrapperwmsqueue=*) 
                                                WRAPPERWMSQUEUE=${WORD/--wrapperwmsqueue=/}
                                                shift ;;
                                        --wrapperbatchqueue=*) 
                                                WRAPPERBATCHQUEUE=${WORD/--wrapperbatchqueue=/}
                                                shift ;;
                                        --wrappergrid=*)
                                                WRAPPERGRID=${WORD/--wrappergrid=/}
                                                shift ;;
                                        --wrapperpurpose=*)
                                                WRAPPERPURPOSE=${WORD/--wrapperpurpose=/}
                                                shift ;;
                                        --wrappertarballurl=*) 
                                                WRAPPERTARBALLURL=${WORD/--wrappertarballurl=/}
                                                shift ;;
                                        --wrapperpilotcodeurl=*) 
                                                WRAPPERPILOTCODEURL=${WORD/--wrapperpilotcodeurl=/}
                                                shift ;;
                                        --wrapperspecialcmd=*) 
                                                WRAPPERSPECIALCMD=${WORD/--wrapperspecialcmd=/}
                                                shift ;;
                                        --wrapperplugin=*) 
                                                WRAPPERPLUGIN=${WORD/--wrapperplugin=/}
                                                shift ;;
                                        --wrapperpilotcode=*) 
                                                WRAPPERPILOTCODE=${WORD/--wrapperpilotcode=/}
                                                shift ;;
                                        --wrapperloglevel=*) 
                                                WRAPPERLOGLEVEL=${WORD/--wrapperloglevel=/}
                                                shift ;;
                                        --wrappermode=*)
                                                WRAPPERMODE=${WORD/--wrappermode=/}
                                                shift ;;
                                        --wrappertarballchecksum=*)
                                                WRAPPERTARBALLCHECKSUM=${WORD/--wrappertarballchecksum=/}
                                                shift ;;
                                        --wrapperpilotcodechecksum=*)
                                                WRAPPERPILOTCODECHECKSUM=${WORD/--wrapperpilotcodechecksum=/}
                                                shift ;;
                                        *) unexpectedopts=${unexpectedopts}" "$WORD 
                                           shift ;;     
                                esac ;;
                        *) unexpectedopts=${unexpectedopts}" "$WORD 
                           shift ;;
                esac
        done
        f_print_options
        return 0
}

f_print_options(){
        # printing the input options
        f_print_info_msg "Wrapper input options:"
        echo " vo: "$WRAPPERVO
        echo " site: "$WRAPPERWMSQUEUE
        echo " queue: "$WRAPPERBATCHQUEUE
        echo " grid flavor: "$WRAPPERGRID
        echo " purpose: "$WRAPPERPURPOSE
        echo " code url: "$WRAPPERTARBALLURL
        echo " special commands: "$WRAPPERSPECIALCMD
        echo " plugin module: "$WRAPPERPLUGIN
        echo " pilot code: "$WRAPPERPILOTCODE
        echo " debug mode: "$WRAPPERLOGLEVEL
        echo " operation mode: "$WRAPPERMODE
        echo " wrapper tarball checksum: "$WRAPPERTARBALLCHECKSUM
        echo " pilot tarball checksum: "$WRAPPERPILOTCODECHECKSUM
        if [ "$unexpectedopts" != "" ]; then
                # warning message for unrecognized input options
                f_print_warning_msg "Unrecognized input options"
                echo $unexpectedopts
        fi
        f_print_line

        f_check_mandatory_option "SITE" $WRAPPERWMSQUEUE
        f_check_mandatory_option "QUEUE" $WRAPPERBATCHQUEUE
        f_check_mandatory_option "CODE URL" $WRAPPERTARBALLURL

}

f_check_mandatory_option(){
        # check if every mandatory input option has a value. 
        # A message is displayed and the program exits otherwise.

        if [ "$2" == "" ]; then
                f_print_error_msg "$1 has no value"
                f_usage
                f_exit -1
        fi
}

f_build_extra_opts(){
        # variable unexpectedopts is analyzed, 
        # and a variable extraopts is created to pass them
        # to the python wrapper. 
        # String --extraopts is added as a trick to facilitate parsing
        extraopts=""
        for WORD in $unexpectedopts; do
                extraopts=${extraopts}" --extraopts="$WORD
        done
}

f_build_pythonwrapper_opts(){
        # Not all input options should be passed to the python wrapper. 
        # The complete list of input options to be passed to the python script
        # is created here. 

        f_build_extra_opts

        pythonwrapperopts=""
        pythonwrapperopts=${pythonwrapperopts}" --wrappervo="$WRAPPERVO
        pythonwrapperopts=${pythonwrapperopts}" --wrapperwmsqueue="$WRAPPERWMSQUEUE
        pythonwrapperopts=${pythonwrapperopts}" --wrapperbatchqueue="$WRAPPERBATCHQUEUE
        pythonwrapperopts=${pythonwrapperopts}" --wrappergrid="$WRAPPERGRID
        pythonwrapperopts=${pythonwrapperopts}" --wrapperpurpose="$WRAPPERPURPOSE
        pythonwrapperopts=${pythonwrapperopts}" --wrappertarballurl="$WRAPPERTARBALLURL
        pythonwrapperopts=${pythonwrapperopts}" --wrapperpilotcodeurl="$WRAPPERPILOTCODEURL
        pythonwrapperopts=${pythonwrapperopts}" --wrapperplugin="$WRAPPERPLUGIN
        pythonwrapperopts=${pythonwrapperopts}" --wrapperpilotcode="$WRAPPERPILOTCODE
        pythonwrapperopts=${pythonwrapperopts}" --wrapperloglevel="$WRAPPERLOGLEVEL
        pythonwrapperopts=${pythonwrapperopts}" --wrappermode="$WRAPPERMODE
        pythonwrapperopts=${pythonwrapperopts}" --wrappertarballchecksum="$WRAPPERTARBALLCHECKSUM
        pythonwrapperopts=${pythonwrapperopts}" --wrapperpilotcodechecksum="$WRAPPERPILOTCODECHECKSUM
        pythonwrapperopts=${pythonwrapperopts}" "$extraopts

}

# ------------------------------------------------------------------------- # 
#                           M O N I T O R                                   #
# ------------------------------------------------------------------------- # 

f_monping() {
    #CMD="curl -fksS --connect-timeout 10 --max-time 20 ${APFMON}$1/$APFFID/$APFCID/$2"

    if [ "$1" == "running" ]; then 
        CMD="curl -ksS -d state=$1 --connect-timeout 10 --max-time 20 ${APFMON}/jobs/${APFFID}:${APFCID}"
    fi
    if [ "$1" == "exiting" ]; then 
        CMD="curl -ksS -d state=$1 -d rc=$2 --connect-timeout 10 --max-time 20 ${APFMON}/jobs/${APFFID}:${APFCID}"
    fi

    echo "Monitor ping: $CMD"
    
    NTRIALS=0
    MAXTRIALS=1
    DELAY=30
    while [ $NTRIALS -lt "$MAXTRIALS" ] ; do
        out=`$CMD`
        if [ $? -eq 0 ]; then
            echo "Monitor ping: out=$out" 
            NTRIALS="$MAXTRIALS"
        else
            echo "Monitor ping: ERROR: out=$out"
            echo "Monotor ping: http_proxy=$http_proxy"
            NTRIALS=$(($NTRIALS+1))
            echo "Trial number=$NTRIALS"
            sleep $DELAY
        fi
    done
}

# ------------------------------------------------------------------------- #  
#    G E T   W R A P P E R    P L U G I N S    T A R B A L L                #
# ------------------------------------------------------------------------- # 

f_download_wrapper_tarball(){
        # donwload a tarball with scripts in python
        # to complete the wrapper actions chain
        # The address string (WRAPPERTARBALLURL) can actually be a list of comma-split URLs.
        # This function splits that strings and tries them one by one. 

        f_print_info_msg "Getting the wrapper tarball from $WRAPPERTARBALLURL"

        LISTURLS=$(echo $WRAPPERTARBALLURL | tr "," " ")
        for WRAPPERTARBALLURLTRIAL in $LISTURLS
        do

                # getting the file basename
                #WRAPPERTARBALLNAME=`/bin/basename $WRAPPERTARBALLURLTRIAL`
                # To be able to use links for the wrapper tarball names, 
                # where the URL does not match the name of the file being downloaded,
                # we need to use a generic tarballname
                WRAPPERTARBALLNAME=wrapper.tar.gz
               

                f_print_info_msg "Trying with tarball from $WRAPPERTARBALLURLTRIAL"
                f_download_wrapper_tarball_trial
                rc=$?
                if [ $rc -eq 0 ]; then
                    # breaks
                    return $rc  
                fi
        done
        # if the loop was not broken, then we return the last RC
        return $rc
}

f_download_wrapper_tarball_trial(){
        # Tries to donwload a tarball with scripts in python for each 
        # field in original WRAPPERTARBALLURL

        f_print_info_msg "Getting the wrapper tarball from $WRAPPERTARBALLURLTRIAL"

        if [ ${WRAPPERTARBALLURLTRIAL:0:5} == "http:" ]; then
            f_download_wrapper_tarball_trial_from_URL
        elif [ ${WRAPPERTARBALLURLTRIAL:0:5} == "file:" ]; then
            f_download_wrapper_tarball_trial_from_disk
        fi

        rc=$?
        if [ $rc -eq 0 ]; then
                f_print_info_msg "apparently, wrapper tarball $WRAPPERTARBALLNAME downloaded successfully"
                f_check_tarball
                rc=$?
        fi
        return $rc
}

f_download_wrapper_tarball_trial_from_URL(){
        # downloads the tarball from an URL

        cmd="curl  --connect-timeout 20 --max-time 120 -s -S $WRAPPERTARBALLURLTRIAL -o $WRAPPERTARBALLNAME"
        echo $cmd
        $cmd
        rc=$?
        return $rc
}

f_download_wrapper_tarball_trial_from_disk(){
        # copies the tarball from disk
        # WRAPPERTARBALLURLTRIAL looks like 
        #       file:///path/to/wrapper
        # First, we need to get the real path 
        # by removing the first 6 chars
        # and then copy

        # getting the real path
        WRAPPERTARBALLPATHTRIAL=${WRAPPERTARBALLURLTRIAL:7}
        cmd="cp $WRAPPERTARBALLPATHTRIAL ./$WRAPPERTARBALLNAME"
        echo $cmd
        $cmd
        rc=$?
        return $rc

}


f_checksum_wrapper_tarball(){
        # verify, if needed, the checksum of the wrapper tarball
        if [ ${#WRAPPERTARBALLCHECKSUM} -eq 0 ];then
                return 0
        else
                f_print_info_msg "Checking the checksum of the wrapper tarball"
                md=($(md5sum $WRAPPERTARBALLNAME))
                if [ $md != $WRAPPERTARBALLCHECKSUM ]; then 
                        f_print_error_msg "Checksum validation failed"
                        return 1
                else
                        f_print_info_msg "Checksum verified"
                        return 0        
                fi
        fi 
}


f_check_tarball(){
        # check the downloaded file is really a tarball
        f_print_info_msg "checking the wrapper tarball $WRAPPERTARBALLNAME is really a gzip file"
        checkfile=`file $WRAPPERTARBALLNAME`
        [[ "$checkfile" =~ "gzip compressed data" ]]
        rc=$?
        if [ $rc -eq 0 ]; then
            f_print_info_msg "the tarball $WRAPPERTARBALLNAME is really a tarball"
        else
            f_print_warning_msg "WARNING: the tarball $WRAPPERTARBALLNAME is NOT really a tarball"
        fi
        return $rc
}


f_untar_wrapper_tarball(){
        # untar the wrapper tarball and remove the original file
        f_print_info_msg "Untarring the wrapper tarball"
        tar zxvf $WRAPPERTARBALLNAME
        rm $WRAPPERTARBALLNAME
        return $?
}


# ------------------------------------------------------------------------- #  
#               E X I T                                                     #
# ------------------------------------------------------------------------- # 

f_exit(){
        if [ "$1" == "" ]; then
                RETVAL=0
        else
                RETVAL=$1
        fi
        
        # if we leave job.out there it will appear in the output 
        # for the next pilot, even if it does not run any job 
        # FIXME: that should not be here !!
        #        it should be in a clean() method in the wrapper.py module
        rm -f job.out
        
        f_print_info_msg "exiting with RC = $RETVAL"

        # notify the monitor just after execution
        f_monping exiting $rc

        exit $RETVAL
}


# ------------------------------------------------------------------------- #  
#               P Y T H O N       E X E C U T I O N                         #
# ------------------------------------------------------------------------- # 

f_invoke_wrapper(){
        # Function to run the python wrapper
        # We run it with &
        # so the shell is released and PID can be calculated
        # and therefore can be used to propagate a SIGTERM if needed.

        f_print_info_msg "Executing wrapper.py ..." 
        STARTTIME=`date +%s`

        WRAPPERNAME="wrapper.py"
        $PYTHON ./$WRAPPERNAME $@ &
        PID=$!
        f_print_info_msg "wrapper.py runs as process PID=$PID"
        wait $PID
        rc=$?

        ENDTIME=`date +%s`
        TOTALTIME=$((ENDTIME-STARTTIME))
        TOTALTIMEHUMAN=`printf "%dd:%dh:%dm:%ds" $((TOTALTIME/86400)) $((TOTALTIME%86400/3600)) $((TOTALTIME%3600/60)) $((TOTALTIME%60))`
        f_print_info_msg "wrapper.py running process PID=$PID has finished"
        f_print_info_msg "wrapper.py running process PID=$PID has been running for $TOTALTIME seconds ($TOTALTIMEHUMAN)"

        return $rc
}

# ------------------------------------------------------------------------- #  
#                S I G N A L   H A N D L I N G                              # 
# ------------------------------------------------------------------------- #  

f_handle_signal(){
        # catches a signal and kills the python process.
        # SIGTERM == signal 15
        # SIGQUIT == signal 3
        # SIGSEGV == signal 11
        # SIGXCPU == signal 30
        # SIGUSR1 == signal 16
        # SIGBUS == signal 10
        # Note: it is not possible to trap SIGKILL (signal 9)

        SIGNAL_TRAPPED=$1
        f_print_error_msg "Catching a SIGTERM signal. Propagating it to process $PID"
        kill -$SIGNAL_TRAPPED $PID
        wait
        # we have here a second wait command. 
        # That is because the wait command in f_invoke_wrapper will finish 
        # inmediately if a signal is sent. 
        # In other words, when a signal is received, the wait in f_invoke_wrapper
        # will not wait.  
        # Explanation can be found in SIGNALS section in man bash:
        #
        #     If  bash  is waiting for a command to complete and receives a signal 
        #     for which a trap has been set, the trap will not be executed until 
        #     the command com-pletes.  When bash  is waiting for an asynchronous 
        #     command via the wait builtin, the reception of a signal for which a 
        #     trap has been set will cause  the wait builtin to return immediately 
        #     with an exit status greater than 128, immediately after which 
        #     the trap is executed.
 
}

f_checkpid(){
        # check if the child PID is still alive. 
        # When the child process is gone, then it is OK to stop looping
        # and wrapper.sh can finish.
        # Child process was recorded in variable PID.
        # We check all pid's that are children of this wrapper.sh process,
        # to avoid misinterpret another pid with same value as child.
        # The wrapper.sh process is $$
        # The command to get pid's only of children processes is ps --ppid <pid>

        #o=`ps -e | grep -v grep | grep $PID`
        o=`ps --ppid $$ -o pid | grep -v grep | grep $PID`
        if [ "$o" == "" ]; then
                return 0
        else
                return 1
        fi
}

f_infiniteloop(){
        while true; do
                sleep 10
                f_checkpid
                rc=$?
                if [ $rc -eq 0 ]; then
                        return
                fi
        done
}


# ------------------------------------------------------------------------- #  
#                           M A I N                                         # 
# ------------------------------------------------------------------------- #  

# notify the monitor
f_monping running

f_init

# --- parsing input options and initial tests ---
f_parse_arguments "$@"
rc=$?
if [ $rc -ne 0 ]; then
        f_exit $rc
fi

# --- setting up environment ---
f_setup_grid $WRAPPERGRID
rc=$?
if [ $rc -ne 0 ]; then
        f_exit $rc
fi

# --- running special command 
f_special_cmd $WRAPPERSPECIALCMD
rc=$?
if [ $rc -ne 0 ]; then
        f_exit $rc
fi

f_check

# --- download and execute the wrapper tarball ---
f_download_wrapper_tarball
rc=$?
if [ $rc -ne 0 ]; then
        f_exit $rc
fi

# --- verify checksum of the wrapper tarball
f_checksum_wrapper_tarball
rc=$?
if [ $rc -ne 0 ]; then
        f_exit $rc
fi

f_untar_wrapper_tarball
rc=$?
if [ $rc -ne 0 ]; then
        f_exit $rc
fi

# prepare the input options
f_build_pythonwrapper_opts

# invoking the python wrapper
trap 'f_handle_signal 15' SIGTERM
trap 'f_handle_signal 3' SIGQUIT 
trap 'f_handle_signal 11' SIGSEGV
trap 'f_handle_signal 30' SIGXCPU
trap 'f_handle_signal 16' SIGUSR1
trap 'f_handle_signal 10' SIGBUS

f_invoke_wrapper $pythonwrapperopts
rc=$?

# exit
f_exit $rc

