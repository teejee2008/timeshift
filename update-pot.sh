#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd "$DIR"

echo "Updating translation templates..."

xgettext --language=C --keyword=_ --copyright-holder='Tony George (teejee2008@gmail.com)' --package-name='timeshift' --package-version='2.2' --msgid-bugs-address='teejee2008@gmail.com' --escape --sort-output -o timeshift.pot src/*.vala

#check for errors
if [ $? -ne 0 ]; then
	echo "Failed"
	exit 1
fi

cd "$backup"
