###################################################################
# Script Name   : Logger
# Description   : Compatible with bash, ash and zsh
# Author        : German Mundinger
# Date          : 2022
###################################################################


#**************************************************************
# COLORS
#**************************************************************
# Regular colours
readonly REGULAR_BLACK='\033[0;30m'
readonly REGULAR_RED='\033[0;31m'
readonly REGULAR_GREEN='\033[0;32m'
readonly REGULAR_YELLOW='\033[0;33m'
readonly REGULAR_BLUE='\033[0;34m'
readonly REGULAR_PURPLE='\033[0;35m'
readonly REGULAR_CYAN='\033[0;36m'
readonly REGULAR_WHITE='\033[0;37m'

# Bold colours
readonly BOLD_BLACK='\033[1;30m'
readonly BOLD_RED='\033[1;31m'
readonly BOLD_GREEN='\033[1;32m'
readonly BOLD_YELLOW='\033[1;33m'
readonly BOLD_BLUE='\033[1;34m'
readonly BOLD_PURPLE='\033[1;35m'
readonly BOLD_CYAN='\033[1;36m'
readonly BOLD_WHITE='\033[1;37m'

# Underline colours
readonly UNDERLINE_BLACK='\033[4;30m'
readonly UNDERLINE_RED='\033[4;31m'
readonly UNDERLINE_GREEN='\033[4;32m'
readonly UNDERLINE_YELLOW='\033[4;33m'
readonly UNDERLINE_BLUE='\033[4;34m'
readonly UNDERLINE_PURPLE='\033[4;35m'
readonly UNDERLINE_CYAN='\033[4;36m'
readonly UNDERLINE_WHITE='\033[4;37m'

# Background colours
readonly BACKGROUND_BLACK='\033[40m'
readonly BACKGROUND_RED='\033[41m'
readonly BACKGROUND_GREEN='\033[42m'
readonly BACKGROUND_YELLOW='\033[43m'
readonly BACKGROUND_BLUE='\033[44m'
readonly BACKGROUND_PURPLE='\033[45m'
readonly BACKGROUND_CYAN='\033[46m'
readonly BACKGROUND_WHITE='\033[47m'

# Reset text colour
readonly RESET_COLOR='\033[0m'
#**************************************************************

#**************************************************************
# LOGGING
#**************************************************************
readonly ERROR_FD="100"
readonly WARN_FD="101"
readonly INFO_FD="102"
readonly DEBUG_FD="103"

readonly QUIET_LEVEL="0"
readonly ERROR_LEVEL="1"
readonly WARN_LEVEL="2"
readonly INFO_LEVEL="3"
readonly DEBUG_LEVEL="4"

readonly STDOUT_BACKUP_FD="104"
readonly STDERR_BACKUP_FD="105"

function debug_msg
{
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    printf "${REGULAR_WHITE}${timestamp} - ${BOLD_WHITE}DEBUG${REGULAR_WHITE} --- ${@} ${RESET_COLOR}\n" 1>&"$DEBUG_FD"

    return 0
}

function info_msg
{
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    printf "${REGULAR_GREEN}${timestamp} - ${BOLD_GREEN}INFO${REGULAR_GREEN} ---- ${@} ${RESET_COLOR}\n" 1>&"$INFO_FD"

    return 0
}

function warn_msg
{
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    printf "${REGULAR_YELLOW}${timestamp} - ${BOLD_YELLOW}WARNING${REGULAR_YELLOW} - ${@} ${RESET_COLOR}\n" 1>&"$WARN_FD"

    return 0
}

function error_msg
{
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    printf "${REGULAR_RED}${timestamp} - ${BOLD_RED}ERROR${REGULAR_RED} --- ${@} ${RESET_COLOR}\n" 1>&"$ERROR_FD"

    return 0
}

function ask_msg
{
    printf "${BOLD_CYAN} ${@} ${RESET_COLOR}\n"

    return 0
}

