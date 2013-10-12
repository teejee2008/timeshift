#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd "$DIR"

sh ./build-deb.sh
sudo gdebi --non-interactive ../builds/timeshift*.deb

cd "$backup"
