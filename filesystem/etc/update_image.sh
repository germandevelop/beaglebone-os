#!/usr/bin/env sh

###################################################################
# Author        : German Mundinger
# Date          : 2022
###################################################################


#**************************************************************
# Version 1.0.0
#**************************************************************
readonly VERSION_MAJOR="1"
readonly VERSION_MINOR="0"
readonly VERSION_PATCH="0"
#**************************************************************


#**************************************************************
# VARIABLES
#**************************************************************
readonly SOURCE_DIR=$(dirname $(realpath "$0"))
#**************************************************************


#**************************************************************
# SOURCES
#**************************************************************
source "/etc/logger.sh"
#**************************************************************


#**************************************************************
# ARGUMENTS
#**************************************************************
IMAGE_FILE_ARG=""
DEBUG_ARG="false"
LOG_FILE_ARG=""
HELP_ARG="false"
VERSION_ARG="false"

function print_help
{
    printf "Script to update OS\n"
    printf "Version: ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}\n"
    printf "\n"
    printf "Usage:\n"
    printf "\tupdate_image.sh [options]\n"
    printf "\n"
    printf "Options:\n"
    printf "\t-i, --image FILE      Image file to update (mondatory)\n"
    printf "\n"
    printf "\t-d, --debug           Enable debug output\n"
    printf "\t-l, --log FILE        File for logging\n"
    printf "\n"
    printf "\t-h, --help            Display this help\n"
    printf "\t-V, --version         Display version\n"

    return 0
}

function print_version
{
    printf "Version: ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}\n"

    return 0
}

function parse_arguments
{
    local options=""
    options=$(getopt --unquoted --options dl:i:hV --longoptions debug,log:,image:,help,version -- "$@")
    local ret_val="$?"

    if [[ "$ret_val" -ne "0" ]]
    then
        print_help
        exit "$ret_val"
    fi

    for option in $options
    do
        if [[ "$LOG_FILE_ARG" == "true" ]]
        then
            LOG_FILE_ARG="$option"
            continue
        fi

        if [[ "$IMAGE_FILE_ARG" == "true" ]]
        then
            IMAGE_FILE_ARG="$option"
            continue
        fi

        if [[ "$option" == "-d" || "$option" == "--debug" ]]
        then
            DEBUG_ARG="true"

        elif [[ "$option" == "-l" || "$option" == "--log" ]]
        then
            LOG_FILE_ARG="true"

        elif [[ "$option" == "-i" || "$option" == "--image" ]]
        then
            IMAGE_FILE_ARG="true"

        elif [[ "$option" == "-h" || "$option" == "--help" ]]
        then
            HELP_ARG="true"
            break

        elif [[ "$option" == "-V" || "$option" == "--version" ]]
        then
            VERSION_ARG="true"
            break

        elif [[ "$option" == "--" ]] # '--' - last element
        then
            break
        else
            printf "${BOLD_RED}ERROR${REGULAR_RED} --- Unexpected option: ${option} ${RESET_COLOR}\n" 1>&2
            print_help
            exit 1
        fi
    done

    return 0
}
#**************************************************************


#**************************************************************
# LOCAL FUNCTIONS
#**************************************************************
function update_image
{
    info_msg "Copy OS image to eMMC"

    local image_file="$1"

    mkdir -p /mnt/emmc_os                           1>&"$DEBUG_FD"  2>&"$ERROR_FD"
    mount -v -t ext4 /dev/mmcblk1p2 /mnt/emmc_os    1>&"$DEBUG_FD"  2>&"$ERROR_FD"
    cp -f "$image_file" /mnt/emmc_os/os_image.itb   1>&"$INFO_FD"   2>&"$ERROR_FD"
    umount -v /mnt/emmc_os                          1>&"$DEBUG_FD"  2>&"$ERROR_FD"

    return 0
}

function clean_up
{
    umount -v /mnt/emmc_os  1>&"$DEBUG_FD" 2>&"$ERROR_FD"

    deinit_logging

    return 0
}
#**************************************************************


#**************************************************************
# TRAPS
#**************************************************************
function trap_signals
{
    exit "$?"
}

function trap_exit
{
    local exit_code="$?"

    disable_traps

    if [[ "$exit_code" -ne "0" ]]
    then
        error_msg "An error occured"
        clean_up
    fi

    return "$exit_code"
}

function enable_traps
{
    trap trap_signals SIGINT SIGQUIT SIGHUP SIGKILL SIGSTOP SIGTERM SIGFPE # Common signals
    trap trap_exit EXIT

    set -o errexit 	# To make your script exit when a command fails
    set -o pipefail	# The exit status of the last command that threw a non-zero exit code is returned
    set -o nounset 	# Exit when your script tries to use undeclared variables

    return 0
}

function disable_traps
{
    trap - SIGINT SIGQUIT SIGHUP SIGKILL SIGSTOP SIGTERM SIGFPE # Common signals
    trap - EXIT

    set +o errexit
    set +o pipefail
    set +o nounset

    return 0
}
#**************************************************************


#**************************************************************
# MAIN
#**************************************************************
parse_arguments "$@"

if [[ "$HELP_ARG" == "true" ]]
then
    print_help
    exit 0
fi

if [[ "$VERSION_ARG" == "true" ]]
then
    print_version
    exit 0
fi

if [[ "$DEBUG_ARG" != "true" ]]
then
    init_logging "$INFO_LEVEL" "$LOG_FILE_ARG"
else
    init_logging "$DEBUG_LEVEL" "$LOG_FILE_ARG"
fi

enable_traps

update_image "$IMAGE_FILE_ARG"

disable_traps
deinit_logging

exit 0
#**************************************************************
