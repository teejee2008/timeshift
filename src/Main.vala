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
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public Main App;
public const string AppName = "Timeshift RSYNC";
public const string AppShortName = "timeshift";
public const string AppVersion = "16.7";
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
	public bool first_run = false;
	
	public Gee.ArrayList<Device> partitions;

	public Gee.ArrayList<string> exclude_list_user;
	public Gee.ArrayList<string> exclude_list_default;
	public Gee.ArrayList<string> exclude_list_default_extra;
	public Gee.ArrayList<string> exclude_list_home;
	public Gee.ArrayList<string> exclude_list_restore;
	public Gee.ArrayList<AppExcludeEntry> exclude_list_apps;
	public Gee.ArrayList<MountEntry> mount_list;

	public SnapshotStore repo; 

	//temp
	private Gee.ArrayList<Device> grub_device_list;

	public Device root_device;
	public Device home_device;
	//public Device snapshot_device;
	//public bool use_snapshot_path = false;
	//public string snapshot_path = "";

	//public string mount_point_backup = "";
	public string mount_point_restore = "";
	public string mount_point_app = "/mnt/timeshift";

	public LinuxDistro current_distro;
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
	public bool thr_timeout_active = false;
	public string thr_timeout_cmd = "";

	public int startup_delay_interval_mins = 10;
	public int retain_snapshots_max_days = 200;
	public int64 minimum_free_disk_space = 1 * GB;
	public int64 first_snapshot_size = 0;
	public int64 first_snapshot_count = 0;
	public int64 snapshot_location_free_space = 0;
	
	public string log_dir = "";
	public string log_file = "";
	public AppLock app_lock;

	public Snapshot snapshot_to_delete;
	public Snapshot snapshot_to_restore;
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

	public const string TERM_COLOR_YELLOW = "\033[" + "1;33" + "m";
	public const string TERM_COLOR_GREEN = "\033[" + "1;32" + "m";
	public const string TERM_COLOR_RED = "\033[" + "1;31" + "m";
	public const string TERM_COLOR_RESET = "\033[" + "0" + "m";

	public RsyncTask task;
	
	//initialization

	public static int main (string[] args) {
		set_locale();

		LOG_TIMESTAMP = false;
		
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
		init_tmp(AppShortName);
		LOG_ENABLE = true;

		/*
		 * Note:
		 * init_tmp() will fail if timeshift is run as normal user
		 * logging will be disabled temporarily so that the error is not displayed to user
		 */

		/*
		var map = Device.get_mounted_filesystems_using_mtab();
		foreach(Device pi in map.values){
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

		//get Linux distribution info -----------------------

		this.current_distro = LinuxDistro.get_dist_info("/");
		if ((app_mode == "")||(LOG_DEBUG)){
			log_msg(_("Distribution") + ": " + current_distro.full_name(),true);
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

		app_lock = new AppLock();
		
		if (!app_lock.create("timeshift", app_mode)){
			if (app_mode == ""){
				if (app_lock.lock_message == "backup"){
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

		repo = new SnapshotStore();
		
		exclude_list_user = new Gee.ArrayList<string>();
		exclude_list_default = new Gee.ArrayList<string>();
		exclude_list_default_extra = new Gee.ArrayList<string>();
		exclude_list_home = new Gee.ArrayList<string>();
		exclude_list_restore = new Gee.ArrayList<string>();
		exclude_list_apps = new Gee.ArrayList<AppExcludeEntry>();
		partitions = new Gee.ArrayList<Device>();
		mount_list = new Gee.ArrayList<MountEntry>();

		add_default_exclude_entries();
		//add_app_exclude_entries();

		//initialize app --------------------

		update_partitions();
		detect_system_devices();

		//finish initialization --------------

		load_app_config();
		//update_snapshot_list();

		task = create_new_rsync_task();
	}

	public RsyncTask create_new_rsync_task(){
		return new RsyncTask();
	}

	public bool start_application(string[] args){
		bool is_success = true;

		switch(app_mode){
			case "backup":
			case "ondemand":
			case "restore":
			case "delete":
			case "delete-all":
			case "list-snapshots":
				//set backup device from commandline argument if available or prompt user if device is null
				if (!mirror_system){
					get_backup_device_from_cmd(false, null);
				}
				break;
		}

		switch(app_mode){
			case "backup":
				is_success = take_snapshot(false, "", null);
				return is_success;

			case "restore":
				is_success = restore_snapshot(null);
				return is_success;

			case "delete":
				is_success = delete_snapshot();
				return is_success;

			case "delete-all":
				is_success = delete_all_snapshots();
				return is_success;

			case "ondemand":
				is_success = take_snapshot(true,"",null);
				return is_success;

			case "list-snapshots":
				LOG_ENABLE = true;
				if (App.repo.has_snapshots()){
					log_msg(_("Snapshots on device %s").printf(
						repo.device.full_name_with_alias) + ":\n");
					list_snapshots(false);
					return true;
				}
				else{
					log_msg(_("No snapshots found on device") + " '%s'".printf(repo.device.device));
					return false;
				}

			case "list-devices":
				LOG_ENABLE = true;
				log_msg(_("Devices with Linux file systems") + ":\n");
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
		if ((root_device != null) && (root_device.fstype == "btrfs")){
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
		ret_val = exec_script_sync(cmd, out std_out, out std_err);

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
		GLib.CompareDataFunc<AppExcludeEntry> entry_compare = (a, b) => {
			return strcmp(a.relpath,b.relpath);
		};
		exclude_list_apps.sort((owned) entry_compare);
	}

	//console functions

	public static string help_message (){
		string msg = "\n" + AppName + " v" + AppVersion + " by Tony George (teejee2008@gmail.com)" + "\n";
		msg += "\n";
		msg += "Syntax:\n";
		msg += "\n";
		msg += "  timeshift --list-{snapshots|devices} [OPTIONS]\n";
		msg += "  timeshift --backup[-now] [OPTIONS]\n";
		msg += "  timeshift --restore [OPTIONS]\n";
		msg += "  timeshift --delete-[all] [OPTIONS]\n";
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
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					app_mode = "backup";
					break;

				case "--delete":
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					app_mode = "delete";
					break;

				case "--delete-all":
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					app_mode = "delete-all";
					break;

				case "--restore":
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					mirror_system = false;
					app_mode = "restore";
					break;

				case "--clone":
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					mirror_system = true;
					app_mode = "restore";
					break;

				case "--backup-now":
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
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
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					break;

				case "--list-devices":
					app_mode = "list-devices";
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					break;

				default:
					LOG_TIMESTAMP = false;
					log_error(_("Invalid command line arguments") + ": %s".printf(args[k]), true);
					log_msg(Main.help_message());
					exit(1);
					break;
			}
		}

		/* LOG_ENABLE = false; 		disables all console output
		 * LOG_TIMESTAMP = false;	disables the timestamp prepended to every line in terminal output
		 * LOG_DEBUG = false;		disables additional console messages
		 * LOG_COMMANDS = true;		enables printing of all commands on terminal
		 * */

		if (app_mode == ""){
			//Initialize GTK
			LOG_TIMESTAMP = true;
			Gtk.init(ref args);
		}

	}

	public void list_snapshots(bool paginate){
		int count = 0;
		for(int index = 0; index < repo.snapshots.size; index++){
			if (!paginate || ((index >= snapshot_list_start_index) && (index < snapshot_list_start_index + 10))){
				count++;
			}
		}

		string[,] grid = new string[count+1,5];
		bool[] right_align = { false, false, false, false, false};

		int row = 0;
		int col = -1;
		grid[row, ++col] = _("Num");
		grid[row, ++col] = "";
		grid[row, ++col] = _("Name");
		grid[row, ++col] = _("Tags");
		grid[row, ++col] = _("Description");
		row++;

		for(int index = 0; index < repo.snapshots.size; index++){
			Snapshot bak = repo.snapshots[index];
			if (!paginate || ((index >= snapshot_list_start_index) && (index < snapshot_list_start_index + 10))){
				col = -1;
				grid[row, ++col] = "%d".printf(index);
				grid[row, ++col] = ">";
				grid[row, ++col] = "%s".printf(bak.name);
				grid[row, ++col] = "%s".printf(bak.taglist_short);
				grid[row, ++col] = "%s".printf(bak.description);
				row++;
			}
		}

		print_grid(grid, right_align);
	}

	public void list_devices(){
		int count = 0;
		foreach(Device pi in partitions) {
			if (!pi.has_linux_filesystem()) { continue; }
			count++;
		}

		string[,] grid = new string[count+1,6];
		bool[] right_align = { false, false, false, true, true, false};

		int row = 0;
		int col = -1;
		grid[row, ++col] = _("Num");
		grid[row, ++col] = "";
		grid[row, ++col] = _("Device");
		//grid[row, ++col] = _("UUID");
		grid[row, ++col] = _("Size");
		grid[row, ++col] = _("Type");
		grid[row, ++col] = _("Label");
		row++;

		foreach(Device pi in partitions) {
			if (!pi.has_linux_filesystem()) { continue; }

			col = -1;
			grid[row, ++col] = "%d".printf(row - 1);
			grid[row, ++col] = ">";
			grid[row, ++col] = "%s".printf(pi.full_name_with_alias);
			//grid[row, ++col] = "%s".printf(pi.uuid);
			grid[row, ++col] = "%s".printf((pi.size_bytes > 0) ? "%s GB".printf(pi.size) : "?? GB");
			grid[row, ++col] = "%s".printf(pi.fstype);
			grid[row, ++col] = "%s".printf(pi.label);
			row++;
		}

		print_grid(grid, right_align);
	}

	public void print_grid(string[,] grid, bool[] right_align, bool has_header = true){
		int[] col_width = new int[grid.length[1]];

		for(int col=0; col<grid.length[1]; col++){
			for(int row=0; row<grid.length[0]; row++){
				if (grid[row,col].length > col_width[col]){
					col_width[col] = grid[row,col].length;
				}
			}
		}

		for(int row=0; row<grid.length[0]; row++){
			for(int col=0; col<grid.length[1]; col++){
				string fmt = "%" + (right_align[col] ? "+" : "-") + col_width[col].to_string() + "s  ";
				stdout.printf(fmt.printf(grid[row,col]));
			}
			stdout.printf("\n");

			if (has_header && (row == 0)){
				stdout.printf(string.nfill(78, '-'));
				stdout.printf("\n");
			}
		}
	}

	public void list_grub_devices(bool print_to_console = true){
		//add devices
		grub_device_list = new Gee.ArrayList<Device>();
		foreach(Device di in get_block_devices()) {
			grub_device_list.add(di);
		}

		//add partitions
		foreach(Device pi in partitions) {
			if (!pi.has_linux_filesystem()) { continue; }
			if (pi.device.has_prefix("/dev/dm-")) { continue; }
			grub_device_list.add(pi);
		}

		/*Note: Lists are already sorted. No need to sort again */

		string[,] grid = new string[grub_device_list.size+1,4];
		bool[] right_align = { false, false, false, false };

		int row = 0;
		int col = -1;
		grid[row, ++col] = _("Num");
		grid[row, ++col] = "";
		grid[row, ++col] = _("Device");
		grid[row, ++col] = _("Description");
		row++;

		string desc = "";
		foreach(Device pi in grub_device_list) {
			col = -1;
			grid[row, ++col] = "%d".printf(row - 1);
			grid[row, ++col] = ">";
			grid[row, ++col] = "%s".printf(pi.short_name_with_alias);

			if (pi.devtype == "disk"){
				desc = "%s".printf(((pi.vendor.length > 0)||(pi.model.length > 0)) ? (pi.vendor + " " + pi.model  + " [MBR]") : "");
			}
			else{
				desc = "%5s, ".printf(pi.fstype);
				desc += "%10s".printf((pi.size_bytes > 0) ? "%s GB".printf(pi.size) : "?? GB");
				desc += "%s".printf((pi.label.length > 0) ? ", " + pi.label : "");
			}
			grid[row, ++col] = "%s".printf(desc);
			row++;
		}

		print_grid(grid, right_align);
	}

	//prompt for input

	public Device? read_stdin_device(Gee.ArrayList<Device> device_list){
		var counter = new TimeoutCounter();
		counter.exit_on_timeout();
		string? line = stdin.read_line();
		counter.stop();

		line = (line != null) ? line.strip() : "";

		Device selected_device = null;

		if (line.down() == "a"){
			log_msg(_("Aborted."));
			exit_app();
			exit(0);
		}
		else if ((line == null)||(line.length == 0)){
			log_error("Invalid input");
		}
		else if (line.contains("/")){
			selected_device = Device.get_device_by_name(line);
			if (selected_device == null){
				log_error("Invalid input");
			}
		}
		else{
			selected_device = get_device_from_index(device_list, line);
			if (selected_device == null){
				log_error("Invalid input");
			}
		}

		return selected_device;
	}

	public Device? read_stdin_device_mounts(Gee.ArrayList<Device> device_list, MountEntry mnt){
		var counter = new TimeoutCounter();
		counter.exit_on_timeout();
		string? line = stdin.read_line();
		counter.stop();

		line = (line != null) ? line.strip() : "";

		Device selected_device = null;

		if ((line == null)||(line.length == 0)||(line.down() == "c")||(line.down() == "d")){
			//set default
			if (mirror_system){
				return restore_target; //root device
			}
			else{
				return mnt.device; //keep current
			}
		}
		else if (line.down() == "a"){
			log_msg("Aborted.");
			exit_app();
			exit(0);
		}
		else if ((line.down() == "n")||(line.down() == "r")){
			return restore_target; //root device
		}
		else if (line.contains("/")){
			selected_device = Device.get_device_by_name(line);
			if (selected_device == null){
				log_error("Invalid input");
			}
		}
		else{
			selected_device = get_device_from_index(device_list, line);
			if (selected_device == null){
				log_error("Invalid input");
			}
		}

		return selected_device;
	}

	public Device? get_device_from_index(Gee.ArrayList<Device> device_list, string index_string){
		int64 index;
		if (int64.try_parse(index_string, out index)){
			int i = -1;
			foreach(Device pi in device_list) {
				if ((pi.devtype == "partition") && !pi.has_linux_filesystem()) { continue; }
				if (++i == index){
					return pi;
				}
			}
		}

		return null;
	}

	public Snapshot read_stdin_snapshot(){
		var counter = new TimeoutCounter();
		counter.exit_on_timeout();
		string? line = stdin.read_line();
		counter.stop();

		line = (line != null) ? line.strip() : "";

		Snapshot selected_snapshot = null;

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
			if ((snapshot_list_start_index + 10) < repo.snapshots.size){
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
				if (index < repo.snapshots.size){
					selected_snapshot = repo.snapshots[(int) index];
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
		var counter = new TimeoutCounter();
		counter.exit_on_timeout();
		string? line = stdin.read_line();
		counter.stop();

		line = (line != null) ? line.strip() : line;

		if ((line == null)||(line.length == 0)){
			log_error("Invalid input");
			return false;
		}
		else if (line.down() == "a"){
			log_msg("Aborted.");
			exit_app();
			exit(0);
			return true;
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
		var counter = new TimeoutCounter();
		counter.exit_on_timeout();
		
		string? line = stdin.read_line();
		counter.stop();

		line = (line != null) ? line.strip() : "";

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
	
	public bool is_scheduled{
		get{
			return _is_scheduled;
		}
		set{
			_is_scheduled = value;
		}
	}

	public bool live_system(){
		//return true;
		return (root_device == null);
	}

	//backup

	public bool take_snapshot (bool is_ondemand, string snapshot_comments, Gtk.Window? parent_win){
		bool status;
		bool update_symlinks = false;

		try
		{
			log_debug("checking btrfs volumes on root device...");
			
			if (App.check_btrfs_root_layout() == false){
				return false;
			}
		
			// create a timestamp
			DateTime now = new DateTime.now_local();

			log_debug("checking if snapshot device is mounted...");
			
			// mount_backup_device
			//if (!mount_backup_device(parent_win)){
				//return false;
			//}
			// TODO: check if needs to be mounted

			log_debug("checking snapshot device...");
			
			//check backup device
			string message, details;
			int status_code = check_backup_location(out message, out details);
			
			if (!is_ondemand){

				log_debug("is_ondemand: false");
				
				// check if first snapshot was taken
				if (status_code == 2){
					log_error(message);
					log_error(
						_("Please take the first snapshot by running 'sudo timeshift --backup-now'"));
					return false;
				}
			}

			// check space
			if ((status_code != SnapshotLocationStatus.HAS_SNAPSHOTS_HAS_SPACE)
				&& (status_code != SnapshotLocationStatus.NO_SNAPSHOTS_HAS_SPACE)){
					
				is_scheduled = false;
				//log_error(message);
				//log_error(details);
				//log_debug("space_check: Failed!");
				return false;
			}
			else{
				//log_debug("space_check: OK");
			}

			string snapshot_dir = path_combine(repo.snapshot_location, "timeshift/snapshots");
			
			// create snapshot root if missing
			var f = File.new_for_path(snapshot_dir);
			if (!f.query_exists()){
				log_debug("mkdir: %s".printf(snapshot_dir));
				f.make_directory_with_parents();
			}

			// ondemand
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
				Snapshot last_snapshot_boot = repo.get_latest_snapshot("boot");
				Snapshot last_snapshot_hourly = repo.get_latest_snapshot("hourly");
				Snapshot last_snapshot_daily = repo.get_latest_snapshot("daily");
				Snapshot last_snapshot_weekly = repo.get_latest_snapshot("weekly");
				Snapshot last_snapshot_monthly = repo.get_latest_snapshot("monthly");

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
				log_msg(_("Scheduled snapshots are disabled") + " - " + _("Nothing to do!"));
				cron_job_update();
			}

			repo.auto_remove();

			if (update_symlinks){
				repo.load_snapshots();
				repo.create_symlinks();
			}
		}
		catch(Error e){
			log_error (e.message);
			return false;
		}

		return true;
	}

	private string temp_tag;
	private DateTime temp_dt_created;
	private DateTime temp_dt_begin;
	
	public bool backup_and_rotate(string tag, DateTime dt_created){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val = -1;
		string msg;
		File f;

		//log_debug("backup_and_rotate()");
		
		temp_tag = tag;
		temp_dt_created = dt_created;
		
		string time_stamp = dt_created.format("%Y-%m-%d_%H-%M-%S");
		DateTime now = new DateTime.now_local();
		bool backup_taken = false;
		
		string sync_name = ".sync";
		string snapshot_dir = path_combine(repo.snapshot_location, "timeshift/snapshots");
		string sync_path = snapshot_dir + "/" + sync_name;

		try{

			DateTime dt_sys_boot = now.add_seconds((-1) * get_system_uptime_seconds());

			//check if we can rotate an existing backup -------------

			Snapshot last_snapshot = repo.get_latest_snapshot();
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

				Snapshot backup_to_rotate = null;
				foreach(var bak in repo.snapshots){
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

				log_debug("Creating new backup...");
				
				// take new backup ---------------------------------

				temp_dt_begin = new DateTime.now_local();

				string exclude_from_file = sync_path + "/exclude.list";

				/*
				Check if a control file was written after restore.
				If control file exists, we will delete the existing
				.sync snapshot and hard-link the restored snapshot to .sync.
				This will save disk space as the new snapshot will share
				almost all files with the restored snapshot.
				*/
				
				Snapshot bak_restore = null;
				string ctl_path = snapshot_dir + "/.sync-restore";

				f = File.new_for_path(ctl_path);
				if(f.query_exists()){
					string snapshot_path = file_read(ctl_path);

					// find the snapshot that was restored
					foreach(var bak in repo.snapshots){
						if (bak.path == snapshot_path){
							bak_restore = bak;
							break;
						}
					}

					// delete the restore-control-file
					f.delete();

					if (bak_restore != null){
						// delete the existing .sync snapshot

						f = File.new_for_path(sync_path);
						if(f.query_exists()){

							f = File.new_for_path(sync_path + "/info.json");
							if(!f.query_exists()){

								progress_text = _("Removing partially completed snapshot...");
								log_msg(progress_text);

								if (repo.remove_sync_dir()){
									return false;
								}
							}
						}

						// hard-link restored snapshot to .sync
						
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

				// create sync directory if missing

				dir_create(sync_path + "/localhost");
				
				// delete existing control file
				
				file_delete(sync_path + "/info.json");

				// save exclude list

				save_exclude_list(sync_path);

				// update modification date of .sync directory

				cmd = "touch \"%s\"".printf(sync_path);
				Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);

				if (LOG_COMMANDS) { log_debug(cmd); }

				if (ret_val != 0){
					log_error(std_err);
					log_error(_("Failed to update modification date"));
					return false;
				}

				// rsync file system with .sync

				progress_text = _("Synching files...");
				log_msg(progress_text);

				var log_file = sync_path + "/rsync-log";
				f = File.new_for_path(log_file);
				if (f.query_exists()){
					f.delete();
				}

				task = create_new_rsync_task();

				task.source_path = "";
				task.dest_path = sync_path + "/localhost/";
				task.exclude_from_file = exclude_from_file;
				task.rsync_log_file = log_file;

				if (app_mode.length > 0){
					// console mode
					task.io_nice = true;
				}

				task.execute();

				while (task.status == AppStatus.RUNNING){
					sleep(1000);
					gtk_do_events();
				}

				if (task.total_size == 0){
					log_error(_("rsync returned an error") + ": %d".printf(ret_val));
					log_error(_("Failed to create new snapshot"));
					return false;
				}

				// write control file ----------

				write_snapshot_control_file(sync_path, temp_dt_created, temp_tag);

				// rotate .sync to required level ----------

				progress_text = _("Saving snapshot...");
				log_msg(progress_text);

				string new_name = time_stamp;
				string new_path = snapshot_dir + "/" + new_name;

				cmd = "cp -alp \"%s\" \"%s\"".printf(sync_path, new_path);

				if (LOG_COMMANDS) { log_debug(cmd); }

				try{
					
					Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
					if (ret_val != 0){
						log_error(_("Failed to save snapshot") + ":'%s'".printf(new_name));
						log_error (std_err);
						return false;
					}
				}
				catch(Error e){
					log_error (e.message);
					return false;
				}

				DateTime dt_end = new DateTime.now_local();
				TimeSpan elapsed = dt_end.difference(temp_dt_begin);
				long seconds = (long)(elapsed * 1.0 / TimeSpan.SECOND);
				msg = _("Snapshot saved successfully") + " (%lds)".printf(seconds);
				log_msg(msg);
				OSDNotify.notify_send("TimeShift",msg,10000,"low");

				log_msg(_("Snapshot") + " '%s' ".printf(new_name)
					+ _("tagged") + " '%s'".printf(temp_tag));

				repo.load_snapshots();
			}
		}
		catch(Error e){
			log_error (e.message);
			return false;
		}

		return true;
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

			file_write(list_file,file_text);
		}
		catch (Error e) {
	        log_error (e.message);
	    }
	}

	public Snapshot write_snapshot_control_file(string snapshot_path, DateTime dt_created, string tag){
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

	    return (new Snapshot(snapshot_path));
	}

	//restore

	public void get_backup_device_from_cmd(bool prompt_if_empty, Gtk.Window? parent_win){
		if (cmd_backup_device.length > 0){
			//set backup device from command line argument
			var cmd_dev = Device.get_device_by_name(cmd_backup_device);
			if (cmd_dev != null){
				repo = new SnapshotStore.from_device(cmd_dev, null);
				if (!repo.is_available()){
					exit_app();
					exit(1);
				}
			}
			else{
				log_error(_("Could not find device") + ": '%s'".printf(cmd_backup_device));
				exit_app();
				exit(1);
			}
		}
		else{
			if ((repo.device == null) || (prompt_if_empty && (repo.snapshots.size == 0))){
				//prompt user for backup device
				log_msg("");

				log_msg(TERM_COLOR_YELLOW + _("Select backup device") + ":\n" + TERM_COLOR_RESET);
				list_devices();
				log_msg("");

				Device dev = null;
				int attempts = 0;
				while (dev == null){
					attempts++;
					if (attempts > 3) { break; }
					stdout.printf(TERM_COLOR_YELLOW +
						_("Enter device name or number (a=Abort)") + ": " + TERM_COLOR_RESET);
					stdout.flush();
					dev = read_stdin_device(partitions);
				}

				log_msg("");
				
				if (dev == null){
					log_error(_("Failed to get input from user in 3 attempts"));
					log_msg(_("Aborted."));
					exit_app();
					exit(0);
				}

				repo = new SnapshotStore.from_device(dev, null);
				if (!repo.is_available()){
					exit_app();
					exit(1);
				}
			}
		}
	}

	public bool restore_snapshot(Gtk.Window? parent_win){
		bool found = false;

		//set snapshot device -----------------------------------------------

		if (!mirror_system){
			if (repo.device != null){
				//print snapshot_device name
				log_msg(TERM_COLOR_YELLOW + string.nfill(78, '*') + TERM_COLOR_RESET);
				log_msg(_("Backup Device") + ": %s".printf(repo.device.device), true);
				log_msg(TERM_COLOR_YELLOW + string.nfill(78, '*') + TERM_COLOR_RESET);
				//mount_backup_device(parent_win);
				//repo.load_snapshots();
				//TODO: check if repo needs to be re-initialized
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
					foreach(var bak in repo.snapshots) {
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

					if (!repo.has_snapshots()){
						log_error(_("No snapshots found on device") + ": '%s'".printf(repo.device.device));
						return false;
					}

					log_msg("");
					log_msg(TERM_COLOR_YELLOW + _("Select snapshot to restore") + ":\n" + TERM_COLOR_RESET);
					list_snapshots(true);
					log_msg("");

					int attempts = 0;
					while (snapshot_to_restore == null){
						attempts++;
						if (attempts > 3) { break; }
						stdout.printf(TERM_COLOR_YELLOW + _("Enter snapshot number (a=Abort, p=Previous, n=Next)") + ": " + TERM_COLOR_RESET);
						stdout.flush();
						snapshot_to_restore = read_stdin_snapshot();
					}
					log_msg("");

					if (snapshot_to_restore == null){
						log_error(_("Failed to get input from user in 3 attempts"));
						log_msg(_("Aborted."));
						exit_app();
						exit(0);
					}
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
				foreach(Device pi in partitions) {
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
				log_msg(TERM_COLOR_YELLOW + _("Select target device") + " (/):\n" + TERM_COLOR_RESET);
				list_devices();
				log_msg("");

				int attempts = 0;
				while (restore_target == null){
					attempts++;
					if (attempts > 3) { break; }
					stdout.printf(TERM_COLOR_YELLOW + _("Enter device name or number (a=Abort)") + ": " + TERM_COLOR_RESET);
					stdout.flush();
					restore_target = read_stdin_device(partitions);
				}
				log_msg("");

				if (restore_target == null){
					log_error(_("Failed to get input from user in 3 attempts"));
					log_msg(_("Aborted."));
					exit_app();
					exit(0);
				}
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
			log_msg(_("Target Device") + ": %s".printf(restore_target.full_name_with_alias), true);
			log_msg(TERM_COLOR_YELLOW + string.nfill(78, '*') + TERM_COLOR_RESET);
		}
		else{
			//print error
			log_error(_("Target device not specified!"));
			return false;
		}

		//select other devices in mount_list --------------------

		if (app_mode != ""){ //command line mode
			init_mount_list();

			for(int i = mount_list.size - 1; i >= 0; i--){
				MountEntry mnt = mount_list[i];
				Device dev = null;
				string default_device = "";

				if (mnt.mount_point == "/"){ continue; }

				if (mirror_system){
					default_device = restore_target.device;
				}
				else{
					default_device = mnt.device.device;
				}

				//prompt user for device
				if (dev == null){
					log_msg("");
					log_msg(TERM_COLOR_YELLOW + _("Select '%s' device (default = %s)").printf(mnt.mount_point, default_device) + ":\n" + TERM_COLOR_RESET);
					list_devices();
					log_msg("");

					int attempts = 0;
					while (dev == null){
						attempts++;
						if (attempts > 3) { break; }
						stdout.printf(TERM_COLOR_YELLOW + _("[a = Abort, d = Default (%s), r = Root device]").printf(default_device) + "\n\n" + TERM_COLOR_RESET);
						stdout.printf(TERM_COLOR_YELLOW + _("Enter device name or number") + ": " + TERM_COLOR_RESET);
						stdout.flush();
						dev = read_stdin_device_mounts(partitions, mnt);
					}
					log_msg("");

					if (dev == null){
						log_error(_("Failed to get input from user in 3 attempts"));
						log_msg(_("Aborted."));
						exit_app();
						exit(0);
					}
				}

				if (dev != null){
					mnt.device = dev;
					if (dev.device == restore_target.device){
						mount_list.remove_at(i);
					}

					log_msg(TERM_COLOR_YELLOW + string.nfill(78, '*') + TERM_COLOR_RESET);
					if (dev.device == restore_target.device){
						log_msg(_("'%s' will be on root device").printf(mnt.mount_point), true);
					}
					else{
						log_msg(_("'%s' will be on '%s'").printf(mnt.mount_point, mnt.device.short_name_with_alias), true);
					}
					log_msg(TERM_COLOR_YELLOW + string.nfill(78, '*') + TERM_COLOR_RESET);
				}
			}
		}

		//mount selected devices ---------------------------------------

		if (restore_target != null){
			if (app_mode != ""){ //commandline mode
				//mount target device and other devices
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

				int attempts = 0;
				while ((cmd_skip_grub == false) && (reinstall_grub2 == false)){
					attempts++;
					if (attempts > 3) { break; }
					stdout.printf(TERM_COLOR_YELLOW + _("Re-install GRUB2 bootloader? (y/n)") + ": " + TERM_COLOR_RESET);
					stdout.flush();
					read_stdin_grub_install();
				}

				if ((cmd_skip_grub == false) && (reinstall_grub2 == false)){
					log_error(_("Failed to get input from user in 3 attempts"));
					log_msg(_("Aborted."));
					exit_app();
					exit(0);
				}
			}

			if ((reinstall_grub2) && (grub_device.length == 0)){
				log_msg("");
				log_msg(TERM_COLOR_YELLOW + _("Select GRUB device") + ":\n" + TERM_COLOR_RESET);
				list_grub_devices();
				log_msg("");

				int attempts = 0;
				while (grub_device.length == 0){
					attempts++;
					if (attempts > 3) { break; }
					stdout.printf(TERM_COLOR_YELLOW + _("Enter device name or number (a=Abort)") + ": " + TERM_COLOR_RESET);
					stdout.flush();
					Device dev = read_stdin_device(grub_device_list);
					if (dev != null) { grub_device = dev.device; }
				}
				log_msg("");

				if (grub_device.length == 0){
					log_error(_("Failed to get input from user in 3 attempts"));
					log_msg(_("Aborted."));
					exit_app();
					exit(0);
				}
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

			int attempts = 0;
			while (cmd_confirm == false){
				attempts++;
				if (attempts > 3) { break; }
				stdout.printf(TERM_COLOR_YELLOW + _("Continue with restore? (y/n): ") + TERM_COLOR_RESET);
				stdout.flush();
				read_stdin_restore_confirm();
			}

			if (cmd_confirm == false){
				log_error(_("Failed to get input from user in 3 attempts"));
				log_msg(_("Aborted."));
				exit_app();
				exit(0);
			}
		}

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

	public void init_mount_list(){
		mount_list.clear();

		Gee.ArrayList<FsTabEntry> fstab_list = null;
		if (mirror_system){
			string fstab_path = "/etc/fstab";
			fstab_list = FsTabEntry.read_fstab_file(fstab_path);
		}
		else{
			string fstab_path = snapshot_to_restore.path + "/localhost/etc/fstab";
			fstab_list = FsTabEntry.read_fstab_file(fstab_path);
		}

		foreach(FsTabEntry mnt in fstab_list){
			switch(mnt.mount_point){
				case "/":
				case "/boot":
				case "/home":
					Device mnt_dev = null;
					if (mnt.device.down().has_prefix("uuid=")){
						string uuid = mnt.device.down()["uuid=".length:mnt.device.length];
						mnt_dev = Device.find_device_in_list(partitions, "", uuid);
					}
					else{
						foreach(Device dev in partitions){
							if (dev.device == mnt.device){
								mnt_dev = dev;
								break;
							}
							else{
								foreach(string symlink in dev.symlinks){
									if (symlink == mnt.device){
										mnt_dev = dev;
										break;
									}
								}
								if (mnt_dev != null) { break; }
							}
						}
					}
					if (mnt_dev != null){
						mount_list.add(new MountEntry(mnt_dev, mnt.mount_point, ""));
					}
					break;
			}
		}

		/*foreach(MountEntry mnt in mount_list){
			log_msg("Entry:%s -> %s".printf(mnt.device.device,mnt.mount_point));
		}*/
	}

	// delete from terminal

	public bool delete_snapshot(Snapshot? snapshot = null){

		bool found = false;
		
		// set snapshot -----------------------------------------------

		if (app_mode != ""){ //command-line mode

			if (cmd_snapshot.length > 0){

				//check command line arguments
				found = false;
				foreach(var bak in repo.snapshots) {
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

				if (repo.snapshots.size == 0){
					log_msg(_("No snapshots found on device") +
						" '%s'".printf(repo.device.device));
					return false;
				}

				log_msg("");
				log_msg(TERM_COLOR_YELLOW + _("Select snapshot to delete") + ":\n" + TERM_COLOR_RESET);
				list_snapshots(true);
				log_msg("");

				int attempts = 0;
				while (snapshot_to_delete == null){
					attempts++;
					if (attempts > 3) { break; }
					stdout.printf(TERM_COLOR_YELLOW + _("Enter snapshot number (a=Abort, p=Previous, n=Next)") + ": " + TERM_COLOR_RESET);
					stdout.flush();
					snapshot_to_delete = read_stdin_snapshot();
				}
				log_msg("");

				if (snapshot_to_delete == null){
					log_error(_("Failed to get input from user in 3 attempts"));
					log_msg(_("Aborted."));
					exit_app();
					exit(0);
				}
			}
		}

		if (snapshot_to_delete == null){
			//print error
			log_error(_("Snapshot to delete not specified!"));
			return false;
		}

		return snapshot_to_delete.remove();
	}

	public bool delete_all_snapshots(){
		return repo.remove_all();
	}

	// todo: remove
	public Device unlock_encrypted_device(Device luks_device, Gtk.Window? parent_win){
		Device luks_unlocked = null;

		string mapped_name = "%s_unlocked".printf(luks_device.name);

		// check if already unlocked
		foreach(var part in partitions){
			if (part.pkname == luks_device.kname){
				log_msg(_("Unlocked device is mapped to '%s'").printf(part.device));
				log_msg("");
				return part;
			}
		}
			
		if ((parent_win == null) && (app_mode != "")){

			var counter = new TimeoutCounter();
			counter.kill_process_on_timeout("cryptsetup", 20, true);

			// prompt user to unlock
			string cmd = "cryptsetup luksOpen '%s' '%s'".printf(luks_device.device, mapped_name);
			Posix.system(cmd);
			counter.stop();
			log_msg("");

			update_partitions();

			// check if unlocked
			foreach(var part in partitions){
				if (part.pkname == luks_device.kname){
					log_msg(_("Unlocked device is mapped to '%s'").printf(part.name));
					log_msg("");
					return part;
				}
			}
		}
		else{
			// prompt user for password
			string passphrase = gtk_inputbox(
				_("Encrypted Device"),
				_("Enter passphrase to unlock '%s'").printf(luks_device.name),
				parent_win, true);

			string message, details;
			luks_unlocked = Device.luks_unlock(luks_device, mapped_name, passphrase,
				out message, out details);

			bool is_error = (luks_unlocked == null);
			
			gtk_messagebox(message,details,null,is_error);
		}

		return luks_unlocked;
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
					dir_create(source_path);
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
				string snapshot_dir = path_combine(repo.snapshot_location, "timeshift/snapshots");
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

				file_write(control_file_path, snapshot_to_restore.path); //save snapshot name
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
					temp_script = save_bash_script_temp(sh);

					//restore or clone
					var dlg = new TerminalWindow.with_parent(null);
					dlg.execute_script(temp_script, true);
					
				}
				else{
					//other system, gui
					string std_out, std_err;
					ret_val = exec_script_sync(sh, out std_out, out std_err);
					log_to_file(std_out);
					log_to_file(std_err);
				}
			}
			else{ //console
				if (cmd_verbose){
					//current/other system, console, verbose
					ret_val = exec_script_sync(sh);
					log_msg("");
				}
				else{
					//current/other system, console, quiet
					string std_out, std_err;
					ret_val = exec_script_sync(sh, out std_out, out std_err);
					log_to_file(std_out);
					log_to_file(std_err);
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
							fstab_entry.type = mount_entry.device.fstype;

							//fix mount options for / and /home
							if (restore_target.fstype != "btrfs"){
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
						fstab_entry.type = mount_entry.device.fstype;
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
				file_write(fstab_path, text);

				log_msg(_("Updated /etc/fstab on target device") + ": %s".printf(fstab_path));

				//create folders for mount points in /etc/fstab to prevent mount errors during boot ---------

				foreach(FsTabEntry fstab_entry in fstab_list){
					if (fstab_entry.mount_point.length == 0){ continue; }

					string mount_path = target_path + fstab_entry.mount_point[1:fstab_entry.mount_point.length];
					if (fstab_entry.is_comment || fstab_entry.is_empty_line || (mount_path.length == 0)){ continue; }

					if (!dir_exists(mount_path)){
						log_msg("Created mount point on target device: %s".printf(fstab_entry.mount_point));
						dir_create(mount_path);
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
					foreach(string path in file_read(list_file).split("\n")){
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

			file_write(list_file_restore,file_text);
		}
		catch (Error e) {
	        log_error (e.message);
	    }
	}

	//app config

	public void save_app_config(){
		var config = new Json.Object();
		//config.set_string_member("enabled", is_scheduled.to_string());

		config.set_string_member("backup_device_uuid",
			(repo.device == null) ? "" : repo.device.uuid);
			
		config.set_string_member("use_snapshot_path_custom", repo.use_snapshot_path_custom.to_string());
		config.set_string_member("snapshot_path_custom", repo.snapshot_path_user.to_string());

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
		//config.set_string_member("min_space", (minimum_free_disk_space / (1.0 * GB)).to_string());

		config.set_string_member("first_snapshot_size", first_snapshot_size.to_string());
		config.set_string_member("first_snapshot_count", first_snapshot_count.to_string());

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
		if (!f.query_exists()) {
			first_run = true;
			repo = new SnapshotStore.from_device(root_device, null);
			return;
		}

		var parser = new Json.Parser();
        try{
			parser.load_from_file(this.app_conf_path);
		} catch (Error e) {
	        log_error (e.message);
	    }
        var node = parser.get_root();
        var config = node.get_object();

		// initialize repo using config file values

		string uuid = json_get_string(config,"backup_device_uuid","");
        var snapshot_path = json_get_string(config, "snapshot_path", "");
		var use_snapshot_path = json_get_bool(config, "use_snapshot_path", false);
		
		if (use_snapshot_path){
			repo = new SnapshotStore.from_path(snapshot_path, null);
			repo.check_status();
		}
		else{
			var dev = Device.get_device_by_uuid(uuid);
			if (dev == null){
				dev = new Device();
				dev.uuid = uuid;
			}
			repo = new SnapshotStore.from_device(dev, null);
			//repo.check_status();
			// TODO: move this code to main window
		}

		//TODO; repo.check_status() should not use App

		// initialize repo using command line parameter
		 
		if (cmd_backup_device.length > 0){
			var cmd_dev = Device.get_device_by_name(cmd_backup_device);
			if (cmd_dev != null){
				repo = new SnapshotStore.from_device(cmd_dev, null);
				// TODO: move this code to main window
			}
			else{
				log_error(_("Could not find device") + ": '%s'".printf(cmd_backup_device));
				exit_app();
				exit(1);
			}
		}

		/* Note: In command-line mode, user will be prompted for backup device */

		/* The backup device specified in config file will be mounted at this point if:
		 * 1) app is running in GUI mode, OR
		 * 2) app is running command mode without backup device argument
		 * */

		//if (snapshot_device != null){
			//if ((app_mode == "") || (cmd_backup_device.length == 0)){
				//if (mount_backup_device(null)){
				//	update_partitions();
				//}
				//else{
				//	snapshot_device = null;
				//}
			//}
			// TODO: mount separately
		//}

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
		//this.minimum_free_disk_space = json_get_int64(config,"min_space",minimum_free_disk_space);
		//this.minimum_free_disk_space = this.minimum_free_disk_space * GB;
		
		this.first_snapshot_size = json_get_int64(config,"first_snapshot_size",first_snapshot_size);
		this.first_snapshot_count = json_get_int64(config,"first_snapshot_count",first_snapshot_count);
		
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

	public void update_partitions(){
		partitions.clear();
		partitions = Device.get_filesystems();

		foreach(Device pi in partitions){
			//root_device and home_device will be detected by detect_system_devices()
			if ((repo.device != null) && (pi.uuid == repo.device.uuid)){
				repo.device = pi;
			}
			if (pi.is_mounted){
				pi.dist_info = LinuxDistro.get_dist_info(pi.mount_points[0].mount_point).full_name();
			}
		}
		if (partitions.size == 0){
			log_error("ts: " + _("Failed to get partition list."));
		}

		//log_debug(_("Partition list updated"));
	}

	public void detect_system_devices(){
		foreach(Device pi in partitions){
			foreach(var mp in pi.mount_points){
				if (mp.mount_point == "/"){
					root_device = pi;
					if ((app_mode == "")||(LOG_DEBUG)){
						log_msg(_("/ is mapped to device: %s, UUID=%s").printf(pi.device,pi.uuid));
					}
				}

				if (mp.mount_point == "/home"){
					home_device = pi;
					if ((app_mode == "")||(LOG_DEBUG)){
						log_msg(_("/home is mapped to device: %s, UUID=%s").printf(pi.device,pi.uuid));
					}
				}
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
			dir_create(mount_point_restore);

			//unlock encrypted device
			if (restore_target.is_encrypted()){
				restore_target = unlock_encrypted_device(restore_target, parent_win);

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
			if (restore_target.fstype == "btrfs"){

				//check subvolume layout
				if (!check_btrfs_volume(restore_target) && snapshot_to_restore.has_subvolumes()){
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
				if (!Device.mount(restore_target.uuid, mount_point_restore, "subvol=@")){
					log_error(_("Failed to mount BTRFS subvolume") + ": @");
					return false;
				}

				//mount @home
				if (!Device.mount(restore_target.uuid, mount_point_restore + "/home", "subvol=@home")){
					log_error(_("Failed to mount BTRFS subvolume") + ": @home");
					return false;
				}
			}
			else{
				if (!Device.mount(restore_target.uuid, mount_point_restore, "")){
					return false;
				}
			}

			//mount remaining devices
			foreach (MountEntry mnt in mount_list) {
				if (mnt.mount_point != "/"){

					//unlock encrypted device
					if (mnt.device.is_encrypted()){
						mnt.device = unlock_encrypted_device(mnt.device, parent_win);

						//exit if not found
						if (mnt.device == null){
							return false;
						}
					}

					if (!Device.mount(mnt.device.uuid, mount_point_restore + mnt.mount_point)){
						return false;
					}
				}
			}
		}

		return true;
	}

	public void unmount_target_device(bool exit_on_error = true){
		if (mount_point_restore == null) { return; }
		
		//unmount the target device only if it was mounted by application
		if (mount_point_restore.has_prefix(mount_point_app)){   //always true
			unmount_device(mount_point_restore,exit_on_error);
		}
		else{
			//don't unmount
		}
	}

	public bool unmount_device(string mount_point, bool exit_on_error = true){
		bool is_unmounted = Device.unmount(mount_point);
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

	public SnapshotLocationStatus check_backup_location(out string message, out string details){
		repo.check_status();
		message = repo.status_message;
		details = repo.status_details;
		return repo.status_code;
	}

	public bool check_btrfs_volume(Device dev){
		string mnt_btrfs = mount_point_app + "/btrfs";
		dir_create(mnt_btrfs);

		Device.unmount(mnt_btrfs);
		Device.mount(dev.uuid, mnt_btrfs);

		bool is_supported = dir_exists(mnt_btrfs + "/@") && dir_exists(mnt_btrfs + "/@home");

		if (Device.unmount(mnt_btrfs)){
			if (dir_exists(mnt_btrfs) && (dir_count(mnt_btrfs) == 0)){
				file_delete(mnt_btrfs);
				log_debug(_("Removed mount directory: '%s'").printf(mnt_btrfs));
			}
		}

		return is_supported;
	}

	public bool backup_device_online(){
		/*if (snapshot_device != null){
			//mount_backup_device(null);
			if (Device.get_device_mount_points(snapshot_device.uuid).size > 0){
				return true;
			}
		}*/

		string message, details;
		var status = App.check_backup_location(out message, out details);

		switch(status){
		case SnapshotLocationStatus.NO_SNAPSHOTS_HAS_SPACE:
		case SnapshotLocationStatus.NO_SNAPSHOTS_NO_SPACE:
		case SnapshotLocationStatus.HAS_SNAPSHOTS_HAS_SPACE:
		case SnapshotLocationStatus.HAS_SNAPSHOTS_NO_SPACE:
			return true;
		default:
			//gtk_messagebox(message,details, this, true);
			return false;
		}
		//return false;
	}

	public int64 calculate_size_of_first_snapshot(){

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
		int64 required_space = 0;
		int64 file_count = 0;

		try{

			log_msg("Using temp dir '%s'".printf(TEMP_DIR));

			string file_exclude_list = path_combine(TEMP_DIR, "exclude.list");
			var f = File.new_for_path(file_exclude_list);
			if (f.query_exists()){
				f.delete();
			}

			string file_log = path_combine(TEMP_DIR, "rsync.log");
			f = File.new_for_path(file_log);
			if (f.query_exists()){
				f.delete();
			}

			string dir_empty = path_combine(TEMP_DIR, "empty");
			f = File.new_for_path(dir_empty);
			if (!f.query_exists()){
				dir_create(dir_empty);
			}

			save_exclude_list(TEMP_DIR);
			
			cmd  = "LC_ALL=C ; rsync -ai --delete --numeric-ids --relative --stats --dry-run --delete-excluded --exclude-from='%s' /. '%s' &> '%s'".printf(file_exclude_list, dir_empty, file_log);

			log_debug(cmd);
			ret_val = exec_script_sync(cmd, out std_out, out std_err);

			if (file_exists(file_log)){
				cmd = "cat '%s' | awk '/Total file size/ {print $4}'".printf(file_log);
				ret_val = exec_script_sync(cmd, out std_out, out std_err);
				if (ret_val == 0){
					required_space = long.parse(std_out.replace(",","").strip());

					cmd = "wc -l '%s'".printf(escape_single_quote(file_log));
					ret_val = exec_script_sync(cmd, out std_out, out std_err);
					if (ret_val == 0){
						file_count = long.parse(std_out.split(" ")[0].strip());
					}
					
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
				log_error (std_out);
				thr_success = false;
			}
		}
		catch(Error e){
			log_error (e.message);
			thr_success = false;
		}

		if ((required_space == 0) && (root_device != null)){
			required_space = root_device.used_bytes;
		}

		this.first_snapshot_size = required_space;
		this.first_snapshot_count = file_count;

		log_debug("First snapshot size: %s".printf(format_file_size(required_space)));
		log_debug("File count: %lld".printf(first_snapshot_count));

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
		if (is_scheduled){
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
		if (is_scheduled){
			if (schedule_boot || schedule_hourly
				|| schedule_daily || schedule_weekly || schedule_monthly){
					
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

	public bool crontab_remove(string line){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		cmd = "crontab -l | sed '/%s/d' | crontab -".printf(line);
		ret_val = exec_script_sync(cmd, out std_out, out std_err);

		if (ret_val != 0){
			log_error(std_err);
			return false;
		}
		else{
			return true;
		}
	}

	public bool crontab_add(string entry){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			string crontab = crontab_read_all();
			crontab += crontab.has_suffix("\n") ? "" : "\n";
			crontab += entry + "\n";

			//remove empty lines
			crontab = crontab.replace("\n\n","\n"); //remove empty lines in middle
			crontab = crontab.has_prefix("\n") ? crontab[1:crontab.length] : crontab; //remove empty lines in beginning

			string temp_file = get_temp_file_path();
			file_write(temp_file, crontab);

			cmd = "crontab \"%s\"".printf(temp_file);
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);

			if (ret_val != 0){
				log_error(std_err);
				return false;
			}
			else{
				return true;
			}
		}
		catch(Error e){
			log_error (e.message);
			return false;
		}
	}

	public string crontab_read_all(){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try {
			cmd = "crontab -l";
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
			if (ret_val != 0){
				log_debug(_("Crontab is empty"));
				return "";
			}
			else{
				return std_out;
			}
		}
		catch (Error e){
			log_error (e.message);
			return "";
		}
	}

	public string crontab_read_entry(string search_string, bool use_regex_matching = false){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			Regex rex = null;
			MatchInfo match;
			if (use_regex_matching){
				rex = new Regex(search_string);
			}

			cmd = "crontab -l";
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
			if (ret_val != 0){
				log_debug(_("Crontab is empty"));
			}
			else{
				foreach(string line in std_out.split("\n")){
					if (use_regex_matching && (rex != null)){
						if (rex.match (line, 0, out match)){
							return line.strip();
						}
					}
					else {
						if (line.contains(search_string)){
							return line.strip();
						}
					}
				}
			}

			return "";
		}
		catch(Error e){
			log_error (e.message);
			return "";
		}
	}

	// TODO: Use the new CronTab class

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

			CompareDataFunc<string> compare_func = (a, b) => {
				return strcmp(a,b);
			};

			list.sort((owned) compare_func);

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

		unmount_target_device(false);

		clean_logs();

		app_lock.remove();

		//Gtk.main_quit ();
	}

	public bool is_rsync_running(){
		string cmd = "rsync -ai --delete --numeric-ids --relative --delete-excluded";
		string std_out, std_err;
		exec_sync("ps w -C rsync", out std_out, out std_err);
		foreach(string line in std_out.split("\n")){
			if (line.index_of(cmd) != -1){
				return true;
			}
		}
		return false;
	}

	public void kill_rsync(){
		string cmd = "rsync -ai --delete --numeric-ids --relative --delete-excluded";

		string std_out, std_err;
		exec_sync ("ps w -C rsync", out std_out, out std_err);
		string pid = "";
		foreach(string line in std_out.split("\n")){
			if (line.index_of(cmd) != -1){
				pid = line.strip().split(" ")[0];
				Posix.kill ((Pid) int.parse(pid), 15);
				log_msg(_("Terminating rsync process") + ": [PID=" + pid + "] ");
			}
		}
	}

}

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

public enum SnapshotLocationStatus{
	/*
	-1 - device un-available, path does not exist
	 0 - first snapshot taken, disk space sufficient
	 1 - first snapshot taken, disk space not sufficient
	 2 - first snapshot not taken, disk space not sufficient
	 3 - first snapshot not taken, disk space sufficient
	 4 - path is readonly
     5 - hardlinks not supported
	*/
	NOT_SELECTED = -2,
	NOT_AVAILABLE = -1,
	HAS_SNAPSHOTS_HAS_SPACE = 0,
	HAS_SNAPSHOTS_NO_SPACE = 1,
	NO_SNAPSHOTS_NO_SPACE = 2,
	NO_SNAPSHOTS_HAS_SPACE = 3,
	READ_ONLY_FS = 4,
	HARDLINKS_NOT_SUPPORTED = 5
}

public class SnapshotStore : GLib.Object{
	public Device device = null;
	public string snapshot_path_user = "";
	public string snapshot_path_mount = "";
	public bool use_snapshot_path_custom = false;

	public Gee.ArrayList<Snapshot?> snapshots;

	public string status_message = "";
	public string status_details = "";
	public SnapshotLocationStatus status_code;

	// private
	private Gtk.Window? parent_window = null;
	private bool thr_success = false;
	private bool thr_running = false;
	//private int thr_retval = -1;
	private string thr_args1 = "";

	public SnapshotStore.from_path(string path, Gtk.Window? parent_win){
		this.snapshot_path_user = path;
		this.use_snapshot_path_custom = true;
		this.parent_window = parent_win;
		
		snapshots = new Gee.ArrayList<Snapshot>();

		log_msg(_("Selected snapshot path") + ": %s".printf(path));
		
		var list = Device.get_disk_space_using_df(path);
		if (list.size > 0){
			device = list[0];
			
			log_msg(_("Device") + ": %s".printf(device.device));
			log_msg(_("Free space") + ": %s".printf(format_file_size(device.free_bytes)));
		}
	}

	public SnapshotStore.from_device(Device dev, Gtk.Window? parent_win){
		this.device = dev;
		this.use_snapshot_path_custom = false;
		this.parent_window = parent_win;
		
		snapshots = new Gee.ArrayList<Snapshot>();

		if ((dev != null) && (dev.uuid.length > 0)){
			log_msg("");
			unlock_and_mount_device();

			log_msg(_("Selected snapshot device") + ": %s".printf(device.device));
			log_msg(_("Free space") + ": %s".printf(format_file_size(device.free_bytes)));;
		}
	}

	public string snapshot_location {
		owned get{
			if (use_snapshot_path_custom && dir_exists(snapshot_path_user)){
				return snapshot_path_user;
			}
			else{
				return snapshot_path_mount;
			}
		}
	}

	// load

	public bool unlock_and_mount_device(){
		
		// unlock encrypted device
		if (device.is_encrypted()){

			device = unlock_encrypted_device(device);
			
			if (device == null){
				return false;
			}
		}

		if (device.fstype == "btrfs"){

			snapshot_path_mount = "/mnt/timeshift/backup";
			
			Device.unmount(snapshot_path_mount);
			
			// mount
			
			bool ok = Device.mount(device.uuid, snapshot_path_mount, "");
			if (!ok){
				snapshot_path_mount = "";
			}
		}
		else{
			var mps = Device.get_device_mount_points(device.uuid);

			if (mps.size > 0){
				snapshot_path_mount = mps[0].mount_point;
			}
			else{
				Device.automount_udisks(device.device);

				mps = Device.get_device_mount_points(device.uuid);
				if (mps.size > 0){
					snapshot_path_mount = mps[0].mount_point;
				}
				else{
					snapshot_path_mount = "";
				}
			}
		}
		
		return false;
	}

	public Device unlock_encrypted_device(Device luks_device){
		Device luks_unlocked = null;

		string mapped_name = "%s_unlocked".printf(luks_device.name);

		var partitions = Device.get_block_devices_using_lsblk();
		
		// check if already unlocked
		foreach(var part in partitions){
			if (part.pkname == luks_device.kname){
				log_msg(_("Unlocked device is mapped to '%s'").printf(part.device));
				log_msg("");
				return part;
			}
		}
			
		if (parent_window == null){

			var counter = new TimeoutCounter();
			counter.kill_process_on_timeout("cryptsetup", 20, true);

			// prompt user to unlock
			string cmd = "cryptsetup luksOpen '%s' '%s'".printf(luks_device.device, mapped_name);
			Posix.system(cmd);
			counter.stop();
			log_msg("");

			partitions = Device.get_block_devices_using_lsblk();

			// check if unlocked
			foreach(var part in partitions){
				if (part.pkname == luks_device.kname){
					log_msg(_("Unlocked device is mapped to '%s'").printf(part.name));
					log_msg("");
					return part;
				}
			}
		}
		else{
			// prompt user for password
			string passphrase = gtk_inputbox(
				_("Encrypted Device"),
				_("Enter passphrase to unlock '%s'").printf(luks_device.name),
				parent_window, true);

			string message, details;
			luks_unlocked = Device.luks_unlock(luks_device, mapped_name, passphrase,
				out message, out details);

			bool is_error = (luks_unlocked == null);
			
			gtk_messagebox(message, details, null, is_error);
		}

		return luks_unlocked;
	}
	
	public bool load_snapshots(){

		snapshots.clear();

		string path = snapshot_location + "/timeshift/snapshots";

		if (!dir_exists(path)){
			log_error("Path not found: %s".printf(path));
			return false;
		}

		try{
			var dir = File.new_for_path (path);
			var enumerator = dir.enumerate_children ("*", 0);

			var info = enumerator.next_file ();
			while (info != null) {
				if (info.get_file_type() == FileType.DIRECTORY) {
					if (info.get_name() != ".sync") {
						Snapshot bak = new Snapshot(path + "/" + info.get_name());
						if (bak.is_valid){
							snapshots.add(bak);
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

		snapshots.sort((a,b) => {
			Snapshot t1 = (Snapshot) a;
			Snapshot t2 = (Snapshot) b;
			return t1.date.compare(t2.date);
		});

		return true;
	}

	// get tagged snapshots
	
	public Gee.ArrayList<Snapshot?> get_snapshots_by_tag(string tag = ""){
		var list = new Gee.ArrayList<Snapshot?>();

		foreach(Snapshot bak in snapshots){
			if (tag == "" || bak.has_tag(tag)){
				list.add(bak);
			}
		}
		list.sort((a,b) => {
			Snapshot t1 = (Snapshot) a;
			Snapshot t2 = (Snapshot) b;
			return (t1.date.compare(t2.date));
		});

		return list;
	}

	public Snapshot? get_latest_snapshot(string tag = ""){
		var list = get_snapshots_by_tag(tag);

		if (list.size > 0)
			return list[list.size - 1];
		else
			return null;
	}

	public Snapshot? get_oldest_snapshot(string tag = ""){
		var list = get_snapshots_by_tag(tag);

		if (list.size > 0)
			return list[0];
		else
			return null;
	}

	// status check

	public void check_status(){

		status_code = SnapshotLocationStatus.HAS_SNAPSHOTS_HAS_SPACE;
		status_message = "";
		status_details = "";

		log_msg("");
		log_msg("Config: Free space limit is %s".printf(
			format_file_size(App.minimum_free_disk_space)));

		if (is_available()){
			has_snapshots();
			has_space();
		}

		if (use_snapshot_path_custom){
			log_msg("Custom path is selected for snapshot location");
		}
		
		log_msg(_("Snapshot device") + ": '%s'".printf(
			(device == null) ? " UNKNOWN" : device.device));
			
		log_msg(_("Snapshot location") + ": '%s'".printf(snapshot_location));

		log_msg(status_message);
		log_msg(status_details);
		
		log_msg("Status: %s".printf(
			status_code.to_string().replace("SNAPSHOT_LOCATION_STATUS_","")));
	}

	public bool is_available(){
		if (use_snapshot_path_custom){
			if (snapshot_path_user.strip().length == 0){
				status_message = _("Snapshot location not selected");
				status_details = _("Select the location for saving snapshots");
				status_code = SnapshotLocationStatus.NOT_SELECTED;
				return false;
			}
			else{
				if (!dir_exists(snapshot_path_user)){
					status_message = _("Snapshot location not available!");
					status_details = _("Path not found") + ": '%s'".printf(snapshot_path_user);
					status_code = SnapshotLocationStatus.NOT_AVAILABLE;
					return false;
				}
				else{
					bool is_readonly;
					bool hardlink_supported =
						filesystem_supports_hardlinks(snapshot_path_user, out is_readonly);

					if (is_readonly){
						status_message = _("File system is read-only!");
						status_details = _("Select another location for saving snapshots");
						status_code = SnapshotLocationStatus.READ_ONLY_FS;
						return false;
					}
					else if (!hardlink_supported){
						status_message = _("File system does not support hard-links!");
						status_details = _("Select another location for saving snapshots");
						status_code = SnapshotLocationStatus.HARDLINKS_NOT_SUPPORTED;
						return false;
					}
					else{
						// ok
						return true;
					}
				}
			}
		}
		else{
			if (device == null){
				status_message = _("Snapshot location not selected");
				status_details = _("Select the location for saving snapshots");
				status_code = SnapshotLocationStatus.NOT_SELECTED;
				return false;
			}
			else if (device.device.length == 0){
				status_message = _("Snapshot location not available!");
				status_details = _("Device not found") + ": UUID='%s'".printf(device.uuid);
				status_code = SnapshotLocationStatus.NOT_AVAILABLE;
				return false;
			}
			else{
				// ok
				return true;
			}
		}
	}
	
	public bool has_snapshots(){
		load_snapshots();
		return (snapshots.size > 0);
	}

	public bool has_space(){

		if (device != null){
			device.query_disk_space();
		}
		
		if (snapshots.size > 0){
			// has snapshots, check minimum space

			var min_free = App.minimum_free_disk_space;
			
			if (device.free_bytes < min_free){
				status_message = _("Not enough disk space");
				status_message += " (< %s)".printf(format_file_size(min_free));
					
				status_details = _("Select another device or free up some space");
				
				status_code = SnapshotLocationStatus.HAS_SNAPSHOTS_NO_SPACE;
				return false;
			}
			else{
				//ok
				status_message = "ok";
				
				status_details = _("%d snapshots, %s free").printf(
					snapshots.size, format_file_size(device.free_bytes));
					
				status_code = SnapshotLocationStatus.HAS_SNAPSHOTS_HAS_SPACE;
				return true;
			}
		}
		else {

			// no snapshots, check estimated space
			
			var required_space = App.first_snapshot_size;

			if (device.free_bytes < required_space){
				status_message = _("Not enough disk space");
				status_message += " (< %s)".printf(format_file_size(required_space));
				
				status_details = _("Select another device or free up some space");
				
				status_code = SnapshotLocationStatus.NO_SNAPSHOTS_NO_SPACE;
				return false;
			}
			else{
				status_message = _("No snapshots on this device");
				
				status_details = _("First snapshot requires:");
				status_details += " %s".printf(format_file_size(required_space));
				
				status_code = SnapshotLocationStatus.NO_SNAPSHOTS_HAS_SPACE;
				return true;
			}
		}
	}

	// actions

	public void auto_remove(){
		DateTime now = new DateTime.now_local();
		int count = 0;
		bool show_msg = false;
		DateTime dt_limit;

		// delete older backups - boot ---------------

		var list = get_snapshots_by_tag("boot");

		if (list.size > App.count_boot){
			log_msg(_("Maximum backups exceeded for backup level") + " '%s'".printf("boot"));
			while (list.size > App.count_boot){
				list[0].remove_tag("boot");
				log_msg(_("Snapshot") + " '%s' ".printf(list[0].name) + _("un-tagged") + " '%s'".printf("boot"));
				list = get_snapshots_by_tag("boot");
			}
		}

		// delete older backups - hourly, daily, weekly, monthly ---------

		string[] levels = { "hourly","daily","weekly","monthly" };

		foreach(string level in levels){
			list = get_snapshots_by_tag(level);

			if (list.size == 0) { continue; }

			switch (level){
				case "hourly":
					dt_limit = now.add_hours(-1 * App.count_hourly);
					break;
				case "daily":
					dt_limit = now.add_days(-1 * App.count_daily);
					break;
				case "weekly":
					dt_limit = now.add_weeks(-1 * App.count_weekly);
					break;
				case "monthly":
					dt_limit = now.add_months(-1 * App.count_monthly);
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
					list = get_snapshots_by_tag(level);
				}
			}
		}

		// delete older backups - max days -------

		show_msg = true;
		count = 0;
		foreach(var bak in snapshots){
			if (bak.date.compare(now.add_days(-1 * App.retain_snapshots_max_days)) < 0){
				if (!bak.has_tag("ondemand")){

					if (show_msg){
						log_msg(_("Removing backups older than") + " %d ".printf(
							App.retain_snapshots_max_days) + _("days..."));
						show_msg = false;
					}

					log_msg(_("Snapshot") + " '%s' ".printf(bak.name) + _("un-tagged"));
					bak.tags.clear();
					count++;
				}
			}
		}

		remove_untagged();

		// delete older backups - minimum space -------

		device.query_disk_space();

		show_msg = true;
		count = 0;
		while ((device.size_bytes - device.used_bytes) < App.minimum_free_disk_space){
			
			load_snapshots();
			
			if (snapshots.size > 0){
				if (!snapshots[0].has_tag("ondemand")){

					if (show_msg){
						log_msg(_("Free space is less than") + " %lld GB".printf(
							App.minimum_free_disk_space / GB));
						log_msg(_("Removing older backups to free disk space"));
						show_msg = false;
					}

					snapshots[0].remove();
				}
			}
			
			device.query_disk_space();
		}
	}

	public void remove_untagged(){
		bool show_msg = true;

		foreach(Snapshot bak in snapshots){
			if (bak.tags.size == 0){

				if (show_msg){
					log_msg(_("Removing un-tagged snapshots..."));
					show_msg = false;
				}

				bak.remove();
			}
		}
	}

	public bool remove_all(){
		string timeshift_dir = snapshot_location + "/timeshift";
		string sync_dir = snapshot_location + "/timeshift/snapshots/.sync";

		if (dir_exists(timeshift_dir)){
			//delete snapshots
			foreach(var bak in snapshots){
				if (!bak.remove()){
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
			log_msg(_("No snapshots found") + " '%s'".printf(snapshot_location));
			return true;
		}
	}

	public bool remove_sync_dir(){
		string sync_dir = snapshot_location + "/timeshift/snapshots/.sync";
		//delete .sync
		if (dir_exists(sync_dir)){
			if (!delete_directory(sync_dir)){
				return false;
			}
		}
		
		return true;
	}
	
	// private
	
	private bool delete_directory(string dir_path){
		thr_args1 = dir_path;

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

		thr_args1 = null;

		return thr_success;
	}

	private void delete_directory_thread(){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			var f = File.new_for_path(thr_args1);
			if(f.query_exists()){
				cmd = "rm -rf \"%s\"".printf(thr_args1);

				if (LOG_COMMANDS) { log_debug(cmd); }

				Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);

				if (ret_val != 0){
					log_error(_("Failed to remove") + ": '%s'".printf(thr_args1));
					thr_success = false;
					thr_running = false;
					return;
				}
				else{
					log_msg(_("Removed") + ": '%s'".printf(thr_args1));
					thr_success = true;
					thr_running = false;
					return;
				}
			}
			else{
				log_error(_("Directory not found") + ": '%s'".printf(thr_args1));
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

	// symlinks
	
	public void create_symlinks(){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		cleanup_symlink_dir("boot");
		cleanup_symlink_dir("hourly");
		cleanup_symlink_dir("daily");
		cleanup_symlink_dir("weekly");
		cleanup_symlink_dir("monthly");
		cleanup_symlink_dir("ondemand");

		string path;

		foreach(var bak in snapshots){
			foreach(string tag in bak.tags){
				
				path = snapshot_location + "/timeshift/snapshots-%s".printf(tag);
				cmd = "ln --symbolic \"../snapshots/%s\" -t \"%s\"".printf(bak.name, path);

				if (LOG_COMMANDS) { log_debug(cmd); }

				ret_val = exec_sync(cmd, out std_out, out std_err);
				if (ret_val != 0){
					log_error (std_err);
					log_error(_("Failed to create symlinks") + ": snapshots-%s".printf(tag));
					return;
				}
			}
		}

		log_debug (_("Symlinks updated"));
	}

	public void cleanup_symlink_dir(string tag){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			string path = snapshot_location + "/timeshift/snapshots-%s".printf(tag);
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

}

