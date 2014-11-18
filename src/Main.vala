/*
 * Main.vala
 * 
 * Copyright 2012 Tony George <teejee2008@gmail.com>
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 * 
 * 
 */

using GLib;
using Gtk;
using Gee;
using Json;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.Devices;
using TeeJee.JSON;
using TeeJee.ProcessManagement;
using TeeJee.GtkHelper;
using TeeJee.Multimedia;
using TeeJee.System;
using TeeJee.Misc;

public Main App;
public const string AppName = "Timeshift RSYNC";
public const string AppShortName = "timeshift";
public const string AppVersion = "1.6.2";
public const string AppAuthor = "Tony George";
public const string AppAuthorEmail = "teejee2008@gmail.com";

const string GETTEXT_PACKAGE = "";
const string LOCALE_DIR = "/usr/share/locale";

extern void exit(int exit_code);

public class Main : GLib.Object{
	public string app_path = "";
	public string share_folder = "";
	public string rsnapshot_conf_path = "";
	public string app_conf_path = "";

	public Gee.ArrayList<TimeShiftBackup?> snapshot_list;
	public Gee.HashMap<string,Device> partition_map;

	public Gee.ArrayList<string> exclude_list_user;
	public Gee.ArrayList<string> exclude_list_default;
	public Gee.ArrayList<string> exclude_list_default_extra;
	public Gee.ArrayList<string> exclude_list_home;
	public Gee.ArrayList<string> exclude_list_restore;
	public Gee.ArrayList<AppExcludeEntry> exclude_list_apps;
	public Gee.ArrayList<MountEntry> mount_list;
	
	//temp
	private Gee.ArrayList<Device> grub_device_list;
	
	public Device root_device;
	public Device home_device;
	public Device snapshot_device;
	
	public string mount_point_backup = "";
	public string mount_point_restore = "";
	public string mount_point_app = "/mnt/timeshift";
	
	public DistInfo current_distro;
	public bool mirror_system = false;
	
	public bool _is_scheduled = false;
	public bool schedule_monthly = false;
	public bool schedule_weekly = false;
	public bool schedule_daily = true;
	public bool schedule_hourly = false;
	public bool schedule_boot = true;
	public int count_monthly = 2;
	public int count_weekly = 3;
	public int count_daily = 5;
	public int count_hourly = 6;
	public int count_boot = 5;

	public string app_mode = "";
	
	//global vars for controlling threads
	public bool thr_success = false;
	public bool thr_running = false;
	public int thr_retval = -1;
	public string thr_arg1 = "";
	
	public int startup_delay_interval_mins = 10;
	public int retain_snapshots_max_days = 200;
	public int minimum_free_disk_space_mb = 2048;
	public long first_snapshot_size = 0;
	
	public string log_dir = "";
	public string log_file = "";
	public string lock_dir = "";
	public string lock_file = "";
	
	public TimeShiftBackup snapshot_to_delete;
	public TimeShiftBackup snapshot_to_restore;
	public Device restore_target;
	public bool reinstall_grub2 = false;
	public string grub_device = "";
	
	public bool cmd_skip_grub = false;
	public string cmd_grub_device = "";
	public string cmd_target_device = "";
	public string cmd_backup_device = "";
	public string cmd_snapshot = "";
	public bool cmd_confirm = false;
	public bool cmd_verbose = true;
	
	public string progress_text = "";
	public int snapshot_list_start_index = 0;

	//initialization

	public static int main (string[] args) {

		set_locale();

		//show help and exit
		if (args.length > 1) {
			switch (args[1].down()) {
				case "--help":
				case "-h":
					stdout.printf (Main.help_message ());
					return 0;
			}
		}
		
		//init TMP
		LOG_ENABLE = false;
		init_tmp();
		LOG_ENABLE = true;
		
		/*
		 * Note:
		 * init_tmp() will fail if timeshift is run as normal user
		 * logging will be disabled temporarily so that the error is not displayed to user
		 */
		
		/*
		var map = Device.get_mounted_filesystems_using_mtab();
		foreach(Device pi in map.values){
			LOG_TIMESTAMP = false;
			log_msg(pi.description_full());
		}
		exit(0);
		*/

		App = new Main(args);

		bool success = App.start_application(args);
		App.exit_app();
		
		return (success) ? 0 : 1;
	}
	
	private static void set_locale(){
		Intl.setlocale(GLib.LocaleCategory.MESSAGES, "timeshift");
		Intl.textdomain(GETTEXT_PACKAGE);
		Intl.bind_textdomain_codeset(GETTEXT_PACKAGE, "utf-8");
		Intl.bindtextdomain(GETTEXT_PACKAGE, LOCALE_DIR);
	}
	
	public Main(string[] args){
		string msg = "";

		//parse arguments (initial) ------------
		
		parse_arguments(args);

		//check for admin access before logging is initialized
		//since writing to log directory requires admin access
		
		if (!user_is_admin()){
			msg = _("TimeShift needs admin access to backup and restore system files.") + "\n";
			msg += _("Please run the application as admin (using 'sudo' or 'su')");
			
			LOG_TIMESTAMP = false;
			log_error(msg);
			
			if (app_mode == ""){
				string title = _("Admin Access Required");
				gtk_messagebox(title, msg, null, true);
			}

			exit(0);
		}

		//init log ------------------
		
		try {
			DateTime now = new DateTime.now_local();
			log_dir = "/var/log/timeshift";
			log_file = log_dir + "/" + now.format("%Y-%m-%d_%H-%M-%S") + ".log";
			
			var file = File.new_for_path (log_dir);
			if (!file.query_exists ()) {
				file.make_directory_with_parents();
			}

			file = File.new_for_path (log_file);
			if (file.query_exists ()) {
				file.delete ();
			}
        
			dos_log = new DataOutputStream (file.create(FileCreateFlags.REPLACE_DESTINATION));
			if ((app_mode == "")||(LOG_DEBUG)){
				log_msg(_("Session log file") + ": %s".printf(log_file));
			}
		} 
		catch (Error e) {
			log_error (e.message);
		}

		//log dist info -----------------------
		
		DistInfo info = DistInfo.get_dist_info("/");
		if ((app_mode == "")||(LOG_DEBUG)){
			log_msg(_("Distribution") + ": " + info.full_name(),true);
		}
		
		//check dependencies ---------------------
		
		string message;
		if (!check_dependencies(out message)){
			if (app_mode == ""){
				string title = _("Missing Dependencies");
				gtk_messagebox(title, message, null, true);
			}
			exit(0);
		}

		//check and create lock ------------------
		
		lock_dir = "/var/run/lock/timeshift";
		lock_file = lock_dir + "/lock";
		if (!create_lock()){
			if (app_mode == ""){
				string txt = read_file(lock_file);
				//string pid = txt.split(";")[0].strip();
				string mode = txt.split(";")[1].strip();
				
				if (mode == "backup"){
					msg = _("A scheduled job is currently taking a system snapshot.") + "\n";
					msg += _("Please wait for a few minutes and try again.");
				}
				else{
					msg = _("Another instance of timeshift is currently running!") + "\n";
					msg += _("Please check if you have multiple windows open.") + "\n";
				}
				
				string title = _("Error");
				gtk_messagebox(title, msg, null, true);
			}
			else{
				//already logged - do nothing
			}
			exit(0);
		}

		//initialize variables ------------------
		
		this.app_path = (File.new_for_path (args[0])).get_parent().get_path ();
		this.share_folder = "/usr/share";
		this.app_conf_path = "/etc/timeshift.json";
		//root_device and home_device will be initalized by update_partition_list()
		
		//check if running locally -------------
		
		string local_exec = args[0];
		string local_conf = app_path + "/timeshift.json";
		string local_share = app_path + "/share";

		var f_local_exec = File.new_for_path(local_exec);
		if (f_local_exec.query_exists()){
			
			var f_local_conf = File.new_for_path(local_conf);
			if (f_local_conf.query_exists()){
				this.app_conf_path = local_conf;
			}
			
			var f_local_share = File.new_for_path(local_share);
			if (f_local_share.query_exists()){
				this.share_folder = local_share;
			}
		}
		else{
			//timeshift is running from system directory - update app_path
			this.app_path = get_cmd_path("timeshift");
		}

		//initialize lists -------------------------
		
		snapshot_list = new Gee.ArrayList<TimeShiftBackup>();
		exclude_list_user = new Gee.ArrayList<string>();
		exclude_list_default = new Gee.ArrayList<string>();
		exclude_list_default_extra = new Gee.ArrayList<string>();
		exclude_list_home = new Gee.ArrayList<string>();
		exclude_list_restore = new Gee.ArrayList<string>();
		exclude_list_apps = new Gee.ArrayList<AppExcludeEntry>();
		partition_map = new Gee.HashMap<string,Device>();
		mount_list = new Gee.ArrayList<MountEntry>();

		add_default_exclude_entries();
		//add_app_exclude_entries();
		
		//check current linux distribution -----------------
		
		this.current_distro = DistInfo.get_dist_info("/");

		//initialize app --------------------
		
		update_partition_list();
		detect_system_devices();

		//finish initialization --------------
		
		load_app_config();
		update_snapshot_list();		
	}

	public bool start_application(string[] args){
		bool is_success = true;

		switch(app_mode){
			case "backup":
				is_success = take_snapshot();
				return is_success;

			case "restore":
				is_success = restore_snapshot();
				return is_success;

			case "delete":
				is_success = delete_snapshot();
				return is_success;

			case "delete-all":
				is_success = delete_all_snapshots();
				return is_success;
				
			case "ondemand":
				is_success = take_snapshot(true);
				return is_success;
				
			case "list-snapshots":
				LOG_ENABLE = true;
				LOG_TIMESTAMP = false;
				if (snapshot_list.size > 0){
					log_msg(_("Snapshots") + ":");
					list_snapshots(false);
					return true;
				}
				else{
					log_msg(("No snapshots found on device '%s'").printf(snapshot_device.device));
					return false;
				}

			case "list-devices":
				LOG_ENABLE = true;
				LOG_TIMESTAMP = false;
				log_msg(_("Devices with Linux file systems") + ":");
				list_devices();
				return true;
				
			default:
				//Initialize main window
				var window = new MainWindow ();
				window.destroy.connect(Gtk.main_quit);
				window.show_all();
				
				//start event loop
				Gtk.main();

				return true;
		}
	}

	public bool check_dependencies(out string msg){
		msg = "";
		
		string[] dependencies = { "rsync","/sbin/blkid","df","mount","umount","fuser","crontab","cp","rm","touch","ln","sync"}; //"shutdown","chroot", 

		string path;
		foreach(string cmd_tool in dependencies){
			path = get_cmd_path (cmd_tool);
			if ((path == null) || (path.length == 0)){
				msg += " * " + cmd_tool + "\n";
			}
		}
		
		if (msg.length > 0){
			msg = _("Commands listed below are not available on this system") + ":\n\n" + msg + "\n";
			msg += _("Please install required packages and try running TimeShift again");
			log_error(msg);
			return false;
		}
		else{
			return true;
		}
	}
	
	public bool check_btrfs_root_layout(){	
		//check if root device is a BTRFS volume
		if ((root_device != null) && (root_device.type == "btrfs")){
			//check subvolume layout
			if (check_btrfs_volume(root_device) == false){
				string msg = _("The system partition has an unsupported subvolume layout.") + " ";
				msg += _("Only ubuntu-type layouts with @ and @home subvolumes are currently supported.") + "\n\n";
				msg += _("Application will exit.") + "\n\n";
				string title = _("Not Supported");
				
				if (app_mode == ""){
					gtk_messagebox(title, msg, null, true);
				}
				else{
					log_error(msg);
				}
				return false;
			}
		}
		
		return true;
	}
	
	public void add_default_exclude_entries(){
		
		exclude_list_default.clear();
		exclude_list_home.clear();
		
		//default exclude entries -------------------

		exclude_list_default.add("/dev/*");
		exclude_list_default.add("/proc/*");
		exclude_list_default.add("/sys/*");
		exclude_list_default.add("/media/*");
		exclude_list_default.add("/mnt/*");
		exclude_list_default.add("/tmp/*");
		exclude_list_default.add("/run/*");
		exclude_list_default.add("/var/run/*");
		exclude_list_default.add("/var/lock/*");
		exclude_list_default.add("/lost+found");
		exclude_list_default.add("/timeshift/*");
		exclude_list_default.add("/data/*");
		exclude_list_default.add("/cdrom/*");
		
		exclude_list_default.add("/root/.thumbnails");
		exclude_list_default.add("/root/.cache");
		exclude_list_default.add("/root/.gvfs");
		exclude_list_default.add("/root/.local/share/Trash");
		
		exclude_list_default.add("/home/*/.thumbnails");
		exclude_list_default.add("/home/*/.cache");
		exclude_list_default.add("/home/*/.gvfs");
		exclude_list_default.add("/home/*/.local/share/Trash");
		
		//default extra ------------------

		exclude_list_default_extra.add("/root/.mozilla/firefox/*.default/Cache");
		exclude_list_default_extra.add("/root/.mozilla/firefox/*.default/OfflineCache");
		exclude_list_default_extra.add("/root/.opera/cache");
		exclude_list_default_extra.add("/root/.kde/share/apps/kio_http/cache");
		exclude_list_default_extra.add("/root/.kde/share/cache/http");
		
		exclude_list_default_extra.add("/home/*/.mozilla/firefox/*.default/Cache");
		exclude_list_default_extra.add("/home/*/.mozilla/firefox/*.default/OfflineCache");
		exclude_list_default_extra.add("/home/*/.opera/cache");
		exclude_list_default_extra.add("/home/*/.kde/share/apps/kio_http/cache");
		exclude_list_default_extra.add("/home/*/.kde/share/cache/http");
		
		//default home ----------------
		
		exclude_list_home.add("+ /root/.**");
		exclude_list_home.add("/root/**");
		
		exclude_list_home.add("+ /home/*/.**");
		exclude_list_home.add("/home/*/**");
		
		/*
		Most web browsers store their cache under ~/.cache and /tmp
		These files will be excluded by the entries for ~/.cache and /tmp
		There is no need to add special entries.
		
		~/.cache/google-chrome			-- Google Chrome
		~/.cache/chromium				-- Chromium
		~/.cache/epiphany-browser		-- Epiphany
		~/.cache/midori/web				-- Midori
		/var/tmp/kdecache-$USER/http	-- Rekonq
		*/
		
	}
	
