
/*
 * TeeJee.Misc.vala
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
 
namespace TeeJee.Misc {

	/* Various utility functions */

	using Gtk;
	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.ProcessHelper;

	// color format -------------------
	
	public static Gdk.RGBA hex_to_rgba (string hex_color){

		/* Converts the color in hex to RGBA */

		string hex = hex_color.strip().down();
		if (hex.has_prefix("#") == false){
			hex = "#" + hex;
		}

		Gdk.RGBA color = Gdk.RGBA();
		if(color.parse(hex) == false){
			color.parse("#000000");
		}
		color.alpha = 255;

		return color;
	}

	public static string rgba_to_hex (Gdk.RGBA color, bool alpha = false, bool prefix_hash = true){

		/* Converts the color in RGBA to hex */

		string hex = "";

		if (alpha){
			hex = "%02x%02x%02x%02x".printf((uint)(Math.round(color.red*255)),
									(uint)(Math.round(color.green*255)),
									(uint)(Math.round(color.blue*255)),
									(uint)(Math.round(color.alpha*255)))
									.up();
		}
		else {
			hex = "%02x%02x%02x".printf((uint)(Math.round(color.red*255)),
									(uint)(Math.round(color.green*255)),
									(uint)(Math.round(color.blue*255)))
									.up();
		}

		if (prefix_hash){
			hex = "#" + hex;
		}

		return hex;
	}

	// localization --------------------

	public void set_numeric_locale(string type){
		Intl.setlocale(GLib.LocaleCategory.NUMERIC, type);
	    Intl.setlocale(GLib.LocaleCategory.COLLATE, type);
	    Intl.setlocale(GLib.LocaleCategory.TIME, type);
	}
	
	// timestamp ----------------
	
	public string timestamp (){

		/* Returns a formatted timestamp string */

		Time t = Time.local (time_t ());
		return t.format ("%H:%M:%S");
	}

	public string timestamp_numeric (){

		/* Returns a numeric timestamp string */

		return "%ld".printf((long) time_t ());
	}

	public string timestamp_for_path (){

		/* Returns a formatted timestamp string */

		Time t = Time.local (time_t ());
		return t.format ("%Y-%d-%m_%H-%M-%S");
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
		return html
		.replace("&","&amp;")
		.replace("\"","&quot;")
		//.replace(" ","&nbsp;") //pango markup throws an error with &nbsp;
		.replace("<","&lt;")
		.replace(">","&gt;")
		;
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

	private string pad_numbers_in_string(
		string input, int max_length = 3, char pad_char = '0'){
			
		string sequence = "";
		string output = "";
		bool seq_started = false;

		unichar c;
		string character;
		for (int i = 0; input.get_next_char(ref i, out c);) {
			character = c.to_string();

			if (c.isdigit()){
				sequence += character;
				seq_started = true;
			}
			else{
				if (seq_started){
					if ((max_length - sequence.length) > 0){
						sequence = string.nfill(max_length - sequence.length, pad_char) + sequence;
					}
					output += sequence;
					sequence = "";
					seq_started = false;
				}

				output += character;
			}
		}

		//append remaining characters in sequence
		if (sequence.length > 0){
			if ((max_length - sequence.length) > 0){
				sequence = string.nfill(max_length - sequence.length, pad_char) + sequence;
			}
			output += sequence;
			sequence = "";
		}
					
		return output;
	}


}
