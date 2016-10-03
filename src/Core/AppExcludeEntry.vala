using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class AppExcludeEntry : GLib.Object{
	public string name = "";
	public bool is_include = false;
	public bool is_file = false;
	public bool enabled = false;
	public Gee.ArrayList<string> items;
	public Gee.ArrayList<string> patterns;

	//static
	public static Gee.HashMap<string, AppExcludeEntry> app_map;

	public AppExcludeEntry(string _name, bool _is_include = false){
		name = _name;
		is_include = _is_include;

		items = new Gee.ArrayList<string>();
		patterns = new Gee.ArrayList<string>();
	}

	public string tooltip_text(){
		string txt = "";
		foreach(var item in items){
			txt += "%s\n".printf(item);
		}
		if (txt.has_suffix("\n")){
			txt = txt[0:txt.length - 1];
		}
		return txt;
	}	
	
	// static
	
	public static void clear(){
		if (app_map == null){
			app_map = new Gee.HashMap<string, AppExcludeEntry>();
		}
		else{
			app_map.clear();
		}
	}

	public static void add_app_exclude_entries_from_path(string home){

		clear();
		
		try
		{
			File f_home = File.new_for_path (home);
	        FileEnumerator enumerator = f_home.enumerate_children ("standard::*", 0);
	        FileInfo file;
	        while ((file = enumerator.next_file ()) != null) {
				string name = file.get_name();
				string item = home + "/" + name;
				if (!name.has_prefix(".")){ continue; }
				if (name.has_suffix("~")){ continue; }
				if (name == ".config"){ continue; }
				if (name == ".local"){ continue; }
				if (name == ".gvfs"){ continue; }
				if (name == ".thumbnails"){ continue; }
				if (name == ".cache"){ continue; }
				if (name == ".temp"){ continue; }
				if (name == ".sudo_as_admin_successful"){ continue; }
				if (name.has_suffix(".lock")){ continue; }
				if (name.has_suffix(".log")){ continue; }
				if (name.has_suffix(".old")){ continue; }
				if (name.has_suffix("~")){ continue; }
				
				var relpath = "~/%s".printf(name);
				add_item(relpath, !dir_exists(item), false);
	        }

	        File f_home_config = File.new_for_path (home + "/.config");
	        enumerator = f_home_config.enumerate_children ("standard::*", 0);
	        while ((file = enumerator.next_file ()) != null) {
				string name = file.get_name();
				string item = home + "/.config/" + name;
				if (name.has_suffix(".lock")){ continue; }
				if (name.has_suffix(".log")){ continue; }
				if (name.has_suffix(".old")){ continue; }
				if (name.has_suffix("~")){ continue; }
				
				var relpath = "~/.config/%s".printf(name);
				add_item(relpath, !dir_exists(item), false);
	        }

	        File f_home_local = File.new_for_path (home + "/.local/share");
	        enumerator = f_home_local.enumerate_children ("standard::*", 0);
	        while ((file = enumerator.next_file ()) != null) {
				string name = file.get_name();
				string item = home + "/.local/share/" + name;
				if (name.has_suffix(".lock")){ continue; }
				if (name.has_suffix(".log")){ continue; }
				if (name.has_suffix(".old")){ continue; }
				if (name.has_suffix("~")){ continue; }
				if (name == "applications"){ continue; }
				if (name == "Trash"){ continue; }
				
				var relpath = "~/.local/share/%s".printf(name);
				add_item(relpath, !dir_exists(item), false);
	        }
        }
        catch(Error e){
	        log_error (e.message);
	    }
	}

	public static void add_item(string item_path, bool is_file, bool is_include){

		if (app_map == null){
			app_map = new Gee.HashMap<string, AppExcludeEntry>();
		}

		var name = file_basename(item_path);
		
		if (name.has_suffix(".ini")){
			name = name[0:name.length - ".ini".length];
		}
		else if (name.has_suffix(".sh")){
			name = name[0:name.length - ".sh".length];
		}
		else if (name.has_suffix(".json")){
			name = name[0:name.length - ".json".length];
		}
		else if (name.has_suffix(".conf")){
			name = name[0:name.length - ".conf".length];
		}
		else if (name.has_suffix(".list")){
			name = name[0:name.length - ".list".length];
		}
		else if (name.has_suffix(".xbel")){
			name = name[0:name.length - ".xbel".length];
		}
		else if (name.has_suffix(".xbel.tbcache")){
			name = name[0:name.length - ".xbel.tbcache".length];
		}
		else if (name.has_suffix(".bz2")){
			name = name[0:name.length - ".bz2".length];
		}
		else if (name.has_suffix(".old")){
			name = name[0:name.length - ".old".length];
		}
		else if (name.has_suffix(".dirs")){
			name = name[0:name.length - ".dirs".length];
		}
		else if (name.has_suffix(".locale")){
			name = name[0:name.length - ".locale".length];
		}
		else if (name.has_suffix(".dockitem")){
			name = name[0:name.length - ".dockitem".length];
		}
		else if (name.has_suffix(".xml")){
			name = name[0:name.length - ".xml".length];
		}
		else if (name.has_suffix(".log")){
			name = name[0:name.length - ".log".length];
		}
		else if (name.has_suffix(".txt")){
			name = name[0:name.length - ".txt".length];
		}

		if (name.has_prefix(".")){
			name = name[1:name.length];
		}

		name = name.strip();

		if (name.length == 0){
			return;
		}

		AppExcludeEntry entry = null;
		if (app_map.has_key(name)){
			entry = app_map[name];
		}
		else if (app_map.has_key(name.down())){
			entry = app_map[name.down()];
		}
		else{
			entry = new AppExcludeEntry(name, is_include);
			app_map[name] = entry;
		}
		
		entry.items.add(item_path);
		
		foreach(bool root_user in new bool[] { true, false } ){
			string str = (is_include) ? "+ " : "";
			str += (root_user) ? "/root" : "/home/*";
			str += item_path[1:item_path.length];
			//str += (is_file) ? "" : "/**";
			entry.patterns.add(str);
		}
	}

	public static Gee.ArrayList<AppExcludeEntry> get_apps_list(
		Gee.ArrayList<string> selected_app_names){

		foreach(var selected_name in selected_app_names){
			if (app_map.has_key(selected_name)){
				app_map[selected_name].enabled = true;
			}
			else{
				app_map[selected_name].enabled = false;
			}
		}
			
		var list = new Gee.ArrayList<AppExcludeEntry>();
		foreach(var key in app_map.keys){
			list.add(app_map[key]);
		}

		//sort the list
		GLib.CompareDataFunc<AppExcludeEntry> entry_compare = (a, b) => {
			return strcmp(a.name.down(),b.name.down());
		};
		
		list.sort((owned) entry_compare);

		log_debug("apps: %d".printf(list.size));
		
		return list;
	}
}
