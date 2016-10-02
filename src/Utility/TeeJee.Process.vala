
/*
 * TeeJee.ProcessHelper.vala
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
 
namespace TeeJee.ProcessHelper{
	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.Misc;

	public string TEMP_DIR;
	
	/* Convenience functions for executing commands and managing processes */

	// execute process ---------------------------------
	
    public static void init_tmp(string subdir_name){
		string std_out, std_err;

		TEMP_DIR = Environment.get_tmp_dir() + "/" + subdir_name + "/" + random_string();
		dir_create(TEMP_DIR);

		exec_script_sync("echo 'ok'",out std_out,out std_err, true);
		if ((std_out == null)||(std_out.strip() != "ok")){
			TEMP_DIR = Environment.get_home_dir() + "/.temp/" + subdir_name + "/" + random_string();
			exec_sync("rm -rf '%s'".printf(TEMP_DIR), null, null);
			dir_create(TEMP_DIR);
		}

		//log_debug("TEMP_DIR=" + TEMP_DIR);
	}

	public string create_temp_subdir(){
		var temp = "%s/%s".printf(TEMP_DIR, random_string());
		dir_create(temp);
		return temp;
	}
	
	public int exec_sync (string cmd, out string? std_out = null, out string? std_err = null){

		/* Executes single command synchronously.
		 * Pipes and multiple commands are not supported.
		 * std_out, std_err can be null. Output will be written to terminal if null. */

		try {
			int status;
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out status);
	        return status;
		}
		catch (Error e){
	        log_error (e.message);
	        return -1;
	    }
	}
	
	public int exec_script_sync (string script,
		out string? std_out = null, out string? std_err = null,
		bool supress_errors = false, bool run_as_admin = false,
		bool cleanup_tmp = true){

		/* Executes commands synchronously.
		 * Pipes and multiple commands are fully supported.
		 * Commands are written to a temporary bash script and executed.
		 * std_out, std_err can be null. Output will be written to terminal if null.
		 * */

		string sh_file = save_bash_script_temp(script, null, true, supress_errors);
		string sh_file_admin = "";
		
		if (run_as_admin){
			
			var script_admin = "#!/bin/bash\n";
			script_admin += "pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY";
			script_admin += " '%s'".printf(escape_single_quote(sh_file));
			
			sh_file_admin = GLib.Path.build_filename(file_parent(sh_file),"script-admin.sh");

			save_bash_script_temp(script_admin, sh_file_admin, true, supress_errors);
		}
		
		try {
			string[] argv = new string[1];
			if (run_as_admin){
				argv[0] = sh_file_admin;
			}
			else{
				argv[0] = sh_file;
			}

			string[] env = Environ.get();
			
			int exit_code;

			if ((std_out == null) && (std_err == null)){
				Process.spawn_sync (
					TEMP_DIR, //working dir
					argv, //argv
					env, //environment
					SpawnFlags.SEARCH_PATH,
					null,   // child_setup
					null,
					null,
					out exit_code
					);
			}
			else{
				Process.spawn_sync (
					TEMP_DIR, //working dir
					argv, //argv
					env, //environment
					SpawnFlags.SEARCH_PATH,
					null,   // child_setup
					out std_out,
					out std_err,
					out exit_code
					);
			}

			if (cleanup_tmp){
				file_delete(sh_file);
				if (run_as_admin){
					file_delete(sh_file_admin);
				}
			}
			
			return exit_code;
		}
		catch (Error e){
			if (!supress_errors){
				log_error (e.message);
			}
			return -1;
		}
	}

	public int exec_script_async (string script){

		/* Executes commands synchronously.
		 * Pipes and multiple commands are fully supported.
		 * Commands are written to a temporary bash script and executed.
		 * Return value indicates if script was started successfully.
		 *  */

		try {

			string scriptfile = save_bash_script_temp (script);

			string[] argv = new string[1];
			argv[0] = scriptfile;

			string[] env = Environ.get();
			
			Pid child_pid;
			Process.spawn_async_with_pipes(
			    TEMP_DIR, //working dir
			    argv, //argv
			    env, //environment
			    SpawnFlags.SEARCH_PATH,
			    null,
			    out child_pid);

			return 0;
		}
		catch (Error e){
	        log_error (e.message);
	        return 1;
	    }
	}

	public string? save_bash_script_temp (string commands, string? script_path = null,
		bool force_locale = true, bool supress_errors = false){

		string sh_path = script_path;
		
		/* Creates a temporary bash script with given commands
		 * Returns the script file path */

		var script = new StringBuilder();
		script.append ("#!/bin/bash\n");
		script.append ("\n");
		if (force_locale){
			script.append ("LANG=C\n");
		}
		script.append ("\n");
		script.append ("%s\n".printf(commands));
		script.append ("\n\nexitCode=$?\n");
		script.append ("echo ${exitCode} > ${exitCode}\n");
		script.append ("echo ${exitCode} > status\n");

		if ((sh_path == null) || (sh_path.length == 0)){
			sh_path = get_temp_file_path() + ".sh";
		}

		try{
			//write script file
			var file = File.new_for_path (sh_path);
			if (file.query_exists ()) {
				file.delete ();
			}
			var file_stream = file.create (FileCreateFlags.REPLACE_DESTINATION);
			var data_stream = new DataOutputStream (file_stream);
			data_stream.put_string (script.str);
			data_stream.close();

			// set execute permission
			chmod (sh_path, "u+x");

			return sh_path;
		}
		catch (Error e) {
			if (!supress_errors){
				log_error (e.message);
			}
		}

		return null;
	}

	public string get_temp_file_path(){

		/* Generates temporary file path */

		return TEMP_DIR + "/" + timestamp_numeric() + (new Rand()).next_int().to_string();
	}

	// find process -------------------------------
	
	// dep: which
	public string get_cmd_path (string cmd){

		/* Returns the full path to a command */

		try {
			int exitCode;
			string stdout, stderr;
			Process.spawn_command_line_sync("which " + cmd, out stdout, out stderr, out exitCode);
	        return stdout;
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}

	// dep: pidof, TODO: Rewrite using /proc
	public int get_pid_by_name (string name){

		/* Get the process ID for a process with given name */

		string std_out, std_err;
		exec_sync("pidof \"%s\"".printf(name), out std_out, out std_err);
		
		if (std_out != null){
			string[] arr = std_out.split ("\n");
			if (arr.length > 0){
				return int.parse (arr[0]);
			}
		}

		return -1;
	}

	public int get_pid_by_command(string cmdline){

		/* Searches for process using the command line used to start the process.
		 * Returns the process id if found.
		 * */
		 
		try {
			FileEnumerator enumerator;
			FileInfo info;
			File file = File.parse_name ("/proc");

			enumerator = file.enumerate_children ("standard::name", 0);
			while ((info = enumerator.next_file()) != null) {
				try {
					string io_stat_file_path = "/proc/%s/cmdline".printf(info.get_name());
					var io_stat_file = File.new_for_path(io_stat_file_path);
					if (file.query_exists()){
						var dis = new DataInputStream (io_stat_file.read());

						string line;
						string text = "";
						size_t length;
						while((line = dis.read_until ("\0", out length)) != null){
							text += " " + line;
						}

						if ((text != null) && text.contains(cmdline)){
							return int.parse(info.get_name());
						}
					} //stream closed
				}
				catch(Error e){
					// do not log
					// some processes cannot be accessed by non-admin user
				}
			}
		}
		catch(Error e){
		  log_error (e.message);
		}

		return -1;
	}

	public void get_proc_io_stats(int pid, out int64 read_bytes, out int64 write_bytes){

		/* Returns the number of bytes read and written by a process to disk */
		
		string io_stat_file_path = "/proc/%d/io".printf(pid);
		var file = File.new_for_path(io_stat_file_path);

		read_bytes = 0;
		write_bytes = 0;

		try {
			if (file.query_exists()){
				var dis = new DataInputStream (file.read());
				string line;
				while ((line = dis.read_line (null)) != null) {
					if(line.has_prefix("rchar:")){
						read_bytes = int64.parse(line.replace("rchar:","").strip());
					}
					else if(line.has_prefix("wchar:")){
						write_bytes = int64.parse(line.replace("wchar:","").strip());
					}
				}
			} //stream closed
		}
		catch(Error e){
			log_error (e.message);
		}
	}

	// dep: ps TODO: Rewrite using /proc
	public bool process_is_running(long pid){

		/* Checks if given process is running */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			cmd = "ps --pid %ld".printf(pid);
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}

		return (ret_val == 0);
	}

	// dep: pgrep TODO: Rewrite using /proc
	public bool process_is_running_by_name(string proc_name){

		/* Checks if given process is running */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			cmd = "pgrep -f '%s'".printf(proc_name);
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}

		return (ret_val == 0);
	}
	
	// dep: ps TODO: Rewrite using /proc
	public int[] get_process_children (Pid parent_pid){

		/* Returns the list of child processes spawned by given process */

		string std_out, std_err;
		exec_sync("ps --ppid %d".printf(parent_pid), out std_out, out std_err);

		int pid;
		int[] procList = {};
		string[] arr;

		foreach (string line in std_out.split ("\n")){
			arr = line.strip().split (" ");
			if (arr.length < 1) { continue; }

			pid = 0;
			pid = int.parse (arr[0]);

			if (pid != 0){
				procList += pid;
			}
		}
		return procList;
	}

	// manage process ---------------------------------
	
	public void process_quit(Pid process_pid, bool killChildren = true){

		/* Kills specified process and its children (optional).
		 * Sends signal SIGTERM to the process to allow it to quit gracefully.
		 * */

		int[] child_pids = get_process_children (process_pid);
		Posix.kill (process_pid, Posix.SIGTERM);

		if (killChildren){
			Pid childPid;
			foreach (long pid in child_pids){
				childPid = (Pid) pid;
				Posix.kill (childPid, Posix.SIGTERM);
			}
		}
	}
	
	public void process_kill(Pid process_pid, bool killChildren = true){

		/* Kills specified process and its children (optional).
		 * Sends signal SIGKILL to the process to kill it forcefully.
		 * It is recommended to use the function process_quit() instead.
		 * */
		
		int[] child_pids = get_process_children (process_pid);
		Posix.kill (process_pid, Posix.SIGKILL);

		if (killChildren){
			Pid childPid;
			foreach (long pid in child_pids){
				childPid = (Pid) pid;
				Posix.kill (childPid, Posix.SIGKILL);
			}
		}
	}

	// dep: kill
	public int process_pause (Pid procID){

		/* Pause/Freeze a process */

		return exec_sync ("kill -STOP %d".printf(procID), null, null);
	}

	// dep: kill
	public int process_resume (Pid procID){

		/* Resume/Un-freeze a process*/

		return exec_sync ("kill -CONT %d".printf(procID), null, null);
	}

	// dep: ps TODO: Rewrite using /proc
	public void process_quit_by_name(string cmd_name, string cmd_to_match, bool exact_match){

		/* Kills a specific command */
		
		string std_out, std_err;
		exec_sync ("ps w -C '%s'".printf(cmd_name), out std_out, out std_err);
		//use 'ps ew -C conky' for all users

		string pid = "";
		foreach(string line in std_out.split("\n")){
			if ((exact_match && line.has_suffix(" " + cmd_to_match))
			|| (!exact_match && (line.index_of(cmd_to_match) != -1))){
				pid = line.strip().split(" ")[0];
				Posix.kill ((Pid) int.parse(pid), 15);
				log_debug(_("Stopped") + ": [PID=" + pid + "] ");
			}
		}
	}

	// process priority ---------------------------------------
	
	public void process_set_priority (Pid procID, int prio){

		/* Set process priority */

		if (Posix.getpriority (Posix.PRIO_PROCESS, procID) != prio)
			Posix.setpriority (Posix.PRIO_PROCESS, procID, prio);
	}

	public int process_get_priority (Pid procID){

		/* Get process priority */

		return Posix.getpriority (Posix.PRIO_PROCESS, procID);
	}

	public void process_set_priority_normal (Pid procID){

		/* Set normal priority for process */

		process_set_priority (procID, 0);
	}

	public void process_set_priority_low (Pid procID){

		/* Set low priority for process */

		process_set_priority (procID, 5);
	}

	public class TimeoutCounter : GLib.Object {

		public bool active = false;
		public string process_to_kill = "";
		public int seconds_to_wait = 30;
		public bool exit_app = false;
		
		public void kill_process_on_timeout(
			string process_to_kill, int seconds_to_wait = 20, bool exit_app = false){

			this.process_to_kill = process_to_kill;
			this.seconds_to_wait = seconds_to_wait;
			this.exit_app = exit_app;
				
			try {
				active = true;
				Thread.create<void> (start_counter_thread, true);
			}
			catch (Error e) {
				log_error (e.message);
			}
		}

		public void exit_on_timeout(int seconds_to_wait = 20){
			this.process_to_kill = "";
			this.seconds_to_wait = seconds_to_wait;
			this.exit_app = true;
				
			try {
				active = true;
				Thread.create<void> (start_counter_thread, true);
			}
			catch (Error e) {
				log_error (e.message);
			}
		}

		public void stop(){
			active = false;
		}
		
		public void start_counter_thread(){
			int secs = 0;
			
			while (active && (secs < seconds_to_wait)){
				Thread.usleep((ulong) GLib.TimeSpan.MILLISECOND * 1000);
				secs += 1;
			}

			if (active){
				active = false;
				stdout.printf("\n");

				if (process_to_kill.length > 0){
					Posix.system("killall " + process_to_kill);
					stderr.printf("\n[timeout] Killed process" + ": %s\n".printf(process_to_kill));
				}

				if (exit_app){
					stderr.printf("\n[timeout] Exit application\n");
					exit(0);
				}
			}
		}
	}

	public class AppLock : GLib.Object {
		public string lock_file = "";
		public string lock_message = "";
		
		public bool create(string app_name, string message){

			var lock_dir = "/var/run/lock/%s".printf(app_name);
			dir_create(lock_dir);
			lock_file = path_combine(lock_dir, "lock");
			
			try{
				var file = File.new_for_path(lock_file);
				if (file.query_exists()) {

					string txt = file_read(lock_file);
					string process_id = txt.split(";")[0].strip();
					lock_message = txt.split(";")[1].strip();
					long pid = long.parse(process_id);

					if (process_is_running(pid)){
						log_msg(_("Another instance of this application is running")
							+ " (PID=%ld)".printf(pid));
						return false;
					}
					else{
						log_msg(_("[Warning] Deleted invalid lock"));
						file.delete();
						write_lock_file(message);
						return true;
					}
				}
				else{
					write_lock_file(message);
					return true;
				}
			}
			catch (Error e) {
				log_error (e.message);
				return false;
			}
		}

		private void write_lock_file(string message){
			string current_pid = ((long) Posix.getpid()).to_string();
			file_write(lock_file, "%s;%s".printf(current_pid, message));
		}
		
		public void remove(){
			try{
				var file = File.new_for_path (lock_file);
				if (file.query_exists()) {
					file.delete();
				}
			}
			catch (Error e) {
				log_error (e.message);
			}
		}

	}
}
