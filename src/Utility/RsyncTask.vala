using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.System;
using TeeJee.Misc;

public class RsyncTask : AsyncTask{

	public bool delete_extra = true;
	public string rsync_log_file = "";
	public string exclude_from_file = "";
	public string source_path = "";
	public string dest_path = "";
	public bool verbose = true;
	
	public RsyncTask(string _working_dir, string _log_file){
		working_dir = _working_dir;
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

		/*log_debug(string.nfill(70,'='));
		log_debug(script_file);
		log_debug(string.nfill(70,'='));
		log_debug(file_read(script_file));
		log_debug(string.nfill(70,'='));*/
		
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
