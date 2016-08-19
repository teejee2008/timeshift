/*
 * Bash.vala
 *
 * Copyright 2015 Tony George <teejee2008@gmail.com>
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

using GLib;
using Gtk;
using Gee;
using Json;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class Bash : AsyncTask {

	public Pid bash_pid = -1;
	public int status_code = -1;
	private static Gee.HashMap<string, Regex> regex_list;
	
	public Bash() {
		init_regular_expressions();
	}

	private static void init_regular_expressions(){
		if (regex_list != null){
			return; // already initialized
		}
		
		regex_list = new Gee.HashMap<string,Regex>();
		
		try {
			//Example: status=-1
			regex_list["status"] = new Regex("""status=([0-9\-]+)""");
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	// execution ----------------------------

	public void start_shell() {
		dir_create(working_dir);

		var sh = "bash -c 'pkexec bash'";
		save_bash_script_temp(sh, script_file);
		begin();
		log_debug("Started bash shell");

		if (status == AppStatus.RUNNING){
			bash_pid = -1;
			while ((status == AppStatus.RUNNING) && (bash_pid == -1)) {
				sleep(200);
				var children = get_process_children(child_pid);
				if (children.length > 0){
					bash_pid = children[0];
				}
			}
			
			log_debug("script pid: %d".printf(child_pid));	
			log_debug("bash shell pid: %d".printf(bash_pid));	
		}
	}

	public override void parse_stdout_line(string out_line){
		if ((out_line == null) || (out_line.length == 0)) {
			return;
		}
		MatchInfo match;
		if (regex_list["status"].match(out_line, 0, out match)) {
			status_code = int.parse(match.fetch(1));
		}
		stdout.printf(out_line + "\n");
		stdout.flush();
	}
	
	public override void parse_stderr_line(string err_line){
		stdout.printf(err_line + "\n");
		stdout.flush();
	}

	public int execute(string line){
		status_code = -1;
		write_stdin(line);
		write_stdin("echo status=$?");

		while (status_code == -1){
			sleep(200);
			gtk_do_events();
		}

		return status_code;
	}
	
	protected override void finish_task(){
		log_debug("Bash: finish_task()");
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

