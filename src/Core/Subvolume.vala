/*
 * Subvolume.vala
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

public class Subvolume : GLib.Object{

	public string device_uuid;
	public string name = "";
	public string path = "";
	public long id = -1;
	public int64 total_bytes = 0;
	public int64 unshared_bytes = 0;

	public string mount_path = "";

	//parent
	public SnapshotRepo? repo;
	
	public Subvolume(string name, string path, string parent_dev_uuid, SnapshotRepo? parent_repo){
		
		this.name = name;
		this.path = path;
		this.device_uuid = parent_dev_uuid;
		this.repo = parent_repo;

		if (repo != null){
			this.mount_path = repo.mount_paths[name];
		}
	}

	public string total_formatted{
		owned get{
			return format_file_size(total_bytes);
		}
	}

	public string unshared_formatted{
		owned get{
			return format_file_size(unshared_bytes);
		}
	}

	public Device? get_device(){
		
		return Device.get_device_by_uuid(device_uuid);
	}
	
	public bool exists_on_disk{
		get {
			return dir_exists(path);
		}
	}

	public bool is_system_subvolume{
		get {
			return (repo == null);
		}
	}
	
	public static Gee.HashMap<string, Subvolume> detect_subvolumes_for_system_by_path(
		string system_path, SnapshotRepo? repo, Gtk.Window? parent_window){

		var map = new Gee.HashMap<string, Subvolume>();
		
		log_debug("Searching subvolume for system at path: %s".printf(system_path));
		
		var fstab = FsTabEntry.read_file(path_combine(system_path, "/etc/fstab"));
		var crypttab = CryptTabEntry.read_file(path_combine(system_path, "/etc/crypttab"));
		
		foreach(var item in fstab){
			
			if (!item.is_for_system_directory()){ continue; }
			
			if (item.subvolume_name().length > 0){
				
				var dev = item.resolve_device(crypttab, parent_window);
				var dev_name = (dev == null) ? "" : dev.device;
				var dev_uuid = (dev == null) ? "" : dev.uuid;
				
				log_debug("Found subvolume: %s, on device: %s".printf(item.subvolume_name(), dev_name));
				
				var subvol = new Subvolume(item.subvolume_name(), item.mount_point, dev_uuid, repo);
				map.set(subvol.name, subvol);
			}
		}

		return map;
	}

	public void print_info(){
		
		log_debug("name=%s, uuid=%s, id=%ld, path=%s".printf(name, device_uuid, id, path));
	}

	// actions ----------------------------------
	
	public bool remove(){

		if (is_system_subvolume){
			if (name == "@"){
				path = path_combine(App.mount_point_app + "/backup", "@");
			}
			else if (name == "@home"){
				path = path_combine(App.mount_point_app + "/backup-home", "@home");
			}
		}
		
		string cmd = "";
		string std_out, std_err, subpath;
		int ret_val;

		if (!dir_exists(path)){ return true; } // ok, item does not exist

		log_msg("%s: %s (Id:%ld)".printf(_("Deleting subvolume"), name, id));

		string options = App.use_option_raw ? "--commit-after" : "";
		
		subpath = path_combine(path, name);
		if (dir_exists(subpath)) { // there is a nested subvol to remove first
			cmd = "btrfs subvolume delete %s '%s'".printf(options, subpath);
			log_debug("Deleting nested subvolume in snapshot");
			log_debug(cmd);
			ret_val = exec_sync(cmd, out std_out, out std_err);
			if (ret_val != 0){
				log_error(std_err);
				log_error(_("Failed to delete snapshot nested subvolume") + ": '%s'".printf(path));
				return false;
			}
		}
		
		cmd = "btrfs subvolume delete %s '%s'".printf(options, path);
		log_debug(cmd);
		ret_val = exec_sync(cmd, out std_out, out std_err);
		if (ret_val != 0){
			log_error(std_err);
			log_error(_("Failed to delete snapshot subvolume") + ": '%s'".printf(path));
			return false;
		}

		log_msg("%s: %s (Id:%ld)\n".printf(_("Deleted subvolume"), name, id));

		return true;
	}

	public bool restore(){

		if (is_system_subvolume) { return false; }

		// restore snapshot subvolume by creating new subvolume snapshots ----------------------
		
		string src_path = path;
		string dst_path = path_combine(mount_path, name);

		if (!dir_exists(src_path)){
			log_error("%s: %s".printf(_("Not Found"), src_path));
			return false;
		}

		if (dir_exists(dst_path)){
			log_error("%s: %s".printf(_("Subvolume exists at destination"), dst_path));
			return false;
		}
		
		string cmd = "btrfs subvolume snapshot '%s' '%s'".printf(src_path, dst_path);
		log_debug(cmd);

		string std_out, std_err;
		int status = exec_sync(cmd, out std_out, out std_err);
		
		if (status != 0){
			log_error(std_err);
			log_error(_("btrfs returned an error") + ": %d".printf(status));
			log_error(_("Failed to restore system subvolume") + ": %s".printf(name));
			return false;
		}

		log_msg(_("Restored system subvolume") + ": %s".printf(name));
		
		return true;
	}
}
