#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd "$DIR"

. ./BUILD_CONFIG

echo ""
echo "=========================================================================="
echo " build-upload-ppa.sh"
echo "=========================================================================="
echo ""

echo "app_name: $app_name"
echo "pkg_name: $pkg_name"
echo "--------------------------------------------------------------------------"

# build source
debuild -S

#check for errors
if [ $? -ne 0 ]; then
	cd "$backup"; echo "Failed"; exit 1;
fi

echo "--------------------------------------------------------------------------"

# upload to launchpad
dput ppa:teejee2008/ppa ../timeshift_*_source.changes

#check for errors
if [ $? -ne 0 ]; then
	cd "$backup"; echo "Failed"; exit 1;
fi

echo "-------------------------------------------------------------------------"

cd "$backup"