	public void add_app_exclude_entries(){
		exclude_list_apps.clear();
		
		string home;
		string user_name;
		
		string cmd = "echo ${SUDO_USER:-$(whoami)}";
		string std_out;
		string std_err;
		int ret_val;
		ret_val = execute_command_script_sync(cmd, out std_out, out std_err);

		if ((std_out == null) || (std_out.length == 0)){
			user_name = "root";
			home = "/root";
		}
		else{
			user_name = std_out.strip();
			home = "/home/%s".printf(user_name);
		}
		
		if ((root_device == null) || ((restore_target.device != root_device.device) && (restore_target.uuid != root_device.uuid))){
			home = mount_point_restore + home;
		}
		
		try
		{
			File f_home = File.new_for_path (home);
	        FileEnumerator enumerator = f_home.enumerate_children ("standard::*", 0);
	        FileInfo file;
	        while ((file = enumerator.next_file ()) != null) {
				string name = file.get_name();
				string item = home + "/" + name;
				if (!name.has_prefix(".")){ continue; }
				if (name == ".config"){ continue; }
				if (name == ".local"){ continue; }
				if (name == ".gvfs"){ continue; }
				if (name.has_suffix(".lock")){ continue; }
				
				if (dir_exists(item)) {
					AppExcludeEntry entry = new AppExcludeEntry("~/" + name, false);
					exclude_list_apps.add(entry);
				}
				else{
					AppExcludeEntry entry = new AppExcludeEntry("~/" + name, true);
					exclude_list_apps.add(entry);
				}
	        }
	        
	        File f_home_config = File.new_for_path (home + "/.config");
	        enumerator = f_home_config.enumerate_children ("standard::*", 0);
	        while ((file = enumerator.next_file ()) != null) {
				string name = file.get_name();
				string item = home + "/.config/" + name;
				if (name.has_suffix(".lock")){ continue; }
				
				if (dir_exists(item)) {
					AppExcludeEntry entry = new AppExcludeEntry("~/.config/" + name, false);
					exclude_list_apps.add(entry);
				}
				else{
					AppExcludeEntry entry = new AppExcludeEntry("~/.config/" + name, true);
					exclude_list_apps.add(entry);
				}
	        }
	        
	        File f_home_local = File.new_for_path (home + "/.local/share");
	        enumerator = f_home_local.enumerate_children ("standard::*", 0);
	        while ((file = enumerator.next_file ()) != null) {
				string name = file.get_name();
				string item = home + "/.local/share/" + name;
				if (name.has_suffix(".lock")){ continue; }
				
				if (dir_exists(item)) {
					AppExcludeEntry entry = new AppExcludeEntry("~/.local/share/" + name, false);
					exclude_list_apps.add(entry);
				}
				else{
					AppExcludeEntry entry = new AppExcludeEntry("~/.local/share/" + name, true);
					exclude_list_apps.add(entry);
				}
	        }
        }
        catch(Error e){
	        log_error (e.message);
	    }

		//sort the list
		CompareFunc<AppExcludeEntry> entry_compare = (a, b) => {
			return strcmp(a.relpath,b.relpath);
		};
		exclude_list_apps.sort(entry_compare);
	}
	
	public bool create_lock(){
		try{
			
			string current_pid = ((long)Posix.getpid()).to_string();

			var file = File.new_for_path (lock_dir);
			if (!file.query_exists()) {
				file.make_directory_with_parents();
			}
			
			file = File.new_for_path (lock_file);
			if (file.query_exists()) {
				
				string txt = read_file(lock_file);
				string process_id = txt.split(";")[0].strip();
				//string mode = txt.split(";")[1].strip();
				long pid = long.parse(process_id);
				
				if (process_is_running(pid)){
					log_msg(_("Another instance of timeshift is currently running") + " (PID=%ld)".printf(pid));
					return false;
				}
				else{
					if ((app_mode == "")||(LOG_DEBUG)){
						log_msg(_("Warning: Deleted invalid lock"));
					}
					file.delete();
					write_file(lock_file, current_pid);
					return true;
				}
			}
			else{
				write_file(lock_file, current_pid + ";" + app_mode);
				return true;
			}
		}
		catch (Error e) { 
			log_error (e.message); 
			return false;
		}
	}
	
	public void remove_lock(){
		try{
			var file = File.new_for_path (lock_file);
			if (file.query_exists()) {
				file.delete();
			}
		}
		catch (Error e) { 
			log_error (e.message); 
		}
	}
	
	//console functions
	
	public static string help_message (){
		string msg = "\n" + AppName + " v" + AppVersion + " by Tony George (teejee2008@gmail.com)" + "\n";
		msg += "\n";
		msg += "Syntax:\n";//+" timeshift [--list | --backup[-now] | --restore]\n";
		msg += "\n";
		msg += "  timeshift --list-{snapshots|devices} [OPTIONS]\n";
		msg += "  timeshift --backup[-now] [OPTIONS]\n";
		msg += "  timeshift --restore [OPTIONS]\n";
		msg += "\n";
		msg += _("Options") + ":\n";
		msg += "\n";
		msg += _("List") + ":\n";
		msg += "  --list[-snapshots]         " + _("List snapshots") + "\n";
		msg += "  --list-devices             " + _("List devices") + "\n";
		msg += "\n";
		msg += _("Backup") + ":\n";
		msg += "  --backup                   " + _("Take scheduled backup") + "\n";
		msg += "  --backup-now               " + _("Take on-demand backup") + "\n";
		msg += "\n";
		msg += _("Restore") + ":\n";
		msg += "  --restore                  " + _("Restore snapshot") + "\n";
		msg += "  --clone                    " + _("Clone current system") + "\n";
		msg += "  --snapshot <name>          " + _("Specify snapshot to restore") + "\n";
		msg += "  --target[-device] <device> " + _("Specify target device") + "\n";
		msg += "  --grub[-device] <device>   " + _("Specify device for installing GRUB2 bootloader") + "\n";
		msg += "  --skip-grub                " + _("Skip GRUB2 reinstall") + "\n";
		msg += "\n";
		msg += _("Delete") + ":\n";
		msg += "  --delete                   " + _("Delete snapshot") + "\n";
		msg += "  --delete-all               " + _("Delete all snapshots") + "\n";
		msg += "\n";
		msg += _("Global") + ":\n";
		msg += "  --backup-device <device>   " + _("Specify backup device") + "\n";
		msg += "  --yes                      " + _("Answer YES to all confirmation prompts") + "\n";
		msg += "  --debug                    " + _("Show additional debug messages") + "\n";
		msg += "  --verbose                  " + _("Show rsync output (default)") + "\n";
		msg += "  --quiet                    " + _("Hide rsync output") + "\n";
		msg += "  --help                     " + _("Show all options") + "\n";
		msg += "\n";
		
		msg += _("Examples") + ":\n";
		msg += "\n";
		msg += "timeshift --list\n";
		msg += "timeshift --list --backup-device /dev/sda1\n";
		msg += "timeshift --backup-now \n";
		msg += "timeshift --restore \n";
		msg += "timeshift --restore --snapshot '2014-10-12_16-29-08' --target /dev/sda1 --skip-grub\n";
		msg += "timeshift --delete  --snapshot '2014-10-12_16-29-08'\n";
		msg += "timeshift --delete-all \n";
		msg += "\n";
		
		msg += _("Notes") + ":\n";
		msg += "\n";
		msg += "  1) --backup will take a snapshot only if a scheduled snapshot is due\n";
		msg += "  2) --backup-now will take an immediate (forced) snapshot\n";
		msg += "  3) --backup will not take snapshots till first snapshot is taken with --backup-now\n";
		msg += "  4) Use --restore without other options to select options interactively\n";
		msg += "  5) UUID can be specified instead of device name\n";
		msg += "\n";
		return msg;
	}

	private void parse_arguments(string[] args){
		for (int k = 1; k < args.length; k++) // Oth arg is app path 
		{
			switch (args[k].down()){
				case "--backup":
					app_mode = "backup";
					break;
					
				case "--delete":
					app_mode = "delete";
					break;

				case "--delete-all":
					app_mode = "delete-all";
					break;
					
				case "--restore":
					mirror_system = false;
					app_mode = "restore";
					break;
					
				case "--clone":
					mirror_system = true;
					app_mode = "restore";
					break;

				case "--backup-now":
					app_mode = "ondemand";
					break;

				case "--skip-grub":
					cmd_skip_grub = true;
					break;
				
				case "--verbose":
					cmd_verbose = true;
					break;

				case "--quiet":
					cmd_verbose = false;
					break;
					
				case "--yes":
					cmd_confirm = true;
					break;

				case "--grub":
				case "--grub-device":
					reinstall_grub2 = true;
					cmd_grub_device = args[++k];
					break;
				
				case "--target":
				case "--target-device":
					cmd_target_device = args[++k];
					break;

				case "--backup-device":
					cmd_backup_device = args[++k];
					break;
					
				case "--snapshot":
				case "--snapshot-name":
					cmd_snapshot = args[++k];
					break;
					
				case "--debug":
					LOG_COMMANDS = true;
					LOG_DEBUG = true;
					break;
				
				case "--list":
				case "--list-snapshots":
					app_mode = "list-snapshots";
					//LOG_ENABLE = false;
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					break;

				case "--list-devices":
					app_mode = "list-devices";
					//LOG_ENABLE = false;
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					break;
					
				default:
					LOG_TIMESTAMP = false;
					log_msg(_("Invalid command line arguments") + "\n");
					Main.help_message();
					exit(1);
					break;
			}
		}
		
		if (app_mode == ""){
			//Initialize GTK
			Gtk.init(ref args);
		}
		
	}

	public void list_snapshots(bool paginate){
		LOG_TIMESTAMP = false;
		int index = -1;
		foreach (TimeShiftBackup bak in snapshot_list){
			index++;
			if (!paginate || ((index >= snapshot_list_start_index) && (index < snapshot_list_start_index + 10))){
				log_msg("%4d > %s%s%s".printf(index, bak.name, " ~ " + bak.taglist_short, (bak.description.length > 0) ? " ~ " + bak.description : ""));
			}
		}
	}
	
	public void list_devices(){
		LOG_TIMESTAMP = false;
		int index = -1;
		foreach(Device pi in partition_list) {
			if (!pi.has_linux_filesystem()) { continue; }
			//log_msg("%4d > %-15s   %s %10s   %s".printf(++index, pi.device, pi.uuid, (pi.size_mb > 0) ? "%0.0f GB".printf(pi.size_mb / 1024.0) : "", pi.label));
			string symlink = "";
			foreach(string sym in pi.symlinks){
				if (sym.has_prefix("/dev/mapper/")){
					symlink = sym;
				}
			}
			log_msg("%4d > %s%s  %s  %s  %s  %s".printf(++index, pi.device, (symlink.length > 0) ? " → " + symlink : "" , pi.uuid, (pi.size_mb > 0) ? "%0.0fGB".printf(pi.size_mb / 1024.0) : "", pi.type, pi.label));
		}
	}
	
	public void list_grub_devices(bool print_to_console = true){
		//add devices
		grub_device_list = new Gee.ArrayList<Device>();
		foreach(Device di in get_block_devices()) {
			grub_device_list.add(di);
		}
		
		//add partitions
		var list = partition_list;
		foreach(Device pi in list) {
			if (!pi.has_linux_filesystem()) { continue; }
			grub_device_list.add(pi);
		}
		
		//sort
		grub_device_list.sort((a,b) => { 
			Device p1 = (Device) a;
			Device p2 = (Device) b;
			
			return strcmp(p1.device,p2.device);
		});
		
		if (print_to_console){
			int index = -1;
			foreach(Device entry in grub_device_list) {
				log_msg("%4d > %-15s ~ %s".printf(++index, entry.device, entry.description().split("~")[1].strip()));
			}
		}
	}
	
