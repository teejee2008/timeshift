/*
 * RsyncTask.vala
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

public class RsyncSpaceCheckTask : AsyncTask{

	// settings
	public bool delete_extra = true;
	public bool delete_after = false;
	public bool delete_excluded = false;
	public bool relative = false;
	
	public string exclude_from_file = "";
	public string link_from_path = "";
	public string source_path = "";
	public string dest_path = "";
	public bool verbose = true;
	public bool io_nice = true;
	public bool dry_run = false;

	// regex
    private Regex sent_bytes_regex;

	// status
    public int64 status_line_count = 0;
	public int64 total_size = 0;

	public RsyncSpaceCheckTask(){
		init_regular_expressions();
	}

	private void init_regular_expressions(){
		if (sent_bytes_regex != null){
			return; // already initialized
		}

		try {
			sent_bytes_regex = new Regex("""sent ([0-9,]+)[ \t]+bytes[ \t]+received""");
		}
		catch (Error e) {
			log_error (e.message);
		}
	}
	
	public void prepare() {
		string script_text = build_script();
		
		log_debug(script_text);
		
		save_bash_script_temp(script_text, script_file);
		log_debug("RsyncSpaceCheckTask:prepare(): saved: %s".printf(script_file));

		total_size = 0;
        status_line_count = 0;
	}

	private string build_script() {
		var cmd = "export LC_ALL=C.UTF-8\n";

		cmd += "rsync -aii";

		cmd += " --recursive";

		if (verbose){
			cmd += " --verbose";
		}
		else{
			cmd += " --quiet";
		}

		if (delete_extra){
			cmd += " --delete";
		}

		if (delete_after){
			cmd += " --delete-after";
		}

		cmd += " --force"; // allow deletion of non-empty directories

		cmd += " --stats";

		cmd += " --sparse";

		if (delete_excluded){
			cmd += " --delete-excluded";
		}

		cmd += " --dry-run";

		if (link_from_path.length > 0){
			if (!link_from_path.has_suffix("/")){
				link_from_path = "%s/".printf(link_from_path);
			}
			
			cmd += " --link-dest='%s'".printf(escape_single_quote(link_from_path));
		}
		
		if (exclude_from_file.length > 0){
			cmd += " --exclude-from='%s'".printf(escape_single_quote(exclude_from_file));

			if (delete_extra && delete_excluded){
				cmd += " --delete-excluded";
			}
		}

		source_path = remove_trailing_slash(source_path);
		
		dest_path = remove_trailing_slash(dest_path);
		
		cmd += " '%s/'".printf(escape_single_quote(source_path));

		cmd += " '%s/'".printf(escape_single_quote(dest_path));
		
		return cmd;
	}

	// execution ----------------------------

	public void execute() {
		
		log_debug("RsyncSpaceCheckTask:execute()");
		
		prepare();
		begin();
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

        if (sent_bytes_regex.match(line, 0, out match)) {
			total_size = int64.parse(match.fetch(1).replace(",",""));
		}
		else{
			//log_debug("not-matched: %s".printf(line));
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
