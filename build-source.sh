#!/bin/bash

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

# commit to bzr repo
bzr add *
bzr commit -m "updated"

#skip errors as commit may fail if no changes

echo "--------------------------------------------------------------------------"

# clean build dir
rm -rf ../builds

# build source
bzr builddeb --source --native --build-dir ../builds/temp --result-dir ../builds

#check for errors
if [ $? -ne 0 ]; then
	cd "$backup"; echo "Failed"; exit 1;
fi

echo "--------------------------------------------------------------------------"

# list files
ls -l ../builds

echo "-------------------------------------------------------------------------"

cd "$backup"
