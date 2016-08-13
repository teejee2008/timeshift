
using GLib;
using Gtk;
using Gee;
using Json;
using Xml;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class MimeApp : GLib.Object {
	// instance
	public string mime_type = "";
	public string applications = "";
	public string group_type = "";
	public bool is_local = false;
	public bool is_selected = false;

	// static
	public static Gee.HashMap<string,MimeApp> mimeapplist;
	public static string user_home;
	
	public MimeApp(string _mime_type, string apps){
		mime_type = _mime_type;
		applications = apps;
	}

	public static void query_mimeapps(string _user_home){
		mimeapplist = new Gee.HashMap<string,MimeApp>();
		user_home = _user_home;

		// Parse all files in reverse order of priority
		// https://wiki.archlinux.org/index.php/default_applications

		string[] path_list = {
			//shared mime-info mappings cache (built by system when desktop files are installed)
			//"/usr/share/applications/mimeinfo.cache",
			//"/usr/local/share/applications/mimeinfo.cache",
			//distribution-provided defaults
			"/usr/share/applications/mimeapps.list",
			"/usr/local/share/applications/mimeapps.list",
			"/usr/share/gnome/applications/defaults.list",
			//sysadmin and vendor overrides 
			"/etc/xdg/mimeapps.list",
			//user overrides 
			"%s/.local/share/applications/mimeapps.list".printf(user_home), //deprecated
			"%s/.config/mimeapps.list".printf(user_home)
		};
			
		foreach(var file_path in path_list){
			if (file_exists(file_path)){
				bool is_user_file = file_path.has_prefix("%s/".printf(user_home));
				parse_mimeapps_file(file_path, is_user_file);
			}
		}

		// debug, print
		
		var list = new Gee.ArrayList<MimeApp>();
		foreach(var app in mimeapplist.values){
			list.add(app);
		}
		list.sort((a,b)=>{
			return strcmp(a.mime_type, b.mime_type);
		});

		/*
		foreach(var app in list){
			stdout.printf("%-30s: %-50s\n".printf(app.mime_type, app.applications));
			stdout.flush();
		}
		*/
		/*
		foreach(var app in list){
			stdout.printf("%-30s: %-50s\n".printf(app.mime_type, app.applications));
			stdout.flush();
		}
		*/
	}

	private static void parse_mimeapps_file(string file_path, bool is_local){
		if (!file_exists(file_path)){
			log_error(_("File not found") + ": %s".printf(file_path));
			log_error("parse_mimeapps_file()");
			return;
		}

		string type = "";
		foreach(string line in file_read(file_path).split("\n")){
			if (line.down().contains("[added associations]")){
				type = "added";
			}
			else if (line.down().contains("[removed associations]")){
				type = "removed";
			}
			else if (line.down().contains("[default applications]")){
				type = "default";
			}
			else if (line.contains("=")){
				var arr = line.split("=");
				var mime_app = new MimeApp(arr[0].strip(),arr[1].strip());
				mime_app.group_type = type;
				mime_app.is_local = is_local;
				mimeapplist[mime_app.mime_type] = mime_app;
				
				/* Note: Existing mime_app will be replaced.
				 * Since we are parsing mimeapp files in reverse order
				 * of priority, the last mime_app object has priority
				* */
			}
		}
	}

	public static DesktopApp? get_default_app(string mimetype){	
		DesktopApp app = null;

		if (!MimeType.mimetypes.has_key(mimetype)){
			log_debug("MimeType.mimetypes: no_key: %s".printf(mimetype));
			return null;
		}

		var mime = MimeType.mimetypes[mimetype];
		
		if (mimeapplist.has_key(mimetype)){
			var mimeapp = mimeapplist[mimetype];

			var desktop_name = mimeapp.applications.split(";")[0];
			if (DesktopApp.applist.has_key(desktop_name)){
				return DesktopApp.applist[desktop_name];
			}
			else{
				log_debug("DesktopApp.applist: no_key: %s".printf(desktop_name));
			}
		}
		else{
			log_debug("MimeApp.mimeapps_local: no_key: %s".printf(mime.type));
		}
		
		return app;
	}

	public static Gee.ArrayList<DesktopApp> get_supported_apps(string mimetype){
		var list = new Gee.ArrayList<DesktopApp>();
		
		foreach(DesktopApp app in DesktopApp.applist.values){
			if (app.mimetypes.contains(mimetype)){
				list.add(app);
			}
		}

		return list;
	}
	 
	public static void set_default(string mimetype, DesktopApp app){
		string cmd = "xdg-mime default %s %s".printf(app.desktop_file_name, mimetype);
		exec_sync(cmd);
	}

	// remove this
	public static void set_default_old(string mimetype, DesktopApp app){
		var list = new Gee.ArrayList<string>();

		var file_path = "%s/.config/mimeapps.list".printf(user_home);
		if (file_exists(file_path)){
			foreach(string line in file_read(file_path).split("\n")){
				list.add(line);
			}
		}

		//log_debug("%d lines in %s".printf(list.size, file_path));

		bool updated = false;
		int index = -1;
		for(int i=0; i < list.size; i++){
			string line = list[i];
			if (line.contains("[Default Applications]")){
				index = i;
			}
			else if (line.contains("=")){
				var arr = line.split("=");
				arr[0] = arr[0].strip();
				arr[1] = arr[1].strip();
				
				if (arr[0] == mimetype){
					//remove if already existing (we will be adding again in 1st position)
					if (arr[1].contains(app.desktop_file_name)){
						arr[1] = arr[1].replace(app.desktop_file_name + ";", "");
						arr[1] = arr[1].replace(app.desktop_file_name, "");
					}
					
					line = "%s=%s;%s".printf(arr[0], app.desktop_file_name, arr[1]);
					list[i] = line;
					updated = true;
					break;
				}
			}
		}

		if (!updated){
			if (index < 0){
				list.add("[Default Applications]");
				index = list.size - 1;
			}
			
			string line = "%s=%s;".printf(mimetype, app.desktop_file_name);
			list.insert(index + 1, line);
		}

		string txt = "";
		foreach(var line in list){
			txt += line + "\n";
		}

		while (txt.contains("\n\n\n")){
			txt = txt.replace("\n\n\n", "\n\n");
		}

		file_write(file_path, txt);

		log_msg("File assoc added: '%s', '%s'".printf(mimetype, app.name));
	}
}
	
