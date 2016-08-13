
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

public class ThunarMenuEntry : GLib.Object {
	public string name = "";
	public string icon = "";
	public string id = "";
	public string command = "";
	public string description = "";
	public string patterns = "";
	public bool show_for_directories = false;
	public bool show_for_audio_files = false;
	public bool show_for_video_files = false;
	public bool show_for_image_files = false;
	public bool show_for_text_files = false;
	public bool show_for_other_files = false;

	public static Gee.HashMap<string,ThunarMenuEntry> action_list;
	public static string user_home;
	
	public static void query_actions(string _user_home){
		log_debug("ThunarMenuEntry.query_actions()");
		
		action_list = new Gee.HashMap<string,ThunarMenuEntry>();
		user_home = _user_home;
		
		var xml_path = "%s/.config/Thunar/uca.xml".printf(user_home);

		if (!file_exists(xml_path)){
			return;
		}

		xml_fix_invalid_declaration(xml_path);
		
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
	
		if (root->name != "actions") {
			log_error("Unexpected element '%s' in xml: %s".printf(root->name, xml_path));
			delete doc;
			return;
		}

		for (Xml.Node* action = root->children; action != null; action = action->next) {
			if (action->type != Xml.ElementType.ELEMENT_NODE) {
				continue;
			}
				
			if (action->name != "action") {
				continue;
			}

			var item = new ThunarMenuEntry();
			
			for (Xml.Node* node = action->children; node != null; node = node->next) {
				if (node->type != Xml.ElementType.ELEMENT_NODE) {
					continue;
				}

				switch (node->name){
				case "name":
					item.name = node->get_content();
					break;
				case "icon":
					item.icon = node->get_content();
					break;
				case "unique-id":
					item.id = node->get_content();
					break;
				case "command":
					item.command = node->get_content();
					break;
				case "description":
					item.description = node->get_content();
					break;
				case "patterns":
					item.patterns = node->get_content();
					break;
				case "directories":
					item.show_for_directories = true;
					break;
				case "audio-files":
					item.show_for_audio_files = true;
					break;
				case "video-files":
					item.show_for_video_files = true;
					break;
				case "image-files":
					item.show_for_image_files = true;
					break;
				case "text-files":
					item.show_for_text_files = true;
					break;
				case "other-files":
					item.show_for_other_files = true;
					break;
				}
			}

			action_list[item.id] = item;
		}

		delete doc;
	}

	public static void xml_fix_invalid_declaration(string xml_file){
		if (!file_exists(xml_file)){
			return;
		}
		
		var xml = file_read(xml_file);
		var dec = xml.split("\n")[0];
		if (dec == "<?xml encoding=\"UTF-8\" version=\"1.0\"?>"){
			xml = xml.replace("<?xml encoding=\"UTF-8\" version=\"1.0\"?>",
				"<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
			file_write(xml_file, xml);
		}
	}
	
	public void add(){
		bool found = false;
		foreach(var action in action_list.values){
			if ((action.id == id)||(action.command == command)){
				found = true;
				return;
			}
		}

		if (!found){
			var xml_path = "%s/.config/Thunar/uca.xml".printf(user_home);

			if (!file_exists(xml_path)){
				return;
			}
			
			xml_fix_invalid_declaration(xml_path);
			
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
		
			if (root->name != "actions") {
				log_error("Unexpected element '%s' in xml: %s".printf(root->name, xml_path));
				delete doc;
				return;
			}

			for (Xml.Node* action = root->children; action != null; action = action->next) {
				if (action->type != Xml.ElementType.ELEMENT_NODE) {
					continue;
				}
					
				if (action->name != "action") {
					continue;
				}
			}

			Xml.Node* action = root->new_text_child (null, "action", "");

			action->new_text_child (null, "name", name);
			action->new_text_child (null, "icon", icon);
			action->new_text_child (null, "unique-id", id);
			action->new_text_child (null, "command", command);
			action->new_text_child (null, "description", description);
			action->new_text_child (null, "patterns", patterns);
			
			if (show_for_directories){
				action->new_text_child (null, "directories", "");
			}
			if (show_for_audio_files){
				action->new_text_child (null, "audio-files", "");
			}
			if (show_for_video_files){
				action->new_text_child (null, "video-files", "");
			}
			if (show_for_image_files){
				action->new_text_child (null, "image-files", "");
			}
			if (show_for_text_files){
				action->new_text_child (null, "text-files", "");
			}
			if (show_for_other_files){
				action->new_text_child (null, "other-files", "");
			}

			doc->save_file(xml_path);

			delete doc;
		}
	}

	public void remove(){
		bool found = false;
		foreach(var action in action_list.values){
			if (action.id == id){
				found = true;
				break;
			}
		}

		if (found){
			var xml_path = "%s/.config/Thunar/uca.xml".printf(user_home);

			if (!file_exists(xml_path)){
				return;
			}
			
			xml_fix_invalid_declaration(xml_path);
			
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
		
			if (root->name != "actions") {
				log_error("Unexpected element '%s' in xml: %s".printf(root->name, xml_path));
				delete doc;
				return;
			}

			for (Xml.Node* action = root->children; action != null; action = action->next) {
				if (action->type != Xml.ElementType.ELEMENT_NODE) {
					continue;
				}
					
				if (action->name != "action") {
					continue;
				}

				for (Xml.Node* node = action->children; node != null; node = node->next) {
					if (node->type != Xml.ElementType.ELEMENT_NODE) {
						continue;
					}

					switch (node->name){
					case "unique-id":
						if (node->get_content().strip() == id){
							action->unlink();
						}
						break;
					}
				}
			}

			doc->save_file(xml_path);

			delete doc;
		}
	}
}

