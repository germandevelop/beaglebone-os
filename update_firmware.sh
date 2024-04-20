#!/usr/bin/env bash

###################################################################
# Script Name   : Blackpill node updater
# Description   : Use '--help' flag for the description.
# Compatibility	: Shell: bash. OS: Linux, FreeBSD. (install GNU getopt for FreeBSD)
# Author        : German Mundinger
# Date          : 2024
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

GETOPT_BIN=""

readonly SERVER_IP="192.168.100.111"
readonly SERVER_PORT="2398"

readonly ADMIN_IP="192.168.100.101"
readonly ADMIN_PORT="2399"

readonly NODE_ADMIN_ID="0"
readonly NODE_B01_ID="1"
readonly NODE_B02_ID="2"
readonly NODE_T01_ID="3"
readonly NODE_BROADCAST_ID="255"

readonly COMMAND_REQUEST_VERSION="1"
readonly COMMAND_UPDATE_FIRMWARE="3"
#**************************************************************


#**************************************************************
# SOURCES
#**************************************************************
source "${SOURCE_DIR}/logger.sh"
#**************************************************************


#**************************************************************
# ARGUMENTS
#**************************************************************
FIRMWARE_FILE_ARG=""
DEBUG_ARG="false"
LOG_FILE_ARG=""
HELP_ARG="false"
VERSION_ARG="false"

function print_help
{
    printf "Script to update node firmware\n"
    printf "Version: ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}\n"
    printf "\n"
    printf "Usage:\n"
    printf "\tupdate_firmware.sh [options]\n"
    printf "\n"
    printf "Options:\n"
	printf "\t-f, --firmware        Firmware file\n"
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

function setup_platform
{
    local os_name=$(uname)

	if [[ "$os_name" == "Linux" ]]
	then
   		GETOPT_BIN="getopt"

	elif [[ "$os_name" == "FreeBSD" ]]
	then
   		GETOPT_BIN="/usr/local/bin/getopt"
	else
		printf "${BOLD_RED}ERROR${REGULAR_RED} --- Unsupported OS: ${os_name} ${RESET_COLOR}\n" 1>&2
  		print_help
     	exit 1
	fi

    return 0
}

function parse_arguments
{
    local options=""
    options=$("$GETOPT_BIN" --unquoted --options df:l:hV --longoptions debug,firmware:,log:,help,version -- "$@")
    local ret_val="$?"

    if [[ "$ret_val" -ne "0" ]]
    then
        print_help
        exit "$ret_val"
    fi

    for option in $options
    do
        if [[ "$FIRMWARE_FILE_ARG" == "true" ]]
        then
            FIRMWARE_FILE_ARG="$option"
            continue
        fi

        if [[ "$LOG_FILE_ARG" == "true" ]]
        then
            LOG_FILE_ARG="$option"
            continue
        fi

        if [[ "$option" == "-f" || "$option" == "--firmware" ]]
        then
            FIRMWARE_FILE_ARG="true"

        elif [[ "$option" == "-d" || "$option" == "--debug" ]]
        then
            DEBUG_ARG="true"

        elif [[ "$option" == "-l" || "$option" == "--log" ]]
        then
            LOG_FILE_ARG="true"

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
function clean_up
{
    debug_msg "Clean up"

    deinit_logging

    return 0
}

function request_version
{
    info_msg "Request version"

	local server_timeout="3"

	local request_msg="{\"src_id\":${NODE_ADMIN_ID},\"dst_id\":[${NODE_BROADCAST_ID}],\"cmd_id\":${COMMAND_REQUEST_VERSION}}\n"

	printf "$request_msg" | nc -v -s "$ADMIN_IP" -w "$server_timeout" "$SERVER_IP" "$SERVER_PORT"	1>&"$INFO_FD"	2>&"$ERROR_FD"

    return 0
}

function update_firmware
{
    info_msg "Update firmware"

	local node_id="$1"
	local firmware_file="$2"

	if [[ ! (-f "$firmware_file") ]]
	then
		error_msg "Firmware file does not exist: \"${firmware_file}\""
       	exit 1
	fi

	local server_timeout="3"

	local request_msg="{\"src_id\":${NODE_ADMIN_ID},\"dst_id\":[${node_id}],\"cmd_id\":${COMMAND_UPDATE_FIRMWARE}}\n"

	printf "$request_msg" | nc -v -s "$ADMIN_IP" -w "$server_timeout" "$SERVER_IP" "$SERVER_PORT"	1>&"$INFO_FD"	2>&"$ERROR_FD"

	local update_timeout="180"

	nc -lv -w "$update_timeout" "$ADMIN_PORT" < "$firmware_file"	1>&"$INFO_FD"	2>&"$ERROR_FD"

    return 0
}

function select_action
{
    local -ra answer_array=([1]="Update B02" \
                            [2]="Update T01" \
                            [3]="Request version" \
                            [4]="Exit")

    ask_msg "Select action"

    select answer in "${answer_array[@]}"
    do
        if [[ !("$REPLY" =~ ^-?[0-9]+$) ]]
        then
            continue
        fi

        if (( "$REPLY" == "1" ))
        then
            update_firmware "$NODE_B02_ID" "$FIRMWARE_FILE_ARG"

        elif (( "$REPLY" == "2" ))
        then
            update_firmware "$NODE_T01_ID" "$FIRMWARE_FILE_ARG"

        elif (( "$REPLY" == "3" ))
        then
            request_version

        elif (( "$REPLY" == "4" ))
        then
            break
        else
            continue
        fi
    done

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

    if (( "$exit_code" != "0" ))
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
setup_platform
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

select_action

disable_traps
deinit_logging

exit 0
#**************************************************************

