using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class FsTabEntry : GLib.Object{
	public bool is_comment = false;
	public bool is_empty_line = false;
	
	public string device_string = "";
	public string mount_point = "";
	public string type = "";
	public string options = "defaults";
	public string dump = "0";
	public string pass = "0";
	public string line = "";

	public string device_uuid {
		owned get{
			if (device_string.down().has_prefix("uuid=")){
				return device_string.replace("\"","").replace("'","").split("=")[1];
			}
			else{
				return "";
			}
		}
		set {
			device_string = "UUID=%s".printf(value);
		}
	}

	public static Gee.ArrayList<FsTabEntry> read_file(string file_path){
		var list = new Gee.ArrayList<FsTabEntry>();

		if (!file_exists(file_path)){ return list; }

		string text = file_read(file_path);
		string[] lines = text.split("\n");
		foreach(string line in lines){
			var entry = new FsTabEntry();
			list.add(entry);

			entry.is_comment = line.strip().has_prefix("#");
			entry.is_empty_line = (line.strip().length == 0);

			if (entry.is_comment){
				entry.line = line;
			}
			else if (entry.is_empty_line){
				entry.line = "";
			}
			else{
				entry.line = line;

				string[] parts = line.replace("\t"," ").split(" ");
				int part_num = -1;
				foreach(string part in parts){
					if (part.strip().length == 0) { continue; }
					switch (++part_num){
						case 0:
							entry.device_string = part.strip();
							break;
						case 1:
							entry.mount_point = part.strip();
							break;
						case 2:
							entry.type = part.strip();
							break;
						case 3:
							entry.options = part.strip();
							break;
						case 4:
							entry.dump = part.strip();
							break;
						case 5:
							entry.pass = part.strip();
							break;
					}
				}
			}
		}

		return list;
	}

	public static string write_file(
		Gee.ArrayList<FsTabEntry> entries, string file_path,
		bool keep_comments_and_empty_lines = false){
			
		string text = "";

		if (!keep_comments_and_empty_lines){
			text += "# <file system> <mount point> <type> <options> <dump> <pass>\n\n";
		}
		
		foreach(var entry in entries){
			if (entry.is_comment || entry.is_empty_line){
				if (keep_comments_and_empty_lines){
					text += "%s\n".printf(entry.line);
				}
			}
			else {
				text += "%s\t%s\t%s\t%s\t%s\t%s\n".printf(
					entry.device_string, entry.mount_point, entry.type,
					entry.options, entry.dump, entry.pass);
			}
		}

		// sort the entries based on mount path
		// this is required to ensure that base paths are mounted before child paths

		entries.sort((a, b)=>{
			return strcmp(a.mount_point, b.mount_point);
		});
		
		if (file_exists(file_path)){
			file_delete(file_path);
		}
		
		file_write(file_path, text);
		
		return text;
	}

	public string subvolume_name(){
		if (options.contains("subvol=")){
			return options.split("subvol=")[1].split(",")[0].strip();
		}
		else{
			return "";
		}
	}

	public bool is_for_system_directory(){

		if (mount_point.has_prefix("/mnt")
			|| mount_point.has_prefix("/mount")
			|| mount_point.has_prefix("/sdcard")
			|| mount_point.has_prefix("/cdrom")
			|| mount_point.has_prefix("/media")
			|| (mount_point == "none")
			|| !mount_point.has_prefix("/")
			|| (!device_string.has_prefix("/dev/") && !device_string.down().has_prefix("uuid="))){
			
			return false;
		}
		else{
			return true;
		}
	}

	public static FsTabEntry? find_entry_by_mount_point(
		Gee.ArrayList<FsTabEntry> entries, string mount_path){
			
		foreach(var entry in entries){
			if (entry.mount_point == mount_path){
				return entry;
			}
		}
		return null;
	}

	public void append_option(string option){
		
		if (!options.contains(option)){
			options += ",%s".printf(option);
		}
		
		if(options.has_prefix(",")){
			options = options[1:options.length];
		}
		
		options = options.strip();
	}

	public void remove_option(string option){
		
		options = options.replace(option,"").strip();
					
		if(options.has_prefix(",")){
			options = options[1:options.length];
		}

		if (options.has_suffix(",")){
			options = options[0:options.length - 1];
		}

		options = options.strip();
	}
}
