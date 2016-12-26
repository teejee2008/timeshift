#!/bin/bash

app_name='timeshift'
app_fullname='Timeshift'
dsc="${app_name}*.dsc"

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd $DIR

if [ -z "$1" ]; then
	echo ""
	echo "E: Distribution name not specified"
	echo ""
	echo "Syntax: 	build-deb-for-dist <dist> <arch>"
	echo "Example: 	build-deb-for-dist trusty amd64"
	echo ""
	exit 1
else
	dist=$1
fi

if [ -z "$2" ]; then
	echo ""
	echo "E: Architecture not specified"
	echo ""
	echo "Syntax: 	build-deb-for-dist <dist> <arch>"
	echo "Example: 	build-deb-for-dist trusty amd64"
	echo ""
	exit 1
else
	arch=$2
fi

	
sh build-source.sh
cd ../builds

# build installer -------------------------------------

#for arch in amd64
#do

rm -rf "${dist}-${arch}"
mkdir -p "${dist}-${arch}"

sudo pbuilder --build --distribution ${dist} --architecture ${arch} --buildresult "${dist}-${arch}" --basetgz "../pbuilder/build/${dist}/base-${arch}.tgz" ${dsc}

#check for errors
if [ $? -ne 0 ]; then
	cd "$backup"
	echo "Failed"
	exit 1
fi

cp "${dist}-${arch}"/* ./

#done

cd "$backup"