	public Device read_stdin_device(Gee.ArrayList<Device> device_list){
		string? line = stdin.read_line();
		line = (line != null) ? line.strip() : line;
		
		Device selected_device = null;
		
		if (line.down() == "a"){
			log_msg("Aborted.");
			exit_app();
			exit(0);
		}
		else if ((line == null)||(line.length == 0)){
			log_error("Invalid input");
		}
		else if (line.contains("/")){
			bool found = false;
			foreach(Device pi in device_list) {
				if (!pi.has_linux_filesystem()) { continue; }
				if (pi.device == line){
					selected_device = pi;
					found = true;
					break;
				}
				else {
					foreach(string symlink in pi.symlinks){
						if (symlink == line){
							selected_device = pi;
							found = true;
							break;
						}
					}
					if (found){ break; }
				}
			}
			if (!found){
				log_error("Invalid input");
			}
		}
		else{
			int64 index;
			bool found = false;
			if (int64.try_parse(line, out index)){
				int i = -1;
				foreach(Device pi in device_list) {
					if ((pi.devtype == "partition") && !pi.has_linux_filesystem()) { continue; }
					if (++i == index){
						selected_device = pi;
						found = true;
						break;
					}
				}
			}
			if (!found){
				log_error("Invalid input");
			}
		}
		
		return selected_device;
	}

	public TimeShiftBackup read_stdin_snapshot(){
		string? line = stdin.read_line();
		line = (line != null) ? line.strip() : line;
		
		TimeShiftBackup selected_snapshot = null;
	
		if (line.down() == "a"){
			log_msg("Aborted.");
			exit_app();
			exit(0);
		}
		else if (line.down() == "p"){
			snapshot_list_start_index -= 10;
			if (snapshot_list_start_index < 0){
				snapshot_list_start_index = 0;
			}
			log_msg("");
			list_snapshots(true);
			log_msg("");
		}
		else if (line.down() == "n"){
			if ((snapshot_list_start_index + 10) < snapshot_list.size){
				snapshot_list_start_index += 10;
			}
			log_msg("");
			list_snapshots(true);
			log_msg("");
		}
		else if (line.contains("_")||line.contains("-")){
			//TODO
			log_error("Invalid input");
		}
		else if ((line == null)||(line.length == 0)){
			log_error("Invalid input");
		}
		else{
			int64 index;
			if (int64.try_parse(line, out index)){
				if (index < snapshot_list.size){
					selected_snapshot = snapshot_list[(int) index];
				}
				else{
					log_error("Invalid input");
				}
			}
			else{
				log_error("Invalid input");
			}
		}
		
		return selected_snapshot;
	}
	
	public bool read_stdin_grub_install(){
		string? line = stdin.read_line();
		line = (line != null) ? line.strip() : line;
		
		if (line.down() == "a"){
			log_msg("Aborted.");
			exit_app();
			exit(0);
			return true;
		}
		else if ((line == null)||(line.length == 0)){
			log_error("Invalid input");
			return false;
		}
		else if (line.down() == "y"){
			cmd_skip_grub = false;
			reinstall_grub2 = true;
			return true;
		}
		else if (line.down() == "n"){
			cmd_skip_grub = true;
			reinstall_grub2 = false;
			return true;
		}
		else if ((line == null)||(line.length == 0)){
			log_error("Invalid input");
			return false;
		}
		else{
			log_error("Invalid input");
			return false;
		}
	}

	public bool read_stdin_restore_confirm(){
		string? line = stdin.read_line();
		line = (line != null) ? line.strip() : line;
		
		if ((line.down() == "a")||(line.down() == "n")){
			log_msg("Aborted.");
			exit_app();
			exit(0);
			return true;
		}
		else if ((line == null)||(line.length == 0)){
			log_error("Invalid input");
			return false;
		}
		else if (line.down() == "y"){
			cmd_confirm = true;
			return true;
		}
		else if ((line == null)||(line.length == 0)){
			log_error("Invalid input");
			return false;
		}
		else{
			log_error("Invalid input");
			return false;
		}
	}
	
	//properties
	
	public string snapshot_dir {
		owned get{
			if (mount_point_backup == "/"){
				return "/timeshift/snapshots";
			}
			else if (mount_point_backup.length > 0){
				return "%s/timeshift/snapshots".printf(mount_point_backup);
			}
			else{
				return "";
			}
		}
	}
	
	public bool is_scheduled{
		get{
			return _is_scheduled;
		}
		set{
			_is_scheduled = value;
		}
	}
	
	public bool live_system(){
		return (root_device == null);
	}
	
	//backup
	
	public bool take_snapshot (bool is_ondemand = false, string snapshot_comments = ""){
		if (check_btrfs_root_layout() == false){
			return false;
		}
		
		bool status;
		bool update_symlinks = false;

		try
		{
			//create a timestamp
			DateTime now = new DateTime.now_local();

			//mount_backup_device
			if (!mount_backup_device()){
				return false;
			}
			
			//check backup device
			string msg;
			int status_code = check_backup_device(out msg);
			
			if (!is_ondemand){
				//check if first snapshot was taken
				if (status_code == 2){
					log_error(msg);
					log_error(_("Please take the first snapshot by running 'sudo timeshift --backup-now'"));
					return false;
				}
			}
			
			//check space
			if ((status_code == 1) || (status_code == 2)){
				is_scheduled = false;
				log_error(msg);
				log_error(_("Scheduled snapshots will be disabled till another device is selected."));
				return false;
			}

			//create snapshot root if missing
			var f = File.new_for_path(snapshot_dir);
			if (!f.query_exists()){
				f.make_directory_with_parents();
			}

			//ondemand
			if (is_ondemand){
				bool ok = backup_and_rotate ("ondemand",now);
				if(!ok){
					return false;
				}
				else{
					update_symlinks = true;
				}
			}
			else if (is_scheduled){
				TimeShiftBackup last_snapshot_boot = get_latest_snapshot("boot");
				TimeShiftBackup last_snapshot_hourly = get_latest_snapshot("hourly");
				TimeShiftBackup last_snapshot_daily = get_latest_snapshot("daily");
				TimeShiftBackup last_snapshot_weekly = get_latest_snapshot("weekly");
				TimeShiftBackup last_snapshot_monthly = get_latest_snapshot("monthly");
				
				DateTime dt_sys_boot = now.add_seconds((-1) * get_system_uptime_seconds());
				bool take_new = false;

				if (schedule_boot){
					
					log_msg(_("Boot snapshots are enabled"));

					if (last_snapshot_boot == null){
						log_msg(_("Last boot snapshot not found"));
						take_new = true;
					}
					else if (last_snapshot_boot.date.compare(dt_sys_boot) < 0){
						log_msg(_("Last boot snapshot is older than system start time"));
						take_new = true;
					}
					else{
						int hours = (int) ((float) now.difference(last_snapshot_boot.date) / TimeSpan.HOUR);
						log_msg(_("Last boot snapshot is %d hours old").printf(hours));
						take_new = false;
					}
					
					if (take_new){
						status = backup_and_rotate ("boot",now);
						if(!status){
							log_error(_("Boot snapshot failed!"));
							return false;
						}
						else{
							update_symlinks = true;
						}
					}
				}
				
				if (schedule_hourly){
					
					log_msg(_("Hourly snapshots are enabled"));

					if (last_snapshot_hourly == null){
						log_msg(_("Last hourly snapshot not found"));
						take_new = true;
					}
					else if (last_snapshot_hourly.date.compare(now.add_hours(-1).add_minutes(1)) < 0){
						log_msg(_("Last hourly snapshot is more than 1 hour old"));
						take_new = true;
					}
					else{
						int mins = (int) ((float) now.difference(last_snapshot_hourly.date) / TimeSpan.MINUTE);
						log_msg(_("Last hourly snapshot is %d minutes old").printf(mins));
						take_new = false;
					}
					
					if (take_new){
						status = backup_and_rotate ("hourly",now);
						if(!status){
							log_error(_("Hourly snapshot failed!"));
							return false;
						}
						else{
							update_symlinks = true;
						}
					}
				}
				
				if (schedule_daily){
					
					log_msg(_("Daily snapshots are enabled"));

					if (last_snapshot_daily == null){
						log_msg(_("Last daily snapshot not found"));
						take_new = true;
					}
					else if (last_snapshot_daily.date.compare(now.add_days(-1).add_minutes(1)) < 0){
						log_msg(_("Last daily snapshot is more than 1 day old"));
						take_new = true;
					}
					else{
						int hours = (int) ((float) now.difference(last_snapshot_daily.date) / TimeSpan.HOUR);
						log_msg(_("Last daily snapshot is %d hours old").printf(hours));
						take_new = false;
					}
					
					if (take_new){
						status = backup_and_rotate ("daily",now);
						if(!status){
							log_error(_("Daily snapshot failed!"));
							return false;
						}
						else{
							update_symlinks = true;
						}
					}
				}
				
				if (schedule_weekly){
					
					log_msg(_("Weekly snapshots are enabled"));

					if (last_snapshot_weekly == null){
						log_msg(_("Last weekly snapshot not found"));
						take_new = true;
					}
					else if (last_snapshot_weekly.date.compare(now.add_weeks(-1).add_minutes(1)) < 0){
						log_msg(_("Last weekly snapshot is more than 1 week old"));
						take_new = true;
					}
					else{
						int days = (int) ((float) now.difference(last_snapshot_weekly.date) / TimeSpan.DAY);
						log_msg(_("Last weekly snapshot is %d days old").printf(days));
						take_new = false;
					}
					
					if (take_new){
						status = backup_and_rotate ("weekly",now);
						if(!status){
							log_error(_("Weekly snapshot failed!"));
							return false;
						}
						else{
							update_symlinks = true;
						}
					}
				}
				
				if (schedule_monthly){
					
					log_msg(_("Monthly snapshot are enabled"));

					if (last_snapshot_monthly == null){
						log_msg(_("Last monthly snapshot not found"));
						take_new = true;
					}
					else if (last_snapshot_monthly.date.compare(now.add_months(-1).add_minutes(1)) < 0){
						log_msg(_("Last monthly snapshot is more than 1 month old"));
						take_new = true;
					}
					else{
						int days = (int) ((float) now.difference(last_snapshot_monthly.date) / TimeSpan.DAY);
						log_msg(_("Last monthly snapshot is %d days old").printf(days));
						take_new = false;
					}
					
					if (take_new){
						status = backup_and_rotate ("monthly",now);
						if(!status){
							log_error(_("Monthly snapshot failed!"));
							return false;
						}
						else{
							update_symlinks = true;
						}
					}
				}
			}
			else{
				log_msg(_("Scheduled snapshots are disabled"));
				log_msg(_("Nothing to do!"));
				cron_job_update();
			}

			auto_delete_backups();
			
			if (update_symlinks){
				update_snapshot_list();
				create_symlinks();
			}
		}
		catch(Error e){
			log_error (e.message);
			return false;
		}

		return true;
	}
	
