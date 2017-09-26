prefix=/usr
sysconfdir=/etc
bindir=$(prefix)/bin
sharedir=$(prefix)/share
localedir=$(sharedir)/locale
launcherdir=$(sharedir)/applications
mandir=$(sharedir)/man
man1dir=$(mandir)/man1
CFLAGS=--std=c99
app_name=timeshift
app_fullname=Timeshift

vte_pkg=$(shell { ((ldconfig -p | grep libvte-2.91*.so) >/dev/null && echo '--pkg vte-2.91') || echo '--pkg vte-2.90'; } )
vte_symbol=$(shell { ((ldconfig -p | grep libvte-2.91*.so) >/dev/null && echo '-D VTE_291') || echo ''; } )

xapp_pkg=$(shell { ((ldconfig -p | grep libxapp.so.*) >/dev/null && echo '--pkg xapp') || echo ''; } )
xapp_symbol=$(shell { ((ldconfig -p | grep libxapp.so.*) >/dev/null && echo '-D XAPP') || echo ''; } )

gtk3_version=$(shell { (pkg-config --modversion gtk+-3.0 | cut -d. -f2); } )

ifeq ($(shell { test ${gtk3_version} -gt 17 ; echo $$? ; } ), 0)
gtk3_symbol=$(shell { echo '-D GTK3_18'; } )
else
gtk3_symbol=$(shell { echo ''; } )
endif

symbols=$(shell { echo "${vte_symbol} ${gtk3_symbol} ${xapp_symbol}"; } )

all:

	#timeshift-gtk
	valac -X -D'GETTEXT_PACKAGE="${app_name}"' --Xcc="-lm" -X -Wl,-rpath,/usr/share/${app_name}/libs ${symbols} --thread Core/*.vala Utility/*.vala  Utility/Gtk/*.vala  Gtk/*.vala -o ${app_name}-gtk --pkg glib-2.0 --pkg gio-unix-2.0 --pkg posix --pkg gtk+-3.0 $(vte_pkg) $(xapp_pkg) --pkg gee-0.8 --pkg json-glib-1.0

	#timeshift
	valac -X -D'GETTEXT_PACKAGE="${app_name}"' --Xcc="-lm" -X -Wl,-rpath,/usr/share/${app_name}/libs ${symbols} --thread Core/*.vala Utility/*.vala Utility/Gtk/*.vala Console/*.vala -o ${app_name} --pkg glib-2.0 --pkg gio-unix-2.0 --pkg posix --pkg gtk+-3.0 $(vte_pkg) $(xapp_pkg) --pkg gee-0.8 --pkg json-glib-1.0

	# update translation template
	find . -iname "*.vala" | xargs xgettext --from-code=UTF-8 --language=C --keyword=_ --copyright-holder='Tony George (teejeetech@gmail.com)' --package-name="${app_name}" --package-version='1.6' --msgid-bugs-address='teejeetech@gmail.com' --escape --sort-output -o ../${app_name}.pot

clean:
	rm -rf *.o ${app_name}

install:
	mkdir -p "$(DESTDIR)$(bindir)"
	mkdir -p "$(DESTDIR)$(sharedir)"
	mkdir -p "$(DESTDIR)$(mandir)"
	mkdir -p "$(DESTDIR)$(man1dir)"
	mkdir -p "$(DESTDIR)$(launcherdir)"
	mkdir -p "$(DESTDIR)$(sysconfdir)"
	mkdir -p "$(DESTDIR)$(sharedir)/${app_name}"
	mkdir -p "$(DESTDIR)$(sharedir)/icons"
	mkdir -p "$(DESTDIR)$(localedir)/bg/LC_MESSAGES"
	mkdir -p "$(DESTDIR)$(localedir)/cs/LC_MESSAGES"
	mkdir -p "$(DESTDIR)$(localedir)/es/LC_MESSAGES"
	mkdir -p "$(DESTDIR)$(localedir)/fr/LC_MESSAGES"
	mkdir -p "$(DESTDIR)$(localedir)/nl/LC_MESSAGES"
	mkdir -p "$(DESTDIR)$(localedir)/pt_BR/LC_MESSAGES"
	mkdir -p "$(DESTDIR)$(localedir)/ru/LC_MESSAGES"
	mkdir -p "$(DESTDIR)$(localedir)/sv/LC_MESSAGES"
	mkdir -p "$(DESTDIR)$(localedir)/tr/LC_MESSAGES"

	# binary
	install -m 0755 ${app_name} "$(DESTDIR)$(bindir)"
	install -m 0755 ${app_name}-gtk "$(DESTDIR)$(bindir)"
	install -m 0755 ${app_name}-uninstall "$(DESTDIR)$(bindir)"
	install -m 0755 ${app_name}-launcher "$(DESTDIR)$(bindir)"

	# shared files
	cp -dpr --no-preserve=ownership -t "$(DESTDIR)$(sharedir)/${app_name}" ./share/${app_name}/*
	chmod --recursive 0755 $(DESTDIR)$(sharedir)/${app_name}/*

	# launcher
	install -m 0755 ${app_name}-gtk.desktop "$(DESTDIR)$(launcherdir)"

	# config
	install -m 0755 ../files/${app_name}.json "$(DESTDIR)$(sysconfdir)"

	# app icons
	cp -dpr --no-preserve=ownership -t "$(DESTDIR)$(sharedir)/icons" ./share/icons/*
	chmod --recursive 0755 $(DESTDIR)$(sharedir)/icons/*

	# translations
	msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/bg/LC_MESSAGES/${app_name}.mo" ../po/${app_name}-bg.po
	msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/cs/LC_MESSAGES/${app_name}.mo" ../po/${app_name}-cs.po
	msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/es/LC_MESSAGES/${app_name}.mo" ../po/${app_name}-es.po
	msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/fr/LC_MESSAGES/${app_name}.mo" ../po/${app_name}-fr.po
	msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/nl/LC_MESSAGES/${app_name}.mo" ../po/${app_name}-nl.po
	msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/pt_BR/LC_MESSAGES/${app_name}.mo" ../po/${app_name}-pt_BR.po
	msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/ru/LC_MESSAGES/${app_name}.mo" ../po/${app_name}-ru.po
	msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/sv/LC_MESSAGES/${app_name}.mo" ../po/${app_name}-sv.po
	msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/tr/LC_MESSAGES/${app_name}.mo" ../po/${app_name}-tr.po

uninstall:

	# binary
	rm -f "$(DESTDIR)$(bindir)/${app_name}"
	rm -f "$(DESTDIR)$(bindir)/${app_name}-gtk"
	rm -f "$(DESTDIR)$(bindir)/${app_name}-uninstall"
	rm -f "$(DESTDIR)$(bindir)/${app_name}-launcher"

	# shared files
	rm -rf "$(DESTDIR)$(sharedir)/${app_name}"

	# launcher
	rm -f "$(DESTDIR)$(launcherdir)/${app_name}-gtk.desktop"

	# app icon
	rm -f "$(DESTDIR)$(sharedir)/icons/hicolor/*/apps/${app_name}.png"

	# translations
	rm -f $(DESTDIR)$(localedir)/*/LC_MESSAGES/${app_name}.mo
