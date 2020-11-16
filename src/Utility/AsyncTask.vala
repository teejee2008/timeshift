/*
 * AsyncTask.vala
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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.System;
using TeeJee.Misc;

public abstract class AsyncTask : GLib.Object{
	
	private string err_line = "";
	private string out_line = "";
	private DataOutputStream dos_in;
	private DataInputStream dis_out;
	private DataInputStream dis_err;
	protected DataOutputStream dos_log;
	protected bool is_terminated = false;

	private bool stdout_is_open = false;
	private bool stderr_is_open = false;
	
	protected Pid child_pid;
	private int input_fd;
	private int output_fd;
	private int error_fd;
	private bool finish_called = false;

	protected string script_file = "";
	protected string working_dir = "";
	protected string log_file = "";

	public bool background_mode = false;
	
	// public
	public AppStatus status;
	public string status_line = "";
	public int exit_code = 0;
	public string error_msg = "";
	public GLib.Timer timer;
	public double progress = 0.0;
	public double percent = 0.0;
	public int64 prg_count = 0;
	public int64 prg_count_total = 0;
	public int64 prg_bytes = 0;
	public int64 prg_bytes_total = 0;
	public string eta = "";
	//public bool is_running = false;
	
	// signals
	public signal void stdout_line_read(string line);
	public signal void stderr_line_read(string line);
	public signal void task_complete();

	protected AsyncTask(){
		
		working_dir = TEMP_DIR + "/" + timestamp_for_path();
		script_file = path_combine(working_dir, "script.sh");
		log_file = path_combine(working_dir, "task.log");

		//regex = new Gee.HashMap<string,Regex>(); // needs to be initialized again in instance constructor
		
		dir_create(working_dir);
	}
	
	public bool begin(){

		status = AppStatus.RUNNING;
		
		bool has_started = true;
		is_terminated = false;
		finish_called = false;
		
		prg_count = 0;
		prg_bytes = 0;
		error_msg = "";
		
		string[] spawn_args = new string[1];
		spawn_args[0] = script_file;
		
		string[] spawn_env = Environ.get();
		
		try {
			// start timer
			timer = new GLib.Timer();
			timer.start();

			// execute script file
			Process.spawn_async_with_pipes(
			    working_dir, // working dir
			    spawn_args,  // argv
			    spawn_env,   // environment
			    SpawnFlags.SEARCH_PATH,
			    null,        // child_setup
			    out child_pid,
			    out input_fd,
			    out output_fd,
			    out error_fd);

			set_priority();

			log_debug("AsyncTask: child_pid: %d".printf(child_pid));
			
			// create stream readers
			UnixOutputStream uos_in = new UnixOutputStream(input_fd, false);
			UnixInputStream uis_out = new UnixInputStream(output_fd, false);
			UnixInputStream uis_err = new UnixInputStream(error_fd, false);
			dos_in = new DataOutputStream(uos_in);
			dis_out = new DataInputStream(uis_out);
			dis_err = new DataInputStream(uis_err);
			dis_out.newline_type = DataStreamNewlineType.ANY;
			dis_err.newline_type = DataStreamNewlineType.ANY;

			// create log file
			if (log_file.length > 0){
				var file = File.new_for_path(log_file);
				if (file.query_exists()){
					file.delete();
				}
				var file_stream = file.create (FileCreateFlags.REPLACE_DESTINATION);
				dos_log = new DataOutputStream (file_stream);
			}

			try {
				//start thread for reading output stream
				Thread.create<void> (read_stdout, true);
			} catch (Error e) {
				log_error ("AsyncTask.begin():create_thread:read_stdout()");
				log_error (e.message);
			}

			try {
				//start thread for reading error stream
				Thread.create<void> (read_stderr, true);
			} catch (Error e) {
				log_error ("AsyncTask.begin():create_thread:read_stderr()");
				log_error (e.message);
			}
		}
		catch (Error e) {
			log_error ("AsyncTask.begin()");
			log_error(e.message);
			has_started = false;
			//status = AppStatus.FINISHED;
		}

		return has_started;
	}

	private void read_stdout() {
		try {
			stdout_is_open = true;
			
			out_line = dis_out.read_line (null);
			while (out_line != null) {
				//log_msg("O: " + out_line);
				if (!is_terminated && (out_line.length > 0)){
					parse_stdout_line(out_line);
					stdout_line_read(out_line); //signal
				}
				out_line = dis_out.read_line (null); //read next
			}

			stdout_is_open = false;

			// dispose stdout
			if ((dis_out != null) && !dis_out.is_closed()){
				dis_out.close();
			}
			//dis_out.close();
			dis_out = null;
			GLib.FileUtils.close(output_fd);

			// check if complete
			if (!stdout_is_open && !stderr_is_open){
				finish();
			}
		}
		catch (Error e) {
			log_error ("AsyncTask.read_stdout()");
			log_error (e.message);
		}
	}
	
	private void read_stderr() {
		try {
			stderr_is_open = true;
			
			err_line = dis_err.read_line (null);
			while (err_line != null) {
				if (!is_terminated && (err_line.length > 0)){
					error_msg += "%s\n".printf(err_line);
					
					parse_stderr_line(err_line);
					stderr_line_read(err_line); //signal
				}
				err_line = dis_err.read_line (null); //read next
			}

			stderr_is_open = false;

			// dispose stderr
			if ((dis_err != null) && !dis_err.is_closed()){
				dis_err.close(); 
			}
			//dis_err.close();
			dis_err = null;
			GLib.FileUtils.close(error_fd);

			// check if complete
			if (!stdout_is_open && !stderr_is_open){
				finish();
			}
		}
		catch (Error e) {
			log_error ("AsyncTask.read_stderr()");
			log_error (e.message);
		}
	}

	public void write_stdin(string line){
		try{
			if (status == AppStatus.RUNNING){
				dos_in.put_string(line + "\n");
			}
			else{
				log_error ("AsyncTask.write_stdin(): NOT RUNNING");
			}
		}
		catch(Error e){
			log_error ("AsyncTask.write_stdin(): %s".printf(line));
			log_error (e.message);
		}
	}
	
	protected abstract void parse_stdout_line(string out_line);
	
	protected abstract void parse_stderr_line(string err_line);
	
	private void finish(){
		
		// finish() gets called by 2 threads but should be executed only once
		if (finish_called) { return; }
		finish_called = true;
		
		log_debug("AsyncTask: finish(): enter");
		
		// dispose stdin
		try{
			if ((dos_in != null) && !dos_in.is_closed() && !dos_in.is_closing()){
				dos_in.close();
			}
		}
		catch(Error e){
			// ignore
			//log_error ("AsyncTask.finish(): dos_in.close()");
			//log_error (e.message);
		}
		
		dos_in = null;
		GLib.FileUtils.close(input_fd);

		// dispose child process
		Process.close_pid(child_pid); //required on Windows, doesn't do anything on Unix

		try{
			// dispose log
			if ((dos_log != null) && !dos_log.is_closed() && !dos_log.is_closing()){
				dos_log.close();
			}
			dos_log = null;
		}
		catch (Error e) {
			// error can be ignored
			// dos_log is closed automatically when the last reference is set to null
			// there may be pending operations which may throw an error
		}

		read_exit_code();
		
		status_line = "";
		err_line = "";
		out_line = "";

		timer.stop();
		
		finish_task();

		if ((status != AppStatus.CANCELLED) && (status != AppStatus.PASSWORD_REQUIRED)) {
			status = AppStatus.FINISHED;
		}

		//dir_delete(working_dir);
		
		task_complete(); //signal
	}

	protected abstract void finish_task();

	protected int read_exit_code(){
		
		exit_code = -1;
		var path = file_parent(script_file) + "/status";
		if (file_exists(path)){
			var txt = file_read(path);
			exit_code = int.parse(txt);
		}
		log_debug("exit_code: %d".printf(exit_code));
		return exit_code;
	}

	public bool is_running(){
		
		return (status == AppStatus.RUNNING);
	}
	
	// public actions --------------

	public void pause() {
		
		Pid sub_child_pid;
		foreach (long pid in get_process_children(child_pid)) {
			sub_child_pid = (Pid) pid;
			process_pause(sub_child_pid);
		}

		status = AppStatus.PAUSED;
	}

	public void resume() {
		
		Pid sub_child_pid;
		foreach (long pid in get_process_children(child_pid)) {
			sub_child_pid = (Pid) pid;
			process_resume(sub_child_pid);
		}

		status = AppStatus.RUNNING;
	}

	public void stop(AppStatus status_to_update = AppStatus.CANCELLED) {
		
		// we need to un-freeze the processes before we kill them
		if (status == AppStatus.PAUSED) {
			resume();
		}

		status = status_to_update;
		
		process_quit(child_pid);
		
		log_debug("process_quit: %d".printf(child_pid));
	}

	public void set_priority() {
		
		if (background_mode){
			set_priority_value(5);
		}
		else{
			set_priority_value(0);
		}
	}

	public void set_priority_value(int prio) {
		
		Pid app_pid = Posix.getpid();
		process_set_priority (app_pid, prio);

		if (status == AppStatus.RUNNING) {
			process_set_priority (child_pid, prio);

			Pid sub_child_pid;
			foreach (long pid in get_process_children (child_pid)) {
				sub_child_pid = (Pid) pid;
				process_set_priority (sub_child_pid, prio);
			}
		}
	}

	public string stat_time_elapsed{
		owned get{
			long elapsed = (long) timer_elapsed(timer);
			return format_duration(elapsed);
		}
	}

	public string stat_time_remaining{
		owned get{
			if (progress > 0){
				long elapsed = (long) timer_elapsed(timer);
				long remaining = (long)((elapsed / progress) * (1.0 - progress));
				if (remaining < 0){
					remaining = 0;
				}
				return format_duration(remaining);
			}
			else{
				return "???";
			}
		}
	}

	public void print_app_status(){
		
		switch(status){
		case AppStatus.NOT_STARTED:
			log_debug("status=%s".printf("NOT_STARTED"));
			break;
		case AppStatus.RUNNING:
			log_debug("status=%s".printf("RUNNING"));
			break;
		case AppStatus.PAUSED:
			log_debug("status=%s".printf("PAUSED"));
			break;
		case AppStatus.FINISHED:
			log_debug("status=%s".printf("FINISHED"));
			break;
		case AppStatus.CANCELLED:
			log_debug("status=%s".printf("CANCELLED"));
			break;
		case AppStatus.PASSWORD_REQUIRED:
			log_debug("status=%s".printf("PASSWORD_REQUIRED"));
			break;
		}
	}
}

public enum AppStatus {
	NOT_STARTED,
	RUNNING,
	PAUSED,
	FINISHED,
	CANCELLED,
	PASSWORD_REQUIRED
}

/* Sample Subclass:
public class RsyncTask : AsyncTask{

	public bool delete_extra = true;
	public string rsync_log_file = "";
	public string exclude_from_file = "";
	public string source_path = "";
	public string dest_path = "";
	public bool verbose = true;
	
	public RsyncTask(string _script_file, string _working_dir, string _log_file){
		working_dir = _working_dir;
		script_file = _script_file;
		log_file = _log_file;
	}
	
	public void prepare() {
		string script_text = build_script();
		save_bash_script_temp(script_text, script_file);
	}

	private string build_script() {
		var script = new StringBuilder();

		var cmd = "rsync -ai";

		if (verbose){
			cmd += " --verbose";
		}
		else{
			cmd += " --quiet";
		}

		if (delete_extra){
			cmd += " --delete";
		}

		cmd += " --numeric-ids --stats --relative --delete-excluded";

		if (rsync_log_file.length > 0){
			cmd += " --log-file='%s'".printf(escape_single_quote(rsync_log_file));
		}

		if (exclude_from_file.length > 0){
			cmd += " --exclude-from='%s'".printf(escape_single_quote(exclude_from_file));
		}

		source_path = remove_trailing_slash(source_path);
		
		dest_path = remove_trailing_slash(dest_path);
		
		cmd += " '%s/'".printf(escape_single_quote(source_path));

		cmd += " '%s/'".printf(escape_single_quote(dest_path));
		
		//cmd += " /. \"%s\"".printf(sync_path + "/localhost/");

		return script.str;
	}
	 
	// execution ----------------------------

	public void execute() {

		prepare();

		begin();

		if (status == AppStatus.RUNNING){
			
			
		}
	}

	public override void parse_stdout_line(string out_line){
		if (is_terminated) {
			return;
		}
		
		update_progress_parse_console_output(out_line);
	}
	
	public override void parse_stderr_line(string err_line){
		if (is_terminated) {
			return;
		}
		
		update_progress_parse_console_output(err_line);
	}

	public bool update_progress_parse_console_output (string line) {
		if ((line == null) || (line.length == 0)) {
			return true;
		}

		return true;
	}

	protected override void finish_task(){
		if ((status != AppStatus.CANCELLED) && (status != AppStatus.PASSWORD_REQUIRED)) {
			status = AppStatus.FINISHED;
		}
	}

	public int read_status(){
		var status_file = working_dir + "/status";
		var f = File.new_for_path(status_file);
		if (f.query_exists()){
			var txt = file_read(status_file);
			return int.parse(txt);
		}
		return -1;
	}
}
*/
