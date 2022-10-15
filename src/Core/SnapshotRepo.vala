/*
 * SnapshotRepo.vala
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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class SnapshotRepo : GLib.Object{
	
	public Device device = null;
	public Device device_home = null; // used for btrfs mode only
	public string mount_path = "";
	public Gee.HashMap<string,string> mount_paths;
	public bool btrfs_mode = false;

	public Gee.ArrayList<Snapshot?> snapshots;
	public Gee.ArrayList<Snapshot?> invalid_snapshots;

	public string status_message = "";
	public string status_details = "";
	public SnapshotLocationStatus status_code;
    public bool last_snapshot_failed_space = false;

	// private
	private Gtk.Window? parent_window = null;
	private bool thr_success = false;
	private bool thr_running = false;
	private string thr_args1 = "";

	public SnapshotRepo.from_path(string path, Gtk.Window? parent_win, bool _btrfs_mode){

		log_debug("SnapshotRepo: from_path()");
		
		this.mount_path = path;
		this.parent_window = parent_win;
		this.btrfs_mode = _btrfs_mode;
		
		snapshots = new Gee.ArrayList<Snapshot>();
		invalid_snapshots = new Gee.ArrayList<Snapshot>();
		mount_paths = new Gee.HashMap<string,string>();
		
		//log_debug("Selected snapshot repo path: %s".printf(path));
		
		var list = Device.get_disk_space_using_df(path);
		
		if (list.size > 0){
			
			device = list[0];
			
			log_debug(_("Device") + ": %s".printf(device.device));
			log_debug(_("Free space") + ": %s".printf(format_file_size(device.free_bytes)));
		}
		
		check_status();
	}

	public SnapshotRepo.from_device(Device dev, Gtk.Window? parent_win, bool btrfs_repo){

		log_debug("SnapshotRepo: from_device(): %s".printf(btrfs_repo ? "BTRFS" : "RSYNC"));
		
		this.device = dev;
		//this.use_snapshot_path_custom = false;
		this.parent_window = parent_win;
		this.btrfs_mode = btrfs_repo;
		
		snapshots = new Gee.ArrayList<Snapshot>();
		invalid_snapshots = new Gee.ArrayList<Snapshot>();
		mount_paths = new Gee.HashMap<string,string>();
		
		init_from_device();
	}

	public SnapshotRepo.from_uuid(string uuid, Gtk.Window? parent_win, bool btrfs_repo){

		log_debug("SnapshotRepo: from_uuid(): %s".printf(btrfs_repo ? "BTRFS" : "RSYNC"));
		log_debug("uuid=%s".printf(uuid));
		
		device = Device.get_device_by_uuid(uuid);
		if (device == null){
			device = new Device();
			device.uuid = uuid;
		}
			
		//this.use_snapshot_path_custom = false;
		this.parent_window = parent_win;
		this.btrfs_mode = btrfs_repo;
		
		snapshots = new Gee.ArrayList<Snapshot>();
		invalid_snapshots = new Gee.ArrayList<Snapshot>();
		mount_paths = new Gee.HashMap<string,string>();

		init_from_device();

		log_debug("SnapshotRepo: from_uuid(): exit");
	}

	public SnapshotRepo.from_null(){

		log_debug("SnapshotRepo: from_null()");
		log_debug("device not set");
		
		snapshots = new Gee.ArrayList<Snapshot>();
		invalid_snapshots = new Gee.ArrayList<Snapshot>();
		mount_paths = new Gee.HashMap<string,string>();

		log_debug("SnapshotRepo: from_null(): exit");
	}

	private void init_from_device(){

		log_debug("SnapshotRepo: init_from_device()");
		
		if ((device != null) && (device.uuid.length > 0) && (Device.get_device_by_uuid(device.uuid) != null)){
			
			log_debug("");
			unlock_and_mount_devices();

			if ((device != null) && (device.device.length > 0)){
				
				log_debug(_("Selected snapshot device") + ": %s".printf(device.device));
				log_debug(_("Free space") + ": %s".printf(format_file_size(device.free_bytes)));
			}
		}

		if ((device != null) && (device.device.length > 0)){
			
			check_status();
		}

		log_debug("SnapshotRepo: init_from_device(): exit");
	}

	// properties
	
	public string timeshift_path {
		owned get{
			if (btrfs_mode){
				return path_combine(mount_path, "timeshift-btrfs");
			}
			else{
				return path_combine(mount_path, "timeshift");
			}
		}
	}
	
	public string snapshots_path {
		owned get{
			return path_combine(timeshift_path, "snapshots");
		}
	}
 
	// load ---------------------------------------

	public bool unlock_and_mount_devices(){

		log_debug("SnapshotRepo: unlock_and_mount_devices()");

		if (device == null){
			log_debug("device=null");
		}
		else{
			log_debug("device=%s".printf(device.device));
		}

		mount_path = unlock_and_mount_device(device, App.mount_point_app + "/backup");
		
		if (mount_path.length == 0){
			return false;
		}

		// rsync
		mount_paths["@"] = "";
		mount_paths["@home"] = "";
			
		if (btrfs_mode){
			
			mount_paths["@"] = mount_path;
			mount_paths["@home"] = mount_path; //default
			device_home = device; //default
			
			// mount @home if on different disk -------
		
			var repo_subvolumes = Subvolume.detect_subvolumes_for_system_by_path(path_combine(mount_path,"@"), this, parent_window);
			
			if (repo_subvolumes.has_key("@home")){
				
				var subvol = repo_subvolumes["@home"];
				
				if (subvol.device_uuid != device.uuid){
					
					// @home is on a separate device
					device_home = subvol.get_device();
					
					mount_paths["@home"] = unlock_and_mount_device(device_home, App.mount_point_app + "/backup-home");
					
					if (mount_paths["@home"].length == 0){
						return false;
					}
				}
			}
		}

		load_snapshots();

		log_debug("SnapshotRepo: unlock_and_mount_device(): exit");
				
		return true;
	}

	public string unlock_and_mount_device(Device device_to_mount, string path_to_mount){

		// mounts the device and returns mount path
		
		log_debug("SnapshotRepo: unlock_and_mount_device()");

		Device dev = device_to_mount;
		
		if (dev == null){
			log_debug("device=null");
		}
		else{
			log_debug("device=%s".printf(dev.device));
		}
		
		// unlock encrypted device
		if (dev.is_encrypted_partition()){

			dev = unlock_encrypted_device(dev);
			device = dev; // set repo device to unlocked child disk
			
			if (dev == null){
				log_debug("device is null");
				log_debug("SnapshotRepo: unlock_and_mount_device(): exit");
				return "";
			}
		}

		// mount
		bool ok = Device.mount(dev.uuid, path_to_mount, ""); // TODO: check if already mounted
		
		if (ok){
			return path_to_mount;
		}
		else{
			return "";
		}
	}

	public Device? unlock_encrypted_device(Device luks_device){

		log_debug("SnapshotRepo: unlock_encrypted_device()");
		
		if (luks_device == null){
			log_debug("luks_device=null");
			return null;
		}
		else{
			log_debug("luks_device=%s".printf(luks_device.device));
		}

		string msg_out, msg_err;
		var luks_unlocked = Device.luks_unlock(
			luks_device, "", "", parent_window, out msg_out, out msg_err);

		return luks_unlocked;
	}
	
	public bool load_snapshots(){

		log_debug("SnapshotRepo: load_snapshots()");
		
		snapshots.clear();
		invalid_snapshots.clear();
		
		if ((device == null) || !dir_exists(snapshots_path)){
			return false;
		}

		try{
			var dir = File.new_for_path(snapshots_path);
			var enumerator = dir.enumerate_children("*", 0);

			var info = enumerator.next_file ();
			while (info != null) {
				if (info.get_file_type() == FileType.DIRECTORY) {
					if (info.get_name() != ".sync") {
						
						//log_debug("load_snapshots():" + snapshots_path + "/" + info.get_name());
						
						Snapshot bak = new Snapshot(snapshots_path + "/" + info.get_name(), btrfs_mode, this);
						if (bak.valid){
							snapshots.add(bak);
						}
						else{
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

		// reset the 'live' flag ------------
		
		DateTime dt_boot = new DateTime.now_local();
		dt_boot = dt_boot.add_seconds(-1.0 * get_system_uptime_seconds());
		foreach(var bak in snapshots){
			if (bak.live){
				if ((App.sys_root == null) || (App.sys_root.uuid != bak.sys_uuid)){
					// we are accessing the snapshot from a live system or another system
					bak.live = false;
					bak.update_control_file();
				}
				else{
					 if (bak.date.difference(dt_boot) < 0){
						// snapshot was created before the last reboot
						bak.live = false;
						bak.update_control_file();
					}
					else{
						// do nothing, snapshot is still in use by system
					}
				}
			}
		}

		if (btrfs_mode){
			App.query_subvolume_info(this);
		}
		
		log_debug("loading snapshots from '%s': %d found".printf(snapshots_path, snapshots.size));

		return true;
	}

	// get tagged snapshots ----------------------------------
	
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

	public Snapshot? get_latest_snapshot(string tag, string sys_uuid){
		
		var list = get_snapshots_by_tag(tag);
		
		for(int i = list.size - 1; i >= 0; i--){
			var bak = list[i];
			if (bak.sys_uuid == sys_uuid){
				return bak;
			}
		}

		return null;
	}

	public Snapshot? get_oldest_snapshot(string tag, string sys_uuid){
		
		var list = get_snapshots_by_tag(tag);

		for(int i = 0; i < list.size; i++){
			var bak = list[i];
			if (bak.sys_uuid == sys_uuid){
				return bak;
			}
		}
		
		return null;
	}

	// status check ---------------------------

	public void check_status(){

		log_debug("SnapshotRepo: check_status()");
		
        if (!last_snapshot_failed_space)
        {
            status_code = SnapshotLocationStatus.HAS_SNAPSHOTS_HAS_SPACE;
            status_message = "";
            status_details = "";
        }

		if (available()){
			has_snapshots();
            if (!last_snapshot_failed_space)
            {
                has_space();
            }
		}

		if ((App != null) && (App.app_mode.length == 0)){
			
			log_debug("%s: '%s'".printf(
				_("Snapshot device"),
				(device == null) ? " UNKNOWN" : device.device));
				
			log_debug("%s: %s".printf(
				_("Snapshot location"), mount_path));

			log_debug(status_message);
			log_debug(status_details);
			
			log_debug("%s: %s".printf(
				_("Status"),
				status_code.to_string().replace("SNAPSHOT_LOCATION_STATUS_","")));

			log_debug("");
		}

        last_snapshot_failed_space = false;
		log_debug("SnapshotRepo: check_status(): exit");
	}

	public bool available(){

		log_debug("SnapshotRepo: available()");
		
		//log_debug("checking selected device");

		if (device == null){
			if (App.backup_uuid.length == 0){
				log_debug("device is null");
				status_message = _("Snapshot device not selected");
				status_details = _("Select the snapshot device");
				status_code = SnapshotLocationStatus.NOT_SELECTED;
				log_debug("is_available: false");
				return false;
			}
			else{
				status_message = _("Snapshot device not available");
				status_details = _("Device not found") + ": UUID='%s'".printf(App.backup_uuid);
				status_code = SnapshotLocationStatus.NOT_AVAILABLE;
				log_debug("is_available: false");
				return false;
			}
		}
		else{
			if (btrfs_mode){
				bool ok = has_btrfs_system();
				if (ok){
					log_debug("is_available: ok");
				}
				return ok;
			}
			else{
				log_debug("is_available: ok");
				return true;
			}
		}
	}

	public bool has_btrfs_system(){
		
		log_debug("SnapshotRepo: has_btrfs_system()");

		var root_path = path_combine(mount_paths["@"],"@");
		log_debug("root_path=%s".printf(root_path));
		log_debug("btrfs_mode=%s".printf(btrfs_mode.to_string()));
		if (btrfs_mode){
			if (!dir_exists(root_path)){
				status_message = _("Selected snapshot device is not a system disk");
				status_details = _("Select BTRFS system disk with root subvolume (@)");
				status_code = SnapshotLocationStatus.NO_BTRFS_SYSTEM;
				log_debug(status_message);
				return false;
			}
		}

		return true;
	}
	
	public bool has_snapshots(){
		
		log_debug("SnapshotRepo: has_snapshots()");
		
		//load_snapshots();
		return (snapshots.size > 0);
	}

	public bool has_space(uint64 needed = 0) {
		log_debug("SnapshotRepo: has_space() - %llu required (%s)".printf(needed, format_file_size(needed)));
		
		if ((device != null) && (device.device.length > 0)){
			device.query_disk_space();
		}
		else{
			log_debug("device is NULL");
			return false;
		}
		
		if (snapshots.size > 0){
			// has snapshots, check minimum space

            if (device.free_bytes < (needed > 0 ? needed : Main.MIN_FREE_SPACE)) {
				status_message = _("Not enough disk space");
				status_message += " (< %s)".printf(format_file_size((needed > 0 ? needed : Main.MIN_FREE_SPACE), false, "", true, 0));
					
				status_details = _("Select another device or free up some space");
				
				status_code = SnapshotLocationStatus.HAS_SNAPSHOTS_NO_SPACE;
                last_snapshot_failed_space = true;
				return false;
			}
			else{
				//ok
				status_message = _("OK");
				
				status_details = _("%d snapshots, %s free").printf(
					snapshots.size, format_file_size(device.free_bytes));
					
                last_snapshot_failed_space = false;
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

	public void print_status(){
		
		check_status();
		
		//log_msg("");
		
		if (device == null){
			log_msg("%-6s : %s".printf(_("Device"), _("Not Selected")));
		}
		else{
			log_msg("%-6s : %s".printf(_("Device"), device.device_name_with_parent));
			log_msg("%-6s : %s".printf("UUID", device.uuid));
			log_msg("%-6s : %s".printf(_("Path"), mount_path));
			log_msg("%-6s : %s".printf(_("Mode"), btrfs_mode ? "BTRFS" : "RSYNC"));
			log_msg("%-6s : %s".printf(_("Status"), status_message));
			log_msg(status_details);
		}

		log_msg("");
	}
	
	// actions -------------------------------------

	public void auto_remove(){

		log_debug("SnapshotRepo: auto_remove()");
		last_snapshot_failed_space = false;
		DateTime now = new DateTime.now_local();
		DateTime dt_limit;
		int count_limit;
		
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
					count_limit = App.count_hourly;
					break;
				case "daily":
					dt_limit = now.add_days(-1 * App.count_daily);
					count_limit = App.count_daily;
					break;
				case "weekly":
					dt_limit = now.add_weeks(-1 * App.count_weekly);
					count_limit = App.count_weekly;
					break;
				case "monthly":
					dt_limit = now.add_months(-1 * App.count_monthly);
					count_limit = App.count_monthly;
					break;
				default:
					dt_limit = now.add_years(-1 * 10);
					count_limit = 100000;
					break;
			}

			if (list.size > count_limit){

				log_msg(_("Maximum backups exceeded for backup level") + " '%s'".printf(level));

				int snaps_count = list.size;
				
				foreach(var snap in list){

					if (snap.description.strip().length > 0){ continue; } // don't delete snapshots with comments
					
					if ((snap.date.compare(dt_limit) < 0) && (snaps_count > count_limit)){

						snap.remove_tag(level);
						snaps_count--;
					
						log_msg(_("Snapshot") + " '%s' ".printf(list[0].name) + _("un-tagged") + " '%s'".printf(level));
					}
				}
			}
		}

		// remove tags from older backups - max days -------

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
					log_msg("%s (%s):".printf(_("Removing snapshots"), _("un-tagged")));
					show_msg = false;
				}

				bak.remove(true);
			}
		}

		load_snapshots(); // update the list
	}

	public void remove_marked_for_deletion(){

		bool show_msg = true;
		
		foreach(var bak in snapshots){
			if (bak.marked_for_deletion){
				
				if (show_msg){
					log_msg("%s (%s):".printf(_("Removing snapshots"), _("marked for deletion")));
					show_msg = false;
				}
				
				bak.remove(true);
			}
		}
		
		load_snapshots(); // update the list
	}
	
	public void remove_invalid(){

		bool show_msg = true;

		foreach(var bak in invalid_snapshots){

			if (show_msg){
				log_msg("%s (%s):".printf(_("Removing snapshots"), _("incomplete")));
				show_msg = false;
			}
				
			bak.remove(true);
		}
		
		load_snapshots(); // update the list
	}

	public bool remove_all(){

		if (dir_exists(timeshift_path)){

			log_msg(_("Removing snapshots") + " > " + _("all") + "...");
			
			//delete snapshots
			foreach(var bak in snapshots){
				bak.remove(true);
			}

			remove_sync_dir();

			bool ok = delete_directory(timeshift_path);

			load_snapshots(); // update the list
			
			return ok;
		}
		else{
			log_msg(_("No snapshots found") + " '%s'".printf(mount_path));
			return true;
		}
	}

	public bool remove_sync_dir(){
		string sync_dir = mount_path + "/timeshift/snapshots/.sync";
		
		//delete .sync
		if (dir_exists(sync_dir)){
			if (!delete_directory(sync_dir)){
				return false;
			}
		}
		
		return true;
	}

	public bool remove_timeshift_dir(){

		// delete /timeshift
		if (dir_exists(timeshift_path)){
			if (!delete_directory(timeshift_path)){
				return false;
			}
		}
		
		return true;
	}

	// private -------------------------------------------
	
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

	// symlinks ----------------------------------------
	
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
				
				path = "%s-%s".printf(snapshots_path, tag);
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
			string path = "%s-%s".printf(snapshots_path, tag);
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
     6 - btrfs device does not have @ subvolume
	*/
	NOT_SELECTED = -2,
	NOT_AVAILABLE = -1,
	HAS_SNAPSHOTS_HAS_SPACE = 0,
	HAS_SNAPSHOTS_NO_SPACE = 1,
	NO_SNAPSHOTS_NO_SPACE = 2,
	NO_SNAPSHOTS_HAS_SPACE = 3,
	READ_ONLY_FS = 4,
	HARDLINKS_NOT_SUPPORTED = 5,
	NO_BTRFS_SYSTEM = 6
}
