#!/bin/bash

set -e

home=/home/neuron
bdb=v2.6
vendor=?
vendor_version=?
arch=?
branch=?
cross=false
user=emqx
smart=false

while getopts ":a:v:b:c:u:s:" OPT; do
    case ${OPT} in
        a)
            arch=$OPTARG
            ;;
        v)
            vendor=$(echo $OPTARG | cut -d '/' -f 1)
            vendor_version=$(echo $OPTARG | cut -d '/' -f 2)
            ;;
        b)
            branch=$OPTARG
            ;;
        c)
            cross=$OPTARG
            ;;
        u)
            user=$OPTARG
            ;;
        s)
            smart=$OPTARG
            ;;
    esac
done

library=$home/$bdb/libs/chilinkos-$vendor_version
neuron_dir=$home/$bdb/Program/chilinkos-$vendor_version/$vendor

case $cross in
    (true)
        tool_dir=/usr/bin;;
    (false)
        tool_dir=$home/buildroot/$vendor/$vendor_version/output/host/bin;;
esac

function compile_source_with_tag() {
    local user=$1
    local repo=$2
    local branch=$3

    cd $neuron_dir
    git clone -b $branch git@github.com:${user}/${repo}.git
    cd $repo
    git submodule update --init
    if [ $repo == "neuron-modules" ]; then
      echo 'link_libraries(atomic)' >> cmake/cross.cmake
    fi
    mkdir build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release -DDISABLE_UT=ON -DDISABLE_WERROR=ON \
	-DTOOL_DIR=$tool_dir -DCOMPILER_PREFIX=$vendor \
	-DCMAKE_SYSTEM_PROCESSOR=$arch -DLIBRARY_DIR=$library \
	-DCMAKE_TOOLCHAIN_FILE=../cmake/cross.cmake

    case $smart in
        (true)
            cmake .. -DSMART_LINK=1 -DCMAKE_BUILD_TYPE=Release -DDISABLE_UT=ON -DDISABLE_WERROR=ON \
            -DTOOL_DIR=$tool_dir -DCOMPILER_PREFIX=$vendor \
            -DCMAKE_SYSTEM_PROCESSOR=$arch -DLIBRARY_DIR=$library \
            -DCMAKE_TOOLCHAIN_FILE=../cmake/cross.cmake;;
        (false)
            cmake .. -DCMAKE_BUILD_TYPE=Release -DDISABLE_UT=ON -DDISABLE_WERROR=ON \
            -DTOOL_DIR=$tool_dir -DCOMPILER_PREFIX=$vendor \
            -DCMAKE_SYSTEM_PROCESSOR=$arch -DLIBRARY_DIR=$library \
            -DCMAKE_TOOLCHAIN_FILE=../cmake/cross.cmake;;
    esac

    make -j4 

    if [ $repo == "neuron" ]; then
    	sudo make install
    fi
}

sudo rm -rf $neuron_dir/*
mkdir -p $neuron_dir
compile_source_with_tag $user neuron $branch
compile_source_with_tag $user neuron-modules $branch
