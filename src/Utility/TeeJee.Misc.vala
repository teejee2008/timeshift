
/*
 * TeeJee.Misc.vala
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
 
namespace TeeJee.Misc {

	/* Various utility functions */

	using Gtk;
	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.ProcessHelper;

	// localization --------------------

	public void set_numeric_locale(string type){
		Intl.setlocale(GLib.LocaleCategory.NUMERIC, type);
	    Intl.setlocale(GLib.LocaleCategory.COLLATE, type);
	    Intl.setlocale(GLib.LocaleCategory.TIME, type);
	}
	
	// timestamp ----------------
	
	public string timestamp (bool show_millis = false){

		/* Returns a formatted timestamp string */

		// NOTE: format() does not support milliseconds

		DateTime now = new GLib.DateTime.now_local();
		
		if (show_millis){
			var msec = now.get_microsecond () / 1000;
			return "%s.%03d".printf(now.format("%H:%M:%S"), msec);
		}
		else{
			return now.format ("%H:%M:%S");
		}
	}

	public string timestamp_numeric(){

		/* Returns a numeric timestamp string */

		return "%ld".printf((long) time_t ());
	}

	public string timestamp_for_path(){

		/* Returns a formatted timestamp string */

		Time t = Time.local (time_t ());
		return t.format ("%Y-%m-%d_%H-%M-%S");
	}

	// string formatting -------------------------------------------------

	public string format_duration (long millis){

		/* Converts time in milliseconds to format '00:00:00.0' */

	    double time = millis / 1000.0; // time in seconds

	    double hr = Math.floor(time / (60.0 * 60));
	    time = time - (hr * 60 * 60);
	    double min = Math.floor(time / 60.0);
	    time = time - (min * 60);
	    double sec = Math.floor(time);

        return "%02.0lf:%02.0lf:%02.0lf".printf (hr, min, sec);
	}

	public string escape_html(string html){
		
		return GLib.Markup.escape_text(html);
	}

	public string random_string(int length = 8, string charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890"){
		
		string random = "";

		for(int i=0;i<length;i++){
			int random_index = Random.int_range(0,charset.length);
			string ch = charset.get_char(charset.index_of_nth_char(random_index)).to_string();
			random += ch;
		}

		return random;
	}
	
	internal string regex_replace(string expression, string text, string replacement){

		try 
		{
			Regex? regex = null;
			regex = new Regex(expression, 0);
			return regex.replace(text, text.length, 0, replacement);
		}
		catch (Error e) 
		{
			log_error (e.message);
			return text;
		}
	}
}
