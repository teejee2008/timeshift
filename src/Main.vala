/*
 * Main.vala
 *
 * Copyright 2016 Tony George <teejeetech@gmail.com>
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
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public Main App;
public const string AppName = "Timeshift RSYNC";
public const string AppShortName = "timeshift";
public const string AppVersion = "16.10.3";
public const string AppAuthor = "Tony George";
public const string AppAuthorEmail = "teejeetech@gmail.com";

const string GETTEXT_PACKAGE = "";
const string LOCALE_DIR = "/usr/share/locale";

extern void exit(int exit_code);

public class Main : GLib.Object{
	public string app_path = "";
	public string share_folder = "";
	public string rsnapshot_conf_path = "";
	public string app_conf_path = "";
	public bool first_run = false;

	public string backup_uuid = "";
	public string backup_parent_uuid = "";
	
	public Gee.ArrayList<Device> partitions;

	public Gee.ArrayList<string> exclude_list_user;
	public Gee.ArrayList<string> exclude_list_default;
	public Gee.ArrayList<string> exclude_list_default_extra;
	public Gee.ArrayList<string> exclude_list_home;
	public Gee.ArrayList<string> exclude_list_restore;
	public Gee.ArrayList<AppExcludeEntry> exclude_list_apps;
	public Gee.ArrayList<MountEntry> mount_list;
	public Gee.ArrayList<string> exclude_app_names;
	
	public SnapshotRepo repo; 

	//temp
	//private Gee.ArrayList<Device> grub_device_list;

	public Device sys_root;
	public Device sys_boot;
	public Device sys_efi;
	public Device sys_home;

	public string mount_point_restore = "";
	public string mount_point_app = "/mnt/timeshift";

	public LinuxDistro current_distro;
	public bool mirror_system = false;

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
	
	public bool thread_estimate_running = false;
	public bool thread_estimate_success = false;
	
	public bool thread_restore_running = false;
	public bool thread_restore_success = false;

	public bool thread_delete_running = false;
	public bool thread_delete_success = false;
			
	public int thr_retval = -1;
	public string thr_arg1 = "";
	public bool thr_timeout_active = false;
	public string thr_timeout_cmd = "";

	public int startup_delay_interval_mins = 10;
	public int retain_snapshots_max_days = 200;
	
	public int64 snapshot_location_free_space = 0;

	public const int SHIELD_ICON_SIZE = 64;
	public const int64 MIN_FREE_SPACE = 1 * GB;
	public static int64 first_snapshot_size = 0;
	public static int64 first_snapshot_count = 0;
	
	public string log_dir = "";
	public string log_file = "";
	public AppLock app_lock;

	public Gee.ArrayList<Snapshot> delete_list;
	
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

	public RsyncTask task;
	public DeleteFileTask delete_file_task;

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
		log_debug("setting locale...");
		Intl.setlocale(GLib.LocaleCategory.MESSAGES, "timeshift");
		Intl.textdomain(GETTEXT_PACKAGE);
		Intl.bind_textdomain_codeset(GETTEXT_PACKAGE, "utf-8");
		Intl.bindtextdomain(GETTEXT_PACKAGE, LOCALE_DIR);
	}

	public Main(string[] args){

		log_debug("Main()");
		
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
			string suffix = (app_mode.length == 0) ? "_gui" : "_" + app_mode;
			
			DateTime now = new DateTime.now_local();
			log_dir = "/var/log/timeshift";
			log_file = path_combine(log_dir,
				"%s_%s.log".printf(now.format("%Y-%m-%d_%H-%M-%S"), suffix));

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

		log_msg("");
		log_msg(_("Running") + " %s v%s".printf(AppName, AppVersion));
		
		//get Linux distribution info -----------------------

		this.current_distro = LinuxDistro.get_dist_info("/");
		log_msg(_("Distribution") + ": " + current_distro.full_name());
		log_msg("DIST_ID" + ": " + current_distro.dist_id);

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
					msg = _("Another instance of Timeshift is creating a snapshot.") + "\n";
					msg += _("Please wait a few minutes and try again.");
				}
				else{
					msg = _("Another instance of timeshift is currently running!") + "\n";
					msg += _("Please check if you have multiple windows open.") + "\n";
				}

				string title = _("Scheduled snapshot in progress...");
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
		//sys_root and sys_home will be initalized by update_partition_list()

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

		repo = new SnapshotRepo();

		mount_list = new Gee.ArrayList<MountEntry>();
		delete_list = new Gee.ArrayList<Snapshot>();

		exclude_app_names = new Gee.ArrayList<string>();
		add_default_exclude_entries();
		//add_app_exclude_entries();

		//initialize app --------------------

		update_partitions();
		detect_system_devices();

		//finish initialization --------------

		load_app_config();

		task = new RsyncTask();
		delete_file_task = new DeleteFileTask();

		log_debug("Main(): ok");
	}

	public bool start_application(string[] args){
		bool is_success = true;

		log_debug("start_application()");

		if (live_system()){
			switch(app_mode){
			case "backup":
			case "ondemand":
				log_error(_("Snapshots cannot be created in Live CD mode"));
				return false;
			}
		}
		
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
				delete_snapshot();
				return true;

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
					log_msg("");
					return true;
				}
				else{
					log_msg(_("No snapshots found on device") + " '%s'".printf(repo.device.device));
					return false;
				}

			case "list-devices":
				LOG_ENABLE = true;
				log_msg(_("Devices with Linux file systems") + ":\n");
				list_all_devices();
				log_msg("");
				return true;

			default:
				log_debug("Creating MainWindow");
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

		log_debug("check_dependencies()");
		
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

	public bool check_btrfs_layout_system(Gtk.Window? win = null){

		log_debug("check_btrfs_layout_system()");

		bool supported = check_btrfs_layout(sys_root, sys_home);

		if (!supported){
			string msg = _("The system partition has an unsupported subvolume layout.") + " ";
			msg += _("Only ubuntu-type layouts with @ and @home subvolumes are currently supported.") + "\n\n";
			msg += _("Application will exit.") + "\n\n";
			string title = _("Not Supported");
			
			if (app_mode == ""){
				gtk_set_busy(false, win);
				gtk_messagebox(title, msg, win, true);
			}
			else{
				log_error(msg);
			}
		}

		return supported;
	}

	public bool check_btrfs_layout(Device? dev_root, Device? dev_home){
		
		bool supported = true; // keep true for non-btrfs systems

		if ((dev_root != null) && (dev_root.fstype == "btrfs")){
			
			if ((dev_home != null) && (dev_home.fstype == "btrfs")){
				supported = supported && check_btrfs_volume(dev_root, "@");
				supported = supported && check_btrfs_volume(dev_home, "@home");
			}
			else{
				supported = supported && check_btrfs_volume(dev_root, "@,@home");
			}
		}

		return supported;
	}

	// exclude lists
	
	public void add_default_exclude_entries(){

		exclude_list_user = new Gee.ArrayList<string>();
		exclude_list_default = new Gee.ArrayList<string>();
		exclude_list_default_extra = new Gee.ArrayList<string>();
		exclude_list_home = new Gee.ArrayList<string>();
		exclude_list_restore = new Gee.ArrayList<string>();
		exclude_list_apps = new Gee.ArrayList<AppExcludeEntry>();
		
		partitions = new Gee.ArrayList<Device>();

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
		AppExcludeEntry.clear();

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

		if ((sys_root == null)
			|| ((restore_target.device != sys_root.device)
				&& (restore_target.uuid != sys_root.uuid))){

			home = mount_point_restore + home;
		}

		if ((sys_root == null)
			|| ((restore_target.device != sys_root.device)
				&& (restore_target.uuid != sys_root.uuid))){

			home = mount_point_restore + home;
		}

		AppExcludeEntry.add_app_exclude_entries_from_path(home);

		exclude_list_apps = AppExcludeEntry.get_apps_list(exclude_app_names);
	}

	public Gee.ArrayList<string> create_exclude_list_for_backup(){
		var list = new Gee.ArrayList<string>();

		//add default entries
		foreach(string path in exclude_list_default){
			if (!list.contains(path)){
				list.add(path);
			}
		}

		//add default extra entries
		foreach(string path in exclude_list_default_extra){
			if (!list.contains(path)){
				list.add(path);
			}
		}

		//add user entries from current settings
		foreach(string path in exclude_list_user){
			if (!list.contains(path)){
				list.add(path);
			}
		}

		//add home entries
		foreach(string path in exclude_list_home){
			if (!list.contains(path)){
				list.add(path);
			}
		}

		string timeshift_path = "/timeshift/*";
		if (!list.contains(timeshift_path)){
			list.add(timeshift_path);
		}

		return list;
	}
	
	public Gee.ArrayList<string> create_exclude_list_for_restore(){

		exclude_list_restore.clear();
		
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
		foreach(var entry in exclude_list_apps){
			if (entry.enabled){
				foreach(var pattern in entry.patterns){
					if (!exclude_list_restore.contains(pattern)){
						exclude_list_restore.add(pattern);
					}
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
		if (snapshot_to_restore != null){
			string list_file = path_combine(snapshot_to_restore.path, "exclude.list");
			if (file_exists(list_file)){
				foreach(string path in file_read(list_file).split("\n")){
					if (!exclude_list_restore.contains(path) && !exclude_list_home.contains(path)){
						exclude_list_restore.add(path);
					}
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
	
		return exclude_list_restore;
	}

	public bool save_exclude_list_for_backup(string output_path){

		var list = create_exclude_list_for_backup();
		
		var txt = "";
		foreach(var pattern in list){
			if (pattern.strip().length > 0){
				txt += "%s\n".printf(pattern);
			}
		}
		
		string list_file = path_combine(output_path, "exclude.list");
		return file_write(list_file, txt);
	}

	public bool save_exclude_list_for_restore(string output_path){

		var list = create_exclude_list_for_restore();

		log_debug("Exclude list -------------");
		
		var txt = "";
		foreach(var pattern in list){
			if (pattern.strip().length > 0){
				txt += "%s\n".printf(pattern);
				log_debug(pattern);
			}
		}
		
		string list_file = path_combine(output_path, "exclude-restore.list");
		return file_write(list_file, txt);
	}

	public void save_exclude_list_selections(){
		
		// add new selected items
		foreach(var entry in App.exclude_list_apps){
			if (entry.enabled && !App.exclude_app_names.contains(entry.name)){
				App.exclude_app_names.add(entry.name);
				log_debug("add app name: %s".printf(entry.name));
			}
		}

		// remove item only if present in current list and un-selected
		foreach(var entry in App.exclude_list_apps){
			if (!entry.enabled && App.exclude_app_names.contains(entry.name)){
				App.exclude_app_names.remove(entry.name);
				log_debug("remove app name: %s".printf(entry.name));
			}
		}

		App.exclude_app_names.sort((a,b) => {
			return Posix.strcmp(a,b);
		});
	}

	//console functions

	public static string help_message (){
		string msg = "\n" + AppName + " v" + AppVersion + " by Tony George (teejeetech@gmail.com)" + "\n";
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

		log_debug("parse_arguments()");
		
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
		}

		Gtk.init(ref args);
		//X.init_threads();
	}

	private void list_snapshots(bool paginate){
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

	private void list_devices(Gee.ArrayList<Device> device_list){
		string[,] grid = new string[device_list.size+1,6];
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

		foreach(var pi in device_list) {
			col = -1;
			grid[row, ++col] = "%d".printf(row - 1);
			grid[row, ++col] = ">";
			grid[row, ++col] = "%s".printf(pi.full_name_with_alias);
			//grid[row, ++col] = "%s".printf(pi.uuid);
			grid[row, ++col] = "%s".printf((pi.size_bytes > 0) ? "%s".printf(pi.size) : "?? GB");
			grid[row, ++col] = "%s".printf(pi.fstype);
			grid[row, ++col] = "%s".printf(pi.label);
			row++;
		}

		print_grid(grid, right_align);
	}

	private Gee.ArrayList<Device> list_all_devices(){

		//add devices
		var device_list = new Gee.ArrayList<Device>();
		foreach(var dev in Device.get_block_devices_using_lsblk()) {
			if (dev.has_linux_filesystem()){
				device_list.add(dev);
			}
		}

		string[,] grid = new string[device_list.size+1,6];
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

		foreach(var pi in device_list) {
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

		return device_list;
	}

	private Gee.ArrayList<Device> list_grub_devices(bool print_to_console = true){
		//add devices
		var grub_device_list = new Gee.ArrayList<Device>();
		foreach(var dev in Device.get_block_devices_using_lsblk()) {
			if (dev.type == "disk"){
				grub_device_list.add(dev);
			}
			else if (dev.type == "part"){ 
				if (dev.has_linux_filesystem()){
					grub_device_list.add(dev);
				}
			}
			// skip crypt/loop
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

			if (pi.type == "disk"){
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

		return grub_device_list;
	}

	private void print_grid(string[,] grid, bool[] right_align, bool has_header = true){
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


	//prompt for input

	public void get_backup_device_from_cmd(bool prompt_if_empty, Gtk.Window? parent_win){

		var list = new Gee.ArrayList<Device>();
		foreach(var pi in partitions){
			if (pi.has_linux_filesystem()){
				list.add(pi);
			}
		}
					
		if (cmd_backup_device.length > 0){
			//set backup device from command line argument
			var cmd_dev = Device.get_device_by_name(cmd_backup_device);
			if (cmd_dev != null){
				repo = new SnapshotRepo.from_device(cmd_dev, null);
				if (!repo.available()){
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

				log_msg(_("Select backup device") + ":\n");
				list_devices(list);
				log_msg("");

				Device dev = null;
				int attempts = 0;
				while (dev == null){
					attempts++;
					if (attempts > 3) { break; }
					stdout.printf("" +
						_("Enter device name or number (a=Abort)") + ": ");
					stdout.flush();

					dev = read_stdin_device(list);
				}

				log_msg("");
				
				if (dev == null){
					log_error(_("Failed to get input from user in 3 attempts"));
					log_msg(_("Aborted."));
					exit_app();
					exit(0);
				}

				repo = new SnapshotRepo.from_device(dev, null);
				if (!repo.available()){
					exit_app();
					exit(1);
				}
			}
		}
	}

	private Device? read_stdin_device(Gee.ArrayList<Device> device_list){
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

	private Device? read_stdin_device_mounts(Gee.ArrayList<Device> device_list, MountEntry mnt){
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

	private Device? get_device_from_index(Gee.ArrayList<Device> device_list, string index_string){
		int64 index;
		if (int64.try_parse(index_string, out index)){
			int i = -1;
			foreach(Device pi in device_list) {
				if (++i == index){
					return pi;
				}
			}
		}

		return null;
	}

	private Snapshot read_stdin_snapshot(){
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
			//TODO: read name
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

	private bool read_stdin_grub_install(){
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

	private bool read_stdin_restore_confirm(){
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
	
	public bool scheduled{
		get{
			return !live_system()
			&& (schedule_boot || schedule_hourly || schedule_daily ||
				schedule_weekly || schedule_monthly);
		}
	}

	public bool live_system(){
		//return true;
		return (sys_root == null);
	}

	// backup

	public bool take_snapshot (
		bool is_ondemand, string snapshot_comments, Gtk.Window? parent_win){

		bool status;
		bool update_symlinks = false;

		string sys_uuid = (sys_root == null) ? "" : sys_root.uuid;
		
		try
		{
			log_debug("checking btrfs volumes on root device...");
			
			if (App.check_btrfs_layout_system() == false){
				return false;
			}
		
			// create a timestamp
			DateTime now = new DateTime.now_local();

			log_debug("checking if snapshot device is mounted...");
			
			log_debug("checking snapshot device...");
			
			// check space
			if (!repo.has_space()){

				log_error(repo.status_message);
				log_error(repo.status_details + "\n");
				
				// remove invalid snapshots
				if (app_mode.length != 0){
					repo.auto_remove();
				}

				// check again ------------

				if (!repo.has_space()){
					log_error(repo.status_message);
					log_error(repo.status_details + "\n");
					return false;
				}
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
			else if (scheduled){
				Snapshot last_snapshot_boot = repo.get_latest_snapshot("boot", sys_uuid);
				Snapshot last_snapshot_hourly = repo.get_latest_snapshot("hourly", sys_uuid);
				Snapshot last_snapshot_daily = repo.get_latest_snapshot("daily", sys_uuid);
				Snapshot last_snapshot_weekly = repo.get_latest_snapshot("weekly", sys_uuid);
				Snapshot last_snapshot_monthly = repo.get_latest_snapshot("monthly", sys_uuid);

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

			if (app_mode.length != 0){
				repo.auto_remove();
			}

			if (update_symlinks){
				repo.load_snapshots();
				repo.create_symlinks();
			}
			
			log_msg("ok");
		}
		catch(Error e){
			log_error (e.message);
			return false;
		}

		return true;
	}

	public bool backup_and_rotate(string tag, DateTime dt_created){
		//string msg;
		File f;

		bool backup_taken = false;

		// save start time
		var dt_begin = new DateTime.now_local();

		string sys_uuid = (sys_root == null) ? "" : sys_root.uuid;
		
		try{
			// get system boot time
			DateTime now = new DateTime.now_local();
			DateTime dt_sys_boot = now.add_seconds((-1) * get_system_uptime_seconds());

			// check if we can rotate an existing backup -------------

			DateTime dt_filter = null;

			if (tag != "ondemand"){
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

				// find a recent backup that can be used
				Snapshot backup_to_rotate = null;
				foreach(var bak in repo.snapshots){
					if (bak.date.compare(dt_filter) > 0){
						backup_to_rotate = bak;
						break;
					}
				}

				if (backup_to_rotate != null){
					
					// tag the backup
					backup_to_rotate.add_tag(tag);
					
					backup_taken = true;
					var message = "%s '%s' %s '%s'".printf(
						_("Snapshot"), backup_to_rotate.name, _("tagged"), tag);
					log_msg(message);
				}
			}

			if (!backup_taken){

				log_msg("Creating new backup...");
				
				// take new backup ---------------------------------

				if (repo.snapshot_location.length == 0){
					log_error("Backup location not mounted");
					exit_app();
				}

				string time_stamp = dt_created.format("%Y-%m-%d_%H-%M-%S");
				string snapshot_dir = path_combine(repo.snapshot_location, "timeshift/snapshots");
				string snapshot_name = time_stamp;
				string snapshot_path = path_combine(snapshot_dir, snapshot_name);

				Snapshot snapshot_to_link = null;

				dir_create(path_combine(snapshot_path, "/localhost"));

				// check if a snapshot was restored recently and use it for linking ---------
				
				string ctl_path = path_combine(snapshot_dir, ".sync-restore");
				f = File.new_for_path(ctl_path);
				
				if (f.query_exists()){

					// read snapshot name from file
					string snap_path = file_read(ctl_path);
					string snap_name = file_basename(snap_path);
					
					// find the snapshot that was restored
					foreach(var bak in repo.snapshots){
						if ((bak.name == snap_name) && (bak.sys_uuid == sys_uuid)){
							// use for linking
							snapshot_to_link = bak;
							// delete the restore-control-file
							f.delete();
							break;
						}
					}
				}

				// get latest snapshot to link if not set -------

				if (snapshot_to_link == null){
					snapshot_to_link = repo.get_latest_snapshot("", sys_uuid);
				}

				string link_from_path = "";
				if (snapshot_to_link != null){
					log_msg("%s: %s".printf(_("Linking from snapshot"), snapshot_to_link.name));
					link_from_path = "%s/localhost/".printf(snapshot_to_link.path);
				}

				// save exclude list ----------------

				bool ok = save_exclude_list_for_backup(snapshot_path);
				
				string exclude_from_file = path_combine(snapshot_path, "exclude.list");

				if (!ok){
					log_error(_("Failed to save exclude list"));
					return false;
				}
				
				// rsync file system -------------------
				
				progress_text = _("Synching files with rsync...");
				log_msg(progress_text);

				var log_file = snapshot_path + "/rsync-log";
				file_delete(log_file);

				task = new RsyncTask();

				task.source_path = "";
				task.dest_path = snapshot_path + "/localhost/";
				task.link_from_path = link_from_path;
				task.exclude_from_file = exclude_from_file;
				task.rsync_log_file = log_file;
				task.prg_count_total = Main.first_snapshot_count;

				task.relative = true;
				task.verbose = true;
				task.delete_extra = true;
				task.delete_excluded = true;
				task.delete_after = false;
					
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
					log_error(_("rsync returned an error"));
					log_error(_("Failed to create new snapshot"));
					return false;
				}

				// write control file
				write_snapshot_control_file(snapshot_path, dt_created, tag);

				// parse log file
				progress_text = _("Parsing log file...");
				log_msg(progress_text);
				var task = new RsyncTask();
				task.parse_log(log_file);

				// finish ------------------------------
				
				var dt_end = new DateTime.now_local();
				TimeSpan elapsed = dt_end.difference(dt_begin);
				long seconds = (long)(elapsed * 1.0 / TimeSpan.SECOND);
				
				var message = "%s (%lds)".printf(_("Snapshot saved successfully"), seconds);
				log_msg(message);
				
				OSDNotify.notify_send("TimeShift", message, 10000, "low");

				message = "%s '%s' %s '%s'".printf(
						_("Snapshot"), snapshot_name, _("tagged"), tag);
				log_msg(message);
	
				repo.load_snapshots();
			}
		}
		catch(Error e){
			log_error (e.message);
			return false;
		}

		return true;
	}
	
	public Snapshot write_snapshot_control_file(
		string snapshot_path, DateTime dt_created, string tag){
			
		var ctl_path = snapshot_path + "/info.json";
		var config = new Json.Object();

		config.set_string_member("created", dt_created.to_utc().to_unix().to_string());
		config.set_string_member("sys-uuid", sys_root.uuid);
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

	// delete from terminal

	public void delete_snapshot(Snapshot? snapshot = null){

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
					return;
				}
			}

			//prompt user for snapshot
			if (snapshot_to_delete == null){

				if (repo.snapshots.size == 0){
					log_msg(_("No snapshots found on device") +
						" '%s'".printf(repo.device.device));
					return;
				}

				log_msg("");
				log_msg(_("Select snapshot to delete") + ":\n");
				list_snapshots(true);
				log_msg("");

				int attempts = 0;
				while (snapshot_to_delete == null){
					attempts++;
					if (attempts > 3) { break; }
					stdout.printf(_("Enter snapshot number (a=Abort, p=Previous, n=Next)") + ": ");
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
			return;
		}

		snapshot_to_delete.remove(true);
	}

	public bool delete_all_snapshots(){
		return repo.remove_all();
	}

	// gui delete

	public void delete_begin(){

		log_debug("delete_begin()");
		
		try {
			thread_delete_running = true;
			thread_delete_success = false;
			Thread.create<void> (delete_thread, true);

			//new Thread<bool> ("", delete_thread);

			log_debug("delete_begin(): thread created");
		}
		catch (Error e) {
			thread_delete_running = false;
			thread_delete_success = false;
			log_error (e.message);
		}
	}

	public void delete_thread(){

		log_debug("delete_thread()");

		foreach(var bak in delete_list){
			bak.mark_for_deletion();
		}
		
		while (delete_list.size > 0){

			var bak = delete_list[0];
			bak.mark_for_deletion(); // mark for deletion again since initial list may have changed
			
			App.delete_file_task = bak.delete_file_task;
			App.delete_file_task.prg_count_total = Main.first_snapshot_count;
			
			bak.remove(true); // wait till complete

			if (App.delete_file_task.status != AppStatus.CANCELLED){
				
				var message = "%s '%s' (%s)".printf(
					_("Removed"), bak.name, App.delete_file_task.stat_time_elapsed);
					
				log_msg(message);
				
				OSDNotify.notify_send("TimeShift", message, 10000, "low");

				delete_list.remove(bak);
			}
		}

		thread_delete_running = false;
		thread_delete_success = false;

		//return thread_delete_success;
	}
	
	// restore

	public void init_mount_list(){

		log_debug("Main: init_mount_list()");
		
		mount_list.clear();

		Gee.ArrayList<FsTabEntry> fstab_list = null;
		Gee.ArrayList<CryptTabEntry> crypttab_list = null;
		
		if (mirror_system){
			string fstab_path = "/etc/fstab";
			fstab_list = FsTabEntry.read_file(fstab_path);
			string cryttab_path = "/etc/crypttab";
			crypttab_list = CryptTabEntry.read_file(cryttab_path);
		}
		else{
			fstab_list = snapshot_to_restore.fstab_list;
			crypttab_list = snapshot_to_restore.cryttab_list;
		}

		bool root_found = false;
		bool boot_found = false;
		bool home_found = false;
		restore_target = null;
		
		foreach(var mnt in fstab_list){

			// skip mounting for non-system devices
			
			if (!mnt.is_for_system_directory()){
				continue;
			}

			// find device by name or uuid
			
			Device mnt_dev = null;
			if (mnt.device_uuid.length > 0){
				mnt_dev = Device.get_device_by_uuid(mnt.device_uuid);
			}
			else{
				mnt_dev = Device.get_device_by_name(mnt.device);
			}

			// replace mapped name with parent device

			if (mnt_dev == null){
				
				/*
				Note: This is required since the mapped name may be different on running system.
				Since we don't have the same mapped name, we cannot resolve the device without
				identifying the parent partition
				*/

				if (mnt.device.has_prefix("/dev/mapper/")){
					string mapped_name = mnt.device.replace("/dev/mapper/","");
					foreach(var entry in crypttab_list){
						if (entry.mapped_name == mapped_name){
							mnt.device = entry.device;
							break;
						}
					}
				}

				// try again - find device by name or uuid
			
				if (mnt.device_uuid.length > 0){
					mnt_dev = Device.get_device_by_uuid(mnt.device_uuid);
				}
				else{
					mnt_dev = Device.get_device_by_name(mnt.device);
				}
			}

			if (mnt_dev != null){
				
				log_debug("added: dev: %s, path: %s, options: %s".printf(
					mnt_dev.device, mnt.mount_point, mnt.options));
					
				mount_list.add(new MountEntry(mnt_dev, mnt.mount_point, mnt.options));
				
				if (mnt.mount_point == "/"){
					restore_target = mnt_dev;
				}
			}
			else{
				log_debug("missing: dev: %s, path: %s, options: %s".printf(
					mnt.device, mnt.mount_point, mnt.options));

				mount_list.add(new MountEntry(null, mnt.mount_point, mnt.options));
			}

			if (mnt.mount_point == "/"){
				root_found = true;
			}
			if (mnt.mount_point == "/boot"){
				boot_found = true;
			}
			if (mnt.mount_point == "/home"){
				home_found = true;
			}
		}

		if (!root_found){
			mount_list.add(new MountEntry(null, "/", "")); // add root entry
		}

		if (!boot_found){
			mount_list.add(new MountEntry(null, "/boot", "")); // add boot entry
		}

		if (!home_found){
			mount_list.add(new MountEntry(null, "/home", "")); // add home entry
		}

		/*
		While cloning the system, /boot is the only mount point that
		we will leave unchanged (to avoid encrypted systems from breaking).
		All other mounts like /home will be defaulted to target device
		(to prevent the "cloned" system from using the original device)
		*/
		
		if (App.mirror_system){
			restore_target = null;
			foreach (var entry in mount_list){
				// user should select another device
				entry.device = null; 
			}
		}

		foreach(var mnt in mount_list){
			if (mnt.device != null){
				log_debug("Entry: %s -> %s".printf(mnt.device.device, mnt.mount_point));
			}
			else{
				log_debug("Entry: null -> %s".printf(mnt.mount_point));
			}
		}

		// sort - parent mountpoints will be placed above children
		mount_list.sort((a,b) => {
			return strcmp(a.mount_point, b.mount_point);
		});

		log_debug("Main: init_mount_list(): exit");
	}

	public bool restore_snapshot(Gtk.Window? parent_win){
		bool found = false;

		// set snapshot device --------------------------------

		if (!mirror_system){
			
			if (repo.device != null){
				//print snapshot_device name
				log_msg(string.nfill(78, '*'));
				log_msg(_("Backup Device") + ": %s".printf(repo.device.device));
				log_msg(string.nfill(78, '*'));
			}
			else{
				//print error
				log_error(_("Backup device not specified!"));
				return false;
			}
		}

		// set snapshot ----------------------------------------

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
					log_msg(_("Select snapshot to restore") + ":\n");
					list_snapshots(true);
					log_msg("");

					int attempts = 0;
					while (snapshot_to_restore == null){
						attempts++;
						if (attempts > 3) { break; }
						stdout.printf(_("Enter snapshot number (a=Abort, p=Previous, n=Next)") + ": ");
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

			if ((snapshot_to_restore != null) && (snapshot_to_restore.marked_for_deletion)){
				log_error(_("Invalid Snapshot"));
				log_error(_("Selected snapshot is marked for deletion"));
				return false;
			}
			
			if (snapshot_to_restore != null){
				//print snapshot name
				log_msg(string.nfill(78, '*'));
				log_msg(_("Snapshot") + ": %s ~ %s".printf(
					snapshot_to_restore.name, snapshot_to_restore.description));
				log_msg(string.nfill(78, '*'));
			}
			else{
				//print error
				log_error(_("Snapshot to restore not specified!"));
				return false;
			}
		}

		// init mounts ---------------

		if (app_mode != ""){
			
			init_mount_list();

			// remove mount points which will remain on root fs
			for(int i = App.mount_list.size-1; i >= 0; i--){
				
				var entry = App.mount_list[i];
				
				if (entry.device == null){
					App.mount_list.remove(entry);
				}

				if (entry.mount_point == "/"){
					App.restore_target = entry.device;
				}
			}
		}

		if (app_mode != ""){ //command line mode

			// set target device from cmd argument
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
		}
		
		// select devices in mount_list --------------------

		log_debug("Selecting devices for mount points");
		
		if (app_mode != ""){ //command line mode

			for(int i = 0; i < mount_list.size; i++){
				MountEntry mnt = mount_list[i];
				Device dev = null;
				string default_device = "";

				log_debug("selecting: %s".printf(mnt.mount_point));

				// no need to ask user to map remaining devices if restoring same system
				if ((restore_target != null) && (sys_root != null)
					&& (restore_target.uuid == sys_root.uuid)){
						
					break;
				}

				if (mirror_system){
					default_device = (restore_target != null) ? restore_target.device : "";
				}
				else{
					if (mnt.device != null){
						default_device = mnt.device.device;
					}
					else{
						default_device = (restore_target != null) ? restore_target.device : "";
					}
				}

				//prompt user for device
				if (dev == null){
					log_msg("");
					log_msg(_("Select '%s' device (default = %s)").printf(
						mnt.mount_point, default_device) + ":\n");
					var device_list = list_all_devices();
					log_msg("");

					int attempts = 0;
					while (dev == null){
						attempts++;
						if (attempts > 3) { break; }
						
						stdout.printf("" +
							_("[a = Abort, d = Default (%s), r = Root device]").printf(default_device) + "\n\n");
							
						stdout.printf(
							_("Enter device name or number")
								+ ": ");
								
						stdout.flush();
						dev = read_stdin_device_mounts(device_list, mnt);
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

					log_debug("selected: %s".printf(dev.uuid));
					
					mnt.device = dev;

					if (mnt.mount_point == "/"){
						restore_target = dev;
					}

					log_msg(string.nfill(78, '*'));
					
					if ((mnt.mount_point != "/")
						&& (restore_target != null)
						&& (dev.device == restore_target.device)){
							
						log_msg(_("'%s' will be on root device").printf(mnt.mount_point), true);
					}
					else{
						log_msg(_("'%s' will be on '%s'").printf(
							mnt.mount_point, mnt.device.short_name_with_alias), true);
							
						//log_debug("UUID=%s".printf(restore_target.uuid));
					}
					log_msg(string.nfill(78, '*'));
				}
			
			}
		}
		
		// mount selected devices ---------------------------------------

		log_debug("Mounting selected devices");
		
		if (restore_target != null){
			if (app_mode != ""){ //commandline mode
				if ((sys_root == null) || (restore_target.uuid != sys_root.uuid)){
					//mount target device and other devices
					bool status = mount_target_device(null);
					if (status == false){
						return false;
					}
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

		// set grub device -----------------------------------------------

		log_debug("Setting grub device");
		
		if (app_mode != ""){ //command line mode

			if (cmd_grub_device.length > 0){

				log_debug("Grub device is specified as command argument");
				
				//check command line arguments
				found = false;
				var device_list = list_grub_devices(false);
				
				foreach(Device dev in device_list) {
					
					if ((dev.device == cmd_grub_device)
						||((dev.uuid.length > 0) && (dev.uuid == cmd_grub_device))){

						grub_device = dev.device;
						found = true;
						break;
					}
					else {
						if (dev.type == "part"){
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
			
			if (mirror_system){
				reinstall_grub2 = true;
			}
			else {
				if ((cmd_skip_grub == false) && (reinstall_grub2 == false)){
					log_msg("");

					int attempts = 0;
					while ((cmd_skip_grub == false) && (reinstall_grub2 == false)){
						attempts++;
						if (attempts > 3) { break; }
						stdout.printf(_("Re-install GRUB2 bootloader? (y/n)") + ": ");
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
			}

			if ((reinstall_grub2) && (grub_device.length == 0)){
				
				log_msg("");
				log_msg(_("Select GRUB device") + ":\n");
				var device_list = list_grub_devices();
				log_msg("");

				int attempts = 0;
				while (grub_device.length == 0){
					
					attempts++;
					if (attempts > 3) { break; }
					
					stdout.printf(_("Enter device name or number (a=Abort)") + ": ");
					stdout.flush();

					// TODO: provide option for default boot device

					var list = new Gee.ArrayList<Device>();
					foreach(var pi in partitions){
						if (pi.has_linux_filesystem()){
							list.add(pi);
						}
					}
					
					Device dev = read_stdin_device(device_list);
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
				
				log_msg(string.nfill(78, '*'));
				log_msg(_("GRUB Device") + ": %s".printf(grub_device));
				log_msg(string.nfill(78, '*'));
			}
			else{
				log_msg(string.nfill(78, '*'));
				log_msg(_("GRUB will NOT be reinstalled"));
				log_msg(string.nfill(78, '*'));
			}
		}

		if ((app_mode != "")&&(cmd_confirm == false)){

			string msg_devices = "";
			string msg_reboot = "";
			string msg_disclaimer = "";

			App.disclaimer_pre_restore(
				false, out msg_devices, out msg_reboot,
				out msg_disclaimer);

			int attempts = 0;
			while (cmd_confirm == false){
				attempts++;
				if (attempts > 3) { break; }
				stdout.printf(_("Continue with restore? (y/n): "));
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
			thread_restore_running = true;
			thr_success = false;
			Thread.create<void> (restore_snapshot_thread, true);
		}
		catch (ThreadError e) {
			thread_restore_running = false;
			thr_success = false;
			log_error (e.message);
		}

		while (thread_restore_running){
			gtk_do_events ();
			Thread.usleep((ulong) GLib.TimeSpan.MILLISECOND * 100);
		}

		snapshot_to_restore = null;

		return thr_success;
	}

	public void disclaimer_pre_restore(bool formatted,
		out string msg_devices, out string msg_reboot,
		out string msg_disclaimer){
			
		string msg = "";

		log_debug("Main: disclaimer_pre_restore()");

		// msg_devices -----------------------------------------
		
		if (!formatted){
			msg += "\n%s\n%s\n%s\n".printf(
				string.nfill(70,'='),
				_("Warning").up(),
				string.nfill(70,'=')
			);
		}
		
		msg += _("Data will be modified on following devices:") + "\n\n";

		int max_mount = _("Mount").length;
		int max_dev = _("Device").length;
		int max_vol = _("Subvol").length;

		foreach(var entry in mount_list){
			if (entry.device == null){ continue; }

			string dev_name = entry.device.short_name_with_alias;
			
			if (dev_name.length > max_dev){
				max_dev = dev_name.length;
			}
			if (entry.mount_point.length > max_mount){
				max_mount = entry.mount_point.length;
			}
			if (entry.subvolume_name().length > max_vol){
				max_vol = entry.subvolume_name().length;
			}
		}

		bool show_subvolume = false;
		foreach(var entry in App.mount_list){
			if (entry.device == null){ continue; }
			
			if ((entry.device != null)
				&& (entry.device.fstype == "btrfs")
				&& (entry.subvolume_name().length > 0)){
					
				// subvolumes are used - show subvolume column
				show_subvolume = true;
				break;
			}
		}
		
		var txt = ("%%-%ds  %%-%ds".printf(max_dev, max_mount))
			.printf(_("Device"),_("Mount"));
		if (show_subvolume){
			txt += "  %s".printf(_("Subvol"));
		}
		txt += "\n";

		txt += string.nfill(max_dev, '-') + "  " + string.nfill(max_mount, '-');
		if (show_subvolume){
			txt += "  " + string.nfill(max_vol, '-');
		}
		txt += "\n";
		
		foreach(var entry in App.mount_list){
			if (entry.device == null){ continue; }
			
			txt += ("%%-%ds  %%-%ds".printf(max_dev, max_mount)).printf(
				entry.device.device_name_with_parent, entry.mount_point);

			if (show_subvolume){
				txt += "  %s".printf(entry.subvolume_name());
			}

			txt += "\n";
		}

		if (formatted){
			msg += "<span size=\"medium\"><tt>%s</tt></span>".printf(txt);
		}
		else{
			msg += "%s\n".printf(txt);
		}

		msg_devices = msg;

		//msg += _("Files will be overwritten on the target device!") + "\n";
		//msg += _("If restore fails and you are unable to boot the system, then boot from the Ubuntu Live CD, install Timeshift, and try to restore again.") + "\n";

		// msg_reboot -----------------------
		
		msg = "";
		if ((sys_root != null) && (restore_target != null)
			&& (restore_target.device == sys_root.device)){
				
			msg += _("Please save your work and close all applications.") + "\n";
			msg += _("System will reboot after files are restored.");
		}

		msg_reboot = msg;

		// msg_disclaimer --------------------------------------

		msg = "";
		if (!formatted){
			msg += "\n%s\n%s\n%s\n".printf(
				string.nfill(70,'='),
				_("Disclaimer").up(),
				string.nfill(70,'=')
			);
		}
		
		msg += _("This software comes without absolutely NO warranty and the author takes no responsibility for any damage arising from the use of this program.");
		msg += " " + _("If these terms are not acceptable to you, please do not proceed beyond this point!");

		if (!formatted){
			msg += "\n";
		}
		
		msg_disclaimer = msg;

		// display messages in console mode
		
		if (app_mode.length > 0){
			log_msg(msg_devices);
			log_msg(msg_reboot);
			log_msg(msg_disclaimer);
		}

		log_debug("Main: disclaimer_pre_restore(): exit");
	}

	public void restore_snapshot_thread(){
		string sh = "";
		int ret_val = -1;
		string temp_script;
		string sh_grub = "";
		string sh_reboot = "";
		
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

			log_debug("source_path=%s".printf(source_path));

			//set target path ----------------

			bool restore_current_system;
			string target_path;

			if ((sys_root != null)
				&& ((restore_target.device == sys_root.device)
					|| (restore_target.uuid == sys_root.uuid))){
					
				restore_current_system = true;
				target_path = "/";
			}
			else{
				restore_current_system = false;
				target_path = mount_point_restore + "/";

				if (mount_point_restore.strip().length == 0){
					log_error(_("Target device is not mounted"));
					thr_success = false;
					thread_restore_running = false;
					return;
				}
			}

			log_debug("target_path=%s".printf(target_path));

			//save exclude list for restore --------------

			save_exclude_list_for_restore(source_path);

			//create script -------------

			sh = "";
			sh += "echo ''\n";
			if (restore_current_system){
				log_debug("restoring current system");
				
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

			log_debug("rsync script:");
			log_debug(sh);
			
			//chroot and re-install grub2 --------

			log_debug("reinstall_grub2=%s".printf(
				reinstall_grub2.to_string()));
				
			log_debug("grub_device=%s".printf(
				(grub_device == null) ? "null" : grub_device));

			var target_distro = LinuxDistro.get_dist_info(target_path);
			
			sh_grub = "";
			
			if (reinstall_grub2 && (grub_device != null) && (grub_device.length > 0)){
				
				sh_grub += "sync \n";
				sh_grub += "echo '' \n";
				sh_grub += "echo '" + _("Re-installing GRUB2 bootloader...") + "' \n";

				string chroot = "";
				if (!restore_current_system){
					if (target_distro.dist_type == "arch"){
						chroot += "arch-chroot \"%s\"".printf(target_path);
					}
					else{
						chroot += "chroot \"%s\"".printf(target_path);
					}
				}
				
				// bind system directories for chrooted system
				sh_grub += "for i in /dev /proc /run /sys; do mount --bind \"$i\" \"%s$i\"; done \n".printf(target_path);

				// search for other operating systems
				//sh_grub += "chroot \"%s\" os-prober \n".printf(target_path);
				
				// re-install grub ---------------

				if (target_distro.dist_type == "redhat"){

					// this will run only in clone mode
					
					sh_grub += "%s grub2-install --recheck %s \n".printf(chroot, grub_device);

					/* NOTE:
					 * grub2-install should NOT be run on Fedora EFI systems 
					 * https://fedoraproject.org/wiki/GRUB_2
					 * Instead following packages should be reinstalled:
					 * dnf reinstall grub2-efi grub2-efi-modules shim
					 *
					 * Bootloader installation will be skipped while restoring in GUI mode.
					 * Fedora seems to boot correctly even after installing new
					 * kernels and restoring a snapshot with an older kernel.
					*/
				}
				else {
					sh_grub += "%s grub-install --recheck %s \n".printf(chroot, grub_device);
				}

				// create new grub menu
				//sh_grub += "chroot \"%s\" grub-mkconfig -o /boot/grub/grub.cfg \n".printf(target_path);

				// update initramfs --------------

				if (target_distro.dist_type == "redhat"){
					sh_grub += "%s dracut -f -v \n".printf(chroot);
				}
				else if (target_distro.dist_type == "arch"){
					sh_grub += "%s mkinitcpio -p /etc/mkinitcpio.d/*.preset\n".printf(chroot);
				}
				else{
					sh_grub += "%s update-initramfs -u -k all \n".printf(chroot);
				}
					
				// update grub menu --------------

				if ((target_distro.dist_type == "redhat") || (target_distro.dist_type == "arch")){
					sh_grub += "%s grub-mkconfig -o /boot/grub2/grub.cfg \n".printf(chroot);
				}
				else{
					sh_grub += "%s update-grub \n".printf(chroot);
				}

				sh_grub += "echo '' \n";

				// sync file systems
				sh_grub += "echo '" + _("Synching file systems...") + "' \n";
				sh_grub += "sync \n";
				sh_grub += "echo '' \n";

				// unmount chrooted system
				sh_grub += "echo '" + _("Cleaning up...") + "' \n";
				sh_grub += "for i in /dev /proc /run /sys; do umount -f \"%s$i\"; done \n".printf(target_path);
				sh_grub += "sync \n";

				log_debug("GRUB2 install script:");
				log_debug(sh_grub);
			
				//sh += sh_grub;
			}
			else{
				log_debug("skipping sh_grub: reinstall_grub2=%s, grub_device=%s".printf(
					reinstall_grub2.to_string(), (grub_device == null) ? "null" : grub_device));
			}

			//reboot if required --------

			if (restore_current_system){
				sh_reboot += "echo '' \n";
				sh_reboot += "echo '" + _("Rebooting system...") + "' \n";
				sh += "reboot -f \n";
				//sh_reboot += "shutdown -r now \n";
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

			progress_text = _("Synching files with rsync...");
			log_msg(progress_text);

			if (app_mode == ""){

				// gui mode --------------
				
				if (restore_current_system){
					//current system, gui, fullscreen
					temp_script = save_bash_script_temp(sh + sh_grub + sh_reboot);
					// Note: sh_grub will be empty if reinstall_grub2 = false 

					//restore or clone
					var dlg = new TerminalWindow.with_parent(null);
					dlg.execute_script(temp_script, true);
				}
				else{
					// other system, gui ------------------------

					//App.progress_text = "Sync";

					progress_text = _("Building file list...");
					//log_msg(progress_text); // gui-only message
					
					task = new RsyncTask();
					task.relative = false;
					task.verbose = true;
					task.delete_extra = true;
					task.delete_excluded = false;
					task.delete_after = true;
					
					if (mirror_system){
						task.source_path = "/";
					}
					else{
						task.source_path =
							path_combine(source_path, "localhost");
					}

					task.dest_path = target_path;
					
					task.exclude_from_file =
						path_combine(source_path, "exclude-restore.list");

					task.rsync_log_file = log_path;
					task.prg_count_total = Main.first_snapshot_count;	
					task.execute();

					while (task.status == AppStatus.RUNNING){
						sleep(1000);

						if (App.task.status_line.length > 0){
							progress_text = _("Synching files with rsync...");
						}
						
						gtk_do_events();
					}

					if (!restore_current_system){
						App.progress_text = "Updating /etc/fstab and /etc/crypttab on target system...";
						log_msg(App.progress_text);
						
						fix_fstab_file(target_path);
						fix_crypttab_file(target_path);
					}

					// re-install grub ------------
				
					if (reinstall_grub2){

						App.progress_text = "Re-installing GRUB2 bootloader...";
						log_msg(App.progress_text);

						log_debug(sh_grub);
						
						//string std_out, std_err;
						ret_val = exec_script_sync(sh_grub, null, null);
						//log_to_file(std_out);
						//log_to_file(std_err);
						//log_msg(std_out);
						//log_msg(std_err);
						log_debug("GRUB2 install completed");
					}

					ret_val = task.exit_code;
				}
			}
			else{

				// console mode ----------
				var script = sh;
				if (restore_current_system){
					script += sh_grub + sh_reboot;
				}

				log_debug("verbose=%s".printf(cmd_verbose.to_string()));
				
				if (cmd_verbose){
					//current/other system, console, verbose
					ret_val = exec_script_sync(script, null, null, false, false, false, true);
					log_msg("");
				}
				else{
					//current/other system, console, quiet
					string std_out, std_err;
					ret_val = exec_script_sync(script, out std_out, out std_err);
					log_to_file(std_out);
					log_to_file(std_err);
				}

				if (!restore_current_system){
					
					// fix fstab and crypttab files ------
					
					fix_fstab_file(target_path);
					fix_crypttab_file(target_path);

					// re-install grub ------------
				
					if (reinstall_grub2){

						App.progress_text = "Re-installing GRUB2 bootloader...";
						log_msg(App.progress_text);
						
						if (cmd_verbose){
							//current/other system, console, verbose
							ret_val = exec_script_sync(sh_grub, null, null, false, false, false, true);
							log_msg("");
						}
						else{
							//current/other system, console, quiet
							string std_out, std_err;
							ret_val = exec_script_sync(sh_grub, out std_out, out std_err);
							log_to_file(std_out);
							log_to_file(std_err);
						}
					}
				}
			}

			// check for errors ----------------------

			if (ret_val != 0){
				log_error(_("Restore failed with exit code") + ": %d".printf(ret_val));
				thr_success = false;
				thread_restore_running = false;
			}
			else{
				log_msg(_("Restore completed without errors"));
				//thr_success = true;
				//thread_restore_running = false;
			}

			// unmount ----------
			
			unmount_target_device(false);
		}
		catch(Error e){
			log_error (e.message);
			thr_success = false;
			thread_restore_running = false;
		}

		thread_restore_running = false;
	}

	public void fix_fstab_file(string target_path){
		
		string fstab_path = target_path + "etc/fstab";
		var fstab_list = FsTabEntry.read_file(fstab_path);

		foreach(var mnt in mount_list){
			// find existing
			var entry = FsTabEntry.find_entry_by_mount_point(fstab_list, mnt.mount_point);

			// add if missing
			if (entry == null){
				entry = new FsTabEntry();
				entry.mount_point = mnt.mount_point;
				fstab_list.add(entry);
			}

			//update fstab entry
			entry.device = "UUID=%s".printf(mnt.device.uuid);
			entry.type = mnt.device.fstype;

			// fix mount options for non-btrfs device
			if (mnt.device.fstype != "btrfs"){
				// remove subvol option
				entry.remove_option("subvol=%s".printf(entry.subvolume_name()));
			}
		}

		/*
		 * Remove fstab entries for any system directories that
		 * the user has not explicitly mapped before restore/clone
		 * This ensures that the cloned/restored system does not mount
		 * any devices to system paths that the user has not explicitly specified
		 * */

		for(int i = fstab_list.size - 1; i >= 0; i--){
			var entry = fstab_list[i];
			
			if (!entry.is_for_system_directory()){ continue; }
			
			var mnt = MountEntry.find_entry_by_mount_point(mount_list, entry.mount_point);
			if (mnt == null){
				fstab_list.remove(entry);
			}
		}
		
		// write the updated file

		FsTabEntry.write_file(fstab_list, fstab_path, false);

		log_msg(_("Updated /etc/fstab on target device") + ": %s".printf(fstab_path));

		// create directories on disk for mount points in /etc/fstab

		foreach(var entry in fstab_list){
			if (entry.mount_point.length == 0){ continue; }
			if (!entry.mount_point.has_prefix("/")){ continue; }
			
			string mount_path = path_combine(
				target_path, entry.mount_point);
				
			if (entry.is_comment
				|| entry.is_empty_line
				|| (mount_path.length == 0)){
				
				continue;
			}

			if (!dir_exists(mount_path)){
				
				log_msg("Created mount point on target device: %s".printf(
					entry.mount_point));
					
				dir_create(mount_path);
			}
		}
	}

	public void fix_crypttab_file(string target_path){
		string crypttab_path = target_path + "etc/crypttab";
		var crypttab_list = CryptTabEntry.read_file(crypttab_path);

		// add option "nofail" to existing entries
		
		foreach(var entry in crypttab_list){
			entry.append_option("nofail");
		}

		// check and add entries for mapped devices which are encrypted
		
		foreach(var mnt in mount_list){
			if ((mnt.device != null) && (mnt.device.is_on_encrypted_partition())){
				
				// find existing
				var entry = CryptTabEntry.find_entry_by_uuid(
					crypttab_list, mnt.device.parent.uuid);

				// add if missing
				if (entry == null){
					entry = new CryptTabEntry();
					crypttab_list.add(entry);
				}
				
				// set custom values
				entry.device_uuid = mnt.device.parent.uuid;
				entry.mapped_name = "luks-%s".printf(mnt.device.parent.uuid);
				entry.keyfile = "none";
				entry.options = "luks,nofail";
			}
		}

		CryptTabEntry.write_file(crypttab_list, crypttab_path, false);

		log_msg(_("Updated /etc/crypttab on target device") + ": %s".printf(crypttab_path));
	}

	public Device? dst_root{
		get {
			foreach(var mnt in mount_list){
				if (mnt.mount_point == "/"){
					return mnt.device;
				}
			}
			return null;
		}
	}

	public Device? dst_boot{
		get {
			foreach(var mnt in mount_list){
				if (mnt.mount_point == "/boot"){
					return mnt.device;
				}
			}
			return null;
		}
	}

	public Device? dst_efi{
		get {
			foreach(var mnt in mount_list){
				if (mnt.mount_point == "/boot/efi"){
					return mnt.device;
				}
			}
			return null;
		}
	}

	public Device? dst_home{
		get {
			foreach(var mnt in mount_list){
				if (mnt.mount_point == "/home"){
					return mnt.device;
				}
			}
			return null;
		}
	}
	
	//app config

	public void save_app_config(){

		log_debug("load_app_config()");
		
		var config = new Json.Object();

		if ((repo != null) && repo.available()){
			// save backup device uuid
			config.set_string_member("backup_device_uuid",
				(repo.device == null) ? "" : repo.device.uuid);
			
			// save parent uuid if backup device has parent
			config.set_string_member("parent_device_uuid",
				(repo.device.has_parent()) ? repo.device.parent.uuid : "");
		}
		else{
			// retain values for next run
			config.set_string_member("backup_device_uuid", backup_uuid);
			config.set_string_member("parent_device_uuid", backup_parent_uuid); 
		}

		config.set_string_member("use_snapshot_path_user",
			repo.use_snapshot_path_custom.to_string());
			
		config.set_string_member("snapshot_path_user",
			repo.snapshot_path_user.to_string());

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

		config.set_string_member("snapshot_size", first_snapshot_size.to_string());
		config.set_string_member("snapshot_count", first_snapshot_count.to_string());

		Json.Array arr = new Json.Array();
		foreach(string path in exclude_list_user){
			arr.add_string_element(path);
		}
		config.set_array_member("exclude",arr);

		arr = new Json.Array();
		foreach(var name in exclude_app_names){
			arr.add_string_element(name);
		}
		config.set_array_member("exclude-apps",arr);

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

		log_debug("load_app_config()");
		
		var f = File.new_for_path(this.app_conf_path);
		if (!f.query_exists()) {
			first_run = true;
			log_debug("first run mode: config file not found");
			initialize_repo();
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

		backup_uuid = json_get_string(config,"backup_device_uuid", backup_uuid);
		backup_parent_uuid = json_get_string(config,"parent_device_uuid", backup_parent_uuid);
		
		initialize_repo();

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

		Main.first_snapshot_size = json_get_int64(config,"snapshot_size",
			Main.first_snapshot_size);
			
		Main.first_snapshot_count = json_get_int64(config,"snapshot_count",
			Main.first_snapshot_count);
		
		exclude_list_user.clear();
		
		if (config.has_member ("exclude")){
			foreach (Json.Node jnode in config.get_array_member ("exclude").get_elements()) {
				
				string path = jnode.get_string();
				
				if (!exclude_list_user.contains(path)
					&& !exclude_list_default.contains(path)
					&& !exclude_list_home.contains(path)){
						
					exclude_list_user.add(path);
				}
			}
		}

		exclude_app_names.clear();

		if (config.has_member ("exclude-apps")){
			var apps = config.get_array_member("exclude-apps");
			foreach (Json.Node jnode in apps.get_elements()) {
				
				string name = jnode.get_string();
				
				if (!exclude_app_names.contains(name)){
					exclude_app_names.add(name);
				}
			}
		}

		if ((app_mode == "")||(LOG_DEBUG)){
			log_msg(_("App config loaded") + ": '%s'".printf(this.app_conf_path));
		}
	}

	public void initialize_repo(){

		log_debug("backup_uuid=%s".printf(backup_uuid));
		log_debug("backup_parent_uuid=%s".printf(backup_parent_uuid));
		
		if (backup_uuid.length > 0){
			log_debug("repo: creating from uuid");
			repo = new SnapshotRepo.from_uuid(backup_uuid, null);

			if ((repo == null) || !repo.available()){
				if (backup_parent_uuid.length > 0){
					log_debug("repo: creating from parent uuid");
					repo = new SnapshotRepo.from_uuid(backup_parent_uuid, null);
				}
			}
		}
		else{
			if (sys_root != null){
				log_debug("repo: uuid is empty, creating from root device");
				repo = new SnapshotRepo.from_device(sys_root, null);
			}
			else{
				log_debug("repo: root device is null");
				repo = new SnapshotRepo.from_null(null);
			}
		}

		// initialize repo using command line parameter
		 
		if (cmd_backup_device.length > 0){
			var cmd_dev = Device.get_device_by_name(cmd_backup_device);
			if (cmd_dev != null){
				log_debug("repo: creating from command argument: %s".printf(cmd_backup_device));
				repo = new SnapshotRepo.from_device(cmd_dev, null);
				
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
	}
	
	//core functions

	public void update_partitions(){

		log_debug("update_partitions()");
		
		partitions.clear();
		
		partitions = Device.get_filesystems();

		foreach(var pi in partitions){

			// sys_root and sys_home will be detected by detect_system_devices()
			if ((repo != null) && (repo.device != null) && (pi.uuid == repo.device.uuid)){
				repo.device = pi;
			}
			
			if (pi.is_mounted){
				pi.dist_info = LinuxDistro.get_dist_info(pi.mount_points[0].mount_point).full_name();
			}
		}
		
		if (partitions.size == 0){
			log_error("ts: " + _("Failed to get partition list."));
		}

		log_debug("partition list updated");
	}

	public void detect_system_devices(){

		log_debug("detect_system_devices()");

		sys_root = null;
		sys_boot = null;
		sys_efi = null;
		sys_home = null;
		
		foreach(Device pi in partitions){
			foreach(var mp in pi.mount_points){
				if (mp.mount_point == "/"){
					sys_root = pi;
					if ((app_mode == "")||(LOG_DEBUG)){
						log_msg(_("/ is mapped to device") + ": %s, UUID=%s".printf(pi.device,pi.uuid));
					}
				}

				if (mp.mount_point == "/home"){
					sys_home = pi;
					if ((app_mode == "")||(LOG_DEBUG)){
						log_msg(_("/home is mapped to device") + ": %s, UUID=%s".printf(pi.device,pi.uuid));
					}
				}

				if (mp.mount_point == "/boot"){
					sys_boot = pi;
					if ((app_mode == "")||(LOG_DEBUG)){
						log_msg(_("/boot is mapped to device") + ": %s, UUID=%s".printf(pi.device,pi.uuid));
					}
				}

				if (mp.mount_point == "/boot/efi"){
					sys_efi = pi;
					if ((app_mode == "")||(LOG_DEBUG)){
						log_msg(_("/boot/efi is mapped to device") + ": %s, UUID=%s".printf(pi.device,pi.uuid));
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

		log_debug("mount_target_device()");
		
		if (restore_target == null){
			return false;
		}
	
		//check and create restore mount point for restore
		mount_point_restore = mount_point_app + "/restore";
		dir_create(mount_point_restore);

		/*var already_mounted = false;
		var dev_mounted = Device.get_device_by_path(mount_point_restore);
		if ((dev_mounted != null)
			&& (dev_mounted.uuid == restore_target.uuid)){

			foreach(var mp in dev_mounted.mount_points){
				if ((mp.mount_point == mount_point_restore)
					&& (mp.mount_options == "subvol=@")){
						
					 = true;
					return; //already_mounted
				}
			}
		}*/
		
		// unmount
		unmount_target_device();

		// unlock encrypted device
		if (restore_target.is_encrypted_partition()){
			
			string msg_out, msg_err;
			
			restore_target = Device.luks_unlock(
				restore_target, "", "", parent_win, out msg_out, out msg_err);

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

		// mount root device
		if (restore_target.fstype == "btrfs"){

			//check subvolume layout

			bool supported = check_btrfs_layout(dst_root, dst_home);
			
			if (!supported && snapshot_to_restore.has_subvolumes()){
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
		}

		// mount all devices
		foreach (var mnt in mount_list) {
			
			// unlock encrypted device
			if (mnt.device.is_encrypted_partition()){

				string msg_out, msg_err;
		
				mnt.device = Device.luks_unlock(
					mnt.device, "", "", parent_win, out msg_out, out msg_err);

				//exit if not found
				if (mnt.device == null){
					return false;
				}
			}

			string mount_options = "";
			if (mnt.device.fstype == "btrfs"){
				if (mnt.mount_point == "/"){
					mount_options = "subvol=@";
				}
				else if (mnt.mount_point == "/home"){
					mount_options = "subvol=@home";
				}
			}

			if (!Device.mount(mnt.device.uuid, mount_point_restore + mnt.mount_point, mount_options)){
				return false;
			}
		}

		return true;
	}

	public void unmount_target_device(bool exit_on_error = true){
		if (mount_point_restore == null) { return; }

		log_debug("unmount_target_device()");
		
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

	public bool check_btrfs_volume(Device dev, string subvol_names){

		log_debug("check_btrfs_volume():%s".printf(subvol_names));
		
		string mnt_btrfs = mount_point_app + "/btrfs";
		dir_create(mnt_btrfs);

		Device.unmount(mnt_btrfs);
		Device.mount(dev.uuid, mnt_btrfs);

		bool supported = true;

		foreach(string subvol_name in subvol_names.split(",")){
			supported = supported && dir_exists(path_combine(mnt_btrfs,subvol_name));
		}

		if (Device.unmount(mnt_btrfs)){
			if (dir_exists(mnt_btrfs) && (dir_count(mnt_btrfs) == 0)){
				dir_delete(mnt_btrfs);
				log_debug(_("Removed mount directory: '%s'").printf(mnt_btrfs));
			}
		}

		return supported;
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

	public int64 estimate_system_size(){

		log_debug("estimate_system_size()");
		
		if (Main.first_snapshot_size > 0){
			return Main.first_snapshot_size;
		}
		else if (live_system()){
			return 0;
		}

		try {
			thread_estimate_running = true;
			thr_success = false;
			Thread.create<void> (estimate_system_size_thread, true);
		} catch (ThreadError e) {
			thread_estimate_running = false;
			thr_success = false;
			log_error (e.message);
		}

		while (thread_estimate_running){
			gtk_do_events ();
			Thread.usleep((ulong) GLib.TimeSpan.MILLISECOND * 100);
		}

		save_app_config();

		log_debug("estimate_system_size(): ok");
		
		return Main.first_snapshot_size;
	}

	public void estimate_system_size_thread(){
		thread_estimate_running = true;

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

			save_exclude_list_for_backup(TEMP_DIR);
			
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

		if ((required_space == 0) && (sys_root != null)){
			required_space = sys_root.used_bytes;
		}

		Main.first_snapshot_size = required_space;
		Main.first_snapshot_count = file_count;

		log_debug("First snapshot size: %s".printf(format_file_size(required_space)));
		log_debug("File count: %lld".printf(first_snapshot_count));

		thread_estimate_running = false;
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
		if (scheduled){
			// run once every hour
			return "@hourly timeshift --backup";

			/*
			if (schedule_hourly){
				
			}
			else if (schedule_daily){
				return "@daily timeshift --backup";
			}
			else if (schedule_weekly){
				return "@weekly timeshift --backup";
			}
			else if (schedule_monthly){
				return "@monthly timeshift --backup";
			}*/
		}

		return "";
	}

	private string get_crontab_entry_boot(){
		if (scheduled){
			return "@reboot sleep %dm && timeshift --backup".printf(startup_delay_interval_mins);
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

		log_debug("clean_logs()");
		
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

		log_debug("exit_app()");
		
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
}






