#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd $DIR

. ./BUILD_CONFIG

rm -vf release/*.run
rm -vf release/*.deb

# build debs
sh build-deb.sh


for arch in i386 amd64
do

rm -rfv release/${arch}/files
mkdir -pv release/${arch}/files

echo ""
echo "=========================================================================="
echo " build-installers.sh : $arch"
echo "=========================================================================="
echo ""

dpkg-deb -x release/${pkg_name}-v${pkg_version}-${arch}.deb release/${arch}/files

if [ $? -ne 0 ]; then cd "$backup"; echo "Failed"; exit 1;fi

echo "--------------------------------------------------------------------------"

rm -rfv release/${arch}/${pkg_name}*.* # remove source files created by pbuilder
cp -pv --no-preserve=ownership release/sanity.config release/${arch}/sanity.config
sanity --generate --base-path release/${arch} --out-path release --arch ${arch}

if [ $? -ne 0 ]; then cd "$backup"; echo "Failed"; exit 1; fi

mv -v release/*${arch}.run release/${pkg_name}-v${pkg_version}-${arch}.run 

echo "--------------------------------------------------------------------------"

done

cp -vf release/*.run ../PACKAGES/
cp -vf release/*.deb ../PACKAGES/

cd "$backup"
