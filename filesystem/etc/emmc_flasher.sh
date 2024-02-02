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
# LOCAL FUNCTIONS
#**************************************************************
function setup_emmc_partitions
{
    info_msg "Create and format eMMC partitions"

    dd if=/dev/zero of=/dev/mmcblk1 bs=4M count=4                       1>&"$INFO_FD" 2>&"$ERROR_FD"
    sfdisk /dev/mmcblk1 < /etc/emmc.sfdisk                              1>&"$INFO_FD" 2>&"$ERROR_FD"
    mkfs.vfat -v -n "boot" /dev/mmcblk1p1                               1>&"$INFO_FD" 2>&"$ERROR_FD"
    mkfs.ext4 -v -F -L "os" -t ext4 -O ^has_journal /dev/mmcblk1p2      1>&"$INFO_FD" 2>&"$ERROR_FD"
    mkfs.ext4 -v -F -L "data_ro" -t ext4 -O ^has_journal /dev/mmcblk1p3 1>&"$INFO_FD" 2>&"$ERROR_FD"
    mkfs.ext4 -v -F -L "data_rw" -t ext4 -O ^has_journal /dev/mmcblk1p4 1>&"$INFO_FD" 2>&"$ERROR_FD"

    return 0
}

function setup_emmc_bootloader
{
    info_msg "Copy booloader to eMMC"

    mkdir -p /mnt/sd_card                                           1>&"$INFO_FD" 2>&"$ERROR_FD"
    mount -v -t vfat /dev/mmcblk0p1 /mnt/sd_card                    1>&"$INFO_FD" 2>&"$ERROR_FD"
    mkdir -p /mnt/emmc_boot                                         1>&"$INFO_FD" 2>&"$ERROR_FD"
    mount -v -t vfat /dev/mmcblk1p1 /mnt/emmc_boot                  1>&"$INFO_FD" 2>&"$ERROR_FD"
    dd if=/mnt/sd_card/MLO of=/dev/mmcblk1 count=1 seek=1 bs=128k   1>&"$INFO_FD" 2>&"$ERROR_FD"
    dd if=/mnt/sd_card/u-boot.img of=/dev/mmcblk1 seek=1 bs=384k    1>&"$INFO_FD" 2>&"$ERROR_FD"
    cp -f /mnt/sd_card/os_boot.scr /mnt/emmc_boot/boot.scr          1>&"$INFO_FD" 2>&"$ERROR_FD"
    umount -v /mnt/emmc_boot                                        1>&"$INFO_FD" 2>&"$ERROR_FD"
    umount -v /mnt/sd_card                                          1>&"$INFO_FD" 2>&"$ERROR_FD"

    return 0
}

function setup_emmc_os
{
    info_msg "Copy OS image to eMMC"

    mkdir -p /mnt/sd_card                           1>&"$INFO_FD" 2>&"$ERROR_FD"
    mount -v -t vfat /dev/mmcblk0p1 /mnt/sd_card    1>&"$INFO_FD" 2>&"$ERROR_FD"
    mkdir -p /mnt/emmc_os                           1>&"$INFO_FD" 2>&"$ERROR_FD"
    mount -v -t ext4 /dev/mmcblk1p2 /mnt/emmc_os    1>&"$INFO_FD" 2>&"$ERROR_FD"
    cp -f /mnt/sd_card/os_image.itb /mnt/emmc_os/   1>&"$INFO_FD" 2>&"$ERROR_FD"
    umount -v /mnt/emmc_os                          1>&"$INFO_FD" 2>&"$ERROR_FD"
    umount -v /mnt/sd_card                          1>&"$INFO_FD" 2>&"$ERROR_FD"

    return 0
}

function clean_up
{
    umount -v /mnt/emmc_boot    1>&"$INFO_FD" 2>&"$ERROR_FD"
    umount -v /mnt/emmc_os      1>&"$INFO_FD" 2>&"$ERROR_FD"
    umount -v /mnt/sd_card      1>&"$INFO_FD" 2>&"$ERROR_FD"

    deinit_logging

    return 0
}

function print_version
{
    printf "eMMC-flasher version: ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}\n"

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
print_version

init_logging "$INFO_LEVEL"
enable_traps

setup_emmc_partitions
setup_emmc_bootloader
setup_emmc_os

disable_traps
deinit_logging

exit 0
#**************************************************************
