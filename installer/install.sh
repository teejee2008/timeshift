#!/bin/bash

prefix=/usr
bindir=${prefix}/bin
sharedir=${prefix}/share
localedir=${sharedir}/locale
launcherdir=${sharedir}/applications

echo "Installing files..."

mkdir -p "${bindir}"
mkdir -p "${sharedir}"
mkdir -p "${launcherdir}"
mkdir -p "${sharedir}/timeshift"
mkdir -p "${sharedir}/pixmaps"
mkdir -p "/mnt/timeshift"

#binary
install -m 0755 timeshift "${bindir}"

#shared files
cp -dpr --no-preserve=ownership -t "${sharedir}/timeshift" ./share/timeshift/*
chmod --recursive 0755 ${sharedir}/timeshift/*

#launcher
install -m 0755 TimeShift.desktop "${launcherdir}"

#app icon
install -m 0755 ./share/pixmaps/timeshift.png "${sharedir}/pixmaps/"


if [ $? -eq 0 ]; then
	echo "TimeShift was installed successfully"
	echo "Use the shortcut in the application menu or run: sudo timeshift"
else
	echo "Installation failed!"
	exit 1
fi
