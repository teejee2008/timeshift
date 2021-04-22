/*
 * DeleteFileTask.vala
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

public class DeleteFileTask : AsyncTask{

	// settings
	public string dest_path = "";
	public bool verbose = true;
	public bool io_nice = true;
	public bool use_rsync = false;

	//private
	private string source_path = ""; 
		
	// regex
	private Gee.HashMap<string, Regex> regex_list;
	
	// status
	public int64 status_line_count = 0;
	public int64 total_size = 0;
	public string status_message = "";
	public string time_remaining = "";
	
	public DeleteFileTask(){
		init_regular_expressions();
	}

	private void init_regular_expressions(){
		if (regex_list != null){
			return; // already initialized
		}
		
		regex_list = new Gee.HashMap<string,Regex>();
		
		try {

			regex_list["rsync-deleted"] = new Regex(
				"""\*deleting[ \t]+(.*)""");

		}
		catch (Error e) {
			log_error (e.message);
		}
	}
	
	public void prepare() {
		string script_text = build_script();
		log_debug(script_text);
		save_bash_script_temp(script_text, script_file);

		log_debug("RsyncTask:prepare(): saved: %s".printf(script_file));

		status_line_count = 0;
		total_size = 0;
	}

	private string build_script() {
		var cmd = "";

		if (io_nice){
			//cmd += "ionice -c2 -n7 ";
		}

		if (use_rsync){

			cmd += "ionice -c idle rsync -aii";

			if (verbose){
				cmd += " --verbose";
			}
			else{
				cmd += " --quiet";
			}

			cmd += " --delete";

			cmd += " --stats --relative";

			source_path = "/tmp/%s_empty".printf(random_string());
			dir_create(source_path);

			source_path = remove_trailing_slash(source_path);
			dest_path = remove_trailing_slash(dest_path);
			
			cmd += " '%s/'".printf(escape_single_quote(source_path));
			cmd += " '%s/'".printf(escape_single_quote(dest_path));
		}
		else{
			cmd += "rm";

			if (verbose){
				cmd += " -rfv";
			}
			else{
				cmd += " -rf";
			}

			cmd += " '%s'".printf(escape_single_quote(dest_path));
		}

		return cmd;
	}

	// execution ----------------------------

	public void execute() {

		status = AppStatus.RUNNING;
		
		log_debug("RsyncTask:execute()");
		
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

		status_line_count++;

		if (prg_count_total > 0){
			prg_count = status_line_count;
			progress = (prg_count * 1.0) / prg_count_total;
		}
		
		MatchInfo match;
		if (regex_list["rsync-deleted"].match(line, 0, out match)) {
			
			//log_debug("matched: rsync-deleted:%s".printf(line));

			status_line = match.fetch(1).split(" -> ")[0].strip();
		}
		else {
			
			//log_debug("matched: else:%s".printf(line));

			status_line = line.strip();
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