	public bool backup_and_rotate(string tag, DateTime dt_created){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val = -1;
		string msg;
		File f;

		string time_stamp = dt_created.format("%Y-%m-%d_%H-%M-%S");
		DateTime now = new DateTime.now_local();
		bool backup_taken = false;
		
		string sync_name = ".sync"; 
		string sync_path = snapshot_dir + "/" + sync_name; 
		
		try{

			//delete the existing .sync snapshot if invalid --------
			
			f = File.new_for_path(sync_path);
			if(f.query_exists()){
				
				f = File.new_for_path(sync_path + "/info.json");
				if(!f.query_exists()){

					progress_text = _("Cleaning up...");
					log_msg(progress_text);
					
					if (!delete_directory(sync_path)){
						return false;
					}
				}
			}

			DateTime dt_sys_boot = now.add_seconds((-1) * get_system_uptime_seconds());
			
			//check if we can rotate an existing backup -------------
			
			TimeShiftBackup last_snapshot = get_latest_snapshot();
			DateTime dt_filter = null;
			
			if ((tag != "ondemand") && (last_snapshot != null)){
				switch(tag){
					case "boot":
						dt_filter = dt_sys_boot;
						break;
					case "hourly":
					case "daily":
					case "weekly":
					case "monthly":
						dt_filter = now.add_hours(-1);
						break;
					default:
						log_error(_("Unknown snapshot type") + ": %s".printf(tag));
						return false;
				}
				
				TimeShiftBackup backup_to_rotate = null;
				foreach(TimeShiftBackup bak in snapshot_list){
					if (bak.date.compare(dt_filter) > 0){
						backup_to_rotate = bak;
						break;
					}
				}

				if (backup_to_rotate != null){
					backup_to_rotate.add_tag(tag);
					backup_taken = true;
					msg = _("Snapshot") + " '%s' ".printf(backup_to_rotate.name) + _("tagged") + " '%s'".printf(tag);
					log_msg(msg);
				}
			}

			if (!backup_taken){

				//take new backup ---------------------------------
				
				DateTime dt_begin = new DateTime.now_local();
				//log_msg("Taking system snapshot...");

				string list_file = sync_path + "/exclude.list";

				f = File.new_for_path(sync_path);
				if (!f.query_exists()){
					
					//create .sync directory --------
					
					f = File.new_for_path(sync_path + "/localhost");
					f.make_directory_with_parents();

					TimeShiftBackup bak_restore = null;
					
					//check if a control file was written after restore -------
					
					string ctl_path = snapshot_dir + "/.sync-restore";
					
					f = File.new_for_path(ctl_path);
					if(f.query_exists()){
						string snapshot_path = read_file(ctl_path);
						
						foreach(TimeShiftBackup bak in snapshot_list){
							if (bak.path == snapshot_path){
								bak_restore = bak;
								break;
							}
						}
						
						f.delete();
					}
					
					if (bak_restore == null){
						//select latest snapshot for hard-linking
						for(int k = snapshot_list.size -1; k >= 0; k--){
							TimeShiftBackup bak = snapshot_list[k];
							bak_restore = bak; //TODO: check dist type
							break;
						}
					}
					
					//hard-link selected snapshot
					if (bak_restore != null){
						progress_text = _("Hard-linking files from previous snapshot...");
						log_msg(progress_text);
					
						cmd = "cp -alp \"%s\" \"%s\"".printf(bak_restore.path + "/localhost/.", sync_path + "/localhost/");
							
						if (LOG_COMMANDS) { log_debug(cmd); }

						Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
						if (ret_val != 0){
							log_error(_("Failed to hard-link last snapshot"));
							log_error (std_err);
							return false;
						}
					}
				}
				
				//delete existing control file --------------
				
				f = File.new_for_path(sync_path + "/info.json");
				if (f.query_exists()){
					f.delete();
				}
				
				//save exclude list ------------
					
				save_exclude_list(sync_path);
					
				//update modification date of .sync directory ---------
				
				cmd = "touch \"%s\"".printf(sync_path);
				Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
				
				if (LOG_COMMANDS) { log_debug(cmd); }

				if (ret_val != 0){
					log_error(std_err);
					log_error(_("Failed to update modification date"));
					return false;
				}
				
				//rsync file system with .sync ------------------
				
				progress_text = _("Synching files...");
				log_msg(progress_text);
				
				var log_path = sync_path + "/rsync-log";
				f = File.new_for_path(log_path);
				if (f.query_exists()){
					f.delete();
				}
			
				cmd = "rsync -ai %s --delete --numeric-ids --stats --relative --delete-excluded".printf(cmd_verbose ? "--verbose" : "--quiet");
				cmd += " --log-file=\"%s\"".printf(log_path);
				cmd += " --exclude-from=\"%s\"".printf(list_file);
				cmd += " /. \"%s\"".printf(sync_path + "/localhost/");

				ret_val = run_rsync(cmd);

				if (ret_val != 0){
					log_error(_("rsync returned an error") + ": %d".printf(ret_val));
					log_error(_("Failed to create new snapshot"));
					return false;
				}

				//write control file ----------
				
				write_snapshot_control_file(sync_path, dt_created, tag);

				//rotate .sync to required level ----------
				
				progress_text = _("Saving new snapshot...");
				log_msg(progress_text);
						
				string new_name = time_stamp; 
				string new_path = snapshot_dir + "/" + new_name; 

				cmd = "cp -alp \"%s\" \"%s\"".printf(sync_path, new_path);
				
				if (LOG_COMMANDS) { log_debug(cmd); }

				Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
				if (ret_val != 0){
					log_error(_("Failed to save snapshot") + ":'%s'".printf(new_name));
					log_error (std_err);
					return false;
				}

				DateTime dt_end = new DateTime.now_local();
				TimeSpan elapsed = dt_end.difference(dt_begin);
				long seconds = (long)(elapsed * 1.0 / TimeSpan.SECOND);
				msg = _("Snapshot saved successfully") + " (%lds)".printf(seconds);
				log_msg(msg);
				notify_send("TimeShift",msg,10000,"low");
				
				log_msg(_("Snapshot") + " '%s' ".printf(new_name) + _("tagged") + " '%s'".printf(tag));
				
				update_snapshot_list();
			}
		}
		catch(Error e){
			log_error (e.message);
			return false;
		}

		return true;
	}

	public int run_rsync(string cmd){
		thr_arg1 = cmd;
		
		try {
			thr_running = true;
			Thread.create<void> (run_rsync_thread, true);

			while (thr_running){
				gtk_do_events ();
				Thread.usleep((ulong) GLib.TimeSpan.MILLISECOND * 100);
			}
		} catch (Error e) {
			log_error (e.message);
			thr_retval = -1;
		}

		return thr_retval;
	}

	public void run_rsync_thread(){
		if (LOG_COMMANDS) { log_debug(thr_arg1); }
		
		int ret_val = -1;

		try{
			if (cmd_verbose){ log_empty_line(); }
			Process.spawn_command_line_sync(thr_arg1, null, null, out ret_val);
			if (cmd_verbose){ log_empty_line(); }
		}
		catch(Error e){
			log_error (e.message);
			thr_success = false;
			thr_running = false;
			thr_retval = -1;
			return;
		}

		thr_retval = ret_val;
		thr_success = (ret_val == 0);
		thr_running = false;
	}

	public void auto_delete_backups(){
		DateTime now = new DateTime.now_local();
		int count = 0;
		bool show_msg = false;
		DateTime dt_limit;
		
		//delete older backups - boot ---------------

		var list = get_snapshot_list("boot");
		
		if (list.size > count_boot){
			log_msg(_("Maximum backups exceeded for backup level") + " '%s'".printf("boot"));
			while (list.size > count_boot){
				list[0].remove_tag("boot");
				log_msg(_("Snapshot") + " '%s' ".printf(list[0].name) + _("un-tagged") + " '%s'".printf("boot"));
				list = get_snapshot_list("boot");
			}
		}
		
		//delete older backups - hourly, daily, weekly, monthly ---------
		
		string[] levels = { "hourly","daily","weekly","monthly" };
		
		foreach(string level in levels){
			list = get_snapshot_list(level);
			
			if (list.size == 0) { continue; }
			
			switch (level){
				case "hourly":
					dt_limit = now.add_hours(-1 * count_hourly);
					break;
				case "daily":
					dt_limit = now.add_days(-1 * count_daily);
					break;
				case "weekly":
					dt_limit = now.add_weeks(-1 * count_weekly);
					break;
				case "monthly":
					dt_limit = now.add_months(-1 * count_monthly);
					break;
				default:
					dt_limit = now.add_years(-1 * 10);
					break;
			}

			if (list[0].date.compare(dt_limit) < 0){
				
				log_msg(_("Maximum backups exceeded for backup level") + " '%s'".printf(level));
				
				while (list[0].date.compare(dt_limit) < 0){
					list[0].remove_tag(level);
					log_msg(_("Snapshot") + " '%s' ".printf(list[0].name) + _("un-tagged") + " '%s'".printf(level));
					list = get_snapshot_list(level);
				}
			}
		}

		//delete older backups - max days -------
		
		show_msg = true;
		count = 0;
		foreach(TimeShiftBackup bak in snapshot_list){
			if (bak.date.compare(now.add_days(-1 * retain_snapshots_max_days)) < 0){
				if (!bak.has_tag("ondemand")){
					
					if (show_msg){
						log_msg(_("Removing backups older than") + " %d ".printf(retain_snapshots_max_days) + _("days..."));
						show_msg = false;
					}
					
					log_msg(_("Snapshot") + " '%s' ".printf(bak.name) + _("un-tagged"));
					bak.tags.clear();
					count++;
				}
			}
		}

		delete_untagged_snapshots();

		//delete older backups - minimum space -------
		
		update_partition_list();

		show_msg = true;
		count = 0;
		while ((snapshot_device.size_mb - snapshot_device.used_mb) < minimum_free_disk_space_mb){
			list = get_snapshot_list();
			if (list.size > 0){
				if (!list[0].has_tag("ondemand")){
					
					if (show_msg){
						log_msg(_("Free space is less than") + " %d GB".printf(minimum_free_disk_space_mb));
						log_msg(_("Removing older backups to free disk space"));
						show_msg = false;
					}

					delete_snapshot(list[0]);
				}
			}
			update_partition_list(); //TODO: update snapshot_device only
		}
	}
	
	public void delete_untagged_snapshots(){
		bool show_msg = true;

		foreach(TimeShiftBackup bak in snapshot_list){
			if (bak.tags.size == 0){
				
				if (show_msg){
					log_msg(_("Removing un-tagged snapshots..."));
					show_msg = false;
				}
					
				delete_snapshot(bak);
			}
		}
	}
	
	public void create_symlinks(){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;
		
		try{
			cleanup_symlink_dir("boot");
			cleanup_symlink_dir("hourly");
			cleanup_symlink_dir("daily");
			cleanup_symlink_dir("weekly");
			cleanup_symlink_dir("monthly");
			cleanup_symlink_dir("ondemand");
			
			string path;
			
			foreach(TimeShiftBackup bak in snapshot_list){
				foreach(string tag in bak.tags){
					path = mount_point_backup + "/timeshift/snapshots-%s".printf(tag);
					cmd = "ln --symbolic \"../snapshots/%s\" -t \"%s\"".printf(bak.name, path);	
					
					if (LOG_COMMANDS) { log_debug(cmd); }
					
					Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
					if (ret_val != 0){
						log_error (std_err);
						log_error(_("Failed to create symlinks") + ": snapshots-%s".printf(tag));
						return;
					}
				}
			}
			
			log_msg (_("Symlinks updated"));
		} 
		catch (Error e) {
	        log_error (e.message);
	    }
	}
	
	public void cleanup_symlink_dir(string tag){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;
		
		try{
			string path = mount_point_backup + "/timeshift/snapshots-%s".printf(tag);
			var f = File.new_for_path(path);
			if (f.query_exists()){
				cmd = "rm -rf \"%s\"".printf(path + "/");	
				
				if (LOG_COMMANDS) { log_debug(cmd); }
				
				Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
				if (ret_val != 0){
					log_error (std_err);
					log_error(_("Failed to delete symlinks") + ": 'snapshots-%s'".printf(tag));
					return;
				}
			}
			
			f.make_directory_with_parents();
		} 
		catch (Error e) {
	        log_error (e.message);
	    }
	}

	public void save_exclude_list(string snapshot_path){
		
		try{
			
			Gee.ArrayList<string> combined_list = new Gee.ArrayList<string>();
			
			//add default entries
			foreach(string path in exclude_list_default){
				if (!combined_list.contains(path)){
					combined_list.add(path);
				}
			}
			
			//add default extra entries
			foreach(string path in exclude_list_default_extra){
				if (!combined_list.contains(path)){
					combined_list.add(path);
				}
			}
			
			//add user entries from current settings
			foreach(string path in exclude_list_user){
				if (!combined_list.contains(path)){
					combined_list.add(path);
				}
			}
			
			//add home entries
			foreach(string path in exclude_list_home){
				if (!combined_list.contains(path)){
					combined_list.add(path);
				}
			}
			
			string timeshift_path = "/timeshift/*";
			if (!combined_list.contains(timeshift_path)){
				combined_list.add(timeshift_path);
			}
			
			//write file -----------
			
			string list_file = snapshot_path + "/exclude.list";
			string file_text = "";
			
			var f = File.new_for_path(list_file);
			if (f.query_exists()){
				f.delete();
			}
			
			foreach(string path in combined_list){
				file_text += path + "\n";
			}
			
			write_file(list_file,file_text);
		} 
		catch (Error e) {
	        log_error (e.message);
	    }
	}

	public void write_snapshot_control_file(string snapshot_path, DateTime dt_created, string tag){
		var ctl_path = snapshot_path + "/info.json";
		var config = new Json.Object();

		config.set_string_member("created", dt_created.to_utc().to_unix().to_string());
		config.set_string_member("sys-uuid", root_device.uuid);
		config.set_string_member("sys-distro", current_distro.full_name());
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
	    		
	}
	
	//restore

