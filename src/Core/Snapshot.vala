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
	public Gee.ArrayList<CryptTabEntry> cryttab_list;
	public bool valid = true;
	public bool marked_for_deletion = false;

	public DeleteFileTask delete_file_task;

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
			delete_file_task = new DeleteFileTask();
			
			read_control_file();
			read_exclude_list();
			read_fstab_file();
			read_crypttab_file();
		}
		catch(Error e){
			log_error (e.message);
		}
	}

	// properties

	public string exclude_file_for_backup {
		owned get {
			return path_combine(path, "exclude.list");
		}	
	}

	public string exclude_file_for_restore {
		owned get {
			return path_combine(path, "exclude-restore.list");
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
				valid = false;
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

			string delete_trigger_file = path + "/delete";
			if (file_exists(delete_trigger_file)){
				marked_for_deletion = true;
			}
		}
		else{
			valid = false;
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
			valid = false;
		}
	}

	public void read_fstab_file(){
		string fstab_path = path + "/localhost/etc/fstab";
		fstab_list = FsTabEntry.read_file(fstab_path);
	}

	public void read_crypttab_file(){
		string crypttab_path = path + "/localhost/etc/crypttab";
		cryttab_list = CryptTabEntry.read_file(crypttab_path);
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

	public void remove(bool wait){

		var message = _("Removing") + " '%s'...".printf(name);
		log_msg(message);

		delete_file_task.dest_path = "%s/".printf(path);
		delete_file_task.status_message = message;
		delete_file_task.execute();

		if (wait){
			while (delete_file_task.is_running){
				gtk_do_events ();
				sleep(1000);
			}
		}
	}
	
	public void mark_for_deletion(){
		string delete_trigger_file = path + "/delete";
		file_write(delete_trigger_file, "");
		marked_for_deletion = true;
	}
}
