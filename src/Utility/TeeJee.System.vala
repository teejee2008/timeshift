
/*
 * TeeJee.System.vala
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
 
namespace TeeJee.System{

	using TeeJee.ProcessHelper;
	using TeeJee.Logging;
	using TeeJee.Misc;
	using TeeJee.FileSystem;
	
	// user ---------------------------------------------------
	
	public bool user_is_admin (){

		/* Check if current application is running with admin priviledges */

		try{
			// create a process
			string[] argv = { "sleep", "10" };
			Pid procId;
			Process.spawn_async(null, argv, null, SpawnFlags.SEARCH_PATH, null, out procId);

			// try changing the priority
			Posix.setpriority (Posix.PRIO_PROCESS, procId, -5);

			// check if priority was changed successfully
			if (Posix.getpriority (Posix.PRIO_PROCESS, procId) == -5)
				return true;
			else
				return false;
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}
	}

	// dep: whoami
	public string get_user_login(){
		/*
		Returns Login ID of current user.
		If running as 'sudo' it will return Login ID of the actual user.
		*/

		string cmd = "echo ${SUDO_USER:-$(whoami)}";
		string std_out;
		string std_err;
		int ret_val;
		ret_val = exec_script_sync(cmd, out std_out, out std_err);

		string user_name;
		if ((std_out == null) || (std_out.length == 0)){
			user_name = "root";
		}
		else{
			user_name = std_out.strip();
		}

		return user_name;
	}

	// dep: id
	public int get_user_id(string user_login){
		/*
		Returns UID of specified user.
		*/

		int uid = -1;
		string cmd = "id %s -u".printf(user_login);
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);
		if ((std_out != null) && (std_out.length > 0)){
			uid = int.parse(std_out);
		}

		return uid;
	}

	// application -----------------------------------------------
	
	public string get_app_path(){

		/* Get path of current process */

		try{
			return GLib.FileUtils.read_link ("/proc/self/exe");
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}

	public string get_app_dir(){

		/* Get parent directory of current process */

		try{
			return (File.new_for_path (GLib.FileUtils.read_link ("/proc/self/exe"))).get_parent ().get_path ();
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}

	// system ------------------------------------

	// dep: cat TODO: rewrite
	public double get_system_uptime_seconds(){

		/* Returns the system up-time in seconds */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			cmd = "cat /proc/uptime";
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
			string uptime = std_out.split(" ")[0];
			double secs = double.parse(uptime);
			return secs;
		}
		catch(Error e){
			log_error (e.message);
			return 0;
		}
	}

	public string get_desktop_name(){

		/* Return the names of the current Desktop environment */

		int pid = -1;

		pid = get_pid_by_name("cinnamon");
		if (pid > 0){
			return "Cinnamon";
		}

		pid = get_pid_by_name("xfdesktop");
		if (pid > 0){
			return "Xfce";
		}

		pid = get_pid_by_name("lxsession");
		if (pid > 0){
			return "LXDE";
		}

		pid = get_pid_by_name("gnome-shell");
		if (pid > 0){
			return "Gnome";
		}

		pid = get_pid_by_name("wingpanel");
		if (pid > 0){
			return "Elementary";
		}

		pid = get_pid_by_name("unity-panel-service");
		if (pid > 0){
			return "Unity";
		}

		pid = get_pid_by_name("plasma-desktop");
		if (pid > 0){
			return "KDE";
		}

		return "Unknown";
	}

	public Gee.ArrayList<string> list_dir_names(string path){
		var list = new Gee.ArrayList<string>();
		
		try
		{
			File f_home = File.new_for_path (path);
			FileEnumerator enumerator = f_home.enumerate_children ("%s".printf(FileAttribute.STANDARD_NAME), 0);
			FileInfo file;
			while ((file = enumerator.next_file ()) != null) {
				string name = file.get_name();
				//string item = path + "/" + name;
				list.add(name);
			}
		}
		catch (Error e) {
			log_error (e.message);
		}

		//sort the list
		CompareDataFunc<string> entry_compare = (a, b) => {
			return strcmp(a,b);
		};
		list.sort((owned) entry_compare);

		return list;
	}

	public int get_display_width(){
		return Gdk.Screen.get_default().get_width();
	}

	public int get_display_height(){
		return Gdk.Screen.get_default().get_height();
	}
	
	// internet helpers ----------------------
	
	public bool check_internet_connectivity(){
		bool connected = false;
		connected = check_internet_connectivity_test1();

		if (connected){
			return connected;
		}
		
		if (!connected){
			connected = check_internet_connectivity_test2();
		}

	    return connected;
	}

	public bool check_internet_connectivity_test1(){
		int exit_code = -1;
		string std_err;
		string std_out;

		string cmd = "ping -q -w 1 -c 1 `ip r | grep default | cut -d ' ' -f 3`\n";
		cmd += "exit $?";
		exit_code = exec_script_sync(cmd, out std_out, out std_err, false);

	    return (exit_code == 0);
	}

	public bool check_internet_connectivity_test2(){
		int exit_code = -1;
		string std_err;
		string std_out;

		string cmd = "ping -q -w 1 -c 1 google.com\n";
		cmd += "exit $?";
		exit_code = exec_script_sync(cmd, out std_out, out std_err, false);

	    return (exit_code == 0);
	}

	public bool shutdown (){

		/* Shutdown the system immediately */

		try{
			string[] argv = { "shutdown", "-h", "now" };
			Pid procId;
			Process.spawn_async(null, argv, null, SpawnFlags.SEARCH_PATH, null, out procId);
			return true;
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}
	}

	public bool command_exists(string command){
		string path = get_cmd_path(command);
		return ((path != null) && (path.length > 0));
	}
	
	// open -----------------------------

	public bool xdg_open (string file){
		string path = get_cmd_path ("xdg-open");
		if ((path != null)&&(path != "")){
			string cmd = "xdg-open '%s'".printf(escape_single_quote(file));
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
			new string[]{ "nemo", "nautilus", "thunar", "pantheon-files", "marlin"}){
				
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

	public bool exo_open_textfile (string txt_file){

		/* Tries to open the given text file in a text editor */

		string path;
		int status;
		string cmd;
		
		path = get_cmd_path ("exo-open");
		if ((path != null)&&(path != "")){
			cmd = "exo-open '%s'".printf(escape_single_quote(txt_file));
			status = exec_script_async (cmd);
			return (status == 0);
		}

		path = get_cmd_path ("gedit");
		if ((path != null)&&(path != "")){
			cmd = "gedit --new-document '%s'".printf(escape_single_quote(txt_file));
			status = exec_script_async (cmd);
			return (status == 0);
		}

		return false;
	}

	public bool exo_open_url (string url){

		/* Tries to open the given text file in a text editor */

		string path;
		int status;
		//string cmd;
		
		path = get_cmd_path ("exo-open");
		if ((path != null)&&(path != "")){
			status = exec_script_async ("exo-open \"" + url + "\"");
			return (status == 0);
		}

		path = get_cmd_path ("firefox");
		if ((path != null)&&(path != "")){
			status = exec_script_async ("firefox \"" + url + "\"");
			return (status == 0);
		}

		path = get_cmd_path ("chromium-browser");
		if ((path != null)&&(path != "")){
			status = exec_script_async ("chromium-browser \"" + url + "\"");
			return (status == 0);
		}

		return false;
	}

	public bool using_efi_boot(){
		
		/* Returns true if the system was booted in EFI mode
		 * and false for BIOS mode */
		 
		return dir_exists("/sys/firmware/efi");
	}

	public void open_terminal_window(
		string terminal_emulator,
		string working_dir,
		string script_file_to_execute,
		bool run_as_admin){
			
		string cmd = "";
		if (run_as_admin){
			cmd += "pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY ";
		}

		string term = terminal_emulator;
		if (!command_exists(term)){
			term = "gnome-terminal";
			if (!command_exists(term)){
				term = "xfce4-terminal";
			}
		}

		cmd += term;
		
		switch (term){
		case "gnome-terminal":
		case "xfce4-terminal":
			if (working_dir.length > 0){
				cmd += " --working-directory='%s'".printf(escape_single_quote(working_dir));
			}
			if (script_file_to_execute.length > 0){
				cmd += " -e '%s\n; echo Press ENTER to exit... ; read dummy;'".printf(escape_single_quote(script_file_to_execute));
			}
			break;
		}

		log_debug(cmd);
		exec_script_async(cmd);
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

	public void timer_elapsed_print(GLib.Timer timer, bool stop = true){
		ulong microseconds;
		double seconds;
		seconds = timer.elapsed (out microseconds);
		if (stop){
			timer.stop();
		}
		log_msg("%s %lu\n".printf(seconds.to_string(), microseconds));
	}	


	public void set_numeric_locale(string type){
		Intl.setlocale(GLib.LocaleCategory.NUMERIC, type);
	    Intl.setlocale(GLib.LocaleCategory.COLLATE, type);
	    Intl.setlocale(GLib.LocaleCategory.TIME, type);
	}
}
