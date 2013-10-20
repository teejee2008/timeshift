#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd $DIR

sh build-source.sh
cd installer

echo "Building installer..."

tgz="/home/teejee/projects/pbuilder/"
dsc="/home/teejee/projects/builds/timeshift*.dsc"

chmod u+x ./install.sh

# build installer -------------------------------------

for arch in i386 amd64
do

rm -rf ${arch}
mkdir -p ${arch}

sudo pbuilder --build  --buildresult ${arch} --basetgz "${tgz}base-${arch}.tgz" ${dsc}

dpkg-deb -x ${arch}/timeshift*.deb ${arch}/extracted

cp -p --no-preserve=ownership -t ${arch}/extracted ./install.sh

makeself ${arch}/extracted ./timeshift-latest-${arch}.run "TimeShift (${arch})" ./install.sh 

cp -p --no-preserve=ownership -t /home/teejee/Dropbox/Public/linux ./timeshift-latest-${arch}.run

done

cd "$backup"
