using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.System;
using TeeJee.Misc;

public class RsyncTask : AsyncTask{

	// settings
	public bool delete_extra = true;
	public string rsync_log_file = "";
	public string exclude_from_file = "";
	public string source_path = "";
	public string dest_path = "";
	public bool verbose = true;

	// regex
	private Gee.HashMap<string, Regex> regex_list;

	// status
	public Gee.ArrayList<string> status_lines;
	public int64 status_line_count = 0;
	public int64 total_size = 0;
	
	public RsyncTask(){
		init_regular_expressions();
		status_lines = new Gee.ArrayList<string>();
	}

	private void init_regular_expressions(){
		if (regex_list != null){
			return; // already initialized
		}
		
		regex_list = new Gee.HashMap<string,Regex>();
		
		try {
			//Example: status=-1
			regex_list["status"] = new Regex(
				"""(.)(.)(c|\+|\.)(s|\+|\.)(t|\+|\.)(p|\+|\.)(o|\+|\.)(g|\+|\.)(u|\+|\.)(a|\+|\.)(x|\+|\.) (.*)""");

			regex_list["total-size"] = new Regex(
				"""total size is ([0-9,]+)[ \t]+speedup is [0-9.]+""");

		}
		catch (Error e) {
			log_error (e.message);
		}
	}
	
	public void prepare() {
		string script_text = build_script();
		save_bash_script_temp(script_text, script_file);
		log_debug("RsyncTask:prepare(): saved: %s".printf(script_file));

		status_lines = new Gee.ArrayList<string>();
		status_line_count = 0;
		total_size = 0;
	}

	private string build_script() {
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

		return cmd;
	}
	 
	// execution ----------------------------

	public void execute() {
		log_debug("RsyncTask:execute()");
		
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

		status_line_count++;
		
		MatchInfo match;
		if (regex_list["status"].match(line, 0, out match)) {
			status_line = match.fetch(12);

			status_lines.add(status_line);
			if (status_lines.size > 15){
				status_lines.remove_at(0);
			}
		}
		else if (regex_list["total-size"].match(line, 0, out match)) {
			total_size = int64.parse(match.fetch(1).replace(",",""));
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