	public bool restore_snapshot(){
		
		bool found = false;
		LOG_TIMESTAMP = false;
		
		//set snapshot device -----------------------------------------------
		
		if (!mirror_system){
			if (snapshot_device != null){
				//print snapshot_device name
				log_msg(TERM_COLOR_YELLOW + string.nfill(78, '*') + TERM_COLOR_RESET);
				log_msg(_("Backup Device") + ": %s".printf(snapshot_device.device), true);
				log_msg(TERM_COLOR_YELLOW + string.nfill(78, '*') + TERM_COLOR_RESET);
				mount_backup_device();
				update_snapshot_list();
			}
			else{
				//print error
				log_error(_("Backup device not specified!"));
				return false;
			}
		}
		
		//set snapshot -----------------------------------------------
		
		if (!mirror_system){
			
			if (app_mode != ""){ //command-line mode
				
				if (cmd_snapshot.length > 0){ 
					
					//check command line arguments
					found = false;
					foreach(TimeShiftBackup bak in snapshot_list) {
						if (bak.name == cmd_snapshot){
							snapshot_to_restore = bak;
							found = true;
							break;
						}
					}
					
					//check if found
					if (!found){
						log_error(_("Could not find snapshot") + ": '%s'".printf(cmd_snapshot));
						return false;
					}
				}
				
				//prompt user for snapshot
				if (snapshot_to_restore == null){
					
					if (snapshot_list.size == 0){
						log_error(_("No snapshots found on device") + ": '%s'".printf(snapshot_device.device));
						return false;
					}
					
					log_msg("");
					log_msg(TERM_COLOR_YELLOW + _("Select snapshot to restore") + ":\n" + TERM_COLOR_RESET);
					list_snapshots(true);
					log_msg("");

					while (snapshot_to_restore == null){
						stdout.printf(TERM_COLOR_YELLOW + _("Enter snapshot number (a=Abort, p=Previous, n=Next)") + ": " + TERM_COLOR_RESET);
						stdout.flush();
						snapshot_to_restore = read_stdin_snapshot();
					}
					log_msg("");
				}
			}
			
			if (snapshot_to_restore != null){
				//print snapshot name
				log_msg(TERM_COLOR_YELLOW + string.nfill(78, '*') + TERM_COLOR_RESET);
				log_msg(_("Snapshot") + ": %s ~ %s".printf(snapshot_to_restore.name, snapshot_to_restore.description), true);
				log_msg(TERM_COLOR_YELLOW + string.nfill(78, '*') + TERM_COLOR_RESET);
			}
			else{
				//print error
				log_error(_("Snapshot to restore not specified!"));
				return false;
			}
		}
		
		//set target device -----------------------------------------------
		
		if (app_mode != ""){ //command line mode

			if (cmd_target_device.length > 0){ 
				
				//check command line arguments
				found = false;
				foreach(Device pi in partition_list) {
					if (!pi.has_linux_filesystem()) { continue; }
					if ((pi.device == cmd_target_device)||((pi.uuid == cmd_target_device))){
						restore_target = pi;
						found = true;
						break;
					}
					else {
						foreach(string symlink in pi.symlinks){
							if (symlink == cmd_target_device){
								restore_target = pi;
								found = true;
								break;
							}
						}
						if (found){ break; }
					}
				}
				
				//check if found
				if (!found){
					log_error(_("Could not find device") + ": '%s'".printf(cmd_target_device));
					exit_app();
					exit(1);
					return false;
				}
			}
			
			//prompt user for target device
			if (restore_target == null){
				log_msg("");
				log_msg(TERM_COLOR_YELLOW + _("Select target device") + ":\n" + TERM_COLOR_RESET);
				list_devices();
				log_msg("");

				while (restore_target == null){
					stdout.printf(TERM_COLOR_YELLOW + _("Enter device name or number (a=Abort)") + ": " + TERM_COLOR_RESET);
					stdout.flush();
					restore_target = read_stdin_device(partition_list);
				}
				log_msg("");
			}
		}
		
		if (restore_target != null){
			string symlink = "";
			foreach(string sym in restore_target.symlinks){
				if (sym.has_prefix("/dev/mapper/")){
					symlink = sym;
				}
			}
			
			//print target device name
			log_msg(TERM_COLOR_YELLOW + string.nfill(78, '*') + TERM_COLOR_RESET);
			log_msg(_("Target Device") + ": %s".printf(restore_target.device + ((symlink.length > 0) ? " → " + symlink : "")), true);
			log_msg(TERM_COLOR_YELLOW + string.nfill(78, '*') + TERM_COLOR_RESET);

			if (app_mode != ""){ //commandline mode
				//init mount list
				mount_list.clear();
				mount_list.add(new MountEntry(restore_target,"/"));

				//mount target device
				bool status = mount_target_device(null);
				if (status == false){
					return false;
				}
			}
			else{
				//mounting is already done
			}
		}
		else{
			//print error
			log_error(_("Target device not specified!"));
			return false;
		}
		
		//set grub device -----------------------------------------------

		if (app_mode != ""){ //command line mode
			
			if (cmd_grub_device.length > 0){ 
				
				//check command line arguments
				found = false;
				list_grub_devices(false);
				foreach(Device dev in grub_device_list) {
					if ((dev.device == cmd_grub_device)
						||((dev.uuid.length > 0) && (dev.uuid == cmd_grub_device))){
						grub_device = dev.device;
						found = true;
						break;
					}
					else {
						if (dev.devtype == "partition"){
							foreach(string symlink in dev.symlinks){
								if (symlink == cmd_grub_device){
									grub_device = dev.device;
									found = true;
									break;
								}
							}
							if (found){ break; }
						}
					}
				}
				
				//check if found
				if (!found){
					log_error(_("Could not find device") + ": '%s'".printf(cmd_grub_device));
					exit_app();
					exit(1);
					return false;
				}
			}
			
			if ((cmd_skip_grub == false) && (reinstall_grub2 == false)){
				log_msg("");

				while ((cmd_skip_grub == false) && (reinstall_grub2 == false)){
					stdout.printf(TERM_COLOR_YELLOW + _("Re-install GRUB2 bootloader? (y/n)") + ": " + TERM_COLOR_RESET);
					stdout.flush();
					read_stdin_grub_install();
				}
			}	
			
			if ((reinstall_grub2) && (grub_device.length == 0)){
				log_msg("");
				log_msg(TERM_COLOR_YELLOW + _("Select GRUB device") + ":\n" + TERM_COLOR_RESET);
				list_grub_devices();
				log_msg("");

				while (grub_device.length == 0){
					stdout.printf(TERM_COLOR_YELLOW + _("Enter device name or number (a=Abort)") + ": " + TERM_COLOR_RESET);
					stdout.flush();
					Device dev = read_stdin_device(grub_device_list);
					if (dev != null) { grub_device = dev.device; }
				}
				log_msg("");
			}
			
			if ((reinstall_grub2) && (grub_device.length > 0)){
				log_msg(TERM_COLOR_YELLOW + string.nfill(78, '*') + TERM_COLOR_RESET);
				log_msg(_("GRUB Device") + ": %s".printf(grub_device), true);
				log_msg(TERM_COLOR_YELLOW + string.nfill(78, '*') + TERM_COLOR_RESET);
			}
			else{
				log_msg(TERM_COLOR_YELLOW + string.nfill(78, '*') + TERM_COLOR_RESET);
				log_msg(_("GRUB will NOT be reinstalled"), true);
				log_msg(TERM_COLOR_YELLOW + string.nfill(78, '*') + TERM_COLOR_RESET);
			}
		}

		if ((app_mode != "")&&(cmd_confirm == false)){
			string msg = disclaimer_pre_restore();
			msg += "\n";
			msg = msg.replace("<b>",TERM_COLOR_RED).replace("</b>",TERM_COLOR_RESET);
			log_msg(msg);
					
			while (cmd_confirm == false){
				stdout.printf(TERM_COLOR_YELLOW + _("Continue with restore? (y/n): ") + TERM_COLOR_RESET);
				stdout.flush();
				read_stdin_restore_confirm();
			}
		}

		LOG_TIMESTAMP = true;
		
		try {
			thr_running = true;
			thr_success = false;
			Thread.create<void> (restore_snapshot_thread, true);
		} 
		catch (ThreadError e) {
			thr_running = false;
			thr_success = false;
			log_error (e.message);
		}
		
		while (thr_running){
			gtk_do_events ();
			Thread.usleep((ulong) GLib.TimeSpan.MILLISECOND * 100);
		}
		
		snapshot_to_restore = null;
		
		return thr_success;
	}
	
	public string unlock_encrypted_device(Device dev, Gtk.Window? parent_win){
		string mapped_name = "%s_unlocked".printf(dev.name);
		string[] name_list = { "%s_unlocked".printf(dev.name), "%s_crypt".printf(dev.name), "luks-%s".printf(dev.uuid)};
		
		if ((parent_win == null)&&(app_mode != "")){
			
			//check if unlocked
			foreach(string name in name_list){
				if (device_exists("/dev/mapper/%s".printf(name))){
					//already unlocked
					log_msg(_("Unlocked device is mapped to '%s'").printf(name));
					log_msg("");
					return name;
				}
			}
			
			//prompt user to unlock
			string cmd = "cryptsetup luksOpen '%s' '%s'".printf(dev.device, mapped_name);
			int retval = Posix.system(cmd);
			log_msg("");

			switch (retval){
				case 512: //invalid passphrase
					log_msg(_("Wrong Passphrase") + ": " + _("Failed to unlock device"));
					return ""; //return
				case 1280: //already unlocked
					log_msg(_("Unlocked device is mapped to '%s'").printf(mapped_name));
					break;
				case 0: //success
					log_msg(_("Unlocked device is mapped to '%s'").printf(mapped_name));
					break;
				default: //unknown error
					log_msg(_("Failed to unlock device"));
					return ""; //return
			}

			update_partition_list();
			return mapped_name;
		}
		else{
			//check if unlocked
			foreach(string name in name_list){
				if (device_exists("/dev/mapper/%s".printf(name))){
					//already unlocked
					gtk_messagebox(_("Encrypted Device"),_("Unlocked device is mapped to '%s'.").printf(name), parent_win);
					return name;
				}
			}
			
			//prompt user to unlock
			string passphrase = gtk_inputbox("Encrypted Device","Enter passphrase to unlock", parent_win, true);
			string cmd = "echo '%s' | cryptsetup luksOpen '%s' '%s'".printf(passphrase, dev.device, mapped_name);
			int retval = execute_script_sync(cmd, false);
			log_debug("cryptsetup:" + retval.to_string());
			
			switch(retval){
				case 512: //invalid passphrase
					gtk_messagebox(_("Wrong Passphrase"),_("Wrong Passphrase") + ": " + _("Failed to unlock device"), parent_win);
					return ""; //return
				case 1280: //already unlocked
					gtk_messagebox(_("Encrypted Device"),_("Unlocked device is mapped to '%s'.").printf(mapped_name), parent_win);
					break;
				case 0: //success
					gtk_messagebox(_("Unlocked Successfully"),_("Unlocked device is mapped to '%s'.").printf(mapped_name), parent_win);
					break;
				default: //unknown error
					gtk_messagebox(_("Error"),_("Failed to unlock device"), parent_win, true);
					return ""; //return
			}

			update_partition_list();
			return mapped_name;
		}
	}
	
	public Device? unlock_and_find_device(Device enc_dev, Gtk.Window? parent_win){
		if (enc_dev.type == "luks"){
			string mapped_name = unlock_encrypted_device(enc_dev, parent_win);
			string mapped_device = "/dev/mapper/%s".printf(mapped_name);
			if (mapped_name.length == 0) { return null; }
			enc_dev = null;
			
			//find unlocked device
			if (mapped_name.length > 0){
				foreach(Device dev in partition_list){
					foreach(string sym in dev.symlinks){
						if (sym == mapped_device){
							return dev;
						}
					}
				}
			}
	
			return null;
		}
		else{
			return enc_dev;
		}
	}
	
	public string disclaimer_pre_restore(){
		string msg = "";
		msg += "<b>" + _("WARNING") + ":</b>\n\n";
		msg += _("Files will be overwritten on the target device!") + "\n";
		msg += _("If restore fails and you are unable to boot the system, \nthen boot from the Ubuntu Live CD, install Timeshift, and try again.") + "\n";
		
		if ((root_device != null) && (restore_target.device == root_device.device)){
			msg += "\n<b>" + _("Please save your work and close all applications.") + "\n";
			msg += _("System will reboot to complete the restore process.") + "</b>\n";
		}
		
		msg += "\n";
		msg += "<b>" + _("DISCLAIMER") + ":</b>\n\n";
		msg += _("This software comes without absolutely NO warranty and the author takes\nno responsibility for any damage arising from the use of this program.");
		msg += "\n" + _("If these terms are not acceptable to you, please do not proceed\nbeyond this point!");
		return msg;
	}
	
