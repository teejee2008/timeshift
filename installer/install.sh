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
	echo "If it fails to start, please check if the following packages"
	echo "are installed on your system:"
	echo "- libgtk-3 libgee2 libsoup libjson-glib rsync"
	echo ""
else
	echo "Installation failed!"
	exit 1
fi

cd "$backup"
