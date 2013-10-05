using GLib;
using Gtk;
using Gee;
using Soup;
using Json;
using Utility;

public Main App;
public const string AppName = "TimeShift";
public const string AppVersion = "1.0";
public const string AppAuthor = "Tony George";
public const string AppAuthorEmail = "teejee2008@gmail.com";
public const bool LogTimestamp = true;
public bool UseConsoleColors = false;

const string GETTEXT_PACKAGE = "";
const string LOCALE_DIR = "/usr/share/locale";

public class Main : GLib.Object
{
	public Main(string arg0)
	{
		this.app_path = (File.new_for_path (arg0)).get_parent ().get_path ();
		this.root_device = get_partition_info("/");
		this.home_device = get_partition_info("/home");
		
		string local_path = app_path + "/share";
		if (dir_exists(local_path)){
			share_folder = local_path;
		}
		
		this.rsnapshot_conf_path = this.share_folder + "/rsnapshot.conf";
		
		load_app_config();
	}
	
}
