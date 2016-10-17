
using TeeJee.Logging;
using TeeJee.FileSystem;
//using TeeJee.JSON;
using TeeJee.ProcessHelper;
//using TeeJee.Multimedia;
//using TeeJee.System;
using TeeJee.Misc;

public class CronTab : GLib.Object {
	
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

	public static bool add_job(string entry){
		
		// read crontab file
		string tab = crontab_read_all();
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

	public static bool remove_job(string entry, bool use_regex = false){
		
		// read crontab file
		string tab = crontab_read_all();
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

	// add and remove job scripts

	public static void add_script_hourly(string script_name, string script_text){
		add_script("hourly", script_name, script_text);
	}

	public static void add_script_daily(string script_name, string script_text){
		add_script("daily", script_name, script_text);
	}

	public static void add_script_weekly(string script_name, string script_text){
		add_script("weekly", script_name, script_text);
	}

	public static void add_script_monthly(string script_name, string script_text){
		add_script("monthly", script_name, script_text);
	}
	
	private static void add_script(string directory_type, string script_name, string script_text){
		
		string file_path = path_combine("/etc/cron.%s".printf(directory_type), script_name);

		string text = "#!/bin/bash\n";;
		text += script_text + "\n";

		file_delete(file_path);
		
		file_write(file_path, text);
		
		chmod(file_path, "a+x");
	}

	public static void remove_script_hourly(string script_name){
		remove_script("hourly", script_name);
	}

	public static void remove_script_daily(string script_name){
		remove_script("daily", script_name);
	}

	public static void remove_script_weekly(string script_name){
		remove_script("weekly", script_name);
	}

	public static void remove_script_monthly(string script_name){
		remove_script("monthly", script_name);
	}
	
	private static void remove_script(string directory_type, string script_name){
		
		string file_path = path_combine("/etc/cron.%s".printf(directory_type), script_name);
		
		file_delete(file_path);
	}
}
