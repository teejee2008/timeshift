#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd "$DIR"

rm -rf ../builds
bzr builddeb --native --build-dir ../builds/temp --result-dir ../builds
ls -l ../builds

cd "$backup"
