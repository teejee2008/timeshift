using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.Devices;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class SnapshotRepo : GLib.Object{
	public Device device = null;
	public string snapshot_path_user = "";
	public string snapshot_path_mount = "";
	public bool use_snapshot_path_custom = false;

	public Gee.ArrayList<Snapshot?> snapshots;
	public Gee.ArrayList<Snapshot?> invalid_snapshots;

	public string status_message = "";
	public string status_details = "";
	public SnapshotLocationStatus status_code;

	// private
	private Gtk.Window? parent_window = null;
	private bool thr_success = false;
	private bool thr_running = false;
	//private int thr_retval = -1;
	private string thr_args1 = "";

	public SnapshotRepo.from_path(string path, Gtk.Window? parent_win){

		log_debug("SnapshotRepo: from_path()");
		
		this.snapshot_path_user = path;
		this.use_snapshot_path_custom = true;
		this.parent_window = parent_win;
		
		snapshots = new Gee.ArrayList<Snapshot>();
		invalid_snapshots = new Gee.ArrayList<Snapshot>();

		log_msg(_("Selected snapshot path") + ": %s".printf(path));
		
		var list = Device.get_disk_space_using_df(path);
		if (list.size > 0){
			device = list[0];
			
			log_msg(_("Device") + ": %s".printf(device.device));
			log_msg(_("Free space") + ": %s".printf(format_file_size(device.free_bytes)));
		}
		
		check_status();
	}

	public SnapshotRepo.from_device(Device dev, Gtk.Window? parent_win){

		log_debug("SnapshotRepo: from_device()");
		
		this.device = dev;
		this.use_snapshot_path_custom = false;
		this.parent_window = parent_win;
		
		snapshots = new Gee.ArrayList<Snapshot>();
		invalid_snapshots = new Gee.ArrayList<Snapshot>();

		init_from_device();
	}

	public SnapshotRepo.from_uuid(string uuid, Gtk.Window? parent_win){

		log_debug("SnapshotRepo: from_uuid()");
		log_debug("uuid=%s".printf(uuid));
		
		device = Device.get_device_by_uuid(uuid);
		if (device == null){
			device = new Device();
			device.uuid = uuid;
		}
			
		this.use_snapshot_path_custom = false;
		this.parent_window = parent_win;
		
		snapshots = new Gee.ArrayList<Snapshot>();
		invalid_snapshots = new Gee.ArrayList<Snapshot>();

		init_from_device();

		log_debug("SnapshotRepo: from_uuid(): exit");
	}

	public SnapshotRepo.from_null(Gtk.Window? parent_win){

		log_debug("SnapshotRepo: from_null()");
		log_debug("device not set");
		
		this.parent_window = parent_win;
		
		snapshots = new Gee.ArrayList<Snapshot>();
		invalid_snapshots = new Gee.ArrayList<Snapshot>();

		log_debug("SnapshotRepo: from_null(): exit");
	}

	private void init_from_device(){

		log_debug("SnapshotRepo: init_from_device()");
		
		if ((device != null) && (device.uuid.length > 0)){
			log_msg("");
			unlock_and_mount_device();

			if ((device != null) && (device.device.length > 0)){
				log_msg(_("Selected snapshot device") + ": %s".printf(device.device));
				log_msg(_("Free space") + ": %s".printf(format_file_size(device.free_bytes)));
			}
		}

		if ((device != null) && (device.device.length > 0)){
			check_status();
		}

		log_debug("SnapshotRepo: init_from_device(): exit");
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

		log_debug("SnapshotRepo: unlock_and_mount_device()");

		if (device == null){
			log_debug("device=null");
		}
		else{
			log_debug("device=%s".printf(device.device));
		}
		
		// unlock encrypted device
		if (device.is_encrypted_partition()){

			device = unlock_encrypted_device(device);
			
			if (device == null){
				log_debug("device is null");
				log_debug("SnapshotRepo: unlock_and_mount_device(): exit");
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

		log_debug("SnapshotRepo: unlock_and_mount_device(): exit");
				
		return false;
	}

	public Device? unlock_encrypted_device(Device luks_device){

		log_debug("SnapshotRepo: unlock_encrypted_device()");
		
		if (luks_device == null){
			log_debug("luks_device=null".printf());
			return null;
		}
		else{
			log_debug("luks_device=%s".printf(luks_device.device));
		}

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

			gtk_set_busy(true, parent_window);

			string message, details;
			luks_unlocked = Device.luks_unlock(luks_device, mapped_name, passphrase,
				out message, out details);

			bool is_error = (luks_unlocked == null);

			gtk_set_busy(false, parent_window);
			
			gtk_messagebox(message, details, null, is_error);
		}

		return luks_unlocked;
	}
	
	public bool load_snapshots(){

		log_debug("SnapshotRepo: load_snapshots()");
		
		snapshots.clear();
		invalid_snapshots.clear();
		
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
						if (bak.valid){
							snapshots.add(bak);
						}
						else{
							// TODO: delete invalid snapshots on every run along with marked snapshots
							invalid_snapshots.add(bak);
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
			if (bak.valid && (tag.length == 0) || bak.has_tag(tag)){
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

		log_debug("SnapshotRepo: check_status()");
		
		status_code = SnapshotLocationStatus.HAS_SNAPSHOTS_HAS_SPACE;
		status_message = "";
		status_details = "";

		log_msg("");
		//log_msg("Config: Free space limit is %s".printf(
		//	format_file_size(Main.MIN_FREE_SPACE)));

		if (available()){
			has_snapshots();
			has_space();
		}

		if ((App != null) && (App.app_mode.length == 0)){
			
			log_msg("%s: '%s'".printf(
				_("Snapshot device"),
				(device == null) ? " UNKNOWN" : device.device));
				
			log_msg("%s: %s".printf(
				_("Snapshot location"), snapshot_location));

			log_msg(status_message);
			log_msg(status_details);
			
			log_msg("%s: %s".printf(
				_("Status"),
				status_code.to_string().replace("SNAPSHOT_LOCATION_STATUS_","")));

			log_msg("");
		}

		log_debug("SnapshotRepo: check_status(): exit");
	}

	public bool available(){

		log_debug("SnapshotRepo: available()");
		
		if (use_snapshot_path_custom){

			log_debug("checking selected path");
			
			if (snapshot_path_user.strip().length == 0){
				status_message = _("Snapshot device not selected");
				status_details = _("Select the snapshot device");
				status_code = SnapshotLocationStatus.NOT_SELECTED;
				return false;
			}
			else{
				
				log_debug("path: %s".printf(snapshot_path_user));
				
				if (!dir_exists(snapshot_path_user)){

					log_debug("path not found");
					
					status_message = _("Snapshot location not available");
					status_details = _("Path not found") + ": '%s'".printf(snapshot_path_user);
					status_code = SnapshotLocationStatus.NOT_AVAILABLE;
					return false;
				}
				else{
					log_debug("path exists");
					
					bool is_readonly;
					bool hardlink_supported =
						filesystem_supports_hardlinks(snapshot_path_user, out is_readonly);

					if (is_readonly){
						status_message = _("File system is read-only");
						status_details = _("Select another location for saving snapshots");
						status_code = SnapshotLocationStatus.READ_ONLY_FS;
						log_debug("is_available: false");
						return false;
					}
					else if (!hardlink_supported){
						status_message = _("File system does not support hard-links");
						status_details = _("Select another location for saving snapshots");
						status_code = SnapshotLocationStatus.HARDLINKS_NOT_SUPPORTED;
						log_debug("is_available: false");
						return false;
					}
					else{
						log_debug("is_available: ok");
						// ok
						return true;
					}
				}
			}
		}
		else{
			log_debug("checking selected device");
			
			if (device == null){
				log_debug("device is null");
				status_message = _("Snapshot device not selected");
				status_details = _("Select the snapshot device");
				status_code = SnapshotLocationStatus.NOT_SELECTED;
				log_debug("is_available: false");
				return false;
			}
			else if (device.device.length == 0){
				status_message = _("Snapshot device not available");
				status_details = _("Device not found") + ": UUID='%s'".printf(device.uuid);
				status_code = SnapshotLocationStatus.NOT_AVAILABLE;
				log_debug("is_available: false");
				return false;
			}
			else{
				log_debug("is_available: ok");
				// ok
				return true;
			}
		}
	}
	
	public bool has_snapshots(){
		
		log_debug("SnapshotRepo: has_snapshots()");
		
		load_snapshots();
		return (snapshots.size > 0);
	}

	public bool has_space(){

		log_debug("SnapshotRepo: has_space()");
		
		if ((device != null) && (device.device.length > 0)){
			device.query_disk_space();
		}
		else{
			log_debug("device is NULL");
			return false;
		}
		
		if (snapshots.size > 0){
			// has snapshots, check minimum space

			//log_debug("has snapshots");
			
			if (device.free_bytes < Main.MIN_FREE_SPACE){
				status_message = _("Not enough disk space");
				status_message += " (< %s)".printf(format_file_size(Main.MIN_FREE_SPACE));
					
				status_details = _("Select another device or free up some space");
				
				status_code = SnapshotLocationStatus.HAS_SNAPSHOTS_NO_SPACE;
				return false;
			}
			else{
				//ok
				status_message = "Device is OK";
				
				status_details = _("%d snapshots, %s free").printf(
					snapshots.size, format_file_size(device.free_bytes));
					
				status_code = SnapshotLocationStatus.HAS_SNAPSHOTS_HAS_SPACE;
				return true;
			}
		}
		else {

			// no snapshots, check estimated space
			log_debug("no snapshots");
			
			var required_space = Main.first_snapshot_size;

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

		log_debug("SnapshotRepo: auto_remove()");
		
		DateTime now = new DateTime.now_local();
		DateTime dt_limit;

		// remove tags from older backups - boot ---------------

		var list = get_snapshots_by_tag("boot");

		if (list.size > App.count_boot){
			log_msg(_("Maximum backups exceeded for backup level") + " '%s'".printf("boot"));
			while (list.size > App.count_boot){
				list[0].remove_tag("boot");
				log_msg(_("Snapshot") + " '%s' ".printf(list[0].name) + _("un-tagged") + " '%s'".printf("boot"));
				list = get_snapshots_by_tag("boot");
			}
		}

		// remove tags from older backups - hourly, daily, weekly, monthly ---------

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

		// remove tags from older older backups - max days -------

		/*show_msg = true;
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
		}*/

		// delete untagged snapshots
		
		remove_untagged();

		// delete older backups - minimum space -------

		/*
		device.query_disk_space();

		show_msg = true;
		count = 0;
		while ((device.size_bytes - device.used_bytes) < App.minimum_free_disk_space){
			
			load_snapshots();
			
			if (snapshots.size > 0){
				if (!snapshots[0].has_tag("ondemand")){

					if (show_msg){
						log_msg(_("Free space is less than") + " %lld GB".printf(
							Main.MIN_FREE_SPACE / GB));
						log_msg(_("Removing older backups to free disk space"));
						show_msg = false;
					}

					snapshots[0].remove();
				}
			}
			
			device.query_disk_space();
		}
		* */

		// delete snapshots marked for deletion

		remove_marked_for_deletion();

		// delete invalid snapshots

		remove_invalid();
	}

	public void remove_untagged(){

		log_debug("SnapshotRepo: remove_untagged()");
		
		bool show_msg = true;

		foreach(Snapshot bak in snapshots){
			if (bak.tags.size == 0){

				if (show_msg){
					log_msg(_("Removing snapshots") + " > " + _("un-tagged") + "...");
					show_msg = false;
				}

				bak.remove(true);
			}
		}

		load_snapshots(); // update the list
	}

	public void remove_marked_for_deletion(){
		log_msg(_("Removing snapshots") + " > " + _("marked for deletion") + "...");
		foreach(var bak in snapshots){
			if (bak.marked_for_deletion){
				bak.remove(true);
			}
		}
		
		load_snapshots(); // update the list
	}
	
	public void remove_invalid(){
		log_msg(_("Removing snapshots") + " > " + _("invalid") + "...");
		foreach(var bak in invalid_snapshots){
			bak.remove(true);
		}
		
		load_snapshots(); // update the list
	}

	public bool remove_all(){
		string timeshift_dir = snapshot_location + "/timeshift";

		if (dir_exists(timeshift_dir)){

			log_msg(_("Removing snapshots") + " > " + _("all") + "...");
			
			//delete snapshots
			foreach(var bak in snapshots){
				bak.remove(true);
			}

			remove_sync_dir();

			bool ok = delete_directory(timeshift_dir);

			load_snapshots(); // update the list
			
			return ok;
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

	public bool remove_timeshift_dir(){
		string timeshift_dir = snapshot_location + "/timeshift";
		
		// delete /timeshift
		if (dir_exists(timeshift_dir)){
			if (!delete_directory(timeshift_dir)){
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