	public void restore_snapshot_thread(){
		string sh = "";
		int ret_val = -1;
		string temp_script;

		try{
			
			string source_path = "";
			
			if (snapshot_to_restore != null){
				source_path = snapshot_to_restore.path;
			}
			else{
				source_path = "/tmp/timeshift";
				if (!dir_exists(source_path)){
					create_dir(source_path);
				}
			}
			
			//set target path ----------------
			
			bool restore_current_system;
			string target_path;
			
			if ((root_device != null) && ((restore_target.device == root_device.device) || (restore_target.uuid == root_device.uuid))){
				restore_current_system = true;
				target_path = "/";
			}
			else{
				restore_current_system = false;
				target_path = mount_point_restore + "/";
				
				if (mount_point_restore.strip().length == 0){
					log_error(_("Target device is not mounted"));
					thr_success = false;
					thr_running = false;
					return;
				}
			}

			//save exclude list for restore --------------
			
			save_exclude_list_for_restore(source_path);
			
			//create script -------------
			
			sh = "";
			sh += "echo ''\n";
			if (restore_current_system){
				sh += "echo '" + _("Please do not interrupt the restore process!") + "'\n";
				sh += "echo '" + _("System will reboot after files are restored") + "'\n";
			}
			sh += "echo ''\n";
			sh += "sleep 3s\n";
			
			//log file
			var log_path = source_path + "/rsync-log-restore";
			var f = File.new_for_path(log_path);
			if (f.query_exists()){
				f.delete();
			}
			
			//run rsync ----------
			
			sh += "rsync -avir --force --delete-after";
			sh += " --log-file=\"%s\"".printf(log_path);
			sh += " --exclude-from=\"%s\"".printf(source_path + "/exclude-restore.list");
			
			if (mirror_system){
				sh += " \"%s\" \"%s\" \n".printf("/", target_path);
			}
			else{
				sh += " \"%s\" \"%s\" \n".printf(source_path + "/localhost/", target_path);
			}

			//sync file system
			sh += "sync \n";
			
			//chroot and re-install grub2 --------
			
			if (reinstall_grub2 && (grub_device != null) && (grub_device.length > 0)){
				sh += "echo '' \n";
				sh += "echo '" + _("Re-installing GRUB2 bootloader...") + "' \n";
				sh += "for i in /dev /proc /run /sys; do mount --bind \"$i\" \"%s$i\"; done \n".printf(target_path);
				//sh += "chroot \"%s\" os-prober \n".printf(target_path);
				sh += "chroot \"%s\" grub-install --recheck %s \n".printf(target_path, grub_device);
				//sh += "chroot \"%s\" grub-mkconfig -o /boot/grub/grub.cfg \n".printf(target_path);
				sh += "chroot \"%s\" update-grub \n".printf(target_path);
				sh += "echo '' \n";
				sh += "echo '" + _("Synching file systems...") + "' \n";
				sh += "sync \n";
				
				sh += "echo '' \n";
				sh += "echo '" + _("Cleaning up...") + "' \n";
				sh += "sync \n";
				sh += "for i in /dev /proc /run /sys; do umount -f \"%s$i\"; done \n".printf(target_path);
				sh += "sync \n";
			}
			
			//reboot if required --------
			
			if (restore_current_system){
				sh += "echo '' \n";
				sh += "echo '" + _("Rebooting system...") + "' \n";
				//sh += "reboot -f \n";
				sh += "shutdown -r now \n";
			}

			//check if current system is being restored and do some housekeeping ---------
			
			if (restore_current_system){
				
				//invalidate the .sync snapshot  -------
				
				string sync_name = ".sync"; 
				string sync_path = snapshot_dir + "/" + sync_name; 
				string control_file_path = sync_path + "/info.json";
				
				f = File.new_for_path(control_file_path);
				if(f.query_exists()){
					f.delete(); //delete the control file
				}
				
				//save a control file for updating the .sync snapshot -----
				
				control_file_path = snapshot_dir + "/.sync-restore";
				
				f = File.new_for_path(control_file_path);
				if(f.query_exists()){
					f.delete(); //delete existing file
				}
				
				write_file(control_file_path, snapshot_to_restore.path); //save snapshot name
			}
		
			//run the script --------------------
			
			if (snapshot_to_restore != null){
				log_msg(_("Restoring snapshot..."));
			}
			else{
				log_msg(_("Cloning system..."));
			}
				
			if (app_mode == ""){ //gui
				if (restore_current_system){
					//current system, gui, fullscreen
					temp_script = create_temp_bash_script(sh);
					ret_val = execute_bash_script_fullscreen_sync(temp_script);
					
					if (ret_val == -1){
						string msg = _("Failed to find a terminal emulator on this system!") + "\n";
						msg += _("Please install one of the following terminal emulators and try again") + ":\n";
						msg += "xfce4-terminal gnome-terminal xterm konsole\n\n";
						msg += _("No changes were made to system.");
						
						log_error(msg);

						string title = _("Error");
						gtk_messagebox(title, msg, null, true);

						thr_success = false;
						thr_running = false;
						return;
					}
				}
				else{
					//other system, gui
					string std_out, std_err;
					ret_val = execute_script_sync_get_output(sh, out std_out, out std_err);
					log_msg_to_file(std_out);
					log_msg_to_file(std_err);
				}
			}
			else{ //console
				if (cmd_verbose){
					//current/other system, console, verbose
					ret_val = execute_script_sync(sh, false);
					log_empty_line();
				}
				else{
					//current/other system, console, quiet
					string std_out, std_err;
					ret_val = execute_script_sync_get_output(sh, out std_out, out std_err);
					log_msg_to_file(std_out);
					log_msg_to_file(std_err);
				}
			}

			//check for errors ----------------------
			
			if (ret_val != 0){
				log_error(_("Restore failed with exit code") + ": %d".printf(ret_val));
				thr_success = false;
				thr_running = false;
			}
			else{
				log_msg(_("Restore completed without errors"));
				thr_success = true;
				thr_running = false;
			}
	
			//update /etc/fstab when restoring to another device --------------------
			
			if (!restore_current_system){
				string fstab_path = target_path + "etc/fstab";
				var fstab_list = FsTabEntry.read_fstab_file(fstab_path);

				foreach(MountEntry mount_entry in mount_list){
					bool found = false;
					foreach(FsTabEntry fstab_entry in fstab_list){
						if (fstab_entry.mount_point == mount_entry.mount_point){
							found = true;
							//update fstab entry
							fstab_entry.device = "UUID=%s".printf(mount_entry.device.uuid);
							fstab_entry.type = mount_entry.device.type;
							
							//fix mount options for / and /home
							if (restore_target.type != "btrfs"){
								if ((fstab_entry.mount_point == "/") && fstab_entry.options.contains("subvol=@")){
									fstab_entry.options = fstab_entry.options.replace("subvol=@","").strip();
									if (fstab_entry.options.has_suffix(",")){
										fstab_entry.options = fstab_entry.options[0:fstab_entry.options.length - 1];
									}
								}
								else if ((fstab_entry.mount_point == "/home") && fstab_entry.options.contains("subvol=@home")){
									fstab_entry.options = fstab_entry.options.replace("subvol=@home","").strip();
									if (fstab_entry.options.has_suffix(",")){
										fstab_entry.options = fstab_entry.options[0:fstab_entry.options.length - 1];
									}
								}
							}
						}
					}
					
					if (!found){
						//add new fstab entry
						FsTabEntry fstab_entry = new FsTabEntry();
						fstab_entry.device = "UUID=%s".printf(mount_entry.device.uuid);
						fstab_entry.mount_point = mount_entry.mount_point;
						fstab_entry.type = mount_entry.device.type;
						fstab_list.add(fstab_entry);
					}
				}
				
				/* 
				 * If user has not mounted /home, and /home is mounted on another device (according to the fstab file)
				 * then remove the /home mount entry from the fstab.
				 * This is required - otherwise when the user boots the restored system they will continue to see
				 * the existing device as /home and instead of seeing the files restored to /home on the *root* device.
				 * We will do this fix only for /home and leave all other mount points untouched.
				 * */
				
				bool found_home_in_fstab = false;
				FsTabEntry fstab_home_entry = null;
				foreach(FsTabEntry fstab_entry in fstab_list){
					if (fstab_entry.mount_point == "/home"){
						found_home_in_fstab = true;
						fstab_home_entry = fstab_entry;
						break;
					}
				}
				
				bool found_home_in_mount_list = false;
				foreach(MountEntry mount_entry in mount_list){
					if (mount_entry.mount_point == "/home"){
						found_home_in_mount_list = true;
						break;
					}
				}

				if (found_home_in_fstab && !found_home_in_mount_list){
					//remove fstab entry for /home
					fstab_list.remove(fstab_home_entry);
				}

				//write the updated file --------------
				
				string text = "# <file system> <mount point> <type> <options> <dump> <pass>\n\n";
				text += FsTabEntry.create_fstab_file(fstab_list.to_array(), false);
				if (file_exists(fstab_path)){
					file_delete(fstab_path);
				}
				write_file(fstab_path, text);
				
				log_msg(_("Updated /etc/fstab on target device") + ": %s".printf(fstab_path));
				
				//create folders for mount points in /etc/fstab to prevent mount errors during boot ---------
				
				foreach(FsTabEntry fstab_entry in fstab_list){
					if (fstab_entry.mount_point.length == 0){ continue; }

					string mount_path = target_path + fstab_entry.mount_point[1:fstab_entry.mount_point.length];
					if (fstab_entry.is_comment || fstab_entry.is_empty_line || (mount_path.length == 0)){ continue; }

					if (!dir_exists(mount_path)){
						log_msg("Created mount point on target device: %s".printf(fstab_entry.mount_point));
						create_dir(mount_path);
					}
				}
			}

			unmount_target_device(false);
		}
		catch(Error e){
			log_error (e.message);
			thr_success = false;
			thr_running = false;
		}
	}

	public void save_exclude_list_for_restore(string file_path){
		
		try{
			string pattern;
			
			if (exclude_list_restore.size == 0){
				
				//add default entries
				foreach(string path in exclude_list_default){
					if (!exclude_list_restore.contains(path)){
						exclude_list_restore.add(path);
					}
				}
				
				if (!mirror_system){
					//add default_extra entries
					foreach(string path in exclude_list_default_extra){
						if (!exclude_list_restore.contains(path)){
							exclude_list_restore.add(path);
						}
					}
				}
				
				//add app entries
				foreach(AppExcludeEntry entry in exclude_list_apps){
					if (entry.enabled){
						pattern = entry.pattern();
						if (!exclude_list_restore.contains(pattern)){
							exclude_list_restore.add(pattern);
						}
						
						pattern = entry.pattern(true);
						if (!exclude_list_restore.contains(pattern)){
							exclude_list_restore.add(pattern);
						}
					}
				}
				
				//add user entries from current settings
				foreach(string path in exclude_list_user){
					if (!exclude_list_restore.contains(path) && !exclude_list_home.contains(path)){
						exclude_list_restore.add(path);
					}
				}
				
				//add user entries from snapshot exclude list
				string list_file = file_path + "/exclude.list";
				if (file_exists(list_file)){
					foreach(string path in read_file(list_file).split("\n")){
						if (!exclude_list_restore.contains(path) && !exclude_list_home.contains(path)){
							exclude_list_restore.add(path);
						}
					}
				}
				
				//add home entries
				foreach(string path in exclude_list_home){
					if (!exclude_list_restore.contains(path)){
						exclude_list_restore.add(path);
					}
				}
				
				string timeshift_path = "/timeshift/*";
				if (!exclude_list_restore.contains(timeshift_path)){
					exclude_list_restore.add(timeshift_path);
				}
			
				log_msg(_("Using the default exclude-list"));
			}
			else{
				log_msg(_("Using user-specified exclude-list"));
			}

			string timeshift_path = "/timeshift/*";
			if (!exclude_list_restore.contains(timeshift_path)){
				exclude_list_restore.add(timeshift_path);
			}
			
			//write file -----------

			string file_text = "";
			string list_file_restore = file_path + "/exclude-restore.list";
			
			var f = File.new_for_path(list_file_restore);
			if (f.query_exists()){
				f.delete();
			}
			
			foreach(string path in exclude_list_restore){
				file_text += path + "\n";
			}

			write_file(list_file_restore,file_text);
		} 
		catch (Error e) {
	        log_error (e.message);
	    }
	}

	//delete
	
	public bool delete_snapshot(TimeShiftBackup? snapshot = null){
		bool found = false;
		snapshot_to_delete = snapshot;

		//set snapshot -----------------------------------------------

		if (app_mode != ""){ //command-line mode
			
			if (cmd_snapshot.length > 0){ 
				
				//check command line arguments
				found = false;
				foreach(TimeShiftBackup bak in snapshot_list) {
					if (bak.name == cmd_snapshot){
						snapshot_to_delete = bak;
						found = true;
						break;
					}
				}
				
				//check if found
				if (!found){
					log_error(_("Could not find snapshot") + ": '%s'".printf(cmd_snapshot));
					return false;
				}
			}
			
			//prompt user for snapshot
			if (snapshot_to_delete == null){
				
				if (snapshot_list.size == 0){
					log_error(_("No snapshots found on device") + ": '%s'".printf(snapshot_device.device));
					return false;
				}
				
				LOG_TIMESTAMP = false;
								
				log_msg("");
				log_msg(TERM_COLOR_YELLOW + _("Select snapshot to delete") + ":\n" + TERM_COLOR_RESET);
				list_snapshots(true);
				log_msg("");

				while (snapshot_to_delete == null){
					stdout.printf(TERM_COLOR_YELLOW + _("Enter snapshot number (a=Abort, p=Previous, n=Next)") + ": " + TERM_COLOR_RESET);
					stdout.flush();
					snapshot_to_delete = read_stdin_snapshot();
				}
				log_msg("");
				
				LOG_TIMESTAMP = true;
			}
		}
		
		if (snapshot_to_delete == null){
			//print error
			log_error(_("Snapshot to delete not specified!"));
			return false;
		}

		try {
			thr_running = true;
			thr_success = false;
			Thread.create<void> (delete_snapshot_thread, true);
		} catch (ThreadError e) {
			thr_running = false;
			thr_success = false;
			log_error (e.message);
		}
		
		while (thr_running){
			gtk_do_events ();
			Thread.usleep((ulong) GLib.TimeSpan.MILLISECOND * 100);
		}
		
		snapshot_to_delete = null;
		
		return thr_success;
	}
	
