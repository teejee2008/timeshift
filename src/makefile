prefix=/usr
bindir=$(prefix)/bin
sharedir=$(prefix)/share
localedir=$(sharedir)/locale
launcherdir=$(sharedir)/applications
mandir=$(sharedir)/man
man1dir=$(mandir)/man1
CFLAGS=--std=c99
app_name=timeshift
app_fullname=Timeshift

all:
	#build binaries
	valac -X -D'GETTEXT_PACKAGE="${app_name}"' --Xcc="-lm" -X -Wl,-rpath,/usr/share/${app_name}/libs --thread "Main.vala" "Utility.vala" "MainWindow.vala" "SettingsWindow.vala" "RestoreWindow.vala" "ExcludeMessageWindow.vala" "AboutWindow.vala" "DonationWindow.vala" -o ${app_name} --pkg glib-2.0 --pkg gio-unix-2.0 --pkg posix --pkg gtk+-3.0 --pkg gee-0.8 --pkg json-glib-1.0 --pkg gudev-1.0
	
	#update translation template
	xgettext --language=C --keyword=_ --copyright-holder='Tony George (teejee2008@gmail.com)' --package-name="${app_name}" --package-version='1.6' --msgid-bugs-address='teejee2008@gmail.com' --escape --sort-output -o ../${app_name}.pot *.vala

clean:
	rm -rf *.o ${app_name}

install:
	mkdir -p "$(DESTDIR)$(bindir)"
	mkdir -p "$(DESTDIR)$(sharedir)"
	mkdir -p "$(DESTDIR)$(mandir)"
	mkdir -p "$(DESTDIR)$(man1dir)"
	mkdir -p "$(DESTDIR)$(launcherdir)"
	mkdir -p "$(DESTDIR)$(sharedir)/${app_name}"
	mkdir -p "$(DESTDIR)$(sharedir)/pixmaps"
	mkdir -p "$(DESTDIR)$(localedir)/it_IT/LC_MESSAGES"
	mkdir -p "$(DESTDIR)$(localedir)/ko_KR/LC_MESSAGES"
	mkdir -p "$(DESTDIR)$(localedir)/fr_FR/LC_MESSAGES"
	
	#binary
	install -m 0755 ${app_name} "$(DESTDIR)$(bindir)"
	install -m 0755 ${app_name}-uninstall "$(DESTDIR)$(bindir)"
	install -m 0755 ${app_name}-launcher "$(DESTDIR)$(bindir)"
	
	#shared files
	cp -dpr --no-preserve=ownership -t "$(DESTDIR)$(sharedir)/${app_name}" ./share/${app_name}/*
	chmod --recursive 0755 $(DESTDIR)$(sharedir)/${app_name}/*
	
	#launcher
	install -m 0755 ${app_name}.desktop "$(DESTDIR)$(launcherdir)"
	
	#app icon
	install -m 0755 ./share/pixmaps/${app_name}.png "$(DESTDIR)$(sharedir)/pixmaps/"
	
	#translations
	msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/it_IT/LC_MESSAGES/${app_name}.mo" ../po/${app_name}-it.po
	msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/ko_KR/LC_MESSAGES/${app_name}.mo" ../po/${app_name}-ko.po
	msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/fr_FR/LC_MESSAGES/${app_name}.mo" ../po/${app_name}-fr.po
	
uninstall:

	#binary
	rm -f "$(DESTDIR)$(bindir)/${app_name}"
	rm -f "$(DESTDIR)$(bindir)/${app_name}-uninstall"
	rm -f "$(DESTDIR)$(bindir)/${app_name}-launcher"
	
	#shared files
	rm -rf "$(DESTDIR)$(sharedir)/${app_name}"
	
	#launcher
	rm -f "$(DESTDIR)$(launcherdir)/${app_name}.desktop"
	
	#app icon
	rm -f "$(DESTDIR)$(sharedir)/pixmaps/${app_name}.png"
	
	#translations
	rm -f $(DESTDIR)$(localedir)/*/LC_MESSAGES/${app_name}.mo
