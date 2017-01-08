#!/bin/bash

app_name='timeshift'
app_fullname='Timeshift'
tgz="../../pbuilder/"
dsc="../../builds/${app_name}*.dsc"
libs="../../libs"

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd $DIR

sh build-source.sh
cd installer

echo "Building installer..."

chmod u+x ./install.sh

# build installer -------------------------------------

for arch in i386 amd64
do

rm -rf ${arch}
mkdir -p ${arch}

sudo pbuilder --build  --buildresult ${arch} --basetgz "${tgz}base-${arch}.tgz" ${dsc}

#check for errors
if [ $? -ne 0 ]; then
	cd "$backup"
	echo "Failed"
	exit 1
fi

dpkg-deb -x ${arch}/${app_name}*.deb ${arch}/extracted

cp -p --no-preserve=ownership -t ${arch}/extracted ./install.sh
cp -p --no-preserve=ownership -t ${arch}/extracted/usr/share/${app_name}/libs ${libs}/${arch}/libgee.so.2
cp -p --no-preserve=ownership -t ${arch}/extracted/usr/share/${app_name}/libs ${libs}/${arch}/libgudev-1.0.so.0
cp -p --no-preserve=ownership -t ${arch}/extracted/usr/share/${app_name}/libs ${libs}/${arch}/libjson-glib-1.0.so.0
chmod --recursive 0755 ${arch}/extracted/usr/share/${app_name}

makeself ${arch}/extracted ./${app_name}-latest-${arch}.run "${app_fullname} (${arch})" ./install.sh 

#check for errors
if [ $? -ne 0 ]; then
	cd "$backup"
	echo "Failed"
	exit 1
fi

cp -p --no-preserve=ownership ./${arch}/${app_name}*.deb ./${app_name}-latest-${arch}.deb 

done

cd "$backup"
