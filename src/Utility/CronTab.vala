/*
 * CronTab.vala
 *
 * Copyright 2012-17 Tony George <teejeetech@gmail.com>
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
 
using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using TeeJee.Misc;

public class CronTab : GLib.Object {

	public static string crontab_text = null;

	public static void clear_cached_text(){
		crontab_text = null;
	}
	
	public static string crontab_read_all(string user_name = ""){
		string std_out, std_err;

		var cmd = "crontab -l";
		if (user_name.length > 0){
			cmd += " -u %s".printf(user_name);
		}

		log_debug(cmd);
		
		int ret_val = exec_sync(cmd, out std_out, out std_err);
		
		if (ret_val != 0){
			log_debug(_("Failed to read cron tab"));
			return "";
		}
		else{
			return std_out;
		}
	}

	public static bool has_job(string entry, bool partial_match, bool use_cached_text){
		
		// read crontab file
		string tab = "";
		if (use_cached_text && (crontab_text != null)){
			tab = crontab_text;
		}
		else{
			crontab_text = crontab_read_all();
			tab = crontab_text;
		}

		var lines = new Gee.ArrayList<string>();
		foreach(string line in tab.split("\n")){
			lines.add(line);
		}

		// check if entry exists
		foreach(string line in lines){
			if (line == entry){
				return true; // return
			}
			else if (partial_match && line.contains(entry)){
				return true; // return
			}
		}

		return false;
	}
	
	public static bool add_job(string entry, bool use_cached_text){
		
		// read crontab file
		string tab = "";
		if (use_cached_text && (crontab_text != null)){
			tab = crontab_text;
		}
		else{
			crontab_text = crontab_read_all();
			tab = crontab_text;
		}
		
		var lines = new Gee.ArrayList<string>();
		foreach(string line in tab.split("\n")){
			lines.add(line);
		}

		// check if entry exists
		foreach(string line in lines){
			if (line == entry){
				return true; // return
			}
		}

		// append entry
		lines.add(entry);

		// create new tab
		string tab_new = "";
		foreach(string line in lines){
			if (line.length > 0){
				tab_new += "%s\n".printf(line);
			}
		}

		// write temp crontab file
		string temp_file = get_temp_file_path();
		file_write(temp_file, tab_new);

		// install crontab file
		var cmd = "crontab \"%s\"".printf(temp_file);
		int status = exec_sync(cmd);

		if (status != 0){
			log_error(_("Failed to add cron job") + ": %s".printf(entry));
			return false;
		}
		else{
			log_msg(_("Cron job added") + ": %s".printf(entry));
			return true;
		}
	}

	public static bool remove_job(string entry, bool use_regex, bool use_cached_text){
		
		// read crontab file
		string tab = "";
		if (use_cached_text && (crontab_text != null)){
			tab = crontab_text;
		}
		else{
			crontab_text = crontab_read_all();
			tab = crontab_text;
		}
		
		var lines = new Gee.ArrayList<string>();
		foreach(string line in tab.split("\n")){
			lines.add(line);
		}
		
		Regex regex = null;

		if (use_regex){
			try {
				regex = new Regex(entry);
			}
			catch (Error e) {
				log_error (e.message);
			}
		}

		// check if entry exists
		bool found = false;
		for(int i=0; i < lines.size; i++){
			string line = lines[i];
			if (line != null){
				line = line.strip();
			}

			if (use_regex && (regex != null)){
				
				MatchInfo match;
				if (regex.match(line, 0, out match)) {
					lines.remove(line);
					found = true;
				}
			}
			else{
				if (line == entry){
					lines.remove(line);
					found = true;
				}
			}
		}
		if (!found){
			return true;
		}

		// create new tab
		string tab_new = "";
		foreach(string line in lines){
			if (line.length > 0){
				tab_new += "%s\n".printf(line);
			}
		}

		// write temp crontab file
		string temp_file = get_temp_file_path();
		file_write(temp_file, tab_new);

		// install crontab file
		var cmd = "crontab \"%s\"".printf(temp_file);
		int status = exec_sync(cmd);

		if (status != 0){
			log_error(_("Failed to remove cron job") + ": %s".printf(entry));
			return false;
		}
		else{
			log_msg(_("Cron job removed") + ": %s".printf(entry));
			return true;
		}
	}

	public static bool install(string file_path, string user_name = ""){

		if (!file_exists(file_path)){
			log_error(_("File not found") + ": %s".printf(file_path));
			return false;
		}
		
		var cmd = "crontab";
		if (user_name.length > 0){
			cmd += " -u %s".printf(user_name);
		}
		cmd += " \"%s\"".printf(file_path);

		log_debug(cmd);

		int status = exec_sync(cmd);

		if (status != 0){
			log_error(_("Failed to install crontab file") + ": %s".printf(file_path));
			return false;
		}
		else{
			log_msg(_("crontab file installed") + ": %s".printf(file_path));
			return true;
		}
	}
	
	public static bool export(string file_path, string user_name = ""){
		if (file_exists(file_path)){
			file_delete(file_path);
		}
		
		bool ok = file_write(file_path, crontab_read_all(user_name));

		if (!ok){
			log_error(_("Failed to export crontab file") + ": %s".printf(file_path));
			return false;
		}
		else{
			log_msg(_("crontab file exported") + ": %s".printf(file_path));
			return true;
		}
	}

	public static bool import(string file_path, string user_name = ""){
		return install(file_path, user_name);
	}

	public static bool add_script_file(string file_name, string cron_dir_type, string text, bool stop_cron_emails){
		
		/* Note:
		 * cron.d and cron.hourly are managed by cron so it expects entries in crontab format
		 * minute hour day_of_month month day_of_week user command
		 * 
		 * cron.{daily|weekly|monthly} are read by anacron. scripts placed here should have commands only.
		 * */

		switch (cron_dir_type){
		case "d":
		case "hourly":
		case "daily":
		case "weekly":
		case "monthly":
			break;
		default:
			log_error("Cron directory type parameter not valid" + ": %s".printf(cron_dir_type));
			log_error("Expected values: d, hourly, daily, weekly, monthly");
			return false;
			break;
		}

		string file_path = "/etc/cron.%s/%s".printf(cron_dir_type, file_name.replace(".","-")); // dot is not allowed in file name

		string sh = "";
		sh += "SHELL=/bin/bash" + "\n";
		sh += "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" + "\n";
		if (stop_cron_emails){
			sh += "MAILTO=\"\"" + "\n";
		}
		sh += "\n";
		sh += text + "\n";

		if (file_exists(file_path) && (file_read(file_path) == sh)){
			log_debug(_("Cron task exists") + ": %s".printf(file_path));
			return true;
		}

		file_write(file_path, sh);
		chown(file_path, "root", "root");
		chmod(file_path, "644");

		log_msg(_("Added cron task") + ": %s".printf(file_path));
		
		return true;
	}

	public static bool remove_script_file(string file_name, string cron_dir_type){

		switch (cron_dir_type){
		case "d":
		case "hourly":
		case "daily":
		case "weekly":
		case "monthly":
			break;
		default:
			log_error("Cron directory type parameter not valid" + ": %s".printf(cron_dir_type));
			log_error("Expected values: d, hourly, daily, weekly, monthly");
			return false;
			break;
		}

		string file_path = "/etc/cron.%s/%s".printf(cron_dir_type, file_name.replace(".","-")); // dot is not allowed in file name

		if (!file_exists(file_path)){
			return true;
		}
		
		file_delete(file_path);

		log_msg(_("Removed cron task") + ": %s".printf(file_path));
		
		return true;
	}
}