public class MimeType : GLib.Object {
	// instance
	public string type = "";
	public string comment = "";
	public string generic_icon = "";
	public string pattern = "";
	public bool is_selected = false;

	// static
	public static Gee.HashMap<string,MimeType> mimetypes;

	public static void query_mimetypes(){
		log_debug("MimeType.query_mimetypes()");
		
		mimetypes = new Gee.HashMap<string,MimeType>();
		
		FileEnumerator enu, enu2;
		FileInfo info, info2;
		File file = File.parse_name ("/usr/share/mime");

		if (!file.query_exists()) {
			return;
		}
		
		try{
			//recurse subdirs
			enu = file.enumerate_children ("%s".printf(FileAttribute.STANDARD_NAME), 0);
			while ((info = enu.next_file()) != null) {
				string subdir_name = info.get_name();
				string subdir_path = "/usr/share/mime/%s".printf(subdir_name);

				if (!dir_exists(subdir_path)){
					continue;
				}

				File file2 = File.parse_name (subdir_path);
				
				//recurse xml
				enu2 = file2.enumerate_children ("%s".printf(FileAttribute.STANDARD_NAME), 0);
				while ((info2 = enu2.next_file()) != null) {
					string xml_name = info2.get_name();
					string xml_path = "%s/%s".printf(subdir_path, xml_name);

					if (!file_exists(xml_path)){
						continue;
					}
				
					parse_mimetype_xml(xml_path);
				}
			}
		}
		catch (GLib.Error e) {
			log_error (e.message);
		}
	}

	private static void parse_mimetype_xml(string xml_path){
		//log_msg("Parsing: %s".printf(xml_path));
		
		// Parse the document from path
		Xml.Doc* doc = Xml.Parser.parse_file (xml_path);
		if (doc == null) {
			log_error("File not found or permission denied: %s".printf(xml_path));
			return;
		}

		Xml.Node* root = doc->get_root_element ();
		if (root == null) {
			log_error("Root element missing in xml: %s".printf(xml_path));
			delete doc;
			return;
		}

		if (root->name == "mime-info"){
			for (Xml.Node* iter = root->children; iter != null; iter = iter->next) {
				if (iter->type == Xml.ElementType.ELEMENT_NODE) {
					root = iter;
					break;
				}
			}
		}
		
		if (root->name != "mime-type") {
			log_error("Unexpected element '%s' in xml: %s".printf(root->name, xml_path));
			delete doc;
			return;
		}

		MimeType mime = new MimeType();
		
		string? type = root->get_prop ("type");
		if (type != null) {
			mime.type = type;
		}

		for (Xml.Node* iter = root->children; iter != null; iter = iter->next) {
			if (iter->type == Xml.ElementType.ELEMENT_NODE) {
				if ((iter->name == "comment") && (iter->get_prop ("lang") == null)) {
					mime.comment = iter->get_content();
				}
				else if (iter->name == "generic-icon") {
					mime.generic_icon = iter->get_prop ("name");
				}
				else if (iter->name == "glob") {
					mime.pattern += iter->get_prop ("pattern") + ";";
				}
			}
		}

		if ((mime.type != null) && (mime.type.length > 0)){
			mimetypes[mime.type] = mime;
		}

		delete doc;
	}
	
}

