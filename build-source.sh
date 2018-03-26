#!/bin/bash

for prog in pbuilder-dist make dpkg-source ; do
	if sh -c "which $prog 2> /dev/null"; then true ; else echo "You don\'t have $prog, install it" ; exit ; fi
done

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd "$DIR"

. ./BUILD_CONFIG

echo ""
echo "=========================================================================="
echo " build-source.sh"
echo "=========================================================================="
echo ""

echo "app_name: $app_name"
echo "pkg_name: $pkg_name"
echo "--------------------------------------------------------------------------"

# clean build dir

rm -rfv /tmp/builds
mkdir -pv /tmp/builds

make clean

rm -rfv release/source
mkdir -pv release/source

echo "--------------------------------------------------------------------------"

# build source package
dpkg-source --build ./

mv -vf ../$pkg_name*.dsc release/source/
mv -vf ../$pkg_name*.tar.xz release/source/

if [ $? -ne 0 ]; then cd "$backup"; echo "Failed"; exit 1; fi

echo "--------------------------------------------------------------------------"

# list files
ls -l release/source

echo "-------------------------------------------------------------------------"

cd "$backup"
