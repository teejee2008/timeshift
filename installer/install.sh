#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd "$DIR"

echo "Installing files..."

sudo cp -dpr --no-preserve=ownership -t / ./*

if [ $? -eq 0 ]; then
	echo "Installed successfully."
	echo ""
	echo "Start TimeShift using the shortcut in the application menu"
	echo "or by running the command: sudo timeshift"	
	echo ""
	echo "Following packages are required for TimeShift to function correctly:"
	echo "- libgtk-3 libgee2 libsoup libjson-glib rsync"
	echo "Please ensure that these packages are installed and up-to-date"
else
	echo "Installation failed!"
	exit 1
fi

cd "$backup"
