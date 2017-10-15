#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd $DIR

. ./BUILD_CONFIG

sh build-source.sh

rm -fv release/${pkg_name}-*.deb 

build_deb_for_dist() {

dist=$1
arch=$2

echo ""
echo "=========================================================================="
echo " build-deb.sh : $dist-$arch"
echo "=========================================================================="
echo ""

rm -rfv release/${arch}
mkdir -pv release/${arch}

echo "-------------------------------------------------------------------------"

pbuilder-dist $dist $arch build release/source/${pkg_name}*.dsc --buildresult release/$arch 

if [ $? -ne 0 ]; then cd "$backup"; echo "Failed"; exit 1; fi

echo "--------------------------------------------------------------------------"

cp -pv --no-preserve=ownership release/${arch}/${pkg_name}*.deb release/${pkg_name}-v${pkg_version}-${arch}.deb 

if [ $? -ne 0 ]; then cd "$backup"; echo "Failed"; exit 1; fi

echo "--------------------------------------------------------------------------"

}

build_deb_for_dist xenial i386
build_deb_for_dist xenial amd64
#build_deb_for_dist stretch armel
#build_deb_for_dist stretch armhf

cd "$backup"
