/*
 * Main.vala
 *
 * Copyright 2012-2018 Tony George <teejeetech@gmail.com>
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

public bool GTK_INITIALIZED = false;

public class Main : GLib.Object{
	
	public string app_path = "";
	public string share_folder = "";
	public string rsnapshot_conf_path = "";
	public string app_conf_path = "";
	public string app_conf_path_default = "";
	public bool first_run = false;
	
	public string backup_uuid = "";
	public string backup_parent_uuid = "";

	public bool btrfs_mode = true;
	public bool include_btrfs_home_for_backup = false;
	public bool include_btrfs_home_for_restore = false;
	
	public bool stop_cron_emails = true;
	
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
	public Gee.HashMap<string, Subvolume> sys_subvolumes;

	public string mount_point_restore = "";
	public string mount_point_app = "/mnt/timeshift";

	public LinuxDistro current_distro;
	public bool mirror_system = false;

	public bool schedule_monthly = false;
	public bool schedule_weekly = false;
	public bool schedule_daily = false;
	public bool schedule_hourly = false;
	public bool schedule_boot = false;
	public int count_monthly = 2;
	public int count_weekly = 3;
	public int count_daily = 5;
	public int count_hourly = 6;
	public int count_boot = 5;

	public bool btrfs_use_qgroup = true;

	public string app_mode = "";

	public bool dry_run = false;

	//global vars for controlling threads
	public bool thr_success = false;
	
	public bool thread_estimate_running = false;
	public bool thread_estimate_success = false;
	
	public bool thread_restore_running = false;
	public bool thread_restore_success = false;

	public bool thread_delete_running = false;
	public bool thread_delete_success = false;

	public bool thread_subvol_info_running = false;
	public bool thread_subvol_info_success = false;
		
	public int thr_retval = -1;
	public string thr_arg1 = "";
	public bool thr_timeout_active = false;
	public string thr_timeout_cmd = "";

	public int startup_delay_interval_mins = 10;
	public int retain_snapshots_max_days = 200;
	
	public int64 snapshot_location_free_space = 0;

	public const uint64 MIN_FREE_SPACE = 1 * GB;
	public static uint64 first_snapshot_size = 0;
	public static int64 first_snapshot_count = 0;
	
	public string log_dir = "";
	public string log_file = "";
	public AppLock app_lock;

	public Gee.ArrayList<Snapshot> delete_list;
	
	public Snapshot snapshot_to_delete;
	public Snapshot snapshot_to_restore;
	//public Device restore_target;
	public bool reinstall_grub2 = true;
	public bool update_initramfs = false;
	public bool update_grub = true;
	public string grub_device = "";
	public bool use_option_raw = true;

	public bool cmd_skip_grub = false;
	public string cmd_grub_device = "";
	public string cmd_target_device = "";
	public string cmd_backup_device = "";
	public string cmd_snapshot = "";
	public bool cmd_confirm = false;
	public bool cmd_verbose = true;
	public bool cmd_scripted = false;
	public string cmd_comments = "";
	public string cmd_tags = "";
	public bool? cmd_btrfs_mode = null;
	
	public string progress_text = "";

	public Gtk.Window? parent_window = null;
	
	public RsyncTask task;
	public DeleteFileTask delete_file_task;

	public Gee.HashMap<string, SystemUser> current_system_users;
	public string users_with_encrypted_home = "";
	public string encrypted_home_dirs = "";
	public bool encrypted_home_warning_shown = false;

	public string encrypted_private_dirs = "";
	public bool encrypted_private_warning_shown = false;

	public Main(string[] args, bool gui_mode){

		parse_some_arguments(args);
	
		if (gui_mode){
			app_mode = "";
			parent_window = new Gtk.Window(); // dummy
		}

		log_debug("Main()");

		if (LOG_DEBUG || gui_mode){
			log_debug("");
			log_debug(_("Running") + " %s v%s".printf(AppName, AppVersion));
			log_debug("");
		}

		check_and_remove_timeshift_btrfs();
		
		// init log ------------------

		try {
			string suffix = gui_mode ? "gui" : app_mode;
			
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
			if (LOG_DEBUG || gui_mode){
				log_debug(_("Session log file") + ": %s".printf(log_file));
			}
		}
		catch (Error e) {
			log_error (e.message);
		}
		
		// get Linux distribution info -----------------------
		
		this.current_distro = LinuxDistro.get_dist_info("/");

		if (LOG_DEBUG || gui_mode){
			log_debug(_("Distribution") + ": " + current_distro.full_name());
			log_debug("DIST_ID" + ": " + current_distro.dist_id);
		}

		// check dependencies ---------------------

		string message;
		if (!check_dependencies(out message)){
			if (gui_mode){
				string title = _("Missing Dependencies");
				gtk_messagebox(title, message, null, true);
			}
			exit_app(1);
		}

		// check and create lock ----------------------------

		app_lock = new AppLock();
		
		if (!app_lock.create("timeshift", app_mode)){
			if (gui_mode){
				string msg = "";
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
			exit(1);
		}

		// initialize variables -------------------------------

		this.app_path = (File.new_for_path (args[0])).get_parent().get_path ();
		this.share_folder = "/usr/share";
		this.app_conf_path = "/etc/timeshift.json";
		this.app_conf_path_default = "/etc/default/timeshift.json";
		//sys_root and sys_home will be initalized by update_partition_list()

		// check if running locally ------------------------

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

		// initialize lists -----------------

		repo = new SnapshotRepo();
		mount_list = new Gee.ArrayList<MountEntry>();
		delete_list = new Gee.ArrayList<Snapshot>();
		sys_subvolumes = new Gee.HashMap<string, Subvolume>();
		exclude_app_names = new Gee.ArrayList<string>();
		add_default_exclude_entries();
		//add_app_exclude_entries();
		task = new RsyncTask();
		delete_file_task = new DeleteFileTask();

		update_partitions();
		
		detect_system_devices();

		detect_encrypted_dirs();

		// set settings from config file ---------------------

		load_app_config();

		IconManager.init(args, AppShortName);
		
		log_debug("Main(): ok");
	}

	public void initialize(){
		
		initialize_repo();
	}

	public bool check_dependencies(out string msg){
		
		msg = "";

		log_debug("Main: check_dependencies()");
		
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

	public void check_and_remove_timeshift_btrfs(){
		
		if (cmd_exists("timeshift-btrfs")){
			string std_out, std_err;
			exec_sync("timeshift-btrfs-uninstall", out std_out, out std_err);
			log_msg(_("** Uninstalled Timeshift BTRFS **"));
		}
	}
	
	public bool check_btrfs_layout_system(Gtk.Window? win = null){

		log_debug("check_btrfs_layout_system()");

		bool supported = sys_subvolumes.has_key("@");
		if (include_btrfs_home_for_backup){
			supported =  supported && sys_subvolumes.has_key("@home");
		}

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

	public bool check_btrfs_layout(Device? dev_root, Device? dev_home, bool unlock){
		
		bool supported = true; // keep true for non-btrfs systems

		if ((dev_root != null) && (dev_root.fstype == "btrfs")){
			
			if ((dev_home != null) && (dev_home.fstype == "btrfs")){

				if (dev_home != dev_root){
					
					supported = supported && check_btrfs_volume(dev_root, "@", unlock);

					if (include_btrfs_home_for_backup){
						supported = supported && check_btrfs_volume(dev_home, "@home", unlock);
					}
				}
				else{
					if (include_btrfs_home_for_backup){
						supported = supported && check_btrfs_volume(dev_root, "@,@home", unlock);
					}
					else{
						supported = supported && check_btrfs_volume(dev_root, "@", unlock);
					}
				}
			}
		}

		return supported;
	}

	private void parse_some_arguments(string[] args){
		
		for (int k = 1; k < args.length; k++) // Oth arg is app path
		{
			switch (args[k].down()){
				case "--debug":
					LOG_COMMANDS = true;
					LOG_DEBUG = true;
					break;

				case "--btrfs":
					btrfs_mode = true;
					cmd_btrfs_mode = btrfs_mode;
					break;

				case "--rsync":
					btrfs_mode = false;
					cmd_btrfs_mode = btrfs_mode;
					break;
					
				case "--check":
					app_mode = "backup";
					break;

				case "--delete":
					app_mode = "delete";
					break;

				case "--delete-all":
					app_mode = "delete-all";
					break;

				case "--restore":
					app_mode = "restore";
					break;

				case "--clone":
					app_mode = "restore";
					break;

				case "--create":
					app_mode = "ondemand";
					break;

				case "--list":
				case "--list-snapshots":
					app_mode = "list-snapshots";
					break;

				case "--list-devices":
					app_mode = "list-devices";
					break;
			}
		}
	}

	private void detect_encrypted_dirs(){
		
		current_system_users = SystemUser.read_users_from_file("/etc/passwd","","");

		string txt = "";
		users_with_encrypted_home = "";
		encrypted_home_dirs = "";
		encrypted_private_dirs = "";
		
		foreach(var user in current_system_users.values){
			
			if (user.is_system) { continue; }
			
			if (txt.length > 0) { txt += " "; }
			txt += "%s".printf(user.name);

			if (user.has_encrypted_home){
				
				users_with_encrypted_home += " %s".printf(user.name);

				encrypted_home_dirs += "%s\n".printf(user.home_path);
			}

			if (user.has_encrypted_private_dirs){

				foreach(string enc_path in user.encrypted_private_dirs){
					encrypted_private_dirs += "%s\n".printf(enc_path);
				}
			}
		}
		users_with_encrypted_home = users_with_encrypted_home.strip();
		
		log_debug("Users: %s".printf(txt));
		log_debug("Encrypted home users: %s".printf(users_with_encrypted_home));
		log_debug("Encrypted home dirs:\n%s".printf(encrypted_home_dirs));
		log_debug("Encrypted private dirs:\n%s".printf(encrypted_private_dirs));
	}
	
	// exclude lists
	
	public void add_default_exclude_entries(){

		log_debug("Main: add_default_exclude_entries()");
		
		exclude_list_user = new Gee.ArrayList<string>();
		exclude_list_default = new Gee.ArrayList<string>();
		exclude_list_default_extra = new Gee.ArrayList<string>();
		exclude_list_home = new Gee.ArrayList<string>();
		exclude_list_restore = new Gee.ArrayList<string>();
		exclude_list_apps = new Gee.ArrayList<AppExcludeEntry>();
		
		partitions = new Gee.ArrayList<Device>();

		// default exclude entries -------------------

		exclude_list_default.add("/dev/*");
		exclude_list_default.add("/proc/*");
		exclude_list_default.add("/sys/*");
		exclude_list_default.add("/media/*");
		exclude_list_default.add("/mnt/*");
		exclude_list_default.add("/tmp/*");
		exclude_list_default.add("/run/*");
		exclude_list_default.add("/var/run/*");
		exclude_list_default.add("/var/lock/*");
		//exclude_list_default.add("/var/spool/*");
		exclude_list_default.add("/var/lib/docker/*");
		exclude_list_default.add("/var/lib/schroot/*");
		exclude_list_default.add("/lost+found");
		exclude_list_default.add("/timeshift/*");
		exclude_list_default.add("/timeshift-btrfs/*");
		exclude_list_default.add("/data/*");
		exclude_list_default.add("/DATA/*");
		exclude_list_default.add("/cdrom/*");
		exclude_list_default.add("/sdcard/*");
		exclude_list_default.add("/system/*");
		exclude_list_default.add("/etc/timeshift.json");
		exclude_list_default.add("/var/log/timeshift/*");
		exclude_list_default.add("/var/log/timeshift-btrfs/*");
		exclude_list_default.add("/swapfile");

		foreach(var entry in FsTabEntry.read_file("/etc/fstab")){

			if (!entry.mount_point.has_prefix("/")){ continue; }

			// ignore standard system folders
			if (entry.mount_point == "/"){ continue; }
			if (entry.mount_point.has_prefix("/bin")){ continue; }
			if (entry.mount_point.has_prefix("/boot")){ continue; }
			if (entry.mount_point.has_prefix("/cdrom")){ continue; }
			if (entry.mount_point.has_prefix("/dev")){ continue; }
			if (entry.mount_point.has_prefix("/etc")){ continue; }
			if (entry.mount_point.has_prefix("/home")){ continue; }
			if (entry.mount_point.has_prefix("/lib")){ continue; }
			if (entry.mount_point.has_prefix("/lib64")){ continue; }
			if (entry.mount_point.has_prefix("/media")){ continue; }
			if (entry.mount_point.has_prefix("/mnt")){ continue; }
			if (entry.mount_point.has_prefix("/opt")){ continue; }
			if (entry.mount_point.has_prefix("/proc")){ continue; }
			if (entry.mount_point.has_prefix("/root")){ continue; }
			if (entry.mount_point.has_prefix("/run")){ continue; }
			if (entry.mount_point.has_prefix("/sbin")){ continue; }
			if (entry.mount_point.has_prefix("/snap")){ continue; }
			if (entry.mount_point.has_prefix("/srv")){ continue; }
			if (entry.mount_point.has_prefix("/sys")){ continue; }
			if (entry.mount_point.has_prefix("/system")){ continue; }
			if (entry.mount_point.has_prefix("/tmp")){ continue; }
			if (entry.mount_point.has_prefix("/usr")){ continue; }
			if (entry.mount_point.has_prefix("/var")){ continue; }

			// add exclude entry for devices mounted to non-standard locations

			exclude_list_default_extra.add(entry.mount_point + "/*");
		}

		exclude_list_default.add("/root/.thumbnails");
		exclude_list_default.add("/root/.cache");
		exclude_list_default.add("/root/.dbus");
		exclude_list_default.add("/root/.gvfs");
		exclude_list_default.add("/root/.local/share/[Tt]rash");

		exclude_list_default.add("/home/*/.thumbnails");
		exclude_list_default.add("/home/*/.cache");
		exclude_list_default.add("/home/*/.dbus");
		exclude_list_default.add("/home/*/.gvfs");
		exclude_list_default.add("/home/*/.local/share/[Tt]rash");

		// default extra ------------------

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

		// default home ----------------

		//exclude_list_home.add("+ /root/.**");
		//exclude_list_home.add("+ /home/*/.**");
		exclude_list_home.add("/root/**");
		exclude_list_home.add("/home/*/**"); // Note: /home/** ignores include filters under /home

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

		log_debug("Main: add_default_exclude_entries(): exit");
	}

	public void add_app_exclude_entries(){

		log_debug("Main: add_app_exclude_entries()");
		
		AppExcludeEntry.clear();
		
		if (snapshot_to_restore != null){
			add_app_exclude_entries_for_prefix(path_combine(snapshot_to_restore.path, "localhost"));
		}

		//if (!restore_current_system){
		//	add_app_exclude_entries_for_prefix(mount_point_restore);
		//}

		exclude_list_apps = AppExcludeEntry.get_apps_list(exclude_app_names);

		log_debug("Main: add_app_exclude_entries(): exit");
	}

	private void add_app_exclude_entries_for_prefix(string path_prefix){
		
		string path = "";

		path = path_combine(path_prefix, "root");
		AppExcludeEntry.add_app_exclude_entries_from_path(path);

		path = path_combine(path_prefix, "home");
		AppExcludeEntry.add_app_exclude_entries_from_home(path);
	}
	

	public Gee.ArrayList<string> create_exclude_list_for_backup(){

		log_debug("Main: create_exclude_list_for_backup()");
		
		var list = new Gee.ArrayList<string>();

		// add default entries ---------------------------
		
		foreach(string path in exclude_list_default){
			if (!list.contains(path)){
				list.add(path);
			}
		}

		// add default extra entries ---------------------------
		
		foreach(string path in exclude_list_default_extra){
			if (!list.contains(path)){
				list.add(path);
			}
		}

		// add entries to exclude **decrypted** contents in $HOME
		// decrypted contents should never be backed-up or restored
		// this overrides all other user entries in exclude_list_user
		//  -------------------------------------------------------
		
		foreach(var user in current_system_users.values){
			
			if (user.is_system){ continue; }
			
			if (user.has_encrypted_home){
				
				// exclude decrypted contents in user's home ($HOME)
				string path = "%s/**".printf(user.home_path);
				list.add(path);
			}
			
			if (user.has_encrypted_private_dirs){

				foreach(string enc_path in user.encrypted_private_dirs){
					
					// exclude decrypted contents in private dirs ($HOME/Private)
					string path = "%s/**".printf(enc_path);
					list.add(path);
				}
			}
		}

		// exclude each user individually if not included in exclude_list_user

		foreach(var user in current_system_users.values){

			if (user.is_system){ continue; }

			string exc_pattern = "%s/**".printf(user.home_path);
			string inc_pattern = "+ %s/**".printf(user.home_path);
			string inc_hidden_pattern = "+ %s/.**".printf(user.home_path);

			if (user.has_encrypted_home){
				inc_pattern = "+ /home/.ecryptfs/%s/***".printf(user.name);
				exc_pattern = "/home/.ecryptfs/%s/***".printf(user.name);
			}
			
			bool include_hidden = exclude_list_user.contains(inc_hidden_pattern);
			bool include_all = exclude_list_user.contains(inc_pattern);
			bool exclude_all = !include_hidden && !include_all;

			if (exclude_all){
				if (!exclude_list_user.contains(exc_pattern)){
					exclude_list_user.add(exc_pattern);
				}
				if (exclude_list_user.contains(inc_pattern)){
					exclude_list_user.remove(inc_pattern);
				}
				if (exclude_list_user.contains(inc_hidden_pattern)){
					exclude_list_user.remove(inc_hidden_pattern);
				}
			}
		}

		// add user entries from current settings ----------
		
		foreach(string path in exclude_list_user){
			if (!list.contains(path)){
				list.add(path);
			}
		}

		// add common entries for excluding home folders for all users --------
		
		foreach(string path in exclude_list_home){
			if (!list.contains(path)){
				list.add(path);
			}
		}

		string timeshift_path = "/timeshift/*";
		if (!list.contains(timeshift_path)){
			list.add(timeshift_path);
		}

		log_debug("Main: create_exclude_list_for_backup(): exit");
		
		return list;
	}

	public Gee.ArrayList<string> create_exclude_list_for_restore(){

		log_debug("Main: create_exclude_list_for_restore()");
		
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

			// skip include filters for restore
			if (path.strip().has_prefix("+")){ continue; }
			
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

		log_debug("Main: create_exclude_list_for_restore(): exit");
		
		return exclude_list_restore;
	}


	public bool save_exclude_list_for_backup(string output_path){

		log_debug("Main: save_exclude_list_for_backup()");
		
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

		log_debug("Main: save_exclude_list_for_restore()");
		
		var list = create_exclude_list_for_restore();

		log_debug("Exclude list -------------");
		
		var txt = "";
		foreach(var pattern in list){
			if (pattern.strip().length > 0){
				txt += "%s\n".printf(pattern);
				log_debug(pattern);
			}
		}
		
		return file_write(restore_exclude_file, txt);
	}

	public void save_exclude_list_selections(){

		log_debug("Main: save_exclude_list_selections()");
		
		// add new selected items
		foreach(var entry in exclude_list_apps){
			if (entry.enabled && !exclude_app_names.contains(entry.name)){
				exclude_app_names.add(entry.name);
				log_debug("add app name: %s".printf(entry.name));
			}
		}

		// remove item only if present in current list and un-selected
		foreach(var entry in exclude_list_apps){
			if (!entry.enabled && exclude_app_names.contains(entry.name)){
				exclude_app_names.remove(entry.name);
				log_debug("remove app name: %s".printf(entry.name));
			}
		}

		exclude_app_names.sort((a,b) => {
			return Posix.strcmp(a,b);
		});
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

	public bool create_snapshot (bool is_ondemand, Gtk.Window? parent_win){

		log_debug("Main: create_snapshot()");
		
		bool status = true;
		bool update_symlinks = false;

		string sys_uuid = (sys_root == null) ? "" : sys_root.uuid;
		
		try
		{
			if (btrfs_mode && (check_btrfs_layout_system() == false)){
				return false;
			}
		
			// create a timestamp
			DateTime now = new DateTime.now_local();

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

			// create snapshot root if missing
			var f = File.new_for_path(repo.snapshots_path);
			if (!f.query_exists()){
				log_debug("mkdir: %s".printf(repo.snapshots_path));
				f.make_directory_with_parents();
			}

			// ondemand
			if (is_ondemand){
				bool ok = create_snapshot_for_tag ("ondemand",now); 
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
						status = create_snapshot_for_tag ("boot",now);
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
						status = create_snapshot_for_tag ("hourly",now);
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
						status = create_snapshot_for_tag ("daily",now);
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
						status = create_snapshot_for_tag ("weekly",now);
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
						status = create_snapshot_for_tag ("monthly",now);
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
			
			log_msg(string.nfill(78, '-'));

			repo.load_snapshots(); // reload list for new snapshot
			
			if (app_mode.length != 0){
				repo.auto_remove();
				repo.load_snapshots();
			}

			if (update_symlinks){
				repo.create_symlinks();
			}
			
			//log_msg("OK");
		}
		catch(Error e){
			log_error (e.message);
			return false;
		}

		return status;
	}

	private bool create_snapshot_for_tag(string tag, DateTime dt_created){

		log_debug("Main: backup_and_rotate()");
		
		// save start time
		var dt_begin = new DateTime.now_local();
		bool status = true;
		
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
	
					var message = _("Tagged snapshot") + " '%s': %s".printf(backup_to_rotate.name, tag);
					log_msg(message);

					return true;
				}
			}

			if (!repo.available() || !repo.has_space()){
				log_error(repo.status_message);
				log_error(repo.status_details);
				exit_app();
			}
			
			// create new snapshot -----------------------

			Snapshot new_snapshot = null;
			if (btrfs_mode){
				new_snapshot = create_snapshot_with_btrfs(tag, dt_created);
			}
			else{
				new_snapshot = create_snapshot_with_rsync(tag, dt_created);
			}
			
			// finish ------------------------------
		
			var dt_end = new DateTime.now_local();
			TimeSpan elapsed = dt_end.difference(dt_begin);
			long seconds = (long)(elapsed * 1.0 / TimeSpan.SECOND);
			
			var message = "";
			if (new_snapshot != null){
				message = "%s %s (%lds)".printf((btrfs_mode ? "BTRFS" : "RSYNC"), _("Snapshot saved successfully"), seconds);
			}
			else{
				message = _("Failed to create snapshot");
			}

			log_msg(message);
			OSDNotify.notify_send("TimeShift", message, 10000, "low");

			if (new_snapshot != null){
				message = _("Tagged snapshot") + " '%s': %s".printf(new_snapshot.name, tag);
				log_msg(message);
			}
		}
		catch(Error e){
			log_error (e.message);
			return false;
		}

		return status;
	}

	private Snapshot? create_snapshot_with_rsync(string tag, DateTime dt_created){

		log_msg(string.nfill(78, '-'));

		if (first_snapshot_size == 0){
			log_msg(_("Estimating system size..."));
			estimate_system_size();
		}
		
		log_msg(_("Creating new snapshot...") + "(RSYNC)");

		log_msg(_("Saving to device") + ": %s".printf(repo.device.device) + ", " + _("mounted at path") + ": %s".printf(repo.mount_path));
		
		// take new backup ---------------------------------

		if (repo.mount_path.length == 0){
			log_error("Backup location not mounted");
			exit_app();
		}

		string time_stamp = dt_created.format("%Y-%m-%d_%H-%M-%S");
		string snapshot_dir = repo.snapshots_path;
		string snapshot_name = time_stamp;
		string snapshot_path = path_combine(snapshot_dir, snapshot_name);
		dir_create(snapshot_path);
		string localhost_path = path_combine(snapshot_path, "localhost");
		dir_create(localhost_path);
		
		string sys_uuid = (sys_root == null) ? "" : sys_root.uuid;

		Snapshot snapshot_to_link = null;

		// check if a snapshot was restored recently and use it for linking ---------

		try{
			
			string ctl_path = path_combine(snapshot_dir, ".sync-restore");
			var f = File.new_for_path(ctl_path);
			
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
		}
		catch(Error e){
			log_error (e.message);
			return null;
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
			return null;
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

			stdout.printf("%6.2f%% %s (%s %s)\r".printf(task.progress * 100.0, _("complete"), task.stat_time_remaining, _("remaining")));
			stdout.flush();
		}

		stdout.printf(string.nfill(80, ' '));
		stdout.flush();

		stdout.printf("\r");
		stdout.flush();
		
		if (task.total_size == 0){
			log_error(_("rsync returned an error"));
			log_error(_("Failed to create new snapshot"));
			return null;
		}

		string initial_tags = (tag == "ondemand") ? "" : tag;
		
		// write control file
		// this step is redundant - just in case if app crashes while parsing log file in next step
		//Snapshot.write_control_file(
		//	snapshot_path, dt_created, sys_uuid, current_distro.full_name(),
		//	initial_tags, cmd_comments, 0, false, false, repo);

		// parse log file
		//progress_text = _("Parsing log file...");
		//log_msg(progress_text);
		//var task = new RsyncTask();
		//task.parse_log(log_file);

		int64 fcount = file_line_count(log_file);

		// write control file (final - with file count after parsing log)
		var snapshot = Snapshot.write_control_file(
			snapshot_path, dt_created, sys_uuid, current_distro.full_name(),
			initial_tags, cmd_comments, fcount, false, false, repo);

		set_tags(snapshot); // set_tags() will update the control file

		return snapshot;
	}

	private Snapshot? create_snapshot_with_btrfs(string tag, DateTime dt_created){

		log_msg(_("Creating new backup...") + "(BTRFS)");

		log_msg(_("Saving to device") + ": %s".printf(repo.device.device) + ", " + _("mounted at path") + ": %s".printf(repo.mount_paths["@"]));
		if ((repo.device_home != null) && (repo.device_home.uuid != repo.device.uuid)){
			log_msg(_("Saving to device") + ": %s".printf(repo.device_home.device) + ", " + _("mounted at path") + ": %s".printf(repo.mount_paths["@home"]));
		}

		// take new backup ---------------------------------

		if (repo.mount_path.length == 0){
			log_error("Snapshot device not mounted");
			exit_app();
		}

		string time_stamp = dt_created.format("%Y-%m-%d_%H-%M-%S");
		string snapshot_name = time_stamp;
		string sys_uuid = (sys_root == null) ? "" : sys_root.uuid;
		string snapshot_path = "";
		
		// create subvolume snapshots

		var subvol_names = new string[] { "@" };
		
		if (include_btrfs_home_for_backup){
			
			subvol_names = new string[] { "@","@home" };
		}
		
		foreach(var subvol_name in subvol_names){

			snapshot_path = path_combine(repo.mount_paths[subvol_name], "timeshift-btrfs/snapshots/%s".printf(snapshot_name));
			
			dir_create(snapshot_path, true);
			
			string src_path = path_combine(repo.mount_paths[subvol_name], subvol_name);
			
			string dst_path = path_combine(snapshot_path, subvol_name);

			// Dirty hack to fix the nested subvilumes issue (cause of issue is unknown)
			if (dst_path.has_suffix("/@/@")){
				dst_path = dst_path.replace("/@/@", "/@");
			}
			else if (dst_path.has_suffix("/@home/@home")){
				dst_path = dst_path.replace("/@home/@home", "/@home");
			}
			
			string cmd = "btrfs subvolume snapshot '%s' '%s' \n".printf(src_path, dst_path);
			
			if (LOG_COMMANDS) { log_debug(cmd); }

			string std_out, std_err;
			
			int ret_val = exec_sync(cmd, out std_out, out std_err);
			
			if (ret_val != 0){
				
				log_error (std_err);
				log_error(_("btrfs returned an error") + ": %d".printf(ret_val));
				log_error(_("Failed to create subvolume snapshot") + ": %s".printf(subvol_name));
				return null;
			}
			else{
				log_msg(_("Created subvolume snapshot") + ": %s".printf(dst_path));
			}
		}

		//log_msg(_("Writing control file..."));

		snapshot_path = path_combine(repo.mount_paths["@"], "timeshift-btrfs/snapshots/%s".printf(snapshot_name));

		string initial_tags = (tag == "ondemand") ? "" : tag;
		
		// write control file
		var snapshot = Snapshot.write_control_file(
			snapshot_path, dt_created, sys_uuid, current_distro.full_name(),
			initial_tags, cmd_comments, 0, true, false, repo);

		// write subvolume info
		foreach(var subvol in sys_subvolumes.values){
			snapshot.subvolumes.set(subvol.name, subvol);
		}
		snapshot.update_control_file(); // save subvolume info

		set_tags(snapshot); // set_tags() will update the control file
		
		return snapshot;
	}

	private void set_tags(Snapshot snapshot){

		// add tags passed on commandline for both --check and --create
		
		foreach(string tag in cmd_tags.split(",")){
			switch(tag.strip().up()){
			case "B":
				snapshot.add_tag("boot");
				break;
			case "H":
				snapshot.add_tag("hourly");
				break;
			case "D":
				snapshot.add_tag("daily");
				break;
			case "W":
				snapshot.add_tag("weekly");
				break;
			case "M":
				snapshot.add_tag("monthly");
				break;
			}
		}

		// add tag as ondemand if no other tag is specified
		
		if (snapshot.tags.size == 0){
			snapshot.add_tag("ondemand");
		}
	}

	public void validate_cmd_tags(){
		foreach(string tag in cmd_tags.split(",")){
			switch(tag.strip().up()){
			case "B":
			case "H":
			case "D":
			case "W":
			case "M":
				break;
			default:
				log_error(_("Unknown value specified for option --tags") + " (%s).".printf(tag));
				log_error(_("Expected values: O, B, H, D, W, M"));
				exit_app(1);
				break;
			}
		}
	}
	
	// gui delete

	public void delete_begin(){

		log_debug("Main: delete_begin()");
		progress_text = _("Preparing...");
		
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

		log_debug("Main: delete_begin(): exit");
	}

	public void delete_thread(){

		log_debug("delete_thread()");

		bool status = true;

		foreach(var bak in delete_list){
			bak.mark_for_deletion();
		}
		
		while (delete_list.size > 0){

			var bak = delete_list[0];
			bak.mark_for_deletion(); // mark for deletion again since initial list may have changed

			if (btrfs_mode){
				status = bak.remove(true); // wait till complete

				var message = "%s '%s'".printf(_("Removed"), bak.name);
				OSDNotify.notify_send("TimeShift", message, 10000, "low");
			}
			else{

				delete_file_task = bak.delete_file_task;
				delete_file_task.prg_count_total = (int64) Main.first_snapshot_count;
			
				status = bak.remove(true); // wait till complete

				if (delete_file_task.status != AppStatus.CANCELLED){
					var message = "%s '%s' (%s)".printf(_("Removed"), bak.name, delete_file_task.stat_time_elapsed);
					OSDNotify.notify_send("TimeShift", message, 10000, "low");
				}
			}

			delete_list.remove(bak);
		}

		thread_delete_running = false;
		thread_delete_success = status;
	}
	
	// restore  - properties

	public Device? dst_root{
		get {
			foreach(var mnt in mount_list){
				if (mnt.mount_point == "/"){
					return mnt.device;
				}
			}
			return null;
		}
		set{
			foreach(var mnt in mount_list){
				if (mnt.mount_point == "/"){
					mnt.device = value;
					break;
				}
			}
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
		set{
			foreach(var mnt in mount_list){
				if (mnt.mount_point == "/boot"){
					mnt.device = value;
					break;
				}
			}
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
		set{
			foreach(var mnt in mount_list){
				if (mnt.mount_point == "/boot/efi"){
					mnt.device = value;
					break;
				}
			}
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
		set{
			foreach(var mnt in mount_list){
				if (mnt.mount_point == "/home"){
					mnt.device = value;
					break;
				}
			}
		}
	}
	
	public bool restore_current_system{
		get {
			if ((sys_root != null) &&
				((dst_root.device == sys_root.device) || (dst_root.uuid == sys_root.uuid))){
					
				return true;
			}
			else{
				return false;
			}
		}
	}

	public string restore_source_path{
		owned get {
			if (mirror_system){
				string source_path = "/tmp/timeshift";
				dir_create(source_path);
				return source_path;
			}
			else{
				return snapshot_to_restore.path;
			}
		}
	}
	
	public string restore_target_path{
		owned get {
			if (restore_current_system){
				return "/";
			}
			else{
				return mount_point_restore + "/";
			}
		}
	}

	public string restore_log_file{
		owned get {
			return restore_source_path + "/rsync-log-restore";
		}
	}

	public string restore_exclude_file{
		owned get {
			return restore_source_path + "/exclude-restore.list";
		}
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
		dst_root = null;
		
		foreach(var fs_entry in fstab_list){

			// skip mounting for non-system devices ----------
			
			if (!fs_entry.is_for_system_directory()){
				continue;
			}

			// skip mounting excluded devices -----------------------
			
			string p1 = "%s/*".printf(fs_entry.mount_point);
			string p2 = "%s/**".printf(fs_entry.mount_point);
			string p3 = "%s/***".printf(fs_entry.mount_point);
			
			if (exclude_list_default.contains(p1) || exclude_list_user.contains(p1)){
				continue;
			}
			else if (exclude_list_default.contains(p2) || exclude_list_user.contains(p2)){
				continue;
			}
			else if (exclude_list_default.contains(p3) || exclude_list_user.contains(p3)){
				continue;
			}

			// find device by name or uuid --------------------------
			
			Device dev_fstab = null;
			if (fs_entry.device_uuid.length > 0){
				dev_fstab = Device.get_device_by_uuid(fs_entry.device_uuid);
			}
			else{
				dev_fstab = Device.get_device_by_name(fs_entry.device_string);
			}

			if (dev_fstab == null){

				/*
				Check if the device mentioned in fstab entry is a mapped device.
				If it is, then try finding the parent device which may be available on the current system.
				Prompt user to unlock it if found.
				
				Note:
				Mapped name may be different on running system, or it may be same.
				Since it is not reliable, we will try to identify the parent intead of the mapped device.
				*/
				
				if (fs_entry.device_string.has_prefix("/dev/mapper/")){
					
					string mapped_name = fs_entry.device_string.replace("/dev/mapper/","");
					
					foreach(var crypt_entry in crypttab_list){
						
						if (crypt_entry.mapped_name == mapped_name){

							// we found the entry for the mapped device
							fs_entry.device_string = crypt_entry.device_string;

							if (fs_entry.device_uuid.length > 0){
								
								// we have the parent's uuid. get the luks device and prompt user to unlock it.
								var dev_luks = Device.get_device_by_uuid(fs_entry.device_uuid);
								
								if (dev_luks != null){
									
									string msg_out, msg_err;
									var dev_unlocked = Device.luks_unlock(
										dev_luks, "", "", parent_window, out msg_out, out msg_err);

									if (dev_unlocked != null){
										dev_fstab = dev_unlocked;
										update_partitions();
									}
									else{
										dev_fstab = dev_luks; // map to parent
									}
								}
							}
							else{
								// nothing to do: we don't have the parent's uuid
							}

							break;
						}
					}
				}
			}

			if (dev_fstab != null){
				
				log_debug("added: dev: %s, path: %s, options: %s".printf(
					dev_fstab.device, fs_entry.mount_point, fs_entry.options));
					
				mount_list.add(new MountEntry(dev_fstab, fs_entry.mount_point, fs_entry.options));
				
				if (fs_entry.mount_point == "/"){
					dst_root = dev_fstab;
				}
			}
			else{
				log_debug("missing: dev: %s, path: %s, options: %s".printf(
					fs_entry.device_string, fs_entry.mount_point, fs_entry.options));

				mount_list.add(new MountEntry(null, fs_entry.mount_point, fs_entry.options));
			}

			if (fs_entry.mount_point == "/"){
				root_found = true;
			}
			if (fs_entry.mount_point == "/boot"){
				boot_found = true;
			}
			if (fs_entry.mount_point == "/home"){
				home_found = true;
			}
		}

		if (!root_found){
			log_debug("added null entry: /");
			mount_list.add(new MountEntry(null, "/", "")); // add root entry
		}

		if (!boot_found){
			log_debug("added null entry: /boot");
			mount_list.add(new MountEntry(null, "/boot", "")); // add boot entry
		}

		if (!home_found){
			log_debug("added null entry: /home");
			mount_list.add(new MountEntry(null, "/home", "")); // add home entry
		}

		/*
		While cloning the system, /boot is the only mount point that
		we will leave unchanged (to avoid encrypted systems from breaking).
		All other mounts like /home will be defaulted to target device
		(to prevent the "cloned" system from using the original device)
		*/
		
		if (mirror_system){
			dst_root = null;
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

		init_boot_options(); // boot options depend on the mount list
		
		log_debug("Main: init_mount_list(): exit");
	}

	public void init_boot_options(){

		var grub_dev = dst_root;
		if(grub_dev != null){
			grub_device = grub_dev.device;
		}

		while ((grub_dev != null) && grub_dev.has_parent()){
			grub_dev = grub_dev.parent;
			grub_device = grub_dev.device;
		}

		if (mirror_system){
			// bootloader must be re-installed
			reinstall_grub2 = true;
			update_initramfs = true;
			update_grub = true;
		}
		else{
			if (snapshot_to_restore.distro.dist_id == "fedora"){
				// grub2-install should never be run on EFI fedora systems
				reinstall_grub2 = false;
				update_initramfs = false;
				update_grub = true;
			}
			else{
				reinstall_grub2 = true;
				update_initramfs = false;
				update_grub = true;
			}
		}
	}
	
	public bool restore_snapshot(Gtk.Window? parent_win){

		log_debug("Main: restore_snapshot()");
		
		parent_window = parent_win;

		// remove mount points which will remain on root fs
		
		for(int i = mount_list.size-1; i >= 0; i--){
			var entry = mount_list[i];
			if (entry.device == null){
				mount_list.remove(entry);
			}
		}
			
		// check if we have all required inputs and abort on error
		
		if (!mirror_system){
			
			if (repo.device == null){
				log_error(_("Backup device not specified!"));
				return false;
			}
			else{
				log_msg(string.nfill(78, '*'));
				log_msg(_("Backup Device") + ": %s".printf(repo.device.device));
				log_msg(string.nfill(78, '*'));
			}
			
			if (snapshot_to_restore == null){
				log_error(_("Snapshot to restore not specified!"));
				return false;
			}
			else if ((snapshot_to_restore != null) && (snapshot_to_restore.marked_for_deletion)){
				log_error(_("Invalid Snapshot"));
				log_error(_("Selected snapshot is marked for deletion"));
				return false;
			}
			else {
				log_msg(string.nfill(78, '*'));
				log_msg("%s: %s ~ %s".printf(_("Snapshot"), snapshot_to_restore.name, snapshot_to_restore.description));
				log_msg(string.nfill(78, '*'));
			}
		}
		
		// final check - check if target root device is mounted

		if (btrfs_mode){
			if (repo.mount_paths["@"].length == 0){
				log_error(_("BTRFS device is not mounted") + ": @");
				return false;
			}
			if (include_btrfs_home_for_restore && (repo.mount_paths["@home"].length == 0)){
				log_error(_("BTRFS device is not mounted") + ": @home");
				return false;
			}
		}
		else{
			if (dst_root == null){
				log_error(_("Target device not specified!"));
				return false;
			}

			if (!restore_current_system){
				if (mount_point_restore.strip().length == 0){
					log_error(_("Target device is not mounted"));
					return false;
				}
			}
		}

		try {
			thread_restore_running = true;
			thr_success = false;
			
			if (btrfs_mode){
				Thread.create<bool> (restore_execute_btrfs, true);
			}
			else{
				Thread.create<bool> (restore_execute_rsync, true);
			}
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

		if (!dry_run){
			snapshot_to_restore = null;
		}

		log_debug("Main: restore_snapshot(): exit");
		
		return thr_success;
	}

	public void get_restore_messages(bool formatted,
		out string msg_devices, out string msg_reboot, out string msg_disclaimer){
			
		string msg = "";

		log_debug("Main: get_restore_messages()");

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

		foreach(var entry in mount_list){
			
			if (entry.device == null){ continue; }

			if (btrfs_mode){
				
				if (entry.subvolume_name().length == 0){ continue; }
				
				if (!App.snapshot_to_restore.subvolumes.has_key(entry.subvolume_name())){ continue; }

				if ((entry.subvolume_name() == "@home") && !include_btrfs_home_for_restore){ continue; }
			}
			
			string dev_name = entry.device.full_name_with_parent;
			if (entry.subvolume_name().length > 0){
				dev_name = dev_name + "(%s)".printf(entry.subvolume_name());
			}
			else if (entry.lvm_name().length > 0){
				dev_name = dev_name + "(%s)".printf(entry.lvm_name());
			}
			
			if (dev_name.length > max_dev){
				max_dev = dev_name.length;
			}
			if (entry.mount_point.length > max_mount){
				max_mount = entry.mount_point.length;
			}
		}

		var txt = ("%%-%ds  %%-%ds".printf(max_dev, max_mount))
			.printf(_("Device"),_("Mount"));
		txt += "\n";

		txt += string.nfill(max_dev, '-') + "  " + string.nfill(max_mount, '-');
		txt += "\n";
		
		foreach(var entry in mount_list){
			
			if (entry.device == null){ continue; }

			if (btrfs_mode){

				if (entry.subvolume_name().length == 0){ continue; }
				
				if (!App.snapshot_to_restore.subvolumes.has_key(entry.subvolume_name())){ continue; }

				if ((entry.subvolume_name() == "@home") && !include_btrfs_home_for_restore){ continue; }
			}
			
			string dev_name = entry.device.full_name_with_parent;
			if (entry.subvolume_name().length > 0){
				dev_name = dev_name + "(%s)".printf(entry.subvolume_name());
			}
			else if (entry.lvm_name().length > 0){
				dev_name = dev_name + "(%s)".printf(entry.lvm_name());
			}
			
			txt += ("%%-%ds  %%-%ds".printf(max_dev, max_mount)).printf(dev_name, entry.mount_point);

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
		//msg += _("If restore fails and you are unable to boot the system, then boot from the Live CD, install Timeshift, and try to restore again.") + "\n";

		// msg_reboot -----------------------
		
		msg = "";
		if (restore_current_system){	
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

		log_debug("Main: get_restore_messages(): exit");
	}

	private void create_restore_scripts(out string sh_sync, out string sh_finish){

		log_debug("Main: create_restore_scripts()");
		
		string sh = "";

		// create scripts --------------------------------------

		sh = "";
		sh += "echo ''\n";
		if (restore_current_system){
			log_debug("restoring current system");
			
			sh += "echo '" + _("Please do not interrupt the restore process!") + "'\n";
			sh += "echo '" + _("System will reboot after files are restored") + "'\n";
		}
		sh += "echo ''\n";
		sh += "sleep 3s\n";

		// run rsync ---------------------------------------

		sh += "rsync -avir --force --delete --delete-after";

		if (dry_run){
			sh += " --dry-run";
		}
		
		sh += " --log-file=\"%s\"".printf(restore_log_file);
		sh += " --exclude-from=\"%s\"".printf(restore_exclude_file);

		if (mirror_system){
			sh += " \"%s\" \"%s\" \n".printf("/", restore_target_path);
		}
		else{
			sh += " \"%s\" \"%s\" \n".printf(restore_source_path + "/localhost/", restore_target_path);
		}

		if (dry_run){
			sh_sync = sh;
			sh_finish = "";
			return; // no need to continue
		}

		sh += "sync \n"; // sync file system

		log_debug("rsync script:");
		log_debug(sh);

		sh_sync = sh;
		
		// chroot and re-install grub2 ---------------------

		log_debug("reinstall_grub2=%s".printf(reinstall_grub2.to_string()));
		log_debug("grub_device=%s".printf((grub_device == null) ? "null" : grub_device));

		var target_distro = LinuxDistro.get_dist_info(restore_target_path);
		
		sh = "";

		string chroot = "";
		if (!restore_current_system){
			//if ((current_distro.dist_type == "arch") && cmd_exists("arch-chroot")){
				//chroot += "arch-chroot \"%s\"".printf(restore_target_path);
			//}
			//else{
				chroot += "chroot \"%s\"".printf(restore_target_path);
			//}

			// bind system directories for chrooted system
			sh += "for i in dev dev/pts proc run sys; do mount --bind \"/$i\" \"%s$i\"; done \n".printf(restore_target_path);
		}

		if (reinstall_grub2 && (grub_device != null) && (grub_device.length > 0)){
			
			sh += "sync \n";
			sh += "echo '' \n";
			sh += "echo '" + _("Re-installing GRUB2 bootloader...") + "' \n";

			// search for other operating systems
			//sh += "chroot \"%s\" os-prober \n".printf(restore_target_path);
			
			// re-install grub ---------------

			if (target_distro.dist_type == "redhat"){

				// this will run only in clone mode
				//sh += "%s grub2-install %s \n".printf(chroot, grub_device);
				sh += "%s grub2-install --recheck --force %s \n".printf(chroot, grub_device);

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
				//sh += "%s grub-install %s \n".printf(chroot, grub_device);
				sh += "%s grub-install --recheck --force %s \n".printf(chroot, grub_device);
			}

			// create new grub menu
			//sh += "chroot \"%s\" grub-mkconfig -o /boot/grub/grub.cfg \n".printf(restore_target_path);
		}
		else{
			log_debug("skipping sh_grub: reinstall_grub2=%s, grub_device=%s".printf(
				reinstall_grub2.to_string(), (grub_device == null) ? "null" : grub_device));
		}

		// update initramfs --------------

		if (update_initramfs){
			sh += "echo '' \n";
			sh += "echo '" + _("Generating initramfs...") + "' \n";
			
			if (target_distro.dist_type == "redhat"){
				sh += "%s dracut -f -v \n".printf(chroot);
			}
			else if (target_distro.dist_type == "arch"){
				sh += "%s mkinitcpio -p /etc/mkinitcpio.d/*.preset\n".printf(chroot);
			}
			else{
				sh += "%s update-initramfs -u -k all \n".printf(chroot);
			}
		}
		
		// update grub menu --------------

		if (update_grub){
			sh += "echo '' \n";
			sh += "echo '" + _("Updating GRUB menu...") + "' \n";
			
			if (target_distro.dist_type == "redhat"){
				sh += "%s grub2-mkconfig -o /boot/grub2/grub.cfg \n".printf(chroot);
			}
			if (target_distro.dist_type == "arch"){
				sh += "%s grub-mkconfig -o /boot/grub/grub.cfg \n".printf(chroot);
			}
			else{
				sh += "%s update-grub \n".printf(chroot);
			}

			sh += "sync \n";
			sh += "echo '' \n";
		}
		
		// sync file systems
		sh += "echo '" + _("Synching file systems...") + "' \n";
		sh += "sync ; sleep 10s; \n";
		sh += "echo '' \n";
		
		if (!restore_current_system){
			// unmount chrooted system
			sh += "echo '" + _("Cleaning up...") + "' \n";
			sh += "for i in dev/pts dev proc run sys; do umount -f \"%s$i\"; done \n".printf(restore_target_path);
			sh += "sync \n";
		}

		log_debug("GRUB2 install script:");
		log_debug(sh);

		// reboot if required -----------------------------------

		if (restore_current_system){
			sh += "echo '' \n";
			sh += "echo '" + _("Rebooting system...") + "' \n";
			sh += "reboot -f \n";
			//sh_reboot += "shutdown -r now \n";
		}

		sh_finish = sh;
	}

	private bool restore_current_console(string sh_sync, string sh_finish){

		log_debug("Main: restore_current_console()");
		
		string script = sh_sync + sh_finish;
		int ret_val = -1;
		
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

		return (ret_val == 0);
	}

	private bool restore_current_gui(string sh_sync, string sh_finish){

		log_debug("Main: restore_current_gui()");
		
		string script = sh_sync + sh_finish;
		string temp_script = save_bash_script_temp(script);

		var dlg = new TerminalWindow.with_parent(parent_window);
		dlg.execute_script(temp_script, true);

		return true;
	}

	private bool restore_other_console(string sh_sync, string sh_finish){

		log_debug("Main: restore_other_console()");
		
		// execute sh_sync --------------------
		
		string script = sh_sync;
		int ret_val = -1;
		
		if (cmd_verbose){
			ret_val = exec_script_sync(script, null, null, false, false, false, true);
			log_msg("");
		}
		else{
			string std_out, std_err;
			ret_val = exec_script_sync(script, out std_out, out std_err);
			log_to_file(std_out);
			log_to_file(std_err);
		}

		// update files -------------------
		
		fix_fstab_file(restore_target_path);
		fix_crypttab_file(restore_target_path);

		progress_text = _("Parsing log file...");
		log_msg(progress_text);
		var task = new RsyncTask();
		task.parse_log(restore_log_file);

		// execute sh_finish --------------------

		log_debug("executing sh_finish: ");
		log_debug(sh_finish);
		
		script = sh_finish;

		if (cmd_verbose){
			ret_val = exec_script_sync(script, null, null, false, false, false, true);
			log_msg("");
		}
		else{
			string std_out, std_err;
			ret_val = exec_script_sync(script, out std_out, out std_err);
			log_to_file(std_out);
			log_to_file(std_err);
		}

		return (ret_val == 0);
	}

	private bool restore_other_gui(string sh_sync, string sh_finish){

		log_debug("Main: restore_other_gui()");
		
		progress_text = _("Building file list...");

		task = new RsyncTask();
		task.relative = false;
		task.verbose = true;
		task.delete_extra = true;
		task.delete_excluded = false;
		task.delete_after = true;

		task.dry_run = dry_run;
	
		if (mirror_system){
			task.source_path = "/";
		}
		else{
			task.source_path = path_combine(snapshot_to_restore.path, "localhost");
		}

		task.dest_path = restore_target_path;
		
		task.exclude_from_file = restore_exclude_file;

		task.rsync_log_file = restore_log_file;

		if ((snapshot_to_restore != null) && (snapshot_to_restore.file_count > 0)){
			task.prg_count_total = snapshot_to_restore.file_count;
		}
		else if (Main.first_snapshot_count > 0){
			task.prg_count_total = Main.first_snapshot_count;
		}
		else{
			task.prg_count_total = 500000;
		}

		task.execute();

		while (task.status == AppStatus.RUNNING){
			sleep(1000);

			if (task.status_line.length > 0){

				if (dry_run){
					progress_text = _("Comparing files with rsync...");
				}
				else{
					progress_text = _("Synching files with rsync...");
				}
			}
			
			gtk_do_events();
		}

		if (dry_run){
			return true; // no need to continue
		}

		// update files after sync --------------------

		fix_fstab_file(restore_target_path);
		fix_crypttab_file(restore_target_path);

		progress_text = _("Parsing log file...");
		log_msg(progress_text);
		var task = new RsyncTask();
		task.parse_log(restore_log_file);

		// execute sh_finish ------------

		if (reinstall_grub2 || update_initramfs || update_grub){
			progress_text = _("Updating bootloader configuration...");
		}

		log_debug("executing sh_finish: ");
		log_debug(sh_finish);
		
		int ret_val = exec_script_sync(sh_finish, null, null, false, false, false, true);

		log_debug("script exit code: %d".printf(ret_val));

		return (ret_val == 0);
	}

	private void fix_fstab_file(string target_path){

		log_debug("Main: fix_fstab_file()");
		
		string fstab_path = path_combine(target_path, "etc/fstab");

		if (!file_exists(fstab_path)){
			log_debug("File not found: %s".printf(fstab_path));
			return;
		}
		
		var fstab_list = FsTabEntry.read_file(fstab_path);

		log_debug("updating entries (1/2)...");
		
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
			entry.device_string = "UUID=%s".printf(mnt.device.uuid);
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

		log_debug("updating entries(2/2)...");
		
		for(int i = fstab_list.size - 1; i >= 0; i--){
			var entry = fstab_list[i];
			
			if (!entry.is_for_system_directory()){ continue; }
			
			var mnt = MountEntry.find_entry_by_mount_point(mount_list, entry.mount_point);
			if (mnt == null){
				fstab_list.remove(entry);
			}
		}
		
		// write the updated file

		log_debug("writing updated file...");

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

		log_debug("Main: fix_fstab_file(): exit");
	}

	private void fix_crypttab_file(string target_path){

		log_debug("Main: fix_crypttab_file()");
		
		string crypttab_path = path_combine(target_path, "etc/crypttab");

		if (!file_exists(crypttab_path)){
			log_debug("File not found: %s".printf(crypttab_path));
			return;
		}

		var crypttab_list = CryptTabEntry.read_file(crypttab_path);
		
		// add option "nofail" to existing entries

		log_debug("checking for 'nofail' option...");
		
		foreach(var entry in crypttab_list){
			entry.append_option("nofail");
		}

		log_debug("updating entries...");

		// check and add entries for mapped devices which are encrypted
		
		foreach(var mnt in mount_list){
			if ((mnt.device != null) && (mnt.device.parent != null) && (mnt.device.is_on_encrypted_partition())){
				
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

		log_debug("writing updated file...");

		CryptTabEntry.write_file(crypttab_list, crypttab_path, false);

		log_msg(_("Updated /etc/crypttab on target device") + ": %s".printf(crypttab_path));

		log_debug("Main: fix_crypttab_file(): exit");
	}

	private void check_and_repair_filesystems(){
		
		if (!restore_current_system){
			string sh_fsck = "echo '" + _("Checking file systems for errors...") + "' \n";
			foreach(var mnt in mount_list){
				if (mnt.device != null) {
					sh_fsck += "fsck -y %s \n".printf(mnt.device.device);
				}
			}
			sh_fsck += "echo '' \n";
			int ret_val = exec_script_sync(sh_fsck, null, null, false, false, false, true);
		}
	}

	public bool restore_execute_rsync(){
		
		log_debug("Main: restore_execute_rsync()");

		try{
			log_debug("source_path=%s".printf(restore_source_path));
			log_debug("target_path=%s".printf(restore_target_path));
			
			string sh_sync, sh_finish;
			create_restore_scripts(out sh_sync, out sh_finish);
			
			save_exclude_list_for_restore(restore_source_path);

			file_delete(restore_log_file);
			file_delete(restore_log_file + "-changes");
			file_delete(restore_log_file + ".gz");
			
			if (restore_current_system){
				string control_file_path = path_combine(snapshot_to_restore.path,".sync-restore");

				var f = File.new_for_path(control_file_path);
				if(f.query_exists()){
					f.delete(); //delete existing file
				}

				file_write(control_file_path, snapshot_to_restore.path); //save snapshot name
			}

			// run the scripts --------------------
		
			if (snapshot_to_restore != null){
				if (dry_run){
					log_msg(_("Comparing Files (Dry Run)..."));
				}
				else{
					log_msg(_("Restoring snapshot..."));
				}
			}
			else{
				log_msg(_("Cloning system..."));
			}

			progress_text = _("Synching files with rsync...");
			log_msg(progress_text);

			bool ok = true;
			
			if (app_mode == ""){ // GUI
				if (!restore_current_system || dry_run){
					ok = restore_other_gui(sh_sync, sh_finish);
				}
				else{
					ok = restore_current_gui(sh_sync, sh_finish);
				}
			}
			else{
				if (restore_current_system){
					ok = restore_current_console(sh_sync, sh_finish);
				}
				else{
					ok = restore_other_console(sh_sync, sh_finish);
				}
			}

			if (!dry_run){

				log_msg(_("Restore completed"));
				thr_success = true;

				log_msg(string.nfill(78, '-'));

				unmount_target_device(false);

				check_and_repair_filesystems();
			}
		}
		catch(Error e){
			log_error (e.message);
			thr_success = false;
		}

		thread_restore_running = false;
		return thr_success;
	}
	
	public bool restore_execute_btrfs(){

		log_debug("Main: restore_execute_btrfs()");
		
		bool ok = create_pre_restore_snapshot_btrfs();

		log_msg(string.nfill(78, '-'));
		
		if (!ok){
			thread_restore_running = false;
			thr_success = false;
			return thr_success;
		}
		
		// restore snapshot subvolumes by creating new subvolume snapshots

		foreach(var subvol in snapshot_to_restore.subvolumes.values){

			if ((subvol.name == "@home") && !include_btrfs_home_for_restore){ continue; }
			
			subvol.restore();
		}

		log_msg(_("Restore completed"));
		thr_success = true;
		
		if (restore_current_system){
			log_msg(_("Snapshot will become active after system is rebooted."));
		}

		log_msg(string.nfill(78, '-'));

		query_subvolume_quotas();

		thread_restore_running = false;
		return thr_success;
	}

	public bool create_pre_restore_snapshot_btrfs(){

		log_debug("Main: create_pre_restore_snapshot_btrfs()");
		
		string cmd, std_out, std_err;
		DateTime dt_created = new DateTime.now_local();
		string time_stamp = dt_created.format("%Y-%m-%d_%H-%M-%S");
		string snapshot_name = time_stamp;
		string snapshot_path = "";
		
		/* Note:
		 * The @ and @home subvolumes need to be backed-up only if they are in use by the system.
		 * If user restores a snapshot and then tries to restore another snapshot before the next reboot
		 * then the @ and @home subvolumes are the ones that were previously restored and need to be deleted.
		 * */

		bool create_pre_restore_backup = false;

		if (restore_current_system){
			
			// check for an existing pre-restore backup

			Snapshot snap_prev = null;
			bool found = false;
			foreach(var bak in repo.snapshots){
				if (bak.live){
					found = true;
					snap_prev = bak;
					log_msg(_("Found existing pre-restore snapshot") + ": %s".printf(bak.name));
					break;
				}
			}

			if (found){
				//delete system subvolumes
				if (sys_subvolumes.has_key("@") && snapshot_to_restore.subvolumes.has_key("@")){
					sys_subvolumes["@"].remove();
					log_msg(_("Deleted subvolume") + ": @");
				}
				if (include_btrfs_home_for_restore && sys_subvolumes.has_key("@home") && snapshot_to_restore.subvolumes.has_key("@home")){
					sys_subvolumes["@home"].remove();
					log_msg(_("Deleted subvolume") + ": @home");
				}

				//update description for pre-restore backup
				snap_prev.description = "Before restoring '%s'".printf(snapshot_to_restore.date_formatted);
				snap_prev.update_control_file();
			}
			else{
				create_pre_restore_backup = true;
			}
		}
		else{
			create_pre_restore_backup = true;
		}

		if (create_pre_restore_backup){

			log_msg(_("Creating pre-restore snapshot from system subvolumes..."));
			
			dir_create(snapshot_path);

			// move subvolumes ----------------
			
			bool no_subvolumes_found = true;

			var subvol_list = new Gee.ArrayList<Subvolume>();

			var subvol_names = new string[] { "@" };
			if (include_btrfs_home_for_restore){
				subvol_names = new string[] { "@","@home" };
			}
			
			foreach(string subvol_name in subvol_names){

				snapshot_path = path_combine(repo.mount_paths[subvol_name], "timeshift-btrfs/snapshots/%s".printf(snapshot_name));
				dir_create(snapshot_path, true);
			
				string src_path = path_combine(repo.mount_paths[subvol_name], subvol_name);
				if (!dir_exists(src_path)){
					log_error(_("Could not find system subvolume") + ": %s".printf(subvol_name));
					dir_delete(snapshot_path);
					continue;
				}
				
				no_subvolumes_found = false;

				string dst_path = path_combine(snapshot_path, subvol_name);
				cmd = "mv '%s' '%s'".printf(src_path, dst_path);
				log_debug(cmd);
				
				int status = exec_sync(cmd, out std_out, out std_err);
				
				if (status != 0){
					log_error (std_err);
					log_error(_("Failed to move system subvolume to snapshot directory") + ": %s".printf(subvol_name));
					return false;
				}
				else{
					var subvol_dev = (subvol_name == "@") ? repo.device : repo.device_home;
					subvol_list.add(new Subvolume(subvol_name, dst_path, subvol_dev.uuid, repo));
					
					log_msg(_("Moved system subvolume to snapshot directory") + ": %s".printf(subvol_name));
				}
			}

			if (no_subvolumes_found){
				//could not find system subvolumes for backing up(!)
				log_error(_("Could not find system subvolumes for creating pre-restore snapshot"));
			}
			else{
				// write control file -----------

				snapshot_path = path_combine(repo.mount_paths["@"], "timeshift-btrfs/snapshots/%s".printf(snapshot_name));
				
				var snap = Snapshot.write_control_file(
					snapshot_path, dt_created, repo.device.uuid,
					LinuxDistro.get_dist_info(path_combine(snapshot_path,"@")).full_name(),
					"ondemand", "", 0, true, false, repo);

				snap.description = "Before restoring '%s'".printf(snapshot_to_restore.date_formatted);
				snap.live = true;
				
				// write subvolume info
				foreach(var subvol in subvol_list){
					snap.subvolumes.set(subvol.name, subvol);
				}
				
				snap.update_control_file(); // save subvolume info

				log_msg(_("Created pre-restore snapshot") + ": %s".printf(snap.name));
				
				repo.load_snapshots();
			}
		}

		return true;
	}
	
	//app config

	public void save_app_config(){

		log_debug("Main: save_app_config()");
		
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

		config.set_string_member("do_first_run", false.to_string());
		config.set_string_member("btrfs_mode", btrfs_mode.to_string());
		config.set_string_member("include_btrfs_home_for_backup", include_btrfs_home_for_backup.to_string());
		config.set_string_member("include_btrfs_home_for_restore", include_btrfs_home_for_restore.to_string());
		config.set_string_member("stop_cron_emails", stop_cron_emails.to_string());
		config.set_string_member("btrfs_use_qgroup", btrfs_use_qgroup.to_string());

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
			log_msg(_("App config saved") + ": %s".printf(this.app_conf_path));
		}
	}

	public void load_app_config(){

		log_debug("Main: load_app_config()");

		// check if first run -----------------------
		
		var f = File.new_for_path(this.app_conf_path);
		if (!f.query_exists()) {
			file_copy(app_conf_path_default, app_conf_path);
		}
		if (!f.query_exists()) {
			set_first_run_flag();
			return;
		}

		// load settings from config file --------------------------
		
		var parser = new Json.Parser();
        try{
			parser.load_from_file(this.app_conf_path);
		} catch (Error e) {
	        log_error (e.message);
	    }
        var node = parser.get_root();
        var config = node.get_object();

		bool do_first_run = json_get_bool(config, "do_first_run", false); // false as default
		
		if (do_first_run){
			set_first_run_flag();
		}

		btrfs_mode = json_get_bool(config, "btrfs_mode", false); // false as default

		if (config.has_member("include_btrfs_home")){
			include_btrfs_home_for_backup = json_get_bool(config, "include_btrfs_home", include_btrfs_home_for_backup);
		}
		else{
			include_btrfs_home_for_backup = json_get_bool(config, "include_btrfs_home_for_backup", include_btrfs_home_for_backup);
		}
		
		include_btrfs_home_for_restore = json_get_bool(config, "include_btrfs_home_for_restore", include_btrfs_home_for_restore);
		stop_cron_emails = json_get_bool(config, "stop_cron_emails", stop_cron_emails);
		btrfs_use_qgroup = json_get_bool(config, "btrfs_use_qgroup", btrfs_use_qgroup);
		
		if (cmd_btrfs_mode != null){
			btrfs_mode = cmd_btrfs_mode; //override
		}
		
		backup_uuid = json_get_string(config,"backup_device_uuid", backup_uuid);
		backup_parent_uuid = json_get_string(config,"parent_device_uuid", backup_parent_uuid);
		
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

		Main.first_snapshot_size = json_get_uint64(config,"snapshot_size", Main.first_snapshot_size);
			
		Main.first_snapshot_count = (int64) json_get_uint64(config,"snapshot_count", Main.first_snapshot_count);
		
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
			log_msg(_("App config loaded") + ": %s".printf(this.app_conf_path));
		}
	}

	public void set_first_run_flag(){
		
		first_run = true;
		
		log_msg("First run mode (config file not found)");

		// load some defaults for first-run based on user's system type
		
		bool supported = sys_subvolumes.has_key("@") && cmd_exists("btrfs"); // && sys_subvolumes.has_key("@home")
		if (supported || (cmd_btrfs_mode == true)){
			log_msg(_("Selected default snapshot type") + ": %s".printf("BTRFS"));
			btrfs_mode = true;
		}
		else{
			log_msg(_("Selected default snapshot type") + ": %s".printf("RSYNC"));
			btrfs_mode = false;
		}
	}
	
	public void initialize_repo(){

		log_debug("Main: initialize_repo()");
		
		log_debug("backup_uuid=%s".printf(backup_uuid));
		log_debug("backup_parent_uuid=%s".printf(backup_parent_uuid));

		// use system disk as snapshot device in btrfs mode for backup
		if (((app_mode == "backup")||((app_mode == "ondemand"))) && btrfs_mode){
			if (sys_root != null){
				log_msg("Using system disk as snapshot device for creating snapshots in BTRFS mode");
				if (cmd_backup_device.length > 0){
					log_msg(_("Option --snapshot-device should not be specified for creating snapshots in BTRFS mode"));
				}
				repo = new SnapshotRepo.from_device(sys_root, parent_window, btrfs_mode);
			}
			else{
				log_error("System disk not found!");
				exit_app(1);
			}
		}
		// initialize repo using command line parameter if specified
		else if (cmd_backup_device.length > 0){
			var cmd_dev = Device.get_device_by_name(cmd_backup_device);
			if (cmd_dev != null){
				log_debug("Using snapshot device specified as command argument: %s".printf(cmd_backup_device));
				repo = new SnapshotRepo.from_device(cmd_dev, parent_window, btrfs_mode);
				// TODO: move this code to main window
			}
			else{
				log_error(_("Device not found") + ": '%s'".printf(cmd_backup_device));
				exit_app(1);
			}
		}
		// select default device for first run mode
		else if (first_run && (backup_uuid.length == 0)){
			
			try_select_default_device_for_backup(parent_window);

			if ((repo != null) && (repo.device != null)){
				log_msg(_("Selected default snapshot device") + ": %s".printf(repo.device.device));
			}
		}
		else {
			log_debug("Setting snapshot device from config file");
			
			// find devices from uuid
			Device dev = null;
			Device dev_parent = null;
			if (backup_uuid.length > 0){
				dev = Device.get_device_by_uuid(backup_uuid);
			}
			if (backup_parent_uuid.length > 0){
				dev_parent = Device.get_device_by_uuid(backup_parent_uuid);
			}

			// try unlocking encrypted parent
			if ((dev_parent != null) && dev_parent.is_encrypted_partition() && !dev_parent.has_children()){
				log_debug("Snapshot device is on an encrypted partition");
				repo = new SnapshotRepo.from_uuid(backup_parent_uuid, parent_window, btrfs_mode);
			}
			// try device	
			else if (dev != null){
				log_debug("repo: creating from uuid");
				repo = new SnapshotRepo.from_uuid(backup_uuid, parent_window, btrfs_mode);
			}
			// try system disk
			/*else {
				log_debug("Could not find device with UUID" + ": %s".printf(backup_uuid));
				if (sys_root != null){
					log_debug("Using system disk as snapshot device");
					repo = new SnapshotRepo.from_device(sys_root, parent_window, btrfs_mode);
				}
				else{
					log_debug("System disk not found");
					repo = new SnapshotRepo.from_null();
				}
			}*/
		}

		/* Note: In command-line mode, user will be prompted for backup device */

		/* The backup device specified in config file will be mounted at this point if:
		 * 1) app is running in GUI mode, OR
		 * 2) app is running command mode without backup device argument
		 * */

		 log_debug("Main: initialize_repo(): exit");
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

		foreach(var pi in partitions){
			if ((app_mode == "")||(LOG_DEBUG)){
				log_debug("Partition \"%s\" on device \"%s\" : read-only = %s.".printf(
					pi.name,
					pi.device, 
					pi.read_only.to_string()
				));
			}

			if ( pi.read_only ) { 
				continue;
			}
			
			foreach(var mp in pi.mount_points){
				
				// skip loop devices - Fedora Live uses loop devices containing ext4-formatted lvm volumes
				if ((pi.type == "loop") || (pi.has_parent() && (pi.parent.type == "loop"))){
					if ((app_mode == "")||(LOG_DEBUG)){
						log_debug("Mount point \"%s\" : read-only = %s.".printf(mp.mount_point, mp.read_only.to_string()));
					}

					if ( mp.read_only ) { 
						continue;
					}
				}

				if (mp.mount_point == "/"){
					sys_root = pi;
					if ((app_mode == "")||(LOG_DEBUG)){
						string txt = _("/ is mapped to device") + ": %s, UUID=%s".printf(pi.device,pi.uuid);
						if (mp.subvolume_name().length > 0){
							txt += ", subvol=%s".printf(mp.subvolume_name());
						}
						log_debug(txt);
					}
				}

				if (mp.mount_point == "/home"){
					sys_home = pi;
					if ((app_mode == "")||(LOG_DEBUG)){
						string txt = _("/home is mapped to device") + ": %s, UUID=%s".printf(pi.device,pi.uuid);
						if (mp.subvolume_name().length > 0){
							txt += ", subvol=%s".printf(mp.subvolume_name());
						}
						log_debug(txt);
					}
				}

				if (mp.mount_point == "/boot"){
					sys_boot = pi;
					if ((app_mode == "")||(LOG_DEBUG)){
						string txt = _("/boot is mapped to device") + ": %s, UUID=%s".printf(pi.device,pi.uuid);
						if (mp.subvolume_name().length > 0){
							txt += ", subvol=%s".printf(mp.subvolume_name());
						}
						log_debug(txt);
					}
				}

				if (mp.mount_point == "/boot/efi"){
					sys_efi = pi;
					if ((app_mode == "")||(LOG_DEBUG)){
						string txt = _("/boot/efi is mapped to device") + ": %s, UUID=%s".printf(pi.device,pi.uuid);
						if (mp.subvolume_name().length > 0){
							txt += ", subvol=%s".printf(mp.subvolume_name());
						}
						log_debug(txt);
					}
				}

			}
		}

		sys_subvolumes = Subvolume.detect_subvolumes_for_system_by_path("/", null, parent_window);
	}

	public bool mount_target_devices(Gtk.Window? parent_win = null){
		/* Note:
		 * Target device will be mounted explicitly to /mnt/timeshift/restore
		 * Existing mount points are not used since we need to mount other devices in sub-directories
		 * */

		log_debug("mount_target_device()");
		
		if (dst_root == null){
			return false;
		}
	
		//check and create restore mount point for restore
		mount_point_restore = mount_point_app + "/restore";
		dir_create(mount_point_restore);

		/*var already_mounted = false;
		var dev_mounted = Device.get_device_by_path(mount_point_restore);
		if ((dev_mounted != null)
			&& (dev_mounted.uuid == dst_root.uuid)){

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

		// mount root device
		if (dst_root.fstype == "btrfs"){

			//check subvolume layout

			bool supported = check_btrfs_layout(dst_root, dst_home, false);
			
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

			if (mnt.device == null){
				continue;
			}
			
			// unlock encrypted device
			if (mnt.device.is_encrypted_partition()){

				// check if unlocked
				if (mnt.device.has_children()){
					mnt.device = mnt.device.children[0];
				}
				else{
					// prompt user
					string msg_out, msg_err;
			
					var dev_unlocked = Device.luks_unlock(
						mnt.device, "", "", parent_win, out msg_out, out msg_err);

					//exit if not found
					if (dev_unlocked == null){
						return false;
					}
					else{
						mnt.device = dev_unlocked;
					}
				}
			}

			string mount_options = "";
			
			if (mnt.device.fstype == "btrfs"){
				if (mnt.mount_point == "/"){
					mount_options = "subvol=@";
				}
				if (include_btrfs_home_for_restore){
					if (mnt.mount_point == "/home"){
						mount_options = "subvol=@home";
					}
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
			unmount_device(mount_point_restore, exit_on_error);
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
				exit_app(1);
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

	public bool check_btrfs_volume(Device dev, string subvol_names, bool unlock){

		log_debug("check_btrfs_volume():%s".printf(subvol_names));
		
		string mnt_btrfs = mount_point_app + "/btrfs";
		dir_create(mnt_btrfs);

		if (!dev.is_mounted_at_path("", mnt_btrfs)){
			
			Device.unmount(mnt_btrfs);

			// unlock encrypted device
			if (dev.is_encrypted_partition()){

				if (unlock){
					
					string msg_out, msg_err;
					var dev_unlocked = Device.luks_unlock(
						dev, "", "", parent_window, out msg_out, out msg_err);
				
					if (dev_unlocked == null){
						log_debug("device is null");
						log_debug("SnapshotRepo: check_btrfs_volume(): exit");
						return false;
					}
					else{
						Device.mount(dev_unlocked.uuid, mnt_btrfs, "", true);
					}
				}
				else{
					return false;
				}
			}
			else{
				Device.mount(dev.uuid, mnt_btrfs, "", true);
			}
		}

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

	public void try_select_default_device_for_backup(Gtk.Window? parent_win){

		log_debug("try_select_default_device_for_backup()");

		// check if currently selected device can be used
		if (repo.available()){
			if (check_device_for_backup(repo.device, false)){
				if (repo.btrfs_mode != btrfs_mode){
					// reinitialize
					repo = new SnapshotRepo.from_device(repo.device, parent_win, btrfs_mode);
				}
				return;
			}
			else{
				repo = new SnapshotRepo.from_null();
			}
		}
		
		update_partitions();

		// In BTRFS mode, select the system disk if system disk is BTRFS
		if (btrfs_mode && sys_subvolumes.has_key("@")){
			var subvol_root = sys_subvolumes["@"];
			repo = new SnapshotRepo.from_device(subvol_root.get_device(), parent_win, btrfs_mode);
			return;
		}
			
		foreach(var dev in partitions){
			if (check_device_for_backup(dev, false)){
				repo = new SnapshotRepo.from_device(dev, parent_win, btrfs_mode);
				break;
			}
			else{
				continue;
			}
		}
	}

	public bool check_device_for_backup(Device dev, bool unlock){
		bool ok = false;

		if (dev.type == "disk") { return false; }
		if (dev.has_children()) { return false; }
		
		if (btrfs_mode && ((dev.fstype == "btrfs")||(dev.fstype == "luks"))){
			if (check_btrfs_volume(dev, "@", unlock)){
				return true;
			}
		}
		else if (!btrfs_mode && dev.has_linux_filesystem()){
			// TODO: check free space
			return true;
		}

		return ok;
	}
	
	public uint64 estimate_system_size(){

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
		uint64 required_space = 0;
		int64 file_count = 0;

		try{

			log_debug("Using temp dir '%s'".printf(TEMP_DIR));

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

	// btrfs

	public void query_subvolume_info(SnapshotRepo parent_repo){

		// SnapshotRepo contructor calls this code in load_snapshots()
		// save the new object reference to repo since repo still holds previous object
		repo = parent_repo;

		// TODO: move query_subvolume_info() and related methods to SnapshotRepo
		
		if ((repo == null) || !repo.btrfs_mode){
			return;
		}
		
		log_debug(_("Querying subvolume info..."));
		
		try {
			thread_subvol_info_running = true;
			thread_subvol_info_success = false;
			Thread.create<void> (query_subvolume_info_thread, true);
		} catch (ThreadError e) {
			thread_subvol_info_running = false;
			thread_subvol_info_success = false;
			log_error (e.message);
		}

		while (thread_subvol_info_running){
			gtk_do_events ();
			Thread.usleep((ulong) GLib.TimeSpan.MILLISECOND * 100);
		}

		log_debug(_("Query completed"));
	}

	public void query_subvolume_info_thread(){
		
		thread_subvol_info_running = true;

		//query IDs
		bool ok = query_subvolume_ids();
		
		if (!ok){
			thread_subvol_info_success = false;
			thread_subvol_info_running = false;
			return;
		}

		//query quota
		ok = query_subvolume_quotas();
		
		if (!ok){

			if (btrfs_use_qgroup){
				
				//try enabling quota
				ok = enable_subvolume_quotas();
				if (!ok){
					thread_subvol_info_success = false;
					thread_subvol_info_running = false;
					return;
				}

				//query quota again
				ok = query_subvolume_quotas();
				if (!ok){
					thread_subvol_info_success = false;
					thread_subvol_info_running = false;
					return;
				}
			}
		}

		thread_subvol_info_success = true;
		thread_subvol_info_running = false;
		return;
	}

	public bool query_subvolume_ids(){
		bool ok = query_subvolume_id("@");
		if ((repo.device_home != null) && (repo.device.uuid != repo.device_home.uuid)){
			ok = ok && query_subvolume_id("@home");
		}
		return ok;
	}
	
	public bool query_subvolume_id(string subvol_name){

		log_debug("query_subvolume_id():%s".printf(subvol_name));
		
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		cmd = "btrfs subvolume list '%s'".printf(repo.mount_paths[subvol_name]);
		log_debug(cmd);
		ret_val = exec_sync(cmd, out std_out, out std_err);
		if (ret_val != 0){
			log_error (std_err);
			log_error(_("btrfs returned an error") + ": %d".printf(ret_val));
			log_error(_("Failed to query subvolume list"));
			return false;
		}

		/* Sample Output:
		 *
		ID 257 gen 56 top level 5 path timeshift-btrfs/snapshots/2014-09-26_23-34-08/@
		ID 258 gen 52 top level 5 path timeshift-btrfs/snapshots/2014-09-26_23-34-08/@home
		* */

		foreach(string line in std_out.split("\n")){
			if (line == null) { continue; }

			string[] parts = line.split(" ");
			if (parts.length < 2) { continue; }

			Subvolume subvol = null;

			if ((sys_subvolumes.size > 0) && line.has_suffix(sys_subvolumes["@"].path.replace(repo.mount_paths["@"] + "/"," "))){
				subvol = sys_subvolumes["@"];
			}
			else if ((sys_subvolumes.size > 0)
				&& sys_subvolumes.has_key("@home")
				&& line.has_suffix(sys_subvolumes["@home"].path.replace(repo.mount_paths["@home"] + "/"," "))){
					
				subvol = sys_subvolumes["@home"];
			}
			else {
				foreach(var bak in repo.snapshots){
					foreach(var sub in bak.subvolumes.values){
						if (line.has_suffix(sub.path.replace(repo.mount_paths[sub.name] + "/",""))){
							subvol = sub;
							break;
						}
					}
				}
			}

			if (subvol != null){
				subvol.id = long.parse(parts[1]);
			}
		}

		return true;
	}

	public bool query_subvolume_quotas(){

		bool ok = query_subvolume_quota("@");
		if (repo.device.uuid != repo.device_home.uuid){
			ok = ok && query_subvolume_quota("@home");
		}
		return ok;
	}
	
	public bool query_subvolume_quota(string subvol_name){

		log_debug("query_subvolume_quota():%s".printf(subvol_name));
		
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		string options = use_option_raw ? "--raw" : "";
		
		cmd = "btrfs qgroup show %s '%s'".printf(options, repo.mount_paths[subvol_name]);
		log_debug(cmd);
		ret_val = exec_sync(cmd, out std_out, out std_err);
		
		if (ret_val != 0){
			
			if (use_option_raw){
				use_option_raw = false;

				// try again without --raw option
				cmd = "btrfs qgroup show '%s'".printf(repo.mount_paths[subvol_name]);
				log_debug(cmd);
				ret_val = exec_sync(cmd, out std_out, out std_err);
			}	
			
			if (ret_val != 0){
				log_error (std_err);
				log_error(_("btrfs returned an error") + ": %d".printf(ret_val));
				log_error(_("Failed to query subvolume quota"));
				return false;
			}
		}

		/* Sample Output:
		 *
		qgroupid rfer       excl
		-------- ----       ----
		0/5      106496     106496
		0/257    3825262592 557056
		0/258    12689408   49152
		 * */

		foreach(string line in std_out.split("\n")){
			if (line == null) { continue; }

			string[] parts = line.split(" ");
			if (parts.length < 3) { continue; }
			if (parts[0].split("/").length < 2) { continue; }

			int subvol_id = int.parse(parts[0].split("/")[1]);

			Subvolume subvol = null;

			if ((sys_subvolumes.size > 0) && (sys_subvolumes["@"].id == subvol_id)){
				
				subvol = sys_subvolumes["@"];
			}
			else if ((sys_subvolumes.size > 0)
				&& sys_subvolumes.has_key("@home")
				&& (sys_subvolumes["@home"].id == subvol_id)){
					
				subvol = sys_subvolumes["@home"];
			}
			else {
				foreach(var bak in repo.snapshots){
					foreach(var sub in bak.subvolumes.values){
						if (sub.id == subvol_id){
							subvol = sub;
						}
					}
				}
			}

			if (subvol != null){
				int part_num = -1;
				foreach(string part in parts){
					if (part.strip().length > 0){
						part_num ++;
						switch (part_num){
							case 1:
								subvol.total_bytes = int64.parse(part);
								break;
							case 2:
								subvol.unshared_bytes = int64.parse(part);
								break;
							default:
								//ignore
								break;
						}
					}
				}
			}
		}

		foreach(var bak in repo.snapshots){
			bak.update_control_file();
		}

		return true;
	}

	public bool enable_subvolume_quotas(){

		if (!btrfs_use_qgroup){ return false; }
		
		bool ok = enable_subvolume_quota("@");
		
		if (repo.device.uuid != repo.device_home.uuid){
			ok = ok && enable_subvolume_quota("@home");
		}
		if (ok){
			log_msg(_("Enabled subvolume quota support"));
		}
		
		return ok;
	}
	
	public bool enable_subvolume_quota(string subvol_name){

		if (!btrfs_use_qgroup){ return false; }
		
		log_debug("enable_subvolume_quota():%s".printf(subvol_name));
		
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		cmd = "btrfs quota enable '%s'".printf(repo.mount_paths[subvol_name]);
		log_debug(cmd);
		
		ret_val = exec_sync(cmd, out std_out, out std_err);
		
		if (ret_val != 0){
			log_error (std_err);
			log_error(_("btrfs returned an error") + ": %d".printf(ret_val));
			log_error(_("Failed to enable subvolume quota"));
			return false;
		}

		return true;
	}

	public bool rescan_subvolume_quotas(){
		
		bool ok = rescan_subvolume_quota("@");
		
		if (repo.device.uuid != repo.device_home.uuid){
			ok = ok && rescan_subvolume_quota("@home");
		}
		if (ok){
			log_msg(_("Enabled subvolume quota support"));
		}
		
		return ok;
	}
	
	public bool rescan_subvolume_quota(string subvol_name){

		log_debug("rescan_subvolume_quota():%s".printf(subvol_name));
		
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		cmd = "btrfs quota rescan '%s'".printf(repo.mount_paths[subvol_name]);
		log_debug(cmd);
		
		ret_val = exec_sync(cmd, out std_out, out std_err);
		
		if (ret_val != 0){
			
			log_error (std_err);
			log_error(_("btrfs returned an error") + ": %d".printf(ret_val));
			log_error(_("Failed to rescan subvolume quota"));
			return false;
		}

		return true;
	}

	// cron jobs

	public void cron_job_update(){
		
		if (live_system()) { return; }

		// remove entries created by previous versions -----------
		
		string entry = "timeshift --backup";

		int count = 0;
		while (CronTab.has_job(entry, true, false)){
			
			CronTab.remove_job(entry, true, true);
			
			if (++count == 100){
				break;
			}
		}

		entry = "timeshift-btrfs --backup";

		count = 0;
		while (CronTab.has_job(entry, true, false)){
			
			CronTab.remove_job(entry, true, true);
			
			if (++count == 100){
				break;
			}
		}

		CronTab.remove_script_file("timeshift-hourly", "hourly");
			
		// start update ---------------------------
		
		if (scheduled){
			
			//hourly
			CronTab.add_script_file("timeshift-hourly", "d", "0 * * * * root timeshift --check --scripted", stop_cron_emails);
			
			//boot
			if (schedule_boot){
				CronTab.add_script_file("timeshift-boot", "d", "@reboot root sleep 10m && timeshift --create --scripted --tags B", stop_cron_emails);
			}
			else{
				CronTab.remove_script_file("timeshift-boot", "d");
			}
		}
		else{
			CronTab.remove_script_file("timeshift-hourly", "d");
			CronTab.remove_script_file("timeshift-boot", "d");
		}
	}
	
	// cleanup

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

				// delete oldest 100 files ---------------

				for(int k = 0; k < 100; k++){
					
					var file = File.new_for_path (list[k]);
					 
					if (file.query_exists()){ 
						file.delete();
						log_msg("%s: %s".printf(_("Removed"), list[k]));
					}
				}
            
				log_msg(_("Older log files removed"));
			}
		}
		catch(Error e){
			log_error (e.message);
		}
	}

	public void exit_app (int exit_code = 0){

		log_debug("exit_app()");
		
		if (app_mode == ""){
			//update app config only in GUI mode
			save_app_config();
		}

		cron_job_update();

		unmount_target_device(false);

		clean_logs();

		app_lock.remove();

		exit(exit_code);

		//Gtk.main_quit ();
	}
}