	public void delete_snapshot_thread(){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		log_msg(_("Removing snapshot") + " '%s'...".printf(snapshot_to_delete.name));
		
		try{
			var f = File.new_for_path(snapshot_to_delete.path);
			if(f.query_exists()){
				cmd = "rm -rf \"%s\"".printf(snapshot_to_delete.path);
				
				if (LOG_COMMANDS) { log_debug(cmd); }
				
				Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
				
				if (ret_val != 0){
					log_error(_("Failed to remove") + ": '%s'".printf(snapshot_to_delete.path));
					thr_success = false;
					thr_running = false;
					return;
				}
				else{
					log_msg(_("Removed") + ": '%s'".printf(snapshot_to_delete.path));
					thr_success = true;
					thr_running = false;
					return;
				}
			}
			else{
				log_error(_("Directory not found") + ": '%s'".printf(snapshot_to_delete.path));
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

	public bool delete_all_snapshots(){
		string timeshift_dir = mount_point_backup + "/timeshift";
		string sync_dir = mount_point_backup + "/timeshift/snapshots/.sync";
		
		if (dir_exists(timeshift_dir)){ 
			//delete snapshots
			foreach(TimeShiftBackup bak in snapshot_list){
				if (!delete_snapshot(bak)){ 
					return false; 
				}
			}
			
			//delete .sync
			if (dir_exists(sync_dir)){
				if (!delete_directory(sync_dir)){ 
					return false; 
				}
			}
			
			//delete /timeshift
			return delete_directory(timeshift_dir);
		}
		else{
			log_msg(("No snapshots found on device '%s'").printf(snapshot_device.device));
			return true; 
		}
	}

	public bool delete_directory(string dir_path){
		thr_arg1 = dir_path;
		
		try {
			thr_running = true;
			thr_success = false;
			Thread.create<void> (delete_directory_thread, true);
		} catch (ThreadError e) {
			thr_running = false;
			thr_success = false;
			log_error (e.message);
		}
		
		while (thr_running){
			gtk_do_events ();
			Thread.usleep((ulong) GLib.TimeSpan.MILLISECOND * 100);
		}
		
		thr_arg1 = null;
		
		return thr_success;
	}
	
	public void delete_directory_thread(){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			var f = File.new_for_path(thr_arg1);
			if(f.query_exists()){
				cmd = "rm -rf \"%s\"".printf(thr_arg1);
				
				if (LOG_COMMANDS) { log_debug(cmd); }
				
				Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
				
				if (ret_val != 0){
					log_error(_("Failed to remove") + ": '%s'".printf(thr_arg1));
					thr_success = false;
					thr_running = false;
					return;
				}
				else{
					log_msg(_("Removed") + ": '%s'".printf(thr_arg1));
					thr_success = true;
					thr_running = false;
					return;
				}
			}
			else{
				log_error(_("Directory not found") + ": '%s'".printf(thr_arg1));
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


	//app config
	
	public void save_app_config(){
		var config = new Json.Object();
		//config.set_string_member("enabled", is_scheduled.to_string());
		
		config.set_string_member("backup_device_uuid", (snapshot_device == null) ? "" : snapshot_device.uuid);
		
		config.set_string_member("is_scheduled", is_scheduled.to_string());
		
		config.set_string_member("schedule_monthly", schedule_monthly.to_string());
		config.set_string_member("schedule_weekly", schedule_weekly.to_string());
		config.set_string_member("schedule_daily", schedule_daily.to_string());
		config.set_string_member("schedule_hourly", schedule_hourly.to_string());
		config.set_string_member("schedule_boot", schedule_boot.to_string());
		
		config.set_string_member("count_monthly", count_monthly.to_string());
		config.set_string_member("count_weekly", count_weekly.to_string());
		config.set_string_member("count_daily", count_daily.to_string());
		config.set_string_member("count_hourly", count_hourly.to_string());
		config.set_string_member("count_boot", count_boot.to_string());
		
		config.set_string_member("max_days", retain_snapshots_max_days.to_string());
		config.set_string_member("min_space", minimum_free_disk_space_mb.to_string());

		Json.Array arr = new Json.Array();
		foreach(string path in exclude_list_user){
			arr.add_string_element(path);
		}
		config.set_array_member("exclude",arr);
		
		var json = new Json.Generator();
		json.pretty = true;
		json.indent = 2;
		var node = new Json.Node(NodeType.OBJECT);
		node.set_object(config);
		json.set_root(node);
		
		try{
			json.to_file(this.app_conf_path);
		} catch (Error e) {
	        log_error (e.message);
	    }
	    
	    if ((app_mode == "")||(LOG_DEBUG)){
			log_msg(_("App config saved") + ": '%s'".printf(this.app_conf_path));
		}
	}
	
	public void load_app_config(){
		var f = File.new_for_path(this.app_conf_path);
		if (!f.query_exists()) { return; }
		
		var parser = new Json.Parser();
        try{
			parser.load_from_file(this.app_conf_path);
		} catch (Error e) {
	        log_error (e.message);
	    }
        var node = parser.get_root();
        var config = node.get_object();
        
        string uuid = json_get_string(config,"backup_device_uuid","");

        foreach(Device pi in partition_list){
			if (pi.uuid == uuid){
				snapshot_device = pi;
				break;
			}
		}
		
		//set backup device from command-line argument (if specified)
		if ((app_mode != "") && (cmd_backup_device.length > 0)){
			bool found = false;
			foreach(Device pi in partition_list){
				if ((pi.device == cmd_backup_device)||(pi.uuid == cmd_backup_device)){
					snapshot_device = pi;
					found = true;
					break;
				}
				else {
					foreach(string symlink in pi.symlinks){
						if (symlink == cmd_backup_device){
							snapshot_device = pi;
							found = true;
							break;
						}
					}
					if (found){ break; }
				}
			}
			if (!found){
				log_error(_("Could not find device") + ": '%s'".printf(cmd_backup_device));
				exit_app();
				exit(1);
				return;
			}
		}
		
		if ((uuid.length == 0) || (snapshot_device == null)){
			if (root_device != null){
				log_msg (_("Warning: Backup device not set! Defaulting to system device"));
				snapshot_device = root_device;
			}
		}
		
		snapshot_device = unlock_and_find_device(snapshot_device, null);
		
		if (mount_backup_device(snapshot_device)){
			update_partition_list();
		}
		else{
			snapshot_device = null;
		}

		this.is_scheduled = json_get_bool(config,"is_scheduled", is_scheduled);

        this.schedule_monthly = json_get_bool(config,"schedule_monthly",schedule_monthly);
		this.schedule_weekly = json_get_bool(config,"schedule_weekly",schedule_weekly);
		this.schedule_daily = json_get_bool(config,"schedule_daily",schedule_daily);
		this.schedule_hourly = json_get_bool(config,"schedule_hourly",schedule_hourly);
		this.schedule_boot = json_get_bool(config,"schedule_boot",schedule_boot);
		
		this.count_monthly = json_get_int(config,"count_monthly",count_monthly);
		this.count_weekly = json_get_int(config,"count_weekly",count_weekly);
		this.count_daily = json_get_int(config,"count_daily",count_daily);
		this.count_hourly = json_get_int(config,"count_hourly",count_hourly);
		this.count_boot = json_get_int(config,"count_boot",count_boot);
		
		this.retain_snapshots_max_days = json_get_int(config,"max_days",retain_snapshots_max_days);
		this.minimum_free_disk_space_mb = json_get_int(config,"min_space",minimum_free_disk_space_mb);

		this.exclude_list_user.clear();
		if (config.has_member ("exclude")){
			foreach (Json.Node jnode in config.get_array_member ("exclude").get_elements()) {
				string path = jnode.get_string();
				if (!exclude_list_user.contains(path) && !exclude_list_default.contains(path) && !exclude_list_home.contains(path)){
					this.exclude_list_user.add(path);
				}
			}
		}
		
		if ((app_mode == "")||(LOG_DEBUG)){
			log_msg(_("App config loaded") + ": '%s'".printf(this.app_conf_path));
		}
	}

	//core functions
	
	public bool update_snapshot_list(){
		
		snapshot_list.clear();

		string path = mount_point_backup + "/timeshift/snapshots";

		if (!dir_exists(path)){
			return false;
		}

		try{
			var dir = File.new_for_path (path);
			var enumerator = dir.enumerate_children ("*", 0);
			
			var info = enumerator.next_file ();
			while (info != null) {
				if (info.get_file_type() == FileType.DIRECTORY) {
					if (info.get_name() != ".sync") {
						TimeShiftBackup bak = new TimeShiftBackup(path + "/" + info.get_name());
						if (bak.is_valid){
							snapshot_list.add(bak);
						}
					}
				}
				info = enumerator.next_file ();
			}
		}
		catch(Error e){
			log_error (e.message);
			return false;
		}

		snapshot_list.sort((a,b) => { 
			TimeShiftBackup t1 = (TimeShiftBackup) a;
			TimeShiftBackup t2 = (TimeShiftBackup) b;
			return t1.date.compare(t2.date);
		});

		//log_debug(_("Updated snapshot list"));
		return true;
	}
	
	public Gee.ArrayList<Device> partition_list {
		owned get{
			var list = new Gee.ArrayList<Device>();
			foreach(Device pi in partition_map.values) {
				list.add(pi);
			}
			list.sort((a,b) => { 
					Device p1 = (Device) a;
					Device p2 = (Device) b;
					
					return strcmp(p1.device,p2.device);
				});
			return list;
		}
	}
	
	public void update_partition_list(){
		partition_map.clear();
		partition_map = Device.get_filesystems();

		foreach(Device pi in partition_map.values){
			//root_device and home_device will be detected by detect_system_devices()
			if ((snapshot_device != null) && (pi.uuid == snapshot_device.uuid)){
				snapshot_device = pi;
			}
			if (pi.is_mounted){
				pi.dist_info = DistInfo.get_dist_info(pi.mount_points[0]).full_name();
			}
		}
		if (partition_map.size == 0){
			log_error("ts: " + _("Failed to get partition list."));
		}

		//log_debug(_("Partition list updated"));
	}

	public Gee.ArrayList<TimeShiftBackup?> get_snapshot_list(string tag = ""){
		var list = new Gee.ArrayList<TimeShiftBackup?>();

		foreach(TimeShiftBackup bak in snapshot_list){
			if (tag == "" || bak.has_tag(tag)){
				list.add(bak);
			}
		}
		list.sort((a,b) => { 
			TimeShiftBackup t1 = (TimeShiftBackup) a;
			TimeShiftBackup t2 = (TimeShiftBackup) b;
			return (t1.date.compare(t2.date)); 
		});

		return list;
	}
	
	public void detect_system_devices(){
		foreach(Device pi in partition_list){
			if (pi.mount_points.contains("/")){
				root_device = pi;
				if ((app_mode == "")||(LOG_DEBUG)){
					log_msg(_("/ is mapped to device: %s, UUID=%s").printf(pi.device,pi.uuid));
				}
			}
			
			if (pi.mount_points.contains("/home")){
				home_device = pi;
				if ((app_mode == "")||(LOG_DEBUG)){
					log_msg(_("/home is mapped to device: %s, UUID=%s").printf(pi.device,pi.uuid));
				}
			}
		}
	}
	
	public TimeShiftBackup? get_latest_snapshot(string tag = ""){
		var list = get_snapshot_list(tag);

		if (list.size > 0)
			return list[list.size - 1];
		else
			return null;
	}
	
	public TimeShiftBackup? get_oldest_snapshot(string tag = ""){
		var list = get_snapshot_list(tag);
		
		if (list.size > 0)
			return list[0];
		else
			return null;
	}

	public bool mount_backup_device(Device? dev = null){
		/* Note:
		 * If backup device is BTRFS then it will be explicitly mounted to /mnt/timeshift/backup
		 * Otherwise existing mount point will be used.
		 * This is required since we need to mount the root subvolume of the BTRFS filesystem
		 * */
		 
		Device backup_device = dev;
		if (backup_device == null){
			backup_device = snapshot_device;
		}
		
		if (backup_device == null){
			return false;
		}
		else{
			if (backup_device.type == "btrfs"){
				//unmount
				unmount_backup_device();

				//mount
				mount_point_backup = mount_point_app + "/backup";
				check_and_create_dir_with_parents(mount_point_backup);
				if (mount(backup_device.uuid, mount_point_backup, "")){
					if ((app_mode == "")||(LOG_DEBUG)){
						log_msg(_("Backup path changed to '%s/timeshift'").printf((mount_point_backup == "/") ? "" : mount_point_backup));
					}
					return true;
				}
				else{
					mount_point_backup = "";
					return false;
				}
			}
			else{
				string backup_device_mount_point = get_device_mount_point(backup_device.uuid);
				if ((mount_point_backup.length == 0) || (backup_device_mount_point != mount_point_backup)){
					//unmount
					unmount_backup_device(false);

					/* Note: Unmount errors can be ignored.
					 * Old device will be hidden if new device is mounted successfully
					 * */
					
					//automount
					mount_point_backup = automount(backup_device.uuid,"", mount_point_app);
					if (mount_point_backup.length > 0){
						if ((app_mode == "")||(LOG_DEBUG)){
							log_msg(_("Backup path changed to '%s/timeshift'").printf((mount_point_backup == "/") ? "" : mount_point_backup));
						}
					}
					else{
						update_partition_list();
					}
				}

				return (mount_point_backup.length > 0);
			}
		}
		
	}
	
	public bool mount_target_device(Gtk.Window? parent_win){
		/* Note:
		 * Target device will be mounted explicitly to /mnt/timeshift/restore
		 * Existing mount points are not used since we need to mount other devices in sub-directories
		 * */
				 
		if (restore_target == null){
			return false;
		}
		else{
			//unmount
			unmount_target_device();
				
			//check and create restore mount point for restore
			mount_point_restore = mount_point_app + "/restore";
			check_and_create_dir_with_parents(mount_point_restore);
			
			//unlock encrypted device
			if (restore_target.type == "luks"){
				restore_target = unlock_and_find_device(restore_target, parent_win);

				//exit if not found
				if (restore_target == null){
					log_error(_("Target device not specified!"));
					return false;
				}
				
				//update mount entry
				foreach (MountEntry mnt in mount_list) {
					if (mnt.mount_point == "/"){
						mnt.device = restore_target;	
						break;		
					}
				}
			}
			
			//mount root device
			if (restore_target.type == "btrfs"){

				//check subvolume layout
				if (check_btrfs_volume(restore_target) == false){
					string msg = _("The target partition has an unsupported subvolume layout.") + "\n";
					msg += _("Only ubuntu-type layouts with @ and @home subvolumes are currently supported.");

					if (app_mode == ""){
						string title = _("Unsupported Subvolume Layout");
						gtk_messagebox(title, msg, null, true);
					}
					else{
						log_error("\n" + msg);
					}
					
					return false;
				}

				//mount @ 
				if (!mount(restore_target.uuid, mount_point_restore, "subvol=@")){
					log_error(_("Failed to mount BTRFS subvolume") + ": @");
					return false;
				}

				//mount @home 
				if (!mount(restore_target.uuid, mount_point_restore + "/home", "subvol=@home")){
					log_error(_("Failed to mount BTRFS subvolume") + ": @home");
					return false;
				}
			}
			else{
				if (!mount(restore_target.uuid, mount_point_restore, "")){
					return false;
				}
			}
			
			//mount remaining devices
			foreach (MountEntry mnt in mount_list) {
				if (mnt.mount_point != "/"){
					if (!mount(mnt.device.uuid, mount_point_restore + mnt.mount_point)){
						return false; 
					}					
				}
			}
		}
		
		return true;
	}

	public void unmount_backup_device(bool exit_on_error = true){
		//unmount the backup device only if it was mounted by application
		if (mount_point_backup.has_prefix(mount_point_app)){
			if (unmount_device(mount_point_backup, false)){
				if (dir_exists(mount_point_backup)){
					file_delete(mount_point_backup);
					log_debug(_("Removed mount directory: '%s'").printf(mount_point_backup));
				}
			}
			else{
				//ignore
			}
		}
		else{
			//don't unmount
		}
	}
	
	public void unmount_target_device(bool exit_on_error = true){
		//unmount the target device only if it was mounted by application
		if (mount_point_restore.has_prefix(mount_point_app)){   //always true
			unmount_device(mount_point_restore,exit_on_error);
		}
		else{
			//don't unmount
		}
	}
	
	public bool unmount_device(string mount_point, bool exit_on_error = true){
		bool is_unmounted = unmount(mount_point);
		if (!is_unmounted){
			if (exit_on_error){
				if (app_mode == ""){
					string title = _("Critical Error");
					string msg = _("Failed to unmount device!") + "\n" + _("Application will exit");
					gtk_messagebox(title, msg, null, true);
				}
				exit_app();
				exit(0);
			}
		}
		return is_unmounted;
	}

	public int check_backup_device(out string message){
		
		/* 
		-1 - device un-available
		 0 - first snapshot taken, disk space sufficient 
		 1 - first snapshot taken, disk space not sufficient
		 2 - first snapshot not taken, disk space not sufficient
		 3 - first snapshot not taken, disk space sufficient
		*/

		int status_code = 0;
		
		//free space message
		if ((snapshot_device != null) && (snapshot_device.free.length > 0)){
			message = "%s ".printf(snapshot_device.free) + _("free");
			message = message.strip();
		}
		else{
			message = "";
		}
		
		if (!live_system()){
			if (!backup_device_online()){
				
				if (snapshot_device == null){
					message = _("Please select the backup device");
				}
				else{
					message = _("Backup device not available");
				}
				
				status_code = -1;
			}
			else{
				if (snapshot_device.size_mb == 0){
					message = _("Backup device not available");
					status_code = -1;
				}
				else{
					if (snapshot_list.size > 0){
						if (snapshot_device.free_mb < minimum_free_disk_space_mb){
							message = _("Backup device does not have enough space!");
							status_code = 1;
						}
						else{
							//ok
						}
					}
					else {
						long required_space = calculate_size_of_first_snapshot();
						message = _("First snapshot needs") + " %.1f GB".printf(required_space/1024.0);
						if (snapshot_device.free_mb < required_space){
							status_code = 2;
						}
						else{
							status_code = 3;
						}
					}
				}
			}
		}

		log_debug("Checked backup device (status=%d)".printf(status_code));
				
		return status_code;
	}
	
	public bool check_btrfs_volume(Device dev){
		string mnt_btrfs = mount_point_app + "/btrfs";
		check_and_create_dir_with_parents(mnt_btrfs);
		
		unmount(mnt_btrfs);
		mount(dev.uuid, mnt_btrfs);
		
		bool is_supported = dir_exists(mnt_btrfs + "/@") && dir_exists(mnt_btrfs + "/@home");
		
		if (unmount(mnt_btrfs)){
			file_delete(mnt_btrfs);
			log_debug(_("Removed mount directory: '%s'").printf(mnt_btrfs));
		}
				
		return is_supported;
	}
	
	public bool backup_device_online(){
		if (snapshot_device != null){
			mount_backup_device();
			if (Device.get_mount_points(snapshot_device.uuid).size > 0){
				return true;
			}
		}
		return false;
	}

	public long calculate_size_of_first_snapshot(){
		
		if (this.first_snapshot_size > 0){
			return this.first_snapshot_size;
		}
		else if (live_system()){
			return 0;
		}
		
		try {
			thr_running = true;
			thr_success = false;
			Thread.create<void> (calculate_size_of_first_snapshot_thread, true);
		} catch (ThreadError e) {
			thr_running = false;
			thr_success = false;
			log_error (e.message);
		}
		
		while (thr_running){
			gtk_do_events ();
			Thread.usleep((ulong) GLib.TimeSpan.MILLISECOND * 100);
		}

		return this.first_snapshot_size;
	}
	
	public void calculate_size_of_first_snapshot_thread(){
		thr_running = true;
		
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;
		long required_space = 0;

		try{
			
			var f = File.new_for_path("/tmp/exclude.list");
			if (f.query_exists()){
				f.delete();
			}
			
			f = File.new_for_path("/tmp/rsync.log");
			if (f.query_exists()){
				f.delete();
			}
			
			f = File.new_for_path("/tmp/empty");
			if (!f.query_exists()){
				create_dir("/tmp/empty");
			}
			
			save_exclude_list("/tmp");
			
			cmd  = "LC_ALL=C ; rsync -ai --delete --numeric-ids --relative --stats --dry-run --delete-excluded --exclude-from=/tmp/exclude.list /. /tmp/empty/ &> /tmp/rsync.log";
			
			ret_val = execute_command_script_sync(cmd, out std_out, out std_err);
			if (ret_val == 0){
				cmd = "cat /tmp/rsync.log | awk '/Total file size/ {print $4}'";
				ret_val = execute_command_script_sync(cmd, out std_out, out std_err);
				if (ret_val == 0){
					required_space = long.parse(std_out.replace(",","").strip());
					required_space = required_space / (1024 * 1024);
					thr_success = true;
				}
				else{
					log_error (_("Failed to estimate system size"));
					log_error (std_err);
					thr_success = false;
				}
			}
			else{
				log_error (_("Failed to estimate system size"));
				log_error (std_err);
				thr_success = false;
			}
		}
		catch(Error e){
			log_error (e.message);
			thr_success = false;
		}
		
		if ((required_space == 0) && (root_device != null)){
			required_space = root_device.used_mb;
		}
		
		this.first_snapshot_size = required_space;
		
		log_debug("First snapshot size: %ld MB".printf(required_space));
		
		thr_running = false;
	}

	//cron jobs
	
	public void cron_job_update(){
		
		if (live_system()) { return; }
		
		string current_entry = "";
		string new_entry = "";
		bool new_entry_exists = false;
		string search_string = "";
		
		//scheduled job ----------------------------------
		
		new_entry = get_crontab_entry_scheduled();
		new_entry_exists = false;
		
		//check and remove crontab entries created by previous versions of timeshift
		
		search_string = "*/30 * * * * timeshift --backup";
		current_entry = crontab_read_entry(search_string);
		if (current_entry.length > 0) {
			//remove entry
			crontab_remove_job(current_entry);
		} 
		
		//check for regular entries
		foreach(string interval in new string[] {"@monthly","@weekly","@daily","@hourly"}){
			
			search_string = "%s timeshift --backup".printf(interval);
			
			//read
			current_entry = crontab_read_entry(search_string);
			
			if (current_entry.length == 0) { continue; } //not found
			
			//check
			if (current_entry == new_entry){
				//keep entry
				new_entry_exists = true;
			}
			else{
				//remove current entry
				crontab_remove_job(current_entry);
			}
		}
		
		//add new entry if missing
		if (!new_entry_exists && new_entry.length > 0){
			crontab_add_job(new_entry);
		}
		
		//boot job ----------------------------------
		
		search_string = """@reboot sleep [0-9]*m && timeshift --backup""";
		
		new_entry = get_crontab_entry_boot();
		new_entry_exists = false;
		
		//read
		current_entry = crontab_read_entry(search_string, true);
		
		if (current_entry.length > 0) {
			//check
			if (current_entry == new_entry){
				//keep entry
				new_entry_exists = true;
			}
			else{
				//remove current entry
				crontab_remove_job(current_entry);
			}
		}
		
		//add new entry if missing
		if (!new_entry_exists && new_entry.length > 0){
			crontab_add_job(new_entry);
		}
	}

	private string get_crontab_entry_scheduled(){
		if (is_scheduled && (snapshot_list.size > 0)){
			if (schedule_hourly){
				return "@hourly timeshift --backup"; 
			}
			else if (schedule_daily){
				return "@daily timeshift --backup";
			}
			else if (schedule_weekly){
				return "@weekly timeshift --backup";
			}
			else if (schedule_monthly){
				return "@monthly timeshift --backup";
			}
		}
		
		return "";
	}

	private string get_crontab_entry_boot(){
		if (is_scheduled && (snapshot_list.size > 0)){
			if (schedule_boot || schedule_hourly || schedule_daily || schedule_weekly || schedule_monthly){
				return "@reboot sleep %dm && timeshift --backup".printf(startup_delay_interval_mins);
			}
		}
		
		return "";
	}
	
	private bool crontab_add_job(string entry){
		if (live_system()) { return false; }
		
		if (crontab_add(entry)){
			log_msg(_("Cron job added") + ": %s".printf(entry));
			return true;
		}
		else {
			log_error(_("Failed to add cron job"));
			return false;
		}
	}
	
	private bool crontab_remove_job(string search_string){
		if (live_system()) { return false; }
		
		if (crontab_remove(search_string)){
			log_msg(_("Cron job removed") + ": %s".printf(search_string));
			return true;
		}
		else{
			log_error(_("Failed to remove cron job"));
			return false;
		}
	}

	//cleanup
	
	public void clean_logs(){
		
		Gee.ArrayList<string> list = new Gee.ArrayList<string>();
		
		try{
			var dir = File.new_for_path (log_dir);
			var enumerator = dir.enumerate_children ("*", 0);
			
			var info = enumerator.next_file ();
			string path;
			
			while (info != null) {
				if (info.get_file_type() == FileType.REGULAR) {
					path = log_dir + "/" + info.get_name();
					if (path != log_file) {
						list.add(path);
					}
				}
				info = enumerator.next_file ();
			}
			
			list.sort(strcmp);
			
			if (list.size > 500){
				for(int k=0; k<100; k++){
					var file = File.new_for_path (list[k]);
					if (file.query_exists()){
						file.delete();
					}
				}
				log_msg(_("Older log files removed"));
			}
		}
		catch(Error e){
			log_error (e.message);
		}
	}
	
	public void exit_app (){
		
		if (app_mode == ""){
			//update app config only in GUI mode
			save_app_config();
		}
		
		cron_job_update();
		
		unmount_backup_device(false);
		unmount_target_device(false);
		
		clean_logs();
		remove_lock();

		//Gtk.main_quit ();
	}
	
	public bool is_rsync_running(){
		string cmd = "rsync -ai --delete --numeric-ids --relative --delete-excluded";
		string txt = execute_command_sync_get_output ("ps w -C rsync");
		foreach(string line in txt.split("\n")){
			if (line.index_of(cmd) != -1){
				return true;
			}
		}
		return false;
	}
	
	public void kill_rsync(){
		string cmd = "rsync -ai --delete --numeric-ids --relative --delete-excluded";
		string txt = execute_command_sync_get_output ("ps w -C rsync");
		string pid = "";
		foreach(string line in txt.split("\n")){
			if (line.index_of(cmd) != -1){
				pid = line.strip().split(" ")[0];
				Posix.kill ((Pid) int.parse(pid), 15);
				log_msg(_("Terminating rsync process") + ": [PID=" + pid + "] ");
			}
		}
	}

}

public class TimeShiftBackup : GLib.Object{
	public string path = "";
	public string name = "";
	public DateTime date;
	public string sys_uuid = "";
	public string sys_distro = "";
	public string app_version = "";
	public string description = "";
	public Gee.ArrayList<string> tags;
	public Gee.ArrayList<string> exclude_list;
	public bool is_valid = true;
	
	public TimeShiftBackup(string dir_path){
		
		try{
			var f = File.new_for_path(dir_path);
			var info = f.query_info("*", FileQueryInfoFlags.NONE);
			
			path = dir_path;
			name = info.get_name();
			description = "";
			
			date = new DateTime.from_unix_utc(0);
			tags = new Gee.ArrayList<string>();
			exclude_list = new Gee.ArrayList<string>();
			
			read_control_file();
			read_exclude_list();
		}
		catch(Error e){
			log_error (e.message);
		}
	}
	
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
			foreach(string path in read_file(list_file).split("\n")){
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
	
	public void update_control_file(){
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
}

public class AppExcludeEntry : GLib.Object{
	public string relpath = "";
	public bool is_include = false;
	public bool is_file = false;
	public bool enabled = false;
	
	public AppExcludeEntry(string _relpath, bool _is_file, bool _is_include = false){
		relpath = _relpath;
		is_file = _is_file;
		is_include = _is_include;
	}
	
	public string pattern(bool root_home = false){
		string str = (is_include) ? "+ " : "";
		str += (root_home) ? "/root" : "/home/*";
		str += relpath[1:relpath.length];
		str += (is_file) ? "" : "/**";
		return str.strip();	
	}
	
}