public class DesktopApp : GLib.Object {
	public string desktop_file_name = "";
	public string desktop_file_path = "";
	public string name = "";
	public string comment = "";
	public string keywords = "";
	public string only_show_in = "";
	public string exec = "";
	public string icon = "";
	public string startup_notify = "";
	public string terminal = "";
	public string type = "";
	public string categories = "";
	public string mimetypes = "";
	
	public Gee.ArrayList<string> mimetypes_list = new Gee.ArrayList<string>();

	public static Gee.HashMap<string,DesktopApp> applist;
	public static Gee.ArrayList<DesktopApp> text_editors;
	
	public static void query_apps(){
		log_debug("DesktopApp.query_apps()");
		
		applist = new Gee.HashMap<string,DesktopApp>();
		text_editors = new Gee.ArrayList<DesktopApp>();
		
		FileEnumerator enu;
		FileInfo info;
		File file = File.parse_name ("/usr/share/applications");

		if (!file.query_exists()) {
			return;
		}
		
		try{
			//parse items
			enu = file.enumerate_children ("%s".printf(FileAttribute.STANDARD_NAME), 0);
			while ((info = enu.next_file()) != null) {
				string child_name = info.get_name();
				string child_path = "/usr/share/applications/%s".printf(child_name);

				if (!file_exists(child_path)){
					continue;
				}

				if (!child_name.has_suffix(".desktop")){
					continue;
				}

				parse_desktop_file(child_path);
			}
		}
		catch (GLib.Error e) {
			log_error (e.message);
		}

		text_editors.sort((a,b)=>{
			return strcmp(a.name, b.name);
		});

		// debug -- print
		
		var list = new Gee.ArrayList<DesktopApp>();
		foreach(var app in applist.values){
			list.add(app);
		}
		list.sort((a,b)=>{
			return strcmp(a.desktop_file_name, b.desktop_file_name);
		});

		/*
		foreach(var app in list){
			stdout.printf("%-50s: %-30s\n".printf(app.desktop_file_name, app.exec));
			stdout.flush();
		}
		* */
		/*
		foreach(var app in list){
			if (app.mimetypes.contains("text/plain")){
				stdout.printf("%-50s: %-30s\n".printf(app.desktop_file_name, app.mimetypes));
				stdout.flush();
			}
		}
		* */
	}

	public static void parse_desktop_file(string file_path){
		if (!file_exists(file_path)){
			return;
		}
		
		var app = new DesktopApp();
		
		foreach(string line in file_read(file_path).split("\n")){

			if (line.strip().has_prefix("[") && (line.strip().down() != "[desktop entry]")){

				// do not read any sections other than [Desktop Entry]
				break; 
			}

			var arr = line.split("=");
			if (arr.length < 2){
				continue;
			}

			var key = arr[0].strip();
			var val = arr[1].strip();
			
			switch(key.down()){
			case "name":
				app.name = val;
				break;
			case "comment":
				app.comment = val;
				break;
			case "keywords":
				app.keywords = val;
				break;
			case "onlyshowin":
				app.only_show_in = val;
				break;
			case "exec":
				app.exec = val;
				break;
			case "icon":
				app.icon = val;
				break;
			case "startupnotify":
				app.startup_notify = val;
				break;
			case "terminal":
				app.terminal = val;
				break;
			case "type":
				app.type = val;
				break;
			case "categories":
				app.categories = val;
				break;
			case "mimetype":
				app.mimetypes = val;
				
				foreach(string type in val.split(";")){
					app.mimetypes_list.add(type.strip());

					if ((type == "text/plain") && !text_editors.contains(app)){
						text_editors.add(app);
					}
				}
				break;
			}
		}

		if (app.name.length > 0){
			app.desktop_file_name = file_basename(file_path);
			app.desktop_file_path = file_path;
			applist[app.desktop_file_name] = app;
		}
	}

	public void execute(string file_path){

		string uri = "file://" + uri_encode(file_path, false);
		
		string cmd = exec
			.replace("%f","'%s'".printf(escape_single_quote(file_path)))
			.replace("%F","'%s'".printf(escape_single_quote(file_path)))
			.replace("%u","'%s'".printf(escape_single_quote(uri)))
			.replace("%U","'%s'".printf(escape_single_quote(uri)));

		// workarounds
		if (cmd.contains("mpv --profile")){
			cmd = cmd.replace("mpv --profile", "mpv");
		}
		
		if (!cmd.contains(file_path) && !cmd.contains(uri)){
			cmd += " '%s'".printf(file_path);
		}
		
		log_debug(exec);
		log_debug(cmd);
		
		exec_script_async(cmd);
	}

	//https://specifications.freedesktop.org/desktop-entry-spec/desktop-entry-spec-1.0.html#exec-variables
}
