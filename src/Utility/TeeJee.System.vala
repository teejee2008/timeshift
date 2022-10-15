
/*
 * TeeJee.System.vala
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
 
namespace TeeJee.System{

	using TeeJee.ProcessHelper;
	using TeeJee.Logging;
	using TeeJee.Misc;
	using TeeJee.FileSystem;
	
	// user ---------------------------------------------------

	public bool user_is_admin(){
		
		return (get_user_id_effective() == 0);
	}
	
	public int get_user_id(){

		// returns actual user id of current user (even for applications executed with sudo and pkexec)
		
		string pkexec_uid = GLib.Environment.get_variable("PKEXEC_UID");

		if (pkexec_uid != null){
			return int.parse(pkexec_uid);
		}

		string sudo_user = GLib.Environment.get_variable("SUDO_USER");

		if (sudo_user != null){
			return get_user_id_from_username(sudo_user);
		}

		return get_user_id_effective(); // normal user
	}

	public int get_user_id_effective(){
		
		// returns effective user id (0 for applications executed with sudo and pkexec)

		int uid = -1;
		string cmd = "id -u";
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);
		if ((std_out != null) && (std_out.length > 0)){
			uid = int.parse(std_out);
		}

		return uid;
	}
	
	public string get_username(){

		// returns actual username of current user (even for applications executed with sudo and pkexec)
		
		return get_username_from_uid(get_user_id());
	}

	public string get_username_effective(){

		// returns effective user id ('root' for applications executed with sudo and pkexec)
		
		return get_username_from_uid(get_user_id_effective());
	}

	public int get_user_id_from_username(string username){
		
		// check local user accounts in /etc/passwd -------------------

		foreach(var line in file_read("/etc/passwd").split("\n")){
			
			var arr = line.split(":");
			
			if ((arr.length >= 3) && (arr[0] == username)){
				
				return int.parse(arr[2]);
			}
		}

		// not found --------------------
		
		log_error("UserId not found for userName: %s".printf(username));

		return -1;
	}

	public string get_username_from_uid(int user_id){

		// check local user accounts in /etc/passwd -------------------
		
		foreach(var line in file_read("/etc/passwd").split("\n")){
			
			var arr = line.split(":");
			
			if ((arr.length >= 3) && (arr[2] == user_id.to_string())){
				
				return arr[0];
			}
		}

		// not found --------------------
		
		log_error("Username not found for uid: %d".printf(user_id));

		return "";
	}

	public string get_user_home(string username = get_username()){

		// check local user accounts in /etc/passwd -------------------
		
		foreach(var line in file_read("/etc/passwd").split("\n")){
			
			var arr = line.split(":");
			
			if ((arr.length >= 6) && (arr[0] == username)){

				return arr[5];
			}
		}

		// not found --------------------

		log_error("Home directory not found for user: %s".printf(username));

		return "";
	}

	public string get_user_home_effective(){
		return get_user_home(get_username_effective());
	}

	// system ------------------------------------

	public double get_system_uptime_seconds(){

		/* Returns the system up-time in seconds */

		string uptime = file_read("/proc/uptime").split(" ")[0];
		double secs = double.parse(uptime);
		return secs;
	}

	// open -----------------------------

	public bool xdg_open (string file, string user = ""){
		string path = get_cmd_path ("xdg-open");
		if ((path != null) && (path != "")){
			string cmd = "xdg-open '%s'".printf(escape_single_quote(file));
			if (user.length > 0){
				cmd = "pkexec --user %s env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY ".printf(user) + cmd;
			}
			log_debug(cmd);
			int status = exec_script_async(cmd);
			return (status == 0);
		}
		return false;
	}

	public bool exo_open_folder (string dir_path, bool xdg_open_try_first = true){

		/* Tries to open the given directory in a file manager */

		/*
		xdg-open is a desktop-independent tool for configuring the default applications of a user.
		Inside a desktop environment (e.g. GNOME, KDE, Xfce), xdg-open simply passes the arguments
		to that desktop environment's file-opener application (gvfs-open, kde-open, exo-open, respectively).
		We will first try using xdg-open and then check for specific file managers if it fails.
		*/

		string path;
		int status;
		
		if (xdg_open_try_first){
			//try using xdg-open
			path = get_cmd_path ("xdg-open");
			if ((path != null)&&(path != "")){
				string cmd = "xdg-open '%s'".printf(escape_single_quote(dir_path));
				status = exec_script_async (cmd);
				return (status == 0);
			}
		}

		foreach(string app_name in
			new string[]{ "nemo", "nautilus", "thunar", "io.elementary.files", "pantheon-files", "marlin", "dolphin" }){
				
			path = get_cmd_path (app_name);
			if ((path != null)&&(path != "")){
				string cmd = "%s '%s'".printf(app_name, escape_single_quote(dir_path));
				status = exec_script_async (cmd);
				return (status == 0);
			}
		}

		if (xdg_open_try_first == false){
			//try using xdg-open
			path = get_cmd_path ("xdg-open");
			if ((path != null)&&(path != "")){
				string cmd = "xdg-open '%s'".printf(escape_single_quote(dir_path));
				status = exec_script_async (cmd);
				return (status == 0);
			}
		}

		return false;
	}

	public bool using_efi_boot(){
		
		/* Returns true if the system was booted in EFI mode
		 * and false for BIOS mode */
		 
		return dir_exists("/sys/firmware/efi");
	}

	// timers --------------------------------------------------
	
	public GLib.Timer timer_start(){
		var timer = new GLib.Timer();
		timer.start();
		return timer;
	}

	public ulong timer_elapsed(GLib.Timer timer, bool stop = true){
		ulong microseconds;
		double seconds;
		seconds = timer.elapsed (out microseconds);
		if (stop){
			timer.stop();
		}
		return (ulong)((seconds * 1000 ) + (microseconds / 1000));
	}

	public void sleep(int milliseconds){
		Thread.usleep ((ulong) milliseconds * 1000);
	}

	public string timer_elapsed_string(GLib.Timer timer, bool stop = true){
		ulong microseconds;
		double seconds;
		seconds = timer.elapsed (out microseconds);
		if (stop){
			timer.stop();
		}
		return "%.0f ms".printf((seconds * 1000 ) + microseconds/1000);
	}

	public void set_numeric_locale(string type){
		Intl.setlocale(GLib.LocaleCategory.NUMERIC, type);
	    Intl.setlocale(GLib.LocaleCategory.COLLATE, type);
	    Intl.setlocale(GLib.LocaleCategory.TIME, type);
	}
}
