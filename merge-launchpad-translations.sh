#!/bin/bash

backup=`pwd`
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd "$DIR"

. ./BUILD_CONFIG

languages="am ar az bg ca ca@valencia cs da de el en_GB es et eu fi fr he hi hr hu ia id is it ko lt nb ne nl pl pt pt_BR ro ru sk sr sv tr uk vi zh_CN zh_TW"

echo ""
echo "=========================================================================="
echo " Update PO files in po/ with downloaded translations placed in po-lp/"
echo "=========================================================================="
echo ""

for lang in $languages; do
	# remove headers in po-lp/*.po so that msgcat does not create malformed headers
	sed -i '/^#/d' po-lp/${app_name}-$lang.po
	msgcat -o po/${app_name}-$lang.po po-lp/${app_name}-$lang.po po/${app_name}-$lang.po --use-first
done

echo ""
echo "=========================================================================="
echo " Update PO files in po/ with latest POT file"
echo "=========================================================================="
echo ""

for lang in $languages; do
	msgmerge --update -v po/${app_name}-$lang.po ${app_name}.pot
done

cd "$backup"
