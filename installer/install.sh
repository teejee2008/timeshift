#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd "$DIR"

echo "Installing files..."

sudo cp -dpr --no-preserve=ownership -t / ./*

if [ $? -eq 0 ]; then
	echo "TimeShift was installed successfully"
	echo "Use the shortcut in the application menu or run: sudo timeshift"
else
	echo "Installation failed!"
	exit 1
fi

cd "$backup"
