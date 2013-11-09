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
using Soup;
using Json;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.DiskPartition;
using TeeJee.JSON;
using TeeJee.ProcessManagement;
using TeeJee.GtkHelper;
using TeeJee.Multimedia;
using TeeJee.System;
using TeeJee.Misc;

public Main App;
public const string AppName = "TimeShift";
public const string AppVersion = "1.2.4";
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
	public Gee.ArrayList<PartitionInfo?> partition_list;
	public Gee.ArrayList<string> exclude_list_user;
	public Gee.ArrayList<string> exclude_list_default;
	public Gee.ArrayList<string> exclude_list_home;
	public Gee.ArrayList<string> exclude_list_restore;
	public Gee.ArrayList<AppExcludeEntry> exclude_list_apps;
	
	public PartitionInfo root_device;
	public PartitionInfo home_device;
	public PartitionInfo snapshot_device;
	public string mount_point_backup = "/mnt/timeshift";
	public string mount_point_restore = "/mnt/timeshift-restore";
	public string mount_point_test = "/mnt/timeshift-test";
	public string snapshot_dir = "/mnt/timeshift/timeshift/snapshots";
	public DistInfo current_distro;
	
	public bool _is_scheduled = true;
	
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
	public bool is_ondemand = false;

	public string snapshot_comments = "";
	public bool is_success = false;
	public bool in_progress = false;

	public int cron_job_interval_mins = 30;
	public int retain_snapshots_max_days = 200;
	public int minimum_free_disk_space_mb = 2048;
	public long first_snapshot_size = 0;
	
	public string log_dir;
	public string log_file;
	public string lock_dir;
	public string lock_file;
	
	public TimeShiftBackup snapshot_to_delete;
	public TimeShiftBackup snapshot_to_restore;
	public PartitionInfo restore_target;
	public bool reinstall_grub2 = false;
	public DeviceInfo grub_device;
	
	public string progress_text;

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
			msg += _("Please run the application as admin (using 'sudo')");
				
			if (app_mode == ""){
				gtk_messagebox_show(_("Admin Access Required"),msg,true);
			}
			else{
				log_error(msg);
			}
			
			exit(0);
		}
		
		//init log ------------------
		
		try {
			DateTime now = new DateTime.now_local();
			log_dir = "/var/log/timeshift";
			log_file = log_dir + "/" + now.format("%Y-%m-%d %H-%M-%S") + ".log";
			
			var file = File.new_for_path (log_dir);
			if (!file.query_exists ()) {
				file.make_directory_with_parents();
			}

			file = File.new_for_path (log_file);
			if (file.query_exists ()) {
				file.delete ();
			}
        
			dos_log = new DataOutputStream (file.create(FileCreateFlags.REPLACE_DESTINATION));
			log_msg(_("Session log file") + ": %s".printf(log_file));
		} 
		catch (Error e) {
			is_success = false;
			log_error (e.message);
		}
		
		//log dist info -----------------------
		
		DistInfo info = DistInfo.get_dist_info("/");
		log_msg(_("Distribution") + ": " + info.full_name());
		
		//check dependencies ---------------------
		
		string message;
		if (!check_dependencies(out message)){
			if (app_mode == ""){
				gtk_messagebox_show(_("Missing Dependencies"),message,true);
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
				
				gtk_messagebox_show("Error",msg,true);
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
		exclude_list_home = new Gee.ArrayList<string>();
		exclude_list_restore = new Gee.ArrayList<string>();
		exclude_list_apps = new Gee.ArrayList<AppExcludeEntry>();
		partition_list = new Gee.ArrayList<PartitionInfo>();

		add_default_exclude_entries();
		//add_app_exclude_entries();
		
		//check current linux distribution -----------------
		
		this.current_distro = DistInfo.get_dist_info("/");
		
		//initialize app --------------------
		
		update_partition_list();
		detect_system_devices();

		//check if root device is a BTRFS volume ---------------
		
		if ((root_device != null) && (root_device.type == "btrfs")){
			//check subvolume layout
			if (check_btrfs_volume(root_device) == false){
				msg = _("The system partition has an unsupported subvolume layout.") + " ";
				msg += _("Only ubuntu-type layouts with @ and @home subvolumes are currently supported.") + "\n\n";
				msg += _("Application will exit.") + "\n\n";
				
				if (app_mode == ""){
					gtk_messagebox_show(_("Not Supported"),msg,true);
				}
				else{
					log_error(msg);
				}
				exit(0);
			}
		}

		//finish initialization --------------
		
		load_app_config();
		update_snapshot_list();
	}
	
	private void parse_arguments(string[] args){
		for (int k = 1; k < args.length; k++) // Oth arg is app path 
		{
			switch (args[k].down ()){
				case "--backup":
					app_mode = "backup";
					break;
					
				case "--backup-now":
					app_mode = "ondemand";
					break;
				
				case "--show-commands":
					LOG_COMMANDS = true;
					break;
					
				case "--debug":
					LOG_DEBUG = true;
					break;
				
				case "--list":
					app_mode = "list";
					LOG_ENABLE = false;
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					break;
					
				default:
					//nothing
					break;
			}
		}
		
		if (app_mode == ""){
			//Initialize GTK
			Gtk.init(ref args);
		}
	}
	
	public bool start_application(string[] args){
		bool is_success = true;
		
		switch(app_mode){
			case "backup":
				is_success = take_snapshot();
				if(!is_success){
					log_error(_("Failed to take snapshot."));
				}
				return is_success;
			
			case "ondemand":
				is_success = take_snapshot(true);
				if(!is_success){
					log_error(_("Failed to take snapshot."));
				}
				return is_success;
				
			case "list":

				LOG_ENABLE = true;
				LOG_TIMESTAMP = false;

				log_msg(_("Snapshots") + ":");
				foreach (TimeShiftBackup bak in this.snapshot_list){
					log_msg("%s%s%s".printf(bak.name, " ~ " + bak.taglist, (bak.description.length > 0) ? " ~ " + bak.description : ""));
				}
				LOG_ENABLE = false;
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
		
		string[] dependencies = { "rsync","/sbin/blkid","df","du","mount","umount","fuser","crontab","cp","rm","touch","ln","sync"}; //"shutdown","chroot", 
		
		log_msg(_("Checking dependencies..."));
		
		string path;
		foreach(string cmd_tool in dependencies){
			path = get_cmd_path (cmd_tool);
			if ((path == null) || (path.length == 0)){
				msg += cmd_tool + "\n";
			}
		}
		
		if (msg.length > 0){
			msg = _("Following dependencies are missing:") + "\n\n" + msg + "\n";
			msg += _("Please install the packages for the commands \nlisted above and try running TimeShift again.");
			log_error(msg);
			log_error(_("Missing dependencies"));
			return false;
		}
		else{
			log_msg(_("All dependencies satisfied"));
			return true;
		}
	}

	public void add_default_exclude_entries(){
		
		exclude_list_default.clear();
		exclude_list_home.clear();
		
		//add default exclude entries -------------------

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
		exclude_list_default.add("/root/.mozilla/firefox/*.default/Cache");
		exclude_list_default.add("/root/.mozilla/firefox/*.default/OfflineCache");
		exclude_list_default.add("/root/.opera/cache");
		exclude_list_default.add("/root/.kde/share/apps/kio_http/cache");
		exclude_list_default.add("/root/.kde/share/cache/http");
		exclude_list_default.add("/root/.local/share/Trash");
		
		exclude_list_default.add("/home/*/.thumbnails");
		exclude_list_default.add("/home/*/.cache");
		exclude_list_default.add("/home/*/.gvfs");
		exclude_list_default.add("/home/*/.mozilla/firefox/*.default/Cache");
		exclude_list_default.add("/home/*/.mozilla/firefox/*.default/OfflineCache");
		exclude_list_default.add("/home/*/.opera/cache");
		exclude_list_default.add("/home/*/.kde/share/apps/kio_http/cache");
		exclude_list_default.add("/home/*/.kde/share/cache/http");
		exclude_list_default.add("/home/*/.local/share/Trash");

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
			home = Environment.get_home_dir();
		}
		else{
			user_name = std_out.strip();
			home = "/home/%s".printf(user_name);
		}

		try
		{
			File f_home = File.new_for_path (home);
	        FileEnumerator enumerator = f_home.enumerate_children (GLib.FileAttribute.STANDARD_NAME, 0);
	        FileInfo file;
	        while ((file = enumerator.next_file ()) != null) {
				string name = file.get_name();
				string item = home + "/" + name;
				if (!name.has_prefix(".")){ continue; }
				if (name == ".config"){ continue; }
				if (!dir_exists(item)) { continue; }
				
				AppExcludeEntry entry = new AppExcludeEntry("~/.%s/**".printf(name), name[1:name.length]);
				exclude_list_apps.add(entry);
	        }
	        
	        File f_home_config = File.new_for_path (home + "/.config");
	        enumerator = f_home_config.enumerate_children (GLib.FileAttribute.STANDARD_NAME, 0);
	        while ((file = enumerator.next_file ()) != null) {
				string name = file.get_name();
				string item = home + "/.config/" + name;
				if (!dir_exists(item)) { continue; }
				
				AppExcludeEntry entry = new AppExcludeEntry("~/.config/%s/**".printf(name), name);
				exclude_list_apps.add(entry);
	        }
        }
        catch(Error e){
	        log_error (e.message);
	    }

		//sort the list
		CompareFunc<AppExcludeEntry> entry_compare = (a, b) => {
			return strcmp(a.name,b.name);
		};
		exclude_list_apps.sort(entry_compare);
	}
	
	public static string help_message (){
		string msg = "\n" + AppName + " v" + AppVersion + " by Tony George (teejee2008@gmail.com)" + "\n";
		msg += "\n";
		msg += "Syntax: sudo timeshift [options]\n";
		msg += "\n";
		msg += _("Options") + ":\n";
		msg += "\n";
		msg += "  --backup          " + _("Take scheduled backup") + "\n";
		msg += "  --backup-now      " + _("Take on-demand backup") + "\n";
		msg += "  --list            " + _("List all snapshots") + "\n";
		msg += "  --show-commands   " + _("Show commands") + "\n";
		msg += "  --debug           " + _("Show additional debug messages") + "\n";
		msg += "  --help            " + _("Show all options") + "\n";
		msg += "\n";
		msg += _("Notes") + ":\n";
		msg += "\n";
		msg += "  1) '--backup' will take a snapshot only if a scheduled snapshot is due\n";
		msg += "  2) '--backup-now' will take an immediate (manual) snapshot\n";
		msg += "\n";
		return msg;
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
					log_msg(_("Warning: Deleted invalid lock"));
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
	
	
	public bool take_snapshot(bool ondemand = false, string comments = ""){

		in_progress = true;
		
		is_ondemand = ondemand;
		snapshot_comments = comments;
		
		try {
			is_success = false;
			Thread.create<void> (take_snapshot_thread, true);

			while (in_progress){
				gtk_do_events ();
				Thread.usleep((ulong) GLib.TimeSpan.MILLISECOND * 100);
			}
		} catch (Error e) {
			is_success = false;
			log_error (e.message);
		}
		
		in_progress = false;
		
		return is_success;
	}
	
	public void take_snapshot_thread(){
		bool status;
		bool update_symlinks = false;
		
		try
		{
			//create a timestamp
			DateTime now = new DateTime.now_local();

			//mount_backup_device
			if (!mount_backup_device()){
				is_success = false;
				in_progress = false;
				return; 
			}
			
			//check backup device
			string msg;
			int status_code = check_backup_device(out msg);
			
			if (!is_ondemand){
				//check if first snapshot was taken
				if (status_code == 2){
					log_error(msg);
					log_error(_("Please take the first snapshot by running 'sudo timeshift --backup-now'"));
					is_success = false;
					in_progress = false;
					return;
				}
			}
			
			//check space
			if ((status_code == 1) || (status_code == 2)){
				log_error(msg);
				is_success = false;
				in_progress = false;
				return;
			}
			
			//create snapshot root if missing
			var f = File.new_for_path(snapshot_dir);
			if (!f.query_exists()){
				f.make_directory_with_parents();
			}

			//ondemand
			if (is_ondemand){
				is_success = backup_and_rotate ("ondemand",now);
				if(!is_success){
					log_error(_("On-demand snapshot failed!"));
					is_success = false;
					in_progress = false;
					return;
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
							is_success = false;
							in_progress = false;
							return;
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
							is_success = false;	
							in_progress = false;				
							return;
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
							is_success = false;
							in_progress = false;
							return;
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
							is_success = false;
							in_progress = false;
							return;
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
							is_success = false;
							in_progress = false;
							return;
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
			is_success = false;
			in_progress = false;
			return;
		}
		
		is_success = true;
		in_progress = false;
		return;
	}
	
	public bool backup_and_rotate(string tag, DateTime dt_created){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;
		string msg;
		File f;

		string time_stamp = dt_created.format("%Y-%m-%d %H-%M-%S");
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
					
					cmd = "rm -rf \"%s\"".printf(sync_path);
					
					if (LOG_COMMANDS) { log_msg(cmd, true); }
					
					Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
					if (ret_val != 0){
						log_error(_("Failed to delete incomplete snapshot") + ": '.sync'");
						return false;
					}
					else{
						log_msg(_("Deleted incomplete snapshot") + ": '.sync'");
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
						//use latest snapshot
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
							
						if (LOG_COMMANDS) { log_msg(cmd, true); }

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
				
				if (LOG_COMMANDS) { log_msg(cmd, true); }

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
			
				cmd = "rsync -ai --delete --numeric-ids --relative --delete-excluded";
				cmd += " --log-file=\"%s\"".printf(log_path);
				cmd += " --exclude-from=\"%s\"".printf(list_file);
				cmd += " /. \"%s\"".printf(sync_path + "/localhost/");
				
				if (LOG_COMMANDS) { log_msg(cmd, true); }

				Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);

				if (ret_val != 0){
					log_error (std_err);
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

				if (LOG_COMMANDS) { log_msg(cmd, true); }

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
					
					if (LOG_COMMANDS) { log_msg(cmd, true); }
					
					Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
					if (ret_val != 0){
						log_error (std_err);
						log_error(_("Failed to create symlinks") + ": snapshots-%s".printf(tag));
						return;
					}
				}
			}
			
			log_msg (_("symlinks updated"));
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
				
				if (LOG_COMMANDS) { log_msg(cmd, true); }
				
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
	
	public void save_exclude_list_for_restore(TimeShiftBackup snapshot){
		
		try{
			string list_file = snapshot.path + "/exclude.list";
			string pattern;
			
			if (exclude_list_restore.size == 0){
				
				//add default entries
				foreach(string path in exclude_list_default){
					if (!exclude_list_restore.contains(path)){
						exclude_list_restore.add(path);
					}
				}
				
				//add app entries
				foreach(AppExcludeEntry entry in exclude_list_apps){
					if (entry.enabled){
						pattern = entry.path.replace("~","/home/*") + "/**";
						if (!exclude_list_restore.contains(pattern)){
							exclude_list_restore.add(pattern);
						}
						
						pattern = entry.path.replace("~","/root") + "/**";
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
				foreach(string path in read_file(list_file).split("\n")){
					if (!exclude_list_restore.contains(path) && !exclude_list_home.contains(path)){
						exclude_list_restore.add(path);
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
			string list_file_restore = snapshot.path + "/exclude-restore.list";
			
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
	
	public bool restore_snapshot(){
		
		if (snapshot_to_restore == null){
			log_error(_("Snapshot to restore not specified!"));
			return false;
		}
		
		try {
			in_progress = true;
			is_success = false;
			Thread.create<void> (restore_snapshot_thread, true);
		} catch (ThreadError e) {
			in_progress = false;
			is_success = false;
			log_error (e.message);
		}
		
		while (in_progress){
			gtk_do_events ();
			Thread.usleep((ulong) GLib.TimeSpan.MILLISECOND * 100);
		}
		
		snapshot_to_restore = null;
		
		return is_success;
	}

	public void restore_snapshot_thread(){
		string sh = "";
		int ret_val;
		string temp_script;
		bool reboot_after_restore = false;

		in_progress = true;

		try{
			
			string source_path = snapshot_to_restore.path;
			
			//set target path ----------------
			
			bool restore_current_system = false;
			if ((root_device != null) && (restore_target.device == root_device.device)){
				restore_current_system = true;
			}
			
			string target_path = "/"; //current system root
			
			if (!restore_current_system){
				
				bool status = mount_target_device();
				
				if (status == false){
					log_error ("Failed to mount target device");
					is_success = false;
					in_progress = false;
					return;
				}
				
				target_path = mount_point_restore;
				
				//check BTRFS volume
				if (restore_target.type == "btrfs"){
					
					//check subvolume layout
					if (check_btrfs_volume(restore_target) == false){
						string msg = _("The target partition has an unsupported subvolume layout.") + " ";
						msg += _("Only ubuntu-type layouts with @ and @home subvolumes are currently supported.") + "\n\n";

						if (app_mode == ""){
							gtk_messagebox_show(_("Not Supported"),msg,true);
						}
						else{
							log_error(msg);
						}

						is_success = false;
						in_progress = false;
						return;
					}
			
					//mount subvolume @home under @/home
					mount_device(restore_target, mount_point_restore + "/@/home", "subvol=@home");
					target_path = mount_point_restore + "/@";
				}
			}
			
			//add trailing slash 
			if (target_path[-1:target_path.length] != "/"){
				target_path += "/";
			}
			
			//save exclude list for restore
			save_exclude_list_for_restore(snapshot_to_restore);
			
			//create script -------------
			
			sh = "";
			sh += "echo ''\n";
			sh += "echo '" + _("Please do not interrupt the restore process!") + "'\n";
			if ((root_device != null) && (restore_target.device == root_device.device) && (restore_target.uuid == root_device.uuid)){
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
			sh += " \"%s\" \"%s\" \n".printf(source_path + "/localhost/", target_path);

			//sync file system
			sh += "sync \n";
			
			//chroot and re-install grub2 --------
			
			if (reinstall_grub2 && grub_device != null){
				sh += "echo '' \n";
				sh += "echo '" + _("Re-installing GRUB2 bootloader...") + "' \n";
				sh += "for i in /dev /proc /run /sys; do mount --bind \"$i\" \"%s$i\"; done \n".printf(target_path);
				sh += "chroot \"%s\" grub-install --recheck %s \n".printf(target_path, grub_device.device);
				sh += "chroot \"%s\" update-grub \n".printf(target_path);
				
				sh += "echo '' \n";
				sh += "echo '" + _("Synching file systems...") + "' \n";
				sh += "sync \n";
				
				sh += "echo '' \n";
				sh += "echo '" + _("Cleaning up...") + "' \n";
				sh += "for i in /dev /proc /run /sys; do umount -f \"%s$i\"; done \n".printf(target_path);
				
				//sync file system
				sh += "sync \n";
			}

			//reboot if required --------
			
			if ((root_device != null) && (restore_target.device == root_device.device) && (restore_target.uuid == root_device.uuid)){
				sh += "echo '' \n";
				sh += "echo '" + _("Rebooting system...") + "' \n";
				//sh += "reboot -f \n";
				sh += "shutdown -r now \n";
				reboot_after_restore = true;
			}
			
			//invalidate the .sync snapshot --------------------
			
			string sync_name = ".sync"; 
			string sync_path = snapshot_dir + "/" + sync_name; 
			string control_file_path = sync_path + "/info.json";
			
			f = File.new_for_path(control_file_path);
			if(f.query_exists()){
				f.delete(); //delete the control file
			}
			
			//save a control file for updating the .sync snapshot --------------------
			
			control_file_path = snapshot_dir + "/.sync-restore";
			
			f = File.new_for_path(control_file_path);
			if(f.query_exists()){
				f.delete(); //delete existing file
			}
			
			write_file(control_file_path, snapshot_to_restore.path); //save snapshot name

			//run the script --------------------
			
			if (reboot_after_restore){
				temp_script = create_temp_bash_script(sh);
				ret_val = execute_bash_script_fullscreen_sync(temp_script);
				
				if (ret_val == -1){
					string msg = _("Failed to find a terminal emulator on this system!") + "\n";
					msg += _("Please install one of the following terminal emulators and try again") + ":\n";
					msg += "xfce4-terminal gnome-terminal xterm konsole\n\n";
					msg += _("No changes were made to system.");
					
					log_error(msg);
					gtk_messagebox_show(_("Error"), msg, true);

					is_success = false;
					in_progress = false;
					return;
				}
			}
			else{
				string std_out;
				string std_err;
				ret_val = execute_command_script_sync(sh,out std_out, out std_err);
			}
			
			//check for errors ----------------------
			
			if (ret_val != 0){
				log_error(_("Restore failed with exit code") + ": %d".printf(ret_val));
				is_success = false;
				in_progress = false;
			}
			else{
				log_msg(_("Restore completed without errors"));
				is_success = true;
				in_progress = false;
			}
		}
		catch(Error e){
			log_error (e.message);
			is_success = false;
			in_progress = false;
		}
	}


	public bool delete_snapshot(TimeShiftBackup bak){
		snapshot_to_delete = bak;
		
		try {
			in_progress = true;
			is_success = false;
			Thread.create<void> (delete_snapshot_thread, true);
		} catch (ThreadError e) {
			in_progress = false;
			is_success = false;
			log_error (e.message);
		}
		
		while (in_progress){
			gtk_do_events ();
			Thread.usleep((ulong) GLib.TimeSpan.MILLISECOND * 100);
		}
		
		snapshot_to_delete = null;
		
		return is_success;
	}
	
	public void delete_snapshot_thread(){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		in_progress = true;

		try{
			var f = File.new_for_path(snapshot_to_delete.path);
			if(f.query_exists()){
				cmd = "rm -rf \"%s\"".printf(snapshot_to_delete.path);
				
				if (LOG_COMMANDS) { log_msg(cmd, true); }
				
				Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
				
				if (ret_val != 0){
					log_error(_("Unable to delete") + ": '%s'".printf(snapshot_to_delete.name));
					is_success = false;
					in_progress = false;
					return;
				}
				else{
					log_msg(_("Snapshot deleted") + ": '%s'".printf(snapshot_to_delete.name));
					is_success = true;
					in_progress = false;
					return;
				}
			}
		}
		catch(Error e){
			log_error (e.message);
			is_success = false;
			in_progress = false;
			return;
		}
		
		in_progress = false;
	}

	public bool delete_all_snapshots(){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;
		bool success;
		
		//delete snapshots
		foreach(TimeShiftBackup bak in snapshot_list){
			success = delete_snapshot(bak);
			if (!success){ return success; }
		}
		
		//delete .sync
		TimeShiftBackup bak_sync = new TimeShiftBackup(mount_point_backup + "/timeshift/snapshots/.sync");
		success = delete_snapshot(bak_sync);
		if (!success){ return success; }
		
		//delete /timeshift directory ------------
		
		try{
			string timeshift_dir = mount_point_backup + "/timeshift";
			
			cmd = "rm -rf \"%s\"".printf(timeshift_dir);
			
			if (LOG_COMMANDS) { log_msg(cmd, true); }
					
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
			
			if (ret_val != 0){
				log_error(_("Unable to delete") + ": '%s'".printf(timeshift_dir));
				return false;
			}
			else{
				log_msg(_("Deleted") + ": '%s'".printf(timeshift_dir));
				return true;
			}
		}
		catch(Error e){
			log_error (e.message);
			return false;
		}
	}
	
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
	    
	    log_msg(_("App config saved") + ": '%s'".printf(this.app_conf_path));
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

        foreach(PartitionInfo pi in partition_list){
			if (pi.uuid == uuid){
				snapshot_device = pi;
				break;
			}
		}
		
		if ((uuid.length == 0) || (snapshot_device == null)){
			log_msg (_("Warning: Backup device not set! Defaulting to system device"));
			snapshot_device = root_device;
		}
		
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
		
		log_msg(_("App config loaded") + ": '%s'".printf(this.app_conf_path));
	}


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

		log_debug(_("updated snapshot list"));
		return true;
	}
	
	public void update_partition_list(){
		partition_list.clear();
		partition_list = get_all_partitions();

		foreach(PartitionInfo pi in partition_list){
			//root_device and home_device will be detected by detect_system_devices()
			if (pi.mount_point_list.contains("/mnt/timeshift")){
				snapshot_device = pi;
			}
			if (pi.is_mounted){
				pi.dist_info = DistInfo.get_dist_info(pi.mount_point_list[0]).full_name();
			}
		}
		if (partition_list.size == 0){
			log_error(_("Failed to get partition list."));
		}

		log_debug(_("updated partition list"));
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
		foreach(PartitionInfo pi in partition_list){
			if (pi.mount_point_list.contains("/")){
				root_device = pi;
			}
			
			if (pi.mount_point_list.contains("/home")){
				home_device = pi;
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

	public bool mount_backup_device(PartitionInfo? dev = null){
		PartitionInfo backup_device = dev;
		if (backup_device == null){
			backup_device = snapshot_device;
		}
		
		if (backup_device == null){
			return false;
		}
		else{
			return mount_device(backup_device, mount_point_backup, "");
		}
	}
	
	public bool mount_target_device(){
		if (restore_target == null){
			return false;
		}
		else{
			return mount_device(restore_target, mount_point_restore, "");
		}
	}
	
	public bool mount_device(PartitionInfo dev, string mount_point, string mount_options){
		bool status = mount(dev.device, mount_point, mount_options);
		return status;
	}

	public void unmount_backup_device(bool force = true){
		unmount_device(mount_point_backup,force);
	}
	
	public void unmount_target_device(bool force = true){
		unmount_device(mount_point_restore,force);
	}
	
	public void unmount_device(string mount_point, bool force = true){
		if (!unmount(mount_point, force)){
			//exit application if a forced un-mount fails
			if (force){
				if (app_mode == ""){
					gtk_messagebox_show(_("Critical Error"), _("Failed to unmount device!") + "\n" + _("Application will exit"));
				}
				exit_app();
				exit(0);
			}
		}
	}


	public void cron_job_update(){
		string crontab_entry = read_crontab_entry();
		string required_entry = get_crontab_string();
		
		if (is_scheduled && snapshot_list.size > 0){
			if (crontab_entry.length > 0){
				if (crontab_entry == required_entry){
					return;
				}
				else{
					cron_job_remove();
					cron_job_add();
				}
			}
			else{
				cron_job_add();
			}
		}
		else{
			if (crontab_entry.length > 0){
				cron_job_remove();
			}
			else{
				//do nothing
			}
		}
	}

	private string get_crontab_string(){
		return "*/%d * * * * timeshift --backup".printf(cron_job_interval_mins);
	}
	
	private string read_crontab_entry(){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;
		
		try{
			cmd = "crontab -l";
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
			if (ret_val != 0){
				log_debug(_("Crontab is empty"));
			}
			else{
				foreach(string line in std_out.split("\n")){
					if (line.contains("timeshift")){
						return line.strip();
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
	
	private bool cron_job_add(){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;
		
		if (live_system()) { return false; }
		
		try{
			string temp_file = get_temp_file_path();
			write_file(temp_file, get_crontab_string() + "\n");

			cmd = "crontab \"%s\"".printf(temp_file);
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
			
			if (ret_val != 0){
				log_error(std_err);
				log_error(_("Failed to add cron job"));
				return false;
			}
			else{
				log_msg(_("Cron job added"));
				return true;
			}
		}
		catch(Error e){
			log_error (e.message);
			return false;
		}
	}
	
	private bool cron_job_remove(){
		
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;
		
		cmd = "crontab -l | sed '/timeshift/d' | crontab -";
		ret_val = execute_command_script_sync(cmd, out std_out, out std_err);
		
		if (ret_val != 0){
			log_error(_("Failed to remove cron job"));
			return false;
		}
		else{
			log_msg(_("Cron job removed"));
			return true;
		}
	}
	
	
	public PartitionInfo? get_backup_device(){
		var list = get_mounted_partitions_using_df();
		foreach(PartitionInfo info in list){
			if (info.mount_point_list.contains("/mnt/timeshift")){
				return info;
			}
		}
		
		return null;
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
		message = "%s ".printf(snapshot_device.free) + _("free");
		message = message.strip();
			
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
				if (snapshot_list.size > 0){
					if (snapshot_device.free_mb < minimum_free_disk_space_mb){
						message = _("Backup device does not have enough space!");
						status_code = 1;
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

		log_debug("check backup device: status = %d".printf(status_code));
				
		return status_code;
	}
	
	public bool check_btrfs_volume(PartitionInfo dev){
		mount_device(dev, mount_point_test, "");
		bool is_supported = dir_exists(mount_point_test + "/@") && dir_exists(mount_point_test + "/@home");
		unmount_device(mount_point_test);
		return is_supported;
	}
	
	public bool backup_device_online(){
		//check if mounted
		foreach(PartitionInfo info in get_mounted_partitions_using_df()){
			if (info.mount_point_list.contains(mount_point_backup)){
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
			in_progress = true;
			is_success = false;
			Thread.create<void> (calculate_size_of_first_snapshot_thread, true);
		} catch (ThreadError e) {
			in_progress = false;
			is_success = false;
			log_error (e.message);
		}
		
		while (in_progress){
			gtk_do_events ();
			Thread.usleep((ulong) GLib.TimeSpan.MILLISECOND * 100);
		}

		return this.first_snapshot_size;
	}
	
	public void calculate_size_of_first_snapshot_thread(){
		in_progress = true;
		
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

			save_exclude_list("/tmp");
			
			cmd = "du --summarize --one-file-system --exclude-from=/tmp/exclude.list /";
			
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
			if (ret_val != 0){
				log_error (_("Failed to estimate system size"));
				log_error (std_err);
				is_success = false;
			}
			else{
				required_space = long.parse(std_out.replace("/","").strip());
				required_space = required_space / 1024;
				is_success = true;
			}
		}
		catch(Error e){
			log_error (e.message);
			is_success = false;
		}
		
		if ((required_space == 0) && (root_device != null)){
			required_space = root_device.used_mb;
		}
		
		this.first_snapshot_size = required_space;
		
		log_debug("check first snapshot size: %ld MB".printf(required_space));
		
		in_progress = false;
	}
	
	
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
		save_app_config();
		
		cron_job_update();
		
		//soft-unmount always
		unmount_backup_device(false);
		unmount_target_device(false);
		
		clean_logs();
		remove_lock();
		
		//Gtk.main_quit ();
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
	public string path = "";
	public string name = "";
	public bool is_include = false;
	public bool enabled = false;
	
	public AppExcludeEntry(string exclude_pattern, string entry_name = ""){
		pattern = exclude_pattern;
		name = entry_name;
	}
	
	public string pattern{
		owned get{
			string str = (is_include) ? "+ " : "";
			str += path;
			return str.strip();
		}
		set{
			path = value.has_prefix("+ ") ? value[2:value.length] : value;
			is_include = value.has_prefix("+ ") ? true : false;
		}
	}
	
}

	


