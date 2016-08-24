using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.Devices;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;
using Json;

public class Snapshot : GLib.Object{
	public string path = "";
	public string name = "";
	public DateTime date;
	public string sys_uuid = "";
	public string sys_distro = "";
	public string app_version = "";
	public string description = "";
	public Gee.ArrayList<string> tags;
	public Gee.ArrayList<string> exclude_list;
	public Gee.ArrayList<FsTabEntry> fstab_list;
	public bool is_valid = true;

	// private
	private bool thr_success = false;
	private bool thr_running = false;
	//private int thr_retval = -1;

	public Snapshot(string dir_path){

		try{
			var f = File.new_for_path(dir_path);
			var info = f.query_info("*", FileQueryInfoFlags.NONE);

			path = dir_path;
			name = info.get_name();
			description = "";

			date = new DateTime.from_unix_utc(0);
			tags = new Gee.ArrayList<string>();
			exclude_list = new Gee.ArrayList<string>();
			fstab_list = new Gee.ArrayList<FsTabEntry>();

			read_control_file();
			read_exclude_list();
			read_fstab_file();
		}
		catch(Error e){
			log_error (e.message);
		}
	}

	// manage tags
	
	public string taglist{
		owned get{
			string str = "";
			foreach(string tag in tags){
				str += " " + tag;
			}
			return str.strip();
		}
		set{
			tags.clear();
			foreach(string tag in value.split(" ")){
				if (!tags.contains(tag.strip())){
					tags.add(tag.strip());
				}
			}
		}
	}

	public string taglist_short{
		owned get{
			string str = "";
			foreach(string tag in tags){
				str += " " + tag.replace("ondemand","O").replace("boot","B").replace("hourly","H").replace("daily","D").replace("weekly","W").replace("monthly","M");
			}
			return str.strip();
		}
	}

	public void add_tag(string tag){
		if (!tags.contains(tag.strip())){
			tags.add(tag.strip());
			update_control_file();
		}
	}

	public void remove_tag(string tag){
		if (tags.contains(tag.strip())){
			tags.remove(tag.strip());
			update_control_file();
		}
	}

	public bool has_tag(string tag){
		return tags.contains(tag.strip());
	}

	// control files
	
	public void read_control_file(){
		string ctl_file = path + "/info.json";

		var f = File.new_for_path(ctl_file);
		if (f.query_exists()) {
			var parser = new Json.Parser();
			try{
				parser.load_from_file(ctl_file);
			} catch (Error e) {
				log_error (e.message);
			}
			var node = parser.get_root();
			var config = node.get_object();


			if ((node == null)||(config == null)){
				is_valid = false;
				return;
			}

			string val = json_get_string(config,"created","");
			if (val.length > 0) {
				DateTime date_utc = new DateTime.from_unix_utc(int64.parse(val));
				date = date_utc.to_local();
			}

			sys_uuid = json_get_string(config,"sys-uuid","");
			sys_distro = json_get_string(config,"sys-distro","");
			taglist = json_get_string(config,"tags","");
			description = json_get_string(config,"comments","");
			app_version = json_get_string(config,"app-version","");
		}
		else{
			is_valid = false;
		}
	}

	public void read_exclude_list(){
		string list_file = path + "/exclude.list";

		exclude_list.clear();

		var f = File.new_for_path(list_file);
		if (f.query_exists()) {
			foreach(string path in file_read(list_file).split("\n")){
				path = path.strip();
				if (!exclude_list.contains(path) && path.length > 0){
					exclude_list.add(path);
				}
			}
		}
		else{
			is_valid = false;
		}
	}

	public void read_fstab_file(){
		string fstab_path = path + "/localhost/etc/fstab";
		fstab_list = FsTabEntry.read_fstab_file(fstab_path);
	}

	public void update_control_file(){
		/* Updates tag and comments */
		
		try{
			string ctl_file = path + "/info.json";
			var f = File.new_for_path(ctl_file);

			if (f.query_exists()) {

				var parser = new Json.Parser();
				try{
					parser.load_from_file(ctl_file);
				} catch (Error e) {
					log_error (e.message);
				}
				var node = parser.get_root();
				var config = node.get_object();

				config.set_string_member("tags", taglist);
				config.set_string_member("comments", description);

				var json = new Json.Generator();
				json.pretty = true;
				json.indent = 2;
				node.set_object(config);
				json.set_root(node);
				f.delete();
				json.to_file(ctl_file);
			}
		} catch (Error e) {
			log_error (e.message);
		}
	}

	public void remove_control_file(){
		string ctl_file = path + "/info.json";
		file_delete(ctl_file);
	}
	
	public static Snapshot write_control_file(
		string snapshot_path, DateTime dt_created,
		string tag, string root_uuid, string distro_full_name){
			
		var ctl_path = snapshot_path + "/info.json";
		var config = new Json.Object();

		config.set_string_member("created", dt_created.to_utc().to_unix().to_string());
		config.set_string_member("sys-uuid", root_uuid);
		config.set_string_member("sys-distro", distro_full_name);
		config.set_string_member("app-version", AppVersion);
		config.set_string_member("tags", tag);
		config.set_string_member("comments", "");

		var json = new Json.Generator();
		json.pretty = true;
		json.indent = 2;
		var node = new Json.Node(NodeType.OBJECT);
		node.set_object(config);
		json.set_root(node);

		try{
			var f = File.new_for_path(ctl_path);
			if (f.query_exists()){
				f.delete();
			}

			json.to_file(ctl_path);
		} catch (Error e) {
	        log_error (e.message);
	    }

	    return (new Snapshot(snapshot_path));
	}

	// check
	
	public bool has_subvolumes(){
		foreach(FsTabEntry en in fstab_list){
			if (en.options.contains("subvol=@")){
				return true;
			}
		}
		return false;
	}

	// actions

	public bool remove(){
		try {
			thr_running = true;
			thr_success = false;
			Thread.create<void> (remove_snapshot_thread, true);
		} catch (ThreadError e) {
			thr_running = false;
			thr_success = false;
			log_error (e.message);
		}

		while (thr_running){
			gtk_do_events ();
			Thread.usleep((ulong) GLib.TimeSpan.MILLISECOND * 500);
		}

		return thr_success;
	}

	private void remove_snapshot_thread(){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		log_msg(_("Removing snapshot") + " '%s'...".printf(name));

		try{
			var f = File.new_for_path(path);
			if(f.query_exists()){
				cmd = "rm -rf \"%s\"".printf(path);

				if (LOG_COMMANDS) { log_debug(cmd); }

				Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);

				if (ret_val != 0){
					log_error(_("Failed to remove") + ": '%s'".printf(path));
					thr_success = false;
					thr_running = false;
					return;
				}
				else{
					log_msg(_("Removed") + ": '%s'".printf(path));
					thr_success = true;
					thr_running = false;
					return;
				}
			}
			else{
				log_error(_("Directory not found") + ": '%s'".printf(path));
				thr_success = true;
				thr_running = false;
			}
		}
		catch(Error e){
			log_error (e.message);
			thr_success = false;
			thr_running = false;
			return;
		}
	}

}
