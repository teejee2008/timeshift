
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

	public string format_date(DateTime date){
		return date.format ("%Y-%m-%d %H:%M");
	}
	
	public string format_date_12_hour(DateTime date){
		return date.format ("%Y-%m-%d %I:%M %p");
	}
	
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

	public string format_time_left(int64 millis){
		double mins = (millis * 1.0) / 60000;
		double secs = ((millis * 1.0) % 60000) / 1000;
		string txt = "";
		if (mins >= 1){
			txt += "%.0fm ".printf(mins);
		}
		txt += "%.0fs".printf(secs);
		return txt;
	}
	
	public double parse_time (string time){

		/* Converts time in format '00:00:00.0' to milliseconds */

		string[] arr = time.split (":");
		double millis = 0;
		if (arr.length >= 3){
			millis += double.parse(arr[0]) * 60 * 60;
			millis += double.parse(arr[1]) * 60;
			millis += double.parse(arr[2]);
		}
		return millis;
	}

	public string string_replace(string str, string search, string replacement, int count = -1){
		string[] arr = str.split(search);
		string new_txt = "";
		bool first = true;
		
		foreach(string part in arr){
			if (first){
				new_txt += part;
			}
			else{
				if (count == 0){
					new_txt += search;
					new_txt += part;
				}
				else{
					new_txt += replacement;
					new_txt += part;
					count--;
				}
			}
			first = false;
		}

		return new_txt;
	}
	
	public string escape_html(string html){
		
		return GLib.Markup.escape_text(html);
	}

	public string unescape_html(string html){
		return html
		.replace("&amp;","&")
		.replace("&quot;","\"")
		//.replace("&nbsp;"," ") //pango markup throws an error with &nbsp;
		.replace("&lt;","<")
		.replace("&gt;",">")
		;
	}

	public string uri_encode(string path, bool encode_forward_slash){
		string uri = Uri.escape_string(path);
		if (!encode_forward_slash){
			uri = uri.replace("%2F","/");
		}
		return uri;
	}

	public string uri_decode(string path){
		return Uri.unescape_string(path);
	}

	public DateTime datetime_from_string (string date_time_string){

		/* Converts date time string to DateTime
		 * 
		 * Supported inputs:
		 * 'yyyy-MM-dd'
		 * 'yyyy-MM-dd HH'
		 * 'yyyy-MM-dd HH:mm'
		 * 'yyyy-MM-dd HH:mm:ss'
		 * */

		string[] arr = date_time_string.replace(":"," ").replace("-"," ").strip().split(" ");

		int year  = (arr.length >= 3) ? int.parse(arr[0]) : 0;
		int month = (arr.length >= 3) ? int.parse(arr[1]) : 0;
		int day   = (arr.length >= 3) ? int.parse(arr[2]) : 0;
		int hour  = (arr.length >= 4) ? int.parse(arr[3]) : 0;
		int min   = (arr.length >= 5) ? int.parse(arr[4]) : 0;
		int sec   = (arr.length >= 6) ? int.parse(arr[5]) : 0;

		return new DateTime.utc(year,month,day,hour,min,sec);
	}

	public string break_string_by_word(string input_text){
		string text = "";
		string line = "";
		foreach(string part in input_text.split(" ")){
			line += part + " ";
			if (line.length > 50){
				text += line.strip() + "\n";
				line = "";
			}
		}
		if (line.length > 0){
			text += line;
		}
		if (text.has_suffix("\n")){
			text = text[0:text.length-1].strip();
		}
		return text;
	}

	public string[] array_concat(string[] a, string[] b){
		string[] c = {};
		foreach(string str in a){ c += str; }
		foreach(string str in b){ c += str; }
		return c;
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

	public bool is_numeric(string text){
		for (int i = 0; i < text.length; i++){
			if (!text[i].isdigit()){
				return false;
			}
		}
		return true;
	}
}
