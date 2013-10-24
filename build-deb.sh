#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd "$DIR"

rm -rf ../builds

bzr builddeb --native --build-dir ../builds/temp --result-dir ../builds

#check for errors
if [ $? -ne 0 ]; then
	cd "$backup"
	echo "Failed"
	exit 1
fi

ls -l ../builds

cd "$backup"
