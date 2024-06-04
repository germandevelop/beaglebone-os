#!/usr/bin/env bash

###################################################################
# Script Name   : OS builder
# Description   : Use '--help' flag for the description
# Compatibility	: Shell: bash. OS: Linux.
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
readonly FILESYSTEM_DIR="${SOURCE_DIR}/filesystem"
readonly DEVICETREE_DIR="${SOURCE_DIR}/devicetree"
readonly BUILD_DIR="${SOURCE_DIR}/build"
readonly UBOOT_DIR="${BUILD_DIR}/u-boot"
readonly LINUX_DIR="${BUILD_DIR}/linux"
readonly BUSYBOX_DIR="${BUILD_DIR}/busybox"
readonly DROPBEAR_DIR="${BUILD_DIR}/dropbear"
readonly LIBCRYPT_DIR="${BUILD_DIR}/libcrypt_armhf"
readonly DISKTOOLS_DIR="${BUILD_DIR}/disktools_armhf"
readonly BOOST_DIR="${BUILD_DIR}/boost"
readonly CAIRO_DIR="${BUILD_DIR}/cairo"
readonly CAIROMM_DIR="${BUILD_DIR}/cairomm"
readonly PANGO_DIR="${BUILD_DIR}/pango"
readonly PANGOMM_DIR="${BUILD_DIR}/pangomm"
readonly ALSA_DIR="${BUILD_DIR}/alsa"
readonly IMAGE_DIR="${BUILD_DIR}/image"
readonly INITRAMFS_DIR="${IMAGE_DIR}/initramfs"

readonly KERNEL_CONFIG="${SOURCE_DIR}/kernel_config"
readonly BUSYBOX_CONFIG="${SOURCE_DIR}/busybox_config"
readonly INITRAMFS_LIST="${SOURCE_DIR}/initramfs.list"
readonly IMAGE_FIT="${SOURCE_DIR}/image_fit.its"
readonly BOOT_SCRIPT="${SOURCE_DIR}/boot.script"
readonly SD_BOOT_SCRIPT="${SOURCE_DIR}/sd_boot.script"
readonly SD_IMAGE_SFDISK="${SOURCE_DIR}/sd_image.sfdisk"

readonly INITRAMFS_GENERATOR="${LINUX_DIR}/usr/gen_init_cpio"
#**************************************************************


#**************************************************************
# SOURCES
#**************************************************************
source "${SOURCE_DIR}/logger.sh"
#**************************************************************


#**************************************************************
# ARGUMENTS
#**************************************************************
DEBUG_ARG="false"
LOG_FILE_ARG=""
HELP_ARG="false"
VERSION_ARG="false"

function print_help
{
    printf "Script to build OS and libraries\n"
    printf "Version: ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}\n"
    printf "\n"
    printf "Usage:\n"
    printf "\tos.sh [options]\n"
    printf "\n"
    printf "Options:\n"
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
    options=$(getopt --unquoted --options dl:hV --longoptions debug,log:,help,version -- "$@")
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

        if [[ "$option" == "-d" || "$option" == "--debug" ]]
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

    rm --force --recursive "$IMAGE_DIR" 1>&"$DEBUG_FD"  2>&"$ERROR_FD"

    deinit_logging

    return 0
}

function install_packages
{
    info_msg "Install packages"

    sudo apt update --yes   1>&"$INFO_FD"   2>&"$ERROR_FD"

    sudo apt install --yes git              1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes build-essential  1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes g++              1>&"$INFO_FD"   2>&"$ERROR_FD"
	sudo apt install --yes cmake            1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes meson            1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes docbook-xsl      1>&"$INFO_FD"   2>&"$ERROR_FD"

    sudo apt install --yes gcc-avr      1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes binutils-avr 1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes avr-libc     1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes gdb-avr      1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes avrdude      1>&"$INFO_FD"   2>&"$ERROR_FD"

    sudo apt install --yes alsa-utils   1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes libusb-dev   1>&"$INFO_FD"   2>&"$ERROR_FD"
	sudo apt install --yes picocom      1>&"$INFO_FD"   2>&"$ERROR_FD"

    sudo apt install --yes libsigc++-2.0-dev            1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes libcairomm-1.0-dev           1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes libboost-thread-dev          1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes libboost-log-dev             1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes libboost-program-options-dev 1>&"$INFO_FD"   2>&"$ERROR_FD"

    sudo apt install --yes g++-arm-linux-gnueabihf  1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes libncurses5-dev          1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes libssl-dev               1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes mm-common                1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes u-boot-tools             1>&"$INFO_FD"   2>&"$ERROR_FD"

    sudo apt install --yes gcc-arm-none-eabi    1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes openocd              1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes gdb-multiarch        1>&"$INFO_FD"   2>&"$ERROR_FD"
    sudo apt install --yes binutils-multiarch   1>&"$INFO_FD"   2>&"$ERROR_FD"

    return 0
}

