all:
	cd src; make all

app-gtk:
	cd src; make app-gtk
	
app-console:
	cd src; make app-console

pot:
	cd src; make pot

manpage:
	cd src; make manpage
	
clean:
	cd src; make clean

install:
	cd src; make install
	
uninstall:
	cd src; make uninstall
