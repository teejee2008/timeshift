#msgfmt -c po/ca.po -o build/locale/LC_MESSAGES/or/timeshift.mo

sudo locale-gen or_IN
msgfmt -c -v -o timeshift.mo oriya.po
sudo mkdir -p /usr/share/locale/or/LC_MESSAGES
sudo cp timeshift.mo /usr/share/locale/or/LC_MESSAGES
  
echo "Finished"
read dummy