function build_uboot
{
    info_msg "Build U-Boot"

    rm --force --recursive "$UBOOT_DIR" 1>&"$DEBUG_FD"   2>&"$ERROR_FD"

    git clone https://github.com/u-boot/u-boot.git "$UBOOT_DIR" 1>&"$INFO_FD"   2>&"$ERROR_FD"

    # MLO + u-boot.img
    pushd "$UBOOT_DIR"
        git checkout v2023.04                                                   1>&"$INFO_FD"   2>&"$ERROR_FD"
        make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- distclean              1>&"$DEBUG_FD"  2>&"$ERROR_FD"
        make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- am335x_evm_defconfig   1>&"$INFO_FD"   2>&"$ERROR_FD"
        make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- --jobs=6               1>&"$INFO_FD"   2>&"$ERROR_FD"
    popd

    return 0
}

function build_linux
{
    info_msg "Build Linux kernel, modules and device trees"

    rm --force --recursive "$LINUX_DIR"  1>&"$DEBUG_FD"   2>&"$ERROR_FD"

    git clone https://github.com/beagleboard/linux.git "$LINUX_DIR" 1>&"$INFO_FD"   2>&"$ERROR_FD"

    pushd "$LINUX_DIR"
        git checkout 5.10.168-ti-r61                                        1>&"$INFO_FD"   2>&"$ERROR_FD"
        cp --force --verbose "$KERNEL_CONFIG" ./.config                     1>&"$INFO_FD"   2>&"$ERROR_FD"
        make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage --jobs=6    1>&"$INFO_FD"   2>&"$ERROR_FD"
        make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- modules --jobs=6   1>&"$INFO_FD"   2>&"$ERROR_FD"
        make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- dtbs --jobs=6      1>&"$INFO_FD"   2>&"$ERROR_FD"
    popd

    return 0
}

function build_busybox
{
    info_msg "Build BusyBox"
    
    rm --force --recursive "$BUSYBOX_DIR"   1>&"$DEBUG_FD"   2>&"$ERROR_FD"

    git clone https://github.com/mirror/busybox.git "$BUSYBOX_DIR"  1>&"$INFO_FD"   2>&"$ERROR_FD"

    pushd "$BUSYBOX_DIR"
        git checkout 1_36_0                                         1>&"$INFO_FD"   2>&"$ERROR_FD"
        cp --force --verbose "$BUSYBOX_CONFIG" ./.config            1>&"$INFO_FD"   2>&"$ERROR_FD"
        make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- --jobs=6   1>&"$INFO_FD"   2>&"$ERROR_FD"
        make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- install    1>&"$INFO_FD"   2>&"$ERROR_FD"
    popd

    return 0
}

