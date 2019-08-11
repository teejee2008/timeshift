/*
 * AptikGtk.vala
 *
 * Copyright 2012-2018 Tony George <teejeetech@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */

using GLib;
using Gtk;
using Gee;
using Json;


using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public Main App;
public const string AppName = "Timeshift";
public const string AppShortName = "timeshift";
public const string AppVersion = "19.08";
public const string AppAuthor = "Tony George";
public const string AppAuthorEmail = "teejeetech@gmail.com";

const string GETTEXT_PACKAGE = "";
const string LOCALE_DIR = "/usr/share/locale";

extern void exit(int exit_code);

public class AppGtk : GLib.Object {

	public static int main (string[] args) {
		
		set_locale();

		Gtk.init(ref args);

		GTK_INITIALIZED = true;

		init_tmp(AppShortName);

		check_if_admin();

		App = new Main(args, true);
		parse_arguments(args);
		App.initialize();
		start_application();

		App.exit_app();

		return 0;
	}

	private static void set_locale() {
		log_debug("setting locale...");
		Intl.setlocale(GLib.LocaleCategory.MESSAGES, "timeshift");
		Intl.textdomain(GETTEXT_PACKAGE);
		Intl.bind_textdomain_codeset(GETTEXT_PACKAGE, "utf-8");
		Intl.bindtextdomain(GETTEXT_PACKAGE, LOCALE_DIR);
	}

	public static bool parse_arguments(string[] args) {
		
		//parse options
		for (int k = 1; k < args.length; k++) // Oth arg is app path
		{
			switch (args[k].down()) {
			case "--debug":
				LOG_DEBUG = true;
				break;
			case "--help":
			case "--h":
			case "-h":
				log_msg(help_message());
				exit(0);
				return true;
			default:
				//unknown option - show help and exit
				log_error(_("Unknown option") + ": %s".printf(args[k]));
				log_msg(help_message());
				App.exit_app(1);
				return false;
			}
		}

		return true;
	}

	public static string help_message() {
		string msg = "\n%s v%s by Tony George (%s)\n".printf(AppName, AppVersion, AppAuthorEmail);
		msg += "\n";
		msg += _("Syntax") + ": timeshift-gtk [options]\n";
		msg += "\n";
		msg += _("Options") + ":\n";
		msg += "\n";
		msg += "  --debug      " + _("Print debug information") + "\n";
		msg += "  --h[elp]     " + _("Show all options") + "\n";
		msg += "\n\n";
		msg += "\n%s\n".printf(_("Run 'timeshift' for the command-line version of this tool"));
		return msg;
	}

	public static void check_if_admin(){
		
		if (!user_is_admin()){
			var msg = _("Admin access is required to backup and restore system files.") + "\n";
			msg += _("Please re-run the application as admin (using 'sudo' or 'su')");

			log_error(msg);

			string title = _("Admin Access Required");
			gtk_messagebox(title, msg, null, true);

			exit(1);
		}
	}

	public static void start_application(){
		
		// show main window
		var window = new MainWindow ();
		window.destroy.connect(Gtk.main_quit);
		window.show_all();

		// start event loop
		Gtk.main();
	}
}