function init_logging
{
    # Try to detect logging level
    local log_level="$1"
    local is_log_level_detetcted="false"

    if [[ "$log_level" =~ ^-?[0-9]+$ ]] # Is it a number ?
    then
        if [[ "$log_level" -ge "$QUIET_LEVEL" && "$log_level" -le "$DEBUG_LEVEL" ]]
        then
            is_log_level_detetcted="true"
        fi
    fi
    
    if [[ "$is_log_level_detetcted" != "true" ]]
    then
        log_level="$INFO_LEVEL"

        printf "${BOLD_YELLOW}WARNING${REGULAR_YELLOW} - Logging level is not detected ${RESET_COLOR}\n"
        printf "${BOLD_YELLOW}WARNING${REGULAR_YELLOW} - Default logging level (3-INFO) is enabled ${RESET_COLOR}\n"
    fi

    # Check a file for logging
    local log_file=""
    local is_logging_to_file="false"

    if [[ "$#" -gt "1" ]] # Does the second argument exist ?
    then
        log_file="$2"

        if [[ ! -z "$log_file" ]]
        then
            local log_file_dir=""
            log_file_dir=$(dirname "$log_file")
            local -i rel_val="$?"

            if [[ "$rel_val" -eq "0" ]]
            then
                if [[ -d "$log_file_dir" ]]
                then
                    log_file=$(realpath "$log_file")

                    if [[ ! -f "$log_file" ]]
                    then
                        touch "$log_file"
                    fi

                    if [[ -w "$log_file" ]]
                    then
                        is_logging_to_file="true"
                    else
                        printf "${BOLD_YELLOW}WARNING${REGULAR_YELLOW} - Write permission is NOT granted on \'${log_file}\' ${RESET_COLOR}\n"
                    fi
                else
                    printf "${BOLD_YELLOW}WARNING${REGULAR_YELLOW} - Directory for logging does not exist ${RESET_COLOR}\n"
                fi
            else
                printf "${BOLD_YELLOW}WARNING${REGULAR_YELLOW} - Logging directory is undetected ${RESET_COLOR}\n"
            fi
        fi
    fi

    # Setup configuration for logging
    exec 104>&1
    exec 105>&2

    if [[ "$is_logging_to_file" == "true" ]]
    then
        exec 1> >(tee --append "$log_file" 1>&"$STDOUT_BACKUP_FD")
        exec 2> >(tee --append "$log_file" 1>&"$STDERR_BACKUP_FD")
    fi

    local log_level_text="INFO"

    if [[ "$log_level" -eq "$QUIET_LEVEL" ]]
    then
        set +o xtrace
        exec 100>/dev/null
        exec 101>/dev/null
        exec 102>/dev/null
        exec 103>/dev/null

        log_level_text="QUIET"

    elif [[ "$log_level" -eq "$ERROR_LEVEL" ]]
    then
        set +o xtrace
        exec 100>&2
        exec 101>/dev/null
        exec 102>/dev/null
        exec 103>/dev/null

        log_level_text="ERROR"

    elif [[ "$log_level" -eq "$WARN_LEVEL" ]]
    then
        set +o xtrace
        exec 100>&2
        exec 101>&1
        exec 102>/dev/null
        exec 103>/dev/null

        log_level_text="WARNING"

    elif [[ "$log_level" -eq "$INFO_LEVEL" ]]
    then
        set +o xtrace
        exec 100>&2
        exec 101>&1
        exec 102>&1
        exec 103>/dev/null

        log_level_text="INFO"

    else
        set -o xtrace
        exec 100>&2
        exec 101>&1
        exec 102>&1
        exec 103>&1

        log_level_text="DEBUG"
    fi

    info_msg "Current logging level is ${log_level_text}(${log_level})"

    if [[ "$is_logging_to_file" == "true" ]]
    then
        info_msg "File for logging - \'${log_file}\'"
    fi

    return 0
}

function deinit_logging
{
    exec 100>&-
    exec 101>&-
    exec 102>&-
    exec 103>&-
    set +o xtrace

    exec 1>&104 104>&-
    exec 2>&105 105>&-

    return 0
}
#**************************************************************
