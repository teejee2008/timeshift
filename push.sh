#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd "$DIR"

sh build-source.sh

echo "Pushing new revisions to launchpad..."
bzr push lp:~teejee2008/timeshift/trunk

cd "$backup"




