#!/bin/env bash 

WRAPPERVERSION="0.9.16"

# 
# A generic wrapper with minimal functionalities
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
# ----------------------------------------------------------------------------
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
        f_check_env
        f_check_python
        f_check_python32
        f_check_curl
        f_check_tar
        f_check_gzip

        # if everything went fine...
        return 0
}

f_check_env(){
        # function to print out the environment
        msg="Environment: "`printenv | sort`
        f_print_info_msg "$msg"
        f_print_line
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

f_setup_platform(){
        # Function to source the corresponding 
        # source file, depending on the platform flavor (grid OSG, grid EGI, HPC...)
        # The flavor is the input option of the function

        GRID=$1
        case $GRID in
                OSG)
                        f_print_info_msg "platform value set to OSG."
                        f_setup_osg
                        return $?
                        ;;
                local|LOCAL|Local)
                        f_print_info_msg "platform value set to LOCAL. Nothing to do."
                        return 0
                        ;;
                EGI)
                        f_print_info_msg "platform value set to EGI. Nothing to do."
                        return 0
                        ;;
                *) 
                        f_print_warning_msg "platform value not defined or not recognized"
                        return 0
                        ;;
        esac
        f_print_line
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
                        f_print_warning_msg "OSG_GRID defined but setup file $OSG_GRID/setup.sh does not exist"
                        return 0
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

                # run the special cmd
                $@
                rc=$?

                msg='Checking again the environment after running special setup command: '"$@"
                f_print_info_msg "$msg" 
                f_check

                return $rc
        fi 
}

# ------------------------------------------------------------------------- #  
#                P A R S I N G    I N P U T    O P T I O N S                #
# ------------------------------------------------------------------------- # 

f_setup_defaults_inputs(){
        # setups default values for the input options. 
        # They can then be overriden by the values
        # provided as input. 

        WRAPPERTARBALLURI=http://dev.racf.bnl.gov/dist/wrapper/latest-wrapper-$WRAPPERVERSION
}

f_parse_arguments(){
        # Function to parse the command line input options.
        # It only pays attention to the variables for this wrapper.sh 
        #       --wrapperplatform
        #       --wrapperspecialcmd
        #       --wrappertarballuri
        #       --wrappertarballchecksum
        #
        # Before parsing the inputs, possible defaults values are setup. 
        #

        f_setup_defaults_inputs

        # before the input options are parsed, they must be re-tokenized
        # so whitespaces as part of the value 
        #       (i.e. --wrapperspecialcmd='module load osg')
        # create no confussion and are not taken as they are splitting 
        # different input options.
        #
        # The format in the condor submission file (or JDL) to address 
        # the multi-words values is:
        #
        #       arguments = "--in1=val1 ... --inN=valN --cmd=""module load osg"""

        items=
        for i in "$@"
        do
            items="$items \"$i\""
        done
        eval set -- $items

        # the --wrapper input options not meant for this wrapper but for the modular python code
        MODULARWRAPPEROPTS=""
        # all the unrecognized input options. Most probably for the payload code
        unexpectedopts=""

        for WORD in "$@" ; do
                case $WORD in
                        --wrapper*)  true ;
                                case $WORD in
                                        --wrapperplatform=*)
                                                WRAPPERPLATFORM=${WORD/--wrapperplatform=/}
                                                shift ;;
                                        --wrapperspecialcmd=*) 
                                                WRAPPERSPECIALCMD=${WORD/--wrapperspecialcmd=/}
                                                shift ;;
                                        --wrappertarballuri=*) 
                                                WRAPPERTARBALLURI=${WORD/--wrappertarballuri=/}
                                                shift ;;
                                        --wrappertarballchecksum=*)
                                                WRAPPERTARBALLCHECKSUM=${WORD/--wrappertarballchecksum=/}
                                                shift ;;
                                        *) MODULARWRAPPEROPTS=${MODULARWRAPPEROPTS}" "$WORD 
                                           shift ;;     
                                esac ;;
                        *) unexpectedopts=${unexpectedopts}" "$WORD
                           shift ;;
                esac
        done
        f_build_extra_opts
        f_print_options
        return 0
}

