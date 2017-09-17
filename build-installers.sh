#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd $DIR

. ./BUILD_CONFIG

rm -vf installer/*.run
rm -vf installer/*.deb

# build debs
sh build-deb.sh

cd installer

for arch in i386 amd64
do

rm -rfv ${arch}/files
mkdir -pv ${arch}/files

echo ""
echo "=========================================================================="
echo " build-installers.sh : $arch"
echo "=========================================================================="
echo ""

dpkg-deb -x ${arch}/${pkg_name}*.deb ${arch}/files

#check for errors
if [ $? -ne 0 ]; then
	cd "$backup"; echo "Failed"; exit 1;
fi

echo "--------------------------------------------------------------------------"

rm -rfv ${arch}/${pkg_name}*.* # remove extra files
cp -pv --no-preserve=ownership ./sanity.config ./${arch}/sanity.config
sanity --generate --base-path ./${arch} --out-path . --arch ${arch}

#check for errors
if [ $? -ne 0 ]; then
	cd "$backup"; echo "Failed"; exit 1;
fi

mv -v ./*${arch}.run ./${pkg_name}-v${pkg_version}-${arch}.run 

echo "--------------------------------------------------------------------------"

done

cp -vf *.run ../../PACKAGES/
cp -vf *.deb ../../PACKAGES/

cd "$backup"
