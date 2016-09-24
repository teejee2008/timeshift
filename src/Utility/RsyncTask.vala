using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.System;
using TeeJee.Misc;

public class RsyncTask : AsyncTask{

	// settings
	public bool delete_extra = true;
	public bool delete_after = false;
	public bool delete_excluded = false;
	public bool relative = false;
	
	public string rsync_log_file = "";
	public string exclude_from_file = "";
	public string link_from_path = "";
	public string source_path = "";
	public string dest_path = "";
	public bool verbose = true;
	public bool io_nice = true;

	// regex
	private Gee.HashMap<string, Regex> regex_list;

	// status
	public GLib.Queue<string> status_lines;
	public int64 status_line_count = 0;
	public int64 total_size = 0;

	public int64 count_created;
	public int64 count_deleted;
	public int64 count_modified;
	public int64 count_checksum;
	public int64 count_size;
	public int64 count_timestamp;
	public int64 count_permissions;
	public int64 count_owner;
	public int64 count_group;
	public int64 count_unchanged;
	
	public RsyncTask(){
		init_regular_expressions();
		status_lines = new GLib.Queue<string>();
	}

	private void init_regular_expressions(){
		if (regex_list != null){
			return; // already initialized
		}
		
		regex_list = new Gee.HashMap<string,Regex>();
		
		try {
			//Example: status=-1
			regex_list["status"] = new Regex(
				"""(.)(.)(c|\+|\.| )(s|\+|\.| )(t|\+|\.| )(p|\+|\.| )(o|\+|\.| )(g|\+|\.| )(u|\+|\.| )(a|\+|\.| )(x|\+|\.| ) (.*)""");

			regex_list["created"] = new Regex(
				"""(.)(.)\+\+\+\+\+\+\+\+\+ (.*)""");

			regex_list["log-created"] = new Regex(
				"""[0-9/]+ [0-9:.]+ \[[0-9]+\] (.)(.)\+\+\+\+\+\+\+\+\+ (.*)""");
				
			regex_list["deleted"] = new Regex(
				"""\*deleting[ \t]+(.*)""");

			regex_list["log-deleted"] = new Regex(
				"""[0-9/]+ [0-9:.]+ \[[0-9]+\] \*deleting[ \t]+(.*)""");

			regex_list["modified"] = new Regex(
				"""(.)(.)(c|\+|\.| )(s|\+|\.| )(t|\+|\.| )(p|\+|\.| )(o|\+|\.| )(g|\+|\.| )(u|\+|\.| )(a|\+|\.| )(x|\+|\.) (.*)""");

			regex_list["log-modified"] = new Regex(
				"""[0-9/]+ [0-9:.]+ \[[0-9]+\] (.)(.)(c|\+|\.| )(s|\+|\.| )(t|\+|\.| )(p|\+|\.| )(o|\+|\.| )(g|\+|\.| )(u|\+|\.| )(a|\+|\.| )(x|\+|\.) (.*)""");

			regex_list["unchanged"] = new Regex(
				"""(.)(.)          (.*)""");

			regex_list["log-unchanged"] = new Regex(
				"""[0-9/]+ [0-9:.]+ \[[0-9]+\] (.)(.)\+\+\+\+\+\+\+\+\+ (.*)""");
				
			regex_list["total-size"] = new Regex(
				"""total size is ([0-9,]+)[ \t]+speedup is [0-9.]+""");

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

		//status_lines = new GLib.Queue<string>();
		status_line_count = 0;
		total_size = 0;

		count_created = 0;
		count_deleted = 0;
		count_modified = 0;
		count_checksum = 0;
		count_size = 0;
		count_timestamp = 0;
		count_permissions = 0;
		count_owner = 0;
		count_group = 0;
		count_unchanged = 0;
	}

	private string build_script() {
		var cmd = "";

		if (io_nice){
			cmd += "ionice -c2 -n7 ";
		}

		cmd += "rsync -aii --recursive";

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

		cmd += " --numeric-ids --stats";

		//if (relative){
		//	cmd += " --relative";
		//}
		
		if (delete_excluded){
			cmd += " --delete-excluded";
		}
		
		if (link_from_path.length > 0){
			if (!link_from_path.has_suffix("/")){
				link_from_path = "%s/".printf(link_from_path);
			}
			
			cmd += " --link-dest='%s'".printf(escape_single_quote(link_from_path));
		}
		
		if (rsync_log_file.length > 0){
			cmd += " --log-file='%s'".printf(escape_single_quote(rsync_log_file));
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

	public FileItem parse_log(string log_file_path){
		var root = new FileItem.dummy_root();

		log_debug("RsyncTask: parse_log()");
		log_debug("log_file = %s".printf(log_file_path));

		prg_count = 0;
		prg_count_total = file_line_count(log_file_path);;
		
		try {
			string line;
			var file = File.new_for_path(log_file_path);
			if (!file.query_exists ()) {
				log_error(_("File not found") + ": %s".printf(log_file_path));
				return root;
			}

			var dis = new DataInputStream (file.read());
			while ((line = dis.read_line (null)) != null) {

				prg_count++;
				
				if (line.strip().length == 0) { continue; }

				string item_path = "";
				var item_type = FileType.REGULAR;
				string item_status = "";
				
				MatchInfo match;
				if (regex_list["log-created"].match(line, 0, out match)) {

					//log_debug("matched: created:%s".printf(line));
					
					item_path = match.fetch(3).split(" -> ")[0].strip();
					item_type = FileType.REGULAR;
					if (match.fetch(2) == "d"){
						item_type = FileType.DIRECTORY;
					}
					item_status = "created";
				}
				else if (regex_list["log-deleted"].match(line, 0, out match)) {
					
					//log_debug("matched: deleted:%s".printf(line));
					
					item_path = match.fetch(1).split(" -> ")[0].strip();
					item_status = "deleted";
				}
				else if (regex_list["log-modified"].match(line, 0, out match)) {

					//log_debug("matched: modified:%s".printf(line));
					
					item_path = match.fetch(12).split(" -> ")[0].strip();
					
					if (match.fetch(2) == "d"){
						item_type = FileType.DIRECTORY;
					}
					
					if (match.fetch(3) == "c"){
						item_status = "checksum";
					}
					else if (match.fetch(4) == "s"){
						item_status = "size";
					}
					else if (match.fetch(5) == "t"){
						item_status = "timestamp";
					}
					else if (match.fetch(6) == "p"){
						item_status = "permissions";
					}
					else if (match.fetch(7) == "o"){
						item_status = "owner";
					}
					else if (match.fetch(8) == "g"){
						item_status = "group";
					}
				}
				else{
					//log_debug("not-matched: %s".printf(line));
				}
				
				if ((item_path.length > 0) && (item_path != "/./") && (item_path != "./")){
					int64 item_size = 0;//int64.parse(size);
					var item = root.add_descendant(item_path, item_type, item_size, 0);
					item.file_status = item_status;

					//log_debug("added: %s".printf(item_path));
				}
				
			}
		}
		catch (Error e) {
			log_error (e.message);
		}

		log_debug("RsyncTask: parse_log(): exit");
		
		return root;
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

		if (prg_count_total > 0){
			prg_count = status_line_count;
			progress = (prg_count * 1.0) / prg_count_total;
		}
		
		//MatchInfo match;
		//if (regex_list["status"].match(line, 0, out match)) {
		//	status_line = match.fetch(12);

			//status_lines.push_tail(status_line);
			//if (status_lines.get_length() > 15){
			//	status_lines.pop_head();
			//}
		//}
		MatchInfo match;
		if (regex_list["created"].match(line, 0, out match)) {

			//log_debug("matched: created:%s".printf(line));
			
			count_created++;
			status_line = match.fetch(3).split(" -> ")[0].strip();
		}
		else if (regex_list["deleted"].match(line, 0, out match)) {
			
			//log_debug("matched: deleted:%s".printf(line));

			count_deleted++;
			status_line = match.fetch(1).split(" -> ")[0].strip();
		}
		else if (regex_list["unchanged"].match(line, 0, out match)) {
			
			//log_debug("matched: deleted:%s".printf(line));

			count_unchanged++;
			status_line = match.fetch(3).split(" -> ")[0].strip();
		}
		else if (regex_list["modified"].match(line, 0, out match)) {

			//log_debug("matched: modified:%s".printf(line));

			count_modified++;
			status_line = match.fetch(12).split(" -> ")[0].strip();
			
			if (match.fetch(3) == "c"){
				count_checksum++;
			}
			else if (match.fetch(4) == "s"){
				count_size++;
			}
			else if (match.fetch(5) == "t"){
				count_timestamp++;
			}
			else if (match.fetch(6) == "p"){
				count_permissions++;
			}
			else if (match.fetch(7) == "o"){
				count_owner++;
			}
			else if (match.fetch(8) == "g"){
				count_group++;
			}
			else{
				count_unchanged++;
			}
		}
		else if (regex_list["total-size"].match(line, 0, out match)) {
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