f_print_options(){
        # printing the input options
        f_print_info_msg "Wrapper input options:"

        [ -n "$WRAPPERPLATFORM" ] && echo " input option for platform flavor: "$WRAPPERPLATFORM
        [ -n "$WRAPPERSPECIALCMD" ] && echo " input option for special command: "$WRAPPERSPECIALCMD
        [ -n "$WRAPPERTARBALLURI" ] && echo " input option for modular wrapper tarball URL: "$WRAPPERTARBALLURI
        [ -n "$WRAPPERTARBALLCHECKSUM" ] && echo " input option for modular wrapper tarball checksum: "$WRAPPERTARBALLCHECKSUM
        [ -n "$MODULARWRAPPEROPTS" ] && echo " list of input options for modular wrapper: "$MODULARWRAPPEROPTS
        [ -n "$extraopts" ] && echo " list of extra input options for modular wrapper: "$extraopts
        f_print_line

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

# ------------------------------------------------------------------------- #  
#    G E T   W R A P P E R    P L U G I N S    T A R B A L L                #
# ------------------------------------------------------------------------- # 

f_download_wrapper_tarball(){
        # donwload a tarball with scripts in python
        # to complete the wrapper actions chain
        # The address string (WRAPPERTARBALLURI) can actually be a list of comma-split URLs.
        # This function splits that strings and tries them one by one. 

        f_print_info_msg "Getting the wrapper tarball from $WRAPPERTARBALLURI"

        LISTURIS=$(echo $WRAPPERTARBALLURI | tr "," " ")
        for WRAPPERTARBALLTRIAL in $LISTURIS
        do

                # getting the file basename
                #WRAPPERTARBALLNAME=`/bin/basename $WRAPPERTARBALLTRIAL`
                # To be able to use links for the wrapper tarball names, 
                # where the URL does not match the name of the file being downloaded,
                # we need to use a generic tarballname
                WRAPPERTARBALLNAME=wrapper.tar.gz
               

                f_print_info_msg "Trying with tarball from $WRAPPERTARBALLTRIAL"
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
        # field in original WRAPPERTARBALLURI

        f_print_info_msg "Getting the wrapper tarball from $WRAPPERTARBALLTRIAL"

        if [ ${WRAPPERTARBALLTRIAL:0:5} == "http:" ]; then
            f_download_wrapper_tarball_trial_from_URL
        elif [ ${WRAPPERTARBALLTRIAL:0:5} == "file:" ]; then
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

        cmd="curl  --connect-timeout 20 --max-time 120 -s -S $WRAPPERTARBALLTRIAL -o $WRAPPERTARBALLNAME"
        f_print_info_msg "command to download the wrapper tarball: $cmd"
        $cmd
        rc=$?
        return $rc
}

f_download_wrapper_tarball_trial_from_disk(){
        # copies the tarball from disk
        # WRAPPERTARBALLTRIAL looks like 
        #       file:///path/to/wrapper
        # First, we need to get the real path 
        # by removing the first 6 chars
        # and then copy

        # getting the real path
        WRAPPERTARBALLPATHTRIAL=${WRAPPERTARBALLTRIAL:7}
        cmd="cp $WRAPPERTARBALLPATHTRIAL ./$WRAPPERTARBALLNAME"
        f_print_info_msg "command to copy from filesystem the wrapper tarball: $cmd"
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
        # The tarball is untarred in a directory ./wrapperplugins/        

        f_print_info_msg "Untarring the wrapper tarball"
        mkdir wrapperplugins
        tar zxvf $WRAPPERTARBALLNAME -C wrapperplugins
        rc=$?
        rm $WRAPPERTARBALLNAME
        return $rc
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
        # NOTE: the tarball has been previously untarred in a directory ./wrapperplugins/

        f_print_info_msg "Executing wrapper.py ..." 
        STARTTIME=`date +%s`

        WRAPPERNAME="wrapper.py"
        $PYTHON ./wrapperplugins/$WRAPPERNAME $@ &
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
        f_print_error_msg "Catching a SIGNAL ${SIGNAL_TRAPPED}. Propagating it to process $PID"
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

f_init

# --- parsing input options and initial tests ---
f_parse_arguments "$@"
rc=$?
if [ $rc -ne 0 ]; then
        f_exit $rc
fi

# --- setting up environment ---
f_setup_platform $WRAPPERPLATFORM
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

# invoking the python wrapper
trap 'f_handle_signal 15' SIGTERM
trap 'f_handle_signal 3' SIGQUIT 
trap 'f_handle_signal 11' SIGSEGV
trap 'f_handle_signal 30' SIGXCPU
trap 'f_handle_signal 16' SIGUSR1
trap 'f_handle_signal 10' SIGBUS

f_invoke_wrapper $MODULARWRAPPEROPTS $extraopts
rc=$?

# exit
f_exit $rc