function build_dropbear
{
    info_msg "Build DropBear"

    rm --force --recursive "$LIBCRYPT_DIR"  1>&"$DEBUG_FD"   2>&"$ERROR_FD"
    mkdir --parents "$LIBCRYPT_DIR"         1>&"$DEBUG_FD"   2>&"$ERROR_FD"

    wget "ftp.de.debian.org/debian/pool/main/libx/libxcrypt/libcrypt-dev_4.4.18-4_armhf.deb" --directory-prefix="$LIBCRYPT_DIR" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    wget "ftp.de.debian.org/debian/pool/main/libx/libxcrypt/libcrypt1_4.4.18-4_armhf.deb" --directory-prefix="$LIBCRYPT_DIR"    1>&"$INFO_FD"   2>&"$ERROR_FD"

    for package in "$LIBCRYPT_DIR"/*
    do
        dpkg-deb --extract "$package" "$LIBCRYPT_DIR"
    done
    
    rm --force --recursive "$DROPBEAR_DIR"   1>&"$DEBUG_FD"   2>&"$ERROR_FD"

    git clone https://github.com/mkj/dropbear.git "$DROPBEAR_DIR" 1>&"$INFO_FD"   2>&"$ERROR_FD"

    pushd "$DROPBEAR_DIR"
        git checkout DROPBEAR_2022.83   1>&"$INFO_FD"   2>&"$ERROR_FD"
        (CPPFLAGS="-I${LIBCRYPT_DIR}/usr/include" LDFLAGS="-L${LIBCRYPT_DIR}/usr/lib/arm-linux-gnueabihf" ./configure --disable-zlib --disable-loginfunc --enable-bundled-libtom --disable-lastlog --host=arm-linux-gnueabihf)
        make PROGRAMS="dropbear dbclient scp" --jobs=6  1>&"$INFO_FD"   2>&"$ERROR_FD"
    popd

    return 0
}

function download_disk_tools
{
    info_msg "Download Disk-Tools"

    rm --force --recursive "$DISKTOOLS_DIR" 1>&"$DEBUG_FD"  2>&"$ERROR_FD"
    mkdir --parents "$DISKTOOLS_DIR"        1>&"$DEBUG_FD"  2>&"$ERROR_FD"

    wget http://ftp.de.debian.org/debian/pool/main/u/util-linux/libblkid1_2.36.1-8+deb11u1_armhf.deb --directory-prefix="$DISKTOOLS_DIR"        1>&"$INFO_FD"   2>&"$ERROR_FD"
    wget http://ftp.de.debian.org/debian/pool/main/u/util-linux/libuuid1_2.36.1-8+deb11u1_armhf.deb --directory-prefix="$DISKTOOLS_DIR"         1>&"$INFO_FD"   2>&"$ERROR_FD"
    wget http://ftp.de.debian.org/debian/pool/main/n/ncurses/libtinfo6_6.2+20201114-2+deb11u2_armhf.deb --directory-prefix="$DISKTOOLS_DIR"     1>&"$INFO_FD"   2>&"$ERROR_FD"
    wget http://ftp.de.debian.org/debian/pool/main/u/util-linux/libsmartcols1_2.36.1-8+deb11u1_armhf.deb --directory-prefix="$DISKTOOLS_DIR"    1>&"$INFO_FD"   2>&"$ERROR_FD"
    wget http://ftp.de.debian.org/debian/pool/main/u/util-linux/libfdisk1_2.36.1-8+deb11u1_armhf.deb --directory-prefix="$DISKTOOLS_DIR"        1>&"$INFO_FD"   2>&"$ERROR_FD"
    wget http://ftp.de.debian.org/debian/pool/main/u/util-linux/fdisk_2.36.1-8+deb11u1_armhf.deb --directory-prefix="$DISKTOOLS_DIR"            1>&"$INFO_FD"   2>&"$ERROR_FD"

    wget http://ftp.de.debian.org/debian/pool/main/e/e2fsprogs/libext2fs2_1.46.2-2_armhf.deb --directory-prefix="$DISKTOOLS_DIR"    1>&"$INFO_FD"   2>&"$ERROR_FD"
    wget http://ftp.de.debian.org/debian/pool/main/e/e2fsprogs/libcom-err2_1.46.2-2_armhf.deb --directory-prefix="$DISKTOOLS_DIR"   1>&"$INFO_FD"   2>&"$ERROR_FD"
    wget http://ftp.de.debian.org/debian/pool/main/e/e2fsprogs/e2fsprogs_1.46.2-2_armhf.deb --directory-prefix="$DISKTOOLS_DIR"     1>&"$INFO_FD"   2>&"$ERROR_FD"

    for package in "$DISKTOOLS_DIR"/*
    do
        dpkg-deb --extract "$package" "$DISKTOOLS_DIR"
    done

    return 0
}

function build_boost
{
    info_msg "Build and Install Boost (armhf)"
    
    rm --force --recursive "$BOOST_DIR" 1>&"$DEBUG_FD"  2>&"$ERROR_FD"

    git clone https://github.com/boostorg/boost.git "$BOOST_DIR"    1>&"$INFO_FD"   2>&"$ERROR_FD"

    pushd "$BOOST_DIR"
        git checkout boost-1.81.0   1>&"$INFO_FD"   2>&"$ERROR_FD"
        git submodule init          1>&"$INFO_FD"   2>&"$ERROR_FD"
        git submodule update        1>&"$INFO_FD"   2>&"$ERROR_FD"

        ./bootstrap.sh --with-libraries=thread,log,program_options                          1>&"$INFO_FD"   2>&"$ERROR_FD"
        echo "using gcc : arm : arm-linux-gnueabihf-g++ ;" >> ./project-config.jam
        ./b2 --build-dir=./build_armhf --prefix=/usr/local/arm-linux-gnueabihf \
        --layout=tagged --no-samples --no-tests variant=release target-os=linux  \
        link=shared runtime-link=shared toolset=gcc-arm threading=multi -j6                 1>&"$INFO_FD"   2>&"$ERROR_FD"
        sudo ./b2 install --build-dir=./build_armhf --prefix=/usr/local/arm-linux-gnueabihf \
        --layout=tagged --no-samples --no-tests variant=release target-os=linux  \
        link=shared runtime-link=shared toolset=gcc-arm threading=multi -j6                 1>&"$INFO_FD"   2>&"$ERROR_FD"
    popd

    return 0
}

function build_cairo
{
    info_msg "Build and Install Cairo (armhf)"
    
    rm --force --recursive "$CAIRO_DIR" 1>&"$DEBUG_FD"  2>&"$ERROR_FD"

    git clone git://anongit.freedesktop.org/git/cairo "$CAIRO_DIR"  1>&"$INFO_FD"   2>&"$ERROR_FD"

    pushd "$CAIRO_DIR"
        git checkout 1.17.8 1>&"$INFO_FD"   2>&"$ERROR_FD"

        cp --verbose "${SOURCE_DIR}/meson_armhf.txt" ./  1>&"$INFO_FD"   2>&"$ERROR_FD"

        meson setup --cross-file=meson_armhf.txt --buildtype=release \
        --prefix=/usr/local/arm-linux-gnueabihf "${CAIRO_DIR}/armhf_build"  1>&"$INFO_FD"   2>&"$ERROR_FD"

        ninja -C "${CAIRO_DIR}/armhf_build"                 1>&"$INFO_FD"   2>&"$ERROR_FD"
        sudo ninja -C "${CAIRO_DIR}/armhf_build" install    1>&"$INFO_FD"   2>&"$ERROR_FD"
    popd


    info_msg "Build and Install Cairo-mm (armhf)"
    
    rm --force --recursive "$CAIROMM_DIR" 1>&"$DEBUG_FD"  2>&"$ERROR_FD"

    git clone git://git.cairographics.org/git/cairomm "$CAIROMM_DIR"  1>&"$INFO_FD"   2>&"$ERROR_FD"

    pushd "$CAIROMM_DIR"
        git checkout 1.16.2 1>&"$INFO_FD"   2>&"$ERROR_FD"

        cp --verbose "${SOURCE_DIR}/meson_armhf.txt" ./  1>&"$INFO_FD"   2>&"$ERROR_FD"

        meson setup --cross-file=meson_armhf.txt --buildtype=release \
        --prefix=/usr/local/arm-linux-gnueabihf "${CAIROMM_DIR}/armhf_build"    1>&"$INFO_FD"   2>&"$ERROR_FD"

        ninja -C "${CAIROMM_DIR}/armhf_build"               1>&"$INFO_FD"   2>&"$ERROR_FD"
        sudo ninja -C "${CAIROMM_DIR}/armhf_build" install  1>&"$INFO_FD"   2>&"$ERROR_FD"
    popd

    return 0
}

function build_pango
{
    info_msg "Build and Install Pango (armhf)"
    
    rm --force --recursive "$PANGO_DIR" 1>&"$DEBUG_FD"  2>&"$ERROR_FD"

    git clone https://gitlab.gnome.org/GNOME/pango.git "$PANGO_DIR"  1>&"$INFO_FD"   2>&"$ERROR_FD"

    pushd "$PANGO_DIR"
        git checkout 1.50.14 1>&"$INFO_FD"   2>&"$ERROR_FD"

        cp --verbose "${SOURCE_DIR}/meson_armhf.txt" ./  1>&"$INFO_FD"   2>&"$ERROR_FD"

        meson setup --cross-file=meson_armhf.txt --buildtype=release \
        --prefix=/usr/local/arm-linux-gnueabihf "${PANGO_DIR}/armhf_build"  1>&"$INFO_FD"   2>&"$ERROR_FD"

        ninja -C "${PANGO_DIR}/armhf_build"                 1>&"$INFO_FD"   2>&"$ERROR_FD"
        sudo ninja -C "${PANGO_DIR}/armhf_build" install    1>&"$INFO_FD"   2>&"$ERROR_FD"
    popd


    info_msg "Build and Install Pango-mm (armhf)"
    
    rm --force --recursive "$PANGOMM_DIR" 1>&"$DEBUG_FD"  2>&"$ERROR_FD"

    git clone https://gitlab.gnome.org/GNOME/pangomm.git "$PANGOMM_DIR"  1>&"$INFO_FD"   2>&"$ERROR_FD"

    pushd "$PANGOMM_DIR"
        git checkout 2.50.1 1>&"$INFO_FD"   2>&"$ERROR_FD"

        cp --verbose "${SOURCE_DIR}/meson_armhf.txt" ./  1>&"$INFO_FD"   2>&"$ERROR_FD"

        meson setup --cross-file=meson_armhf.txt --buildtype=release \
        --prefix=/usr/local/arm-linux-gnueabihf --libdir=lib "${PANGOMM_DIR}/armhf_build"    1>&"$INFO_FD"   2>&"$ERROR_FD"

        ninja -C "${PANGOMM_DIR}/armhf_build"               1>&"$INFO_FD"   2>&"$ERROR_FD"
        sudo ninja -C "${PANGOMM_DIR}/armhf_build" install  1>&"$INFO_FD"   2>&"$ERROR_FD"
    popd

    return 0
}

function build_alsa
{
    info_msg "Build and Install Alsa (armhf)"
    
    rm --force --recursive "$ALSA_DIR"  1>&"$DEBUG_FD"  2>&"$ERROR_FD"

    git clone https://github.com/alsa-project/alsa-lib.git "$ALSA_DIR"  1>&"$INFO_FD"   2>&"$ERROR_FD"

    pushd "$ALSA_DIR"
        git checkout v1.2.9 1>&"$INFO_FD"   2>&"$ERROR_FD"

        libtoolize --force --copy --automake    1>&"$INFO_FD"   2>&"$ERROR_FD"
	    aclocal                                 1>&"$INFO_FD"   2>&"$ERROR_FD"
	    autoheader                              1>&"$INFO_FD"   2>&"$ERROR_FD"
	    automake --foreign --copy --add-missing 1>&"$INFO_FD"   2>&"$ERROR_FD"
	    autoconf                                1>&"$INFO_FD"   2>&"$ERROR_FD"

        ./configure --enable-shared=yes --enable-static=no --with-debug=no --disable-mixer --disable-rawmidi \
        --disable-aload --disable-old-symbols --disable-python --disable-hwdep --disable-topology --disable-seq --disable-ucm \
        --host=arm-linux-gnueabihf --prefix=/usr/local/arm-linux-gnueabihf  1>&"$INFO_FD"   2>&"$ERROR_FD"

        make --jobs=6       1>&"$INFO_FD"   2>&"$ERROR_FD"
        sudo make install   1>&"$INFO_FD"   2>&"$ERROR_FD"
    popd

    return 0
}

function create_image
{
    info_msg "Create OS images"

    # Compile device-trees
    pushd "$LINUX_DIR"
        cp --force --verbose "$DEVICETREE_DIR"/* ./arch/arm/boot/dts/overlays   1>&"$INFO_FD"   2>&"$ERROR_FD"
        make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- dtbs --jobs=6          1>&"$INFO_FD"   2>&"$ERROR_FD"
    popd

    # Prepare initramfs
    mkdir --parents "$INITRAMFS_DIR"    1>&"$DEBUG_FD"   2>&"$ERROR_FD"

    cp --recursive --verbose "$FILESYSTEM_DIR"/* "$INITRAMFS_DIR"   1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${SOURCE_DIR}/logger.sh" "${INITRAMFS_DIR}/etc/"  1>&"$INFO_FD"   2>&"$ERROR_FD"

    mkdir --parents "${INITRAMFS_DIR}/boot/dts/overlays"    1>&"$INFO_FD"   2>&"$ERROR_FD"
    mkdir --parents "${INITRAMFS_DIR}/lib/modules"          1>&"$INFO_FD"   2>&"$ERROR_FD"
    mkdir --parents "${INITRAMFS_DIR}/usr/lib"              1>&"$INFO_FD"   2>&"$ERROR_FD"
    mkdir "${INITRAMFS_DIR}/bin"                            1>&"$INFO_FD"   2>&"$ERROR_FD"
    mkdir "${INITRAMFS_DIR}/sbin"                           1>&"$INFO_FD"   2>&"$ERROR_FD"

    cp --verbose "${LINUX_DIR}/arch/arm/boot/dts/overlays"/node-*.dtbo "${INITRAMFS_DIR}/boot/dts/overlays/"    1>&"$INFO_FD"   2>&"$ERROR_FD"

    cp --verbose "${LINUX_DIR}/sound/ac97_bus.ko"                               "${INITRAMFS_DIR}/lib/modules/" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/sound/soundcore.ko"                              "${INITRAMFS_DIR}/lib/modules/" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/sound/core/snd.ko"                               "${INITRAMFS_DIR}/lib/modules/" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/sound/core/snd-timer.ko"                         "${INITRAMFS_DIR}/lib/modules/" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/sound/core/snd-pcm.ko"                           "${INITRAMFS_DIR}/lib/modules/" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/sound/core/snd-pcm-dmaengine.ko"                 "${INITRAMFS_DIR}/lib/modules/" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/sound/soc/snd-soc-core.ko"                       "${INITRAMFS_DIR}/lib/modules/" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/sound/soc/ti/snd-soc-ti-edma.ko"                 "${INITRAMFS_DIR}/lib/modules/" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/sound/soc/ti/snd-soc-ti-sdma.ko"                 "${INITRAMFS_DIR}/lib/modules/" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/sound/soc/ti/snd-soc-ti-udma.ko"                 "${INITRAMFS_DIR}/lib/modules/" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/sound/soc/ti/snd-soc-davinci-mcasp.ko"           "${INITRAMFS_DIR}/lib/modules/" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/sound/soc/generic/snd-soc-simple-card-utils.ko"  "${INITRAMFS_DIR}/lib/modules/" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/sound/soc/generic/snd-soc-simple-card.ko"        "${INITRAMFS_DIR}/lib/modules/" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/sound/soc/codecs/snd-soc-hdmi-codec.ko"          "${INITRAMFS_DIR}/lib/modules/" 1>&"$INFO_FD"   2>&"$ERROR_FD"

    cp --verbose "${LINUX_DIR}/drivers/iio/chemical/pms7003.ko"     "${INITRAMFS_DIR}/lib/modules/"   1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/drivers/iio/pressure/bmp280.ko"      "${INITRAMFS_DIR}/lib/modules/"   1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/drivers/iio/pressure/bmp280-i2c.ko"  "${INITRAMFS_DIR}/lib/modules/"   1>&"$INFO_FD"   2>&"$ERROR_FD"

    cp --verbose /usr/arm-linux-gnueabihf/lib/ld-linux-armhf.so.3   "${INITRAMFS_DIR}/lib"      1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/arm-linux-gnueabihf/lib/libc.so.6             "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/arm-linux-gnueabihf/lib/libpthread.so.0       "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/arm-linux-gnueabihf/lib/libm.so.6             "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/arm-linux-gnueabihf/lib/librt.so.1            "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/arm-linux-gnueabihf/lib/libnss_compat.so.2    "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/arm-linux-gnueabihf/lib/libnss_files.so.2     "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/arm-linux-gnueabihf/lib/libnss_dns.so.2       "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/arm-linux-gnueabihf/lib/libresolv.so.2        "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/arm-linux-gnueabihf/lib/libstdc++.so.6        "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/arm-linux-gnueabihf/lib/libgcc_s.so.1         "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"

    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libsigc-3.0.so.0.0.0        "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libpng16.so.16.37.0         "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libfreetype.so.6.18.0       "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libfontconfig.so.1.13.0     "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libexpat.so.1.6.11          "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libcairomm-1.16.so.1.4.0    "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libcairo.so.2.11708.0       "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libpixman-1.so.0.42.3       "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libz.so                     "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"

    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libffi.so.7.1.0                 "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libfribidi.so.0.4.0             "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libgio-2.0.so.0.7400.0          "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libglib-2.0.so.0.7400.0         "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libgmodule-2.0.so.0.7400.0      "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libgobject-2.0.so.0.7400.0      "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libharfbuzz.so.0.40000.0        "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libpango-1.0.so.0.5000.14       "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libpangocairo-1.0.so.0.5000.14  "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libpangoft2-1.0.so.0.5000.14    "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libpcre2-8.so                   "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libgiomm-2.68.so.1.3.0          "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libglibmm-2.68.so.1.3.0         "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libpangomm-2.48.so.1.0.30       "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libasound.so.2.0.0              "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"

    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libboost_chrono-mt-a32.so.1.81.0            "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libboost_thread-mt-a32.so.1.81.0            "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libboost_filesystem-mt-a32.so.1.81.0        "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libboost_log-mt-a32.so.1.81.0               "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libboost_log_setup-mt-a32.so.1.81.0         "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/lib/libboost_program_options-mt-a32.so.1.81.0   "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"

    cp --verbose "${BUSYBOX_DIR}/_install/bin/busybox"  "${INITRAMFS_DIR}/bin"  1>&"$INFO_FD"   2>&"$ERROR_FD"

    cp --verbose "${DROPBEAR_DIR}/dropbear" "${INITRAMFS_DIR}/sbin" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${DROPBEAR_DIR}/dbclient" "${INITRAMFS_DIR}/sbin" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${DROPBEAR_DIR}/scp"      "${INITRAMFS_DIR}/sbin" 1>&"$INFO_FD"   2>&"$ERROR_FD"

    cp --verbose "${DISKTOOLS_DIR}/lib/arm-linux-gnueabihf/libtinfo.so.6.2"             "${INITRAMFS_DIR}/lib"      1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${DISKTOOLS_DIR}/usr/lib/arm-linux-gnueabihf/libblkid.so.1.1.0"       "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${DISKTOOLS_DIR}/usr/lib/arm-linux-gnueabihf/libfdisk.so.1.1.0"       "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${DISKTOOLS_DIR}/usr/lib/arm-linux-gnueabihf/libsmartcols.so.1.1.0"   "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${DISKTOOLS_DIR}/usr/lib/arm-linux-gnueabihf/libtic.so.6.2"           "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${DISKTOOLS_DIR}/usr/lib/arm-linux-gnueabihf/libuuid.so.1.3.0"        "${INITRAMFS_DIR}/usr/lib"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${DISKTOOLS_DIR}/lib/arm-linux-gnueabihf/libcom_err.so.2.1"           "${INITRAMFS_DIR}/lib"      1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${DISKTOOLS_DIR}/lib/arm-linux-gnueabihf/libe2p.so.2.3"               "${INITRAMFS_DIR}/lib"      1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${DISKTOOLS_DIR}/lib/arm-linux-gnueabihf/libext2fs.so.2.4"            "${INITRAMFS_DIR}/lib"      1>&"$INFO_FD"   2>&"$ERROR_FD"

    cp --verbose "${DISKTOOLS_DIR}/sbin/fdisk"      "${INITRAMFS_DIR}/sbin" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${DISKTOOLS_DIR}/sbin/sfdisk"     "${INITRAMFS_DIR}/sbin" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${DISKTOOLS_DIR}/sbin/badblocks"  "${INITRAMFS_DIR}/sbin" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${DISKTOOLS_DIR}/sbin/e2fsck"     "${INITRAMFS_DIR}/sbin" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${DISKTOOLS_DIR}/sbin/mke2fs"     "${INITRAMFS_DIR}/sbin" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${DISKTOOLS_DIR}/sbin/resize2fs"  "${INITRAMFS_DIR}/sbin" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${DISKTOOLS_DIR}/sbin/tune2fs"    "${INITRAMFS_DIR}/sbin" 1>&"$INFO_FD"   2>&"$ERROR_FD"

    mkdir --parents "${INITRAMFS_DIR}/etc/fonts/conf.d"                     1>&"$DEBUG_FD"   2>&"$ERROR_FD"
    mkdir --parents "${INITRAMFS_DIR}/usr/share/fontconfig/conf.avail"      1>&"$DEBUG_FD"   2>&"$ERROR_FD"
    mkdir --parents "${INITRAMFS_DIR}/usr/share/fonts/opentype/malayalam"   1>&"$DEBUG_FD"   2>&"$ERROR_FD"
    mkdir --parents "${INITRAMFS_DIR}/usr/share/fonts/opentype/urw-base35"  1>&"$DEBUG_FD"   2>&"$ERROR_FD"

    cp --verbose /usr/local/arm-linux-gnueabihf/etc/fonts/fonts.conf                "${INITRAMFS_DIR}/etc/fonts"                        1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/local/arm-linux-gnueabihf/share/fontconfig/conf.avail/*.conf  "${INITRAMFS_DIR}/usr/share/fontconfig/conf.avail"  1>&"$INFO_FD"   2>&"$ERROR_FD"

    cp --verbose /usr/share/fonts/opentype/malayalam/*  "${INITRAMFS_DIR}/usr/share/fonts/opentype/malayalam"   1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose /usr/share/fonts/opentype/urw-base35/* "${INITRAMFS_DIR}/usr/share/fonts/opentype/urw-base35"  1>&"$INFO_FD"   2>&"$ERROR_FD"

    # Generate initramfs
    local -r initramfs_list="${IMAGE_DIR}/initramfs.list"

    cp "$INITRAMFS_LIST" "$initramfs_list"  1>&"$INFO_FD"   2>&"$ERROR_FD"

    echo "dir /usr/share/fonts/opentype 0755 0 0" >> "$initramfs_list"
    echo "dir /usr/share/fonts/opentype/malayalam 0755 0 0" >> "$initramfs_list"
    echo "dir /usr/share/fonts/opentype/urw-base35 0755 0 0" >> "$initramfs_list"

    local -a font_mals=($(ls "${INITRAMFS_DIR}/usr/share/fonts/opentype/malayalam"))

    for font_mal in "${font_mals[@]}"
    do
        echo "file /usr/share/fonts/opentype/malayalam/${font_mal} initramfs/usr/share/fonts/opentype/malayalam/${font_mal} 0644 0 0" >> "$initramfs_list"
    done

    local -a font_urws=($(ls "${INITRAMFS_DIR}/usr/share/fonts/opentype/urw-base35"))

    for font_urw in "${font_urws[@]}"
    do
        echo "file /usr/share/fonts/opentype/urw-base35/${font_urw} initramfs/usr/share/fonts/opentype/urw-base35/${font_urw} 0644 0 0" >> "$initramfs_list"
    done

    local -a font_confs=($(ls "${INITRAMFS_DIR}/usr/share/fontconfig/conf.avail/"))

    for font_conf in "${font_confs[@]}"
    do
        echo "file /usr/share/fontconfig/conf.avail/${font_conf} initramfs/usr/share/fontconfig/conf.avail/${font_conf} 0644 0 0" >> "$initramfs_list"
        echo "slink /etc/fonts/conf.d/${font_conf} /usr/share/fontconfig/conf.avail/${font_conf} 0644 0 0" >> "$initramfs_list"
    done

    local -a links=($(ls "${BUSYBOX_DIR}/_install/bin/"))

    for link in "${links[@]}"
    do
        if [[ "$link" == "busybox" ]]
        then
            continue
        fi
        echo "slink /bin/${link} /bin/busybox 0777 0 0" >> "$initramfs_list"
    done

    links=($(ls "${BUSYBOX_DIR}/_install/sbin/"))

    for link in "${links[@]}"
    do
        echo "slink /sbin/${link} /bin/busybox 0777 0 0" >> "$initramfs_list"
    done

    links=($(ls "${BUSYBOX_DIR}/_install/usr/bin/"))

    for link in "${links[@]}"
    do
        echo "slink /usr/bin/${link} /bin/busybox 0777 0 0" >> "$initramfs_list"
    done

    links=($(ls "${BUSYBOX_DIR}/_install/usr/sbin/"))

    for link in "${links[@]}"
    do
        echo "slink /usr/sbin/${link} /bin/busybox 0777 0 0" >> "$initramfs_list"
    done

    pushd "$IMAGE_DIR"
        "$INITRAMFS_GENERATOR" "$initramfs_list" > "${IMAGE_DIR}/initramfs.cpio"
    popd

    # Generate image
    cp --verbose "$IMAGE_FIT" "${IMAGE_DIR}/image_fit.its"  1>&"$INFO_FD"   2>&"$ERROR_FD"

    cp --verbose "${LINUX_DIR}/arch/arm/boot/zImage"                            "$IMAGE_DIR"    1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/arch/arm/boot/dts/am335x-boneblack.dtb"          "$IMAGE_DIR"    1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/arch/arm/boot/dts/am335x-boneblack-wireless.dtb" "$IMAGE_DIR"    1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${LINUX_DIR}/arch/arm/boot/dts/am335x-bonegreen-wireless.dtb" "$IMAGE_DIR"    1>&"$INFO_FD"   2>&"$ERROR_FD"

    mkimage -f "${IMAGE_DIR}/image_fit.its" "${IMAGE_DIR}/os_image.itb" 1>&"$INFO_FD"   2>&"$ERROR_FD"

    # Generate sd-image
    cp --verbose "${UBOOT_DIR}/MLO"         "$IMAGE_DIR"    1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --verbose "${UBOOT_DIR}/u-boot.img"  "$IMAGE_DIR"    1>&"$INFO_FD"   2>&"$ERROR_FD"

    mkimage -c none -A arm -T script -d "$BOOT_SCRIPT"      "${IMAGE_DIR}/os_boot.scr"  1>&"$INFO_FD"   2>&"$ERROR_FD"
    mkimage -c none -A arm -T script -d "$SD_BOOT_SCRIPT"   "${IMAGE_DIR}/boot.scr"     1>&"$INFO_FD"   2>&"$ERROR_FD"

    local -r mlo_size=$(stat -c%s "${IMAGE_DIR}/MLO")
    local -r uboot_size=$(stat -c%s "${IMAGE_DIR}/u-boot.img")
    local -r script_size=$(stat -c%s "${IMAGE_DIR}/os_boot.scr")
    local -r sd_script_size=$(stat -c%s "${IMAGE_DIR}/boot.scr")
    local -r image_size=$(stat -c%s "${IMAGE_DIR}/os_image.itb")

    local -r total_size_bytes=$(( "$mlo_size" + "$uboot_size" + "$image_size" + "$sd_script_size" + "$script_size" + "1048576" ))
    local -r total_size_sectors=$(( "$total_size_bytes" / "512" ))
    local -r image_size_blocks=$(( "$total_size_sectors" + "4096" ))

    dd if=/dev/zero of="${IMAGE_DIR}/sd_os_image.img" bs=512 count="$image_size_blocks" 1>&"$INFO_FD"   2>&"$ERROR_FD"

    sed "s/REPLACE_SIZE/${total_size_sectors}/g" "$SD_IMAGE_SFDISK" > "${IMAGE_DIR}/sd_image.sfdisk"
    sfdisk "${IMAGE_DIR}/sd_os_image.img" < "${IMAGE_DIR}/sd_image.sfdisk"
    
    dd if=/dev/zero of="${IMAGE_DIR}/sd_fat.ptr" bs=512 count="$total_size_sectors" 1>&"$INFO_FD"   2>&"$ERROR_FD"
    mkfs.vfat "${IMAGE_DIR}/sd_fat.ptr"                                             1>&"$INFO_FD"   2>&"$ERROR_FD"
    mcopy -i "${IMAGE_DIR}/sd_fat.ptr" "${IMAGE_DIR}/MLO" ::                        1>&"$INFO_FD"   2>&"$ERROR_FD"
    mcopy -i "${IMAGE_DIR}/sd_fat.ptr" "${IMAGE_DIR}/u-boot.img" ::                 1>&"$INFO_FD"   2>&"$ERROR_FD"
    mcopy -i "${IMAGE_DIR}/sd_fat.ptr" "${IMAGE_DIR}/os_boot.scr" ::                1>&"$INFO_FD"   2>&"$ERROR_FD"
    mcopy -i "${IMAGE_DIR}/sd_fat.ptr" "${IMAGE_DIR}/boot.scr" ::                   1>&"$INFO_FD"   2>&"$ERROR_FD"
    mcopy -i "${IMAGE_DIR}/sd_fat.ptr" "${IMAGE_DIR}/os_image.itb" ::               1>&"$INFO_FD"   2>&"$ERROR_FD"

    dd if="${IMAGE_DIR}/MLO"        of="${IMAGE_DIR}/sd_os_image.img" count=1 seek=1 bs=128k    1>&"$INFO_FD"   2>&"$ERROR_FD"
    dd if="${IMAGE_DIR}/u-boot.img" of="${IMAGE_DIR}/sd_os_image.img" seek=1 bs=384k            1>&"$INFO_FD"   2>&"$ERROR_FD"
    dd if="${IMAGE_DIR}/sd_fat.ptr" of="${IMAGE_DIR}/sd_os_image.img" bs=512 seek=4096          1>&"$INFO_FD"   2>&"$ERROR_FD"

    # Copy images
    cp --force --verbose "${IMAGE_DIR}/sd_os_image.img" "$BUILD_DIR"   1>&"$INFO_FD"   2>&"$ERROR_FD"
    cp --force --verbose "${IMAGE_DIR}/os_image.itb"    "$BUILD_DIR"   1>&"$INFO_FD"   2>&"$ERROR_FD"

    rm --force --recursive "$IMAGE_DIR" 1>&"$DEBUG_FD"   2>&"$ERROR_FD"

    return 0
}

function select_action
{
    local -ra answer_array=([1]="Install packages" \
                            [2]="Build U-Boot" \
                            [3]="Build Linux" \
                            [4]="Build BusyBox" \
                            [5]="Build DropBear" \
                            [6]="Download Disk-Tools" \
                            [7]="Build Boost" \
                            [8]="Build Cairo" \
                            [9]="Build Pango" \
                            [10]="Build Alsa" \
                            [11]="Create image" \
                            [12]="Exit")

    ask_msg "Select action"

    select answer in "${answer_array[@]}"
    do
        if [[ !("$REPLY" =~ ^-?[0-9]+$) ]]
        then
            continue
        fi

        if (( "$REPLY" == "1" ))
        then
            install_packages

        elif (( "$REPLY" == "2" ))
        then
            build_uboot

        elif (( "$REPLY" == "3" ))
        then
            build_linux

        elif (( "$REPLY" == "4" ))
        then
            build_busybox

        elif (( "$REPLY" == "5" ))
        then
            build_dropbear

        elif (( "$REPLY" == "6" ))
        then
            download_disk_tools

        elif (( "$REPLY" == "7" ))
        then
            build_boost

        elif (( "$REPLY" == "8" ))
        then
            build_cairo

        elif (( "$REPLY" == "9" ))
        then
            build_pango

        elif (( "$REPLY" == "10" ))
        then
            build_alsa

        elif (( "$REPLY" == "11" ))
        then
            create_image

        elif (( "$REPLY" == "12" ))
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




# Some notes

#Debug
#cd /usr/bin
#ln -s /usr/bin/objdump objdump-multiarch
#ln -s /usr/bin/nm nm-multiarch
#For the FreeRTOS thread awareness you need to add -rtos parameter to the target create script inside tcl/target/stm32f4x.cfg
#target create $_TARGETNAME cortex_m -endian $_ENDIAN -dap $_CHIPNAME.dap -rtos FreeRTOS

#picocom --baud 115200 /dev/ttyUSB0
#sudo picocom --baud 115200 /dev/cuaU0
#Exit: Ctrl+A -> Ctrl+X

#echo 7 >> /sys/class/gpio/export
#echo out >> /sys/class/gpio/gpio7/direction
#echo 1 >> /sys/class/gpio/gpio7/value

#mount -o remount,rw /mnt/ro_data
#mount -o remount,ro /mnt/ro_data

#/tmp/bb_client_software --sound=/mnt/ro_data/sounds --image=/mnt/ro_data/images --config=/mnt/rw_data/config

#arecord -t wav -r 48000 -c 2 -f S16_LE file.wav

#sudo systemctl mask brltty.path

#startx <program>
#xinit <program>
