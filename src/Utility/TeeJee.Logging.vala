
/*
 * TeeJee.Logging.vala
 *
 * Copyright 2016 Tony George <teejee2008@gmail.com>
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
 
namespace TeeJee.Logging{

	/* Functions for logging messages to console and log files */

	using TeeJee.Misc;

	public DataOutputStream dos_log;
	public string err_log;
	public bool LOG_ENABLE = true;
	public bool LOG_TIMESTAMP = false;
	public bool LOG_COLORS = true;
	public bool LOG_DEBUG = false;
	public bool LOG_COMMANDS = false;

	public void log_msg (string message, bool highlight = false){

		if (!LOG_ENABLE) { return; }

		string msg = "";

		if (highlight && LOG_COLORS){
			msg += "\033[1;38;5;34m";
		}

		if (LOG_TIMESTAMP){
			msg += "[" + timestamp(true) +  "] ";
		}

		msg += message;

		if (highlight && LOG_COLORS){
			msg += "\033[0m";
		}

		msg += "\n";

		stdout.printf (msg);
		stdout.flush();

		try {
			if (dos_log != null){
				dos_log.put_string ("[%s] %s\n".printf(timestamp(), message));
			}
		}
		catch (Error e) {
			stdout.printf (e.message);
		}
	}

	public void log_error (string message, bool highlight = false,
		bool is_warning = false){
			
		if (!LOG_ENABLE) { return; }

		string msg = "";

		if (highlight && LOG_COLORS){
			msg += "\033[1;38;5;160m";
		}

		if (LOG_TIMESTAMP){
			msg += "[" + timestamp(true) +  "] ";
		}

		string prefix = (is_warning) ? _("W") : _("E");

		msg += prefix + ": " + message;

		if (highlight && LOG_COLORS){
			msg += "\033[0m";
		}

		msg += "\n";

		stdout.printf (msg);
		stdout.flush();
		
		try {
			string str = "[%s] %s: %s\n".printf(timestamp(), prefix, message);
			
			if (dos_log != null){
				dos_log.put_string (str);
			}

			if (err_log != null){
				err_log += "%s\n".printf(message);
			}
		}
		catch (Error e) {
			stdout.printf (e.message);
		}
	}

	public void log_debug (string message){
		if (!LOG_ENABLE) { return; }

		if (LOG_DEBUG){
			log_msg ("D: " + message);
		}

		try {
			if (dos_log != null){
				dos_log.put_string ("[%s] %s\n".printf(timestamp(), message));
			}
		}
		catch (Error e) {
			stdout.printf (e.message);
		}
	}

	public void log_to_file (string message, bool highlight = false){
		try {
			if (dos_log != null){
				dos_log.put_string ("[%s] %s\n".printf(timestamp(), message));
			}
		}
		catch (Error e) {
			stdout.printf (e.message);
		}
	}

	public void log_draw_line(){
		log_msg(string.nfill(70,'='));
	}

	public void show_err_log(Gtk.Window parent, bool disable_log = true){
		if ((err_log != null) && (err_log.length > 0)){
			//gtk_messagebox(_("Error"), err_log, parent, true);
		}

		if (disable_log){
			err_log_disable();
		}
	}

	public void err_log_clear(){
		err_log = "";
	}

	public void err_log_disable(){
		err_log = null;
	}
}
