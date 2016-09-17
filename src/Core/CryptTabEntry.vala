using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.Devices;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class CryptTabEntry : GLib.Object{
	public bool is_comment = false;
	public bool is_empty_line = false;

	public string mapped_name = "";
	public string device = "";
	public string keyfile = "";
	public string options = "";
	public string line = "";

	public static Gee.ArrayList<CryptTabEntry> read_file(string file_path){
		var list = new Gee.ArrayList<CryptTabEntry>();

		if (!file_exists(file_path)){ return list; }

		string text = file_read(file_path);
		string[] lines = text.split("\n");
		foreach(string line in lines){
			var entry = new CryptTabEntry();
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
							entry.mapped_name = part.strip();
							break;
						case 1:
							entry.device = part.strip();
							break;
						case 2:
							entry.keyfile = part.strip();
							break;
						case 3:
							entry.options = part.strip();
							break;
					}
				}
			}
		}

		return list;
	}

	public static string create_file(
		CryptTabEntry[] entries, bool keep_comments_and_empty_lines = true){
			
		string text = "";
		foreach(var entry in entries){
			if (entry.is_comment || entry.is_empty_line){
				if (keep_comments_and_empty_lines){
					text += "%s\n".printf(entry.line);
				}
			}
			else {
				text += "%s\t%s\t%s\t%s\n".printf(
					entry.mapped_name, entry.device,
					entry.keyfile, entry.options);
			}
		}
		return text;
	}
}
