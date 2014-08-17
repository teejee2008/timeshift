/*
 * Utility.vala
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

using Gtk;
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

/*
extern void exit(int exit_code);
*/

namespace TeeJee.Logging{
	
	/* Functions for logging messages to console and log files */

	using TeeJee.Misc;
	
	public DataOutputStream dos_log;
	
	public bool LOG_ENABLE = true;
	public bool LOG_TIMESTAMP = true;
	public bool LOG_COLORS = true;
	public bool LOG_DEBUG = false;
	public bool LOG_COMMANDS = false;

	public void log_msg (string message, bool highlight = false){

		if (!LOG_ENABLE) { return; }
		
		string msg = "";
		
		if (highlight && LOG_COLORS){
			msg += "\033[1;38;5;34m";
		}
		
		if (LOG_TIMESTAMP){
			msg += "[" + timestamp() +  "] ";
		}
		
		msg += message;
		
		if (highlight && LOG_COLORS){
			msg += "\033[0m";
		}
		
		msg += "\n";
		
		stdout.printf (msg);
		
		try {
			if (dos_log != null){
				dos_log.put_string ("[%s] %s\n".printf(timestamp(), message));
			}
		} 
		catch (Error e) {
			stdout.printf (e.message);
		}
	}

	public void log_error (string message, bool highlight = false, bool is_warning = false){
		if (!LOG_ENABLE) { return; }
		
		string msg = "";
		
		if (highlight && LOG_COLORS){
			msg += "\033[1;38;5;160m";
		}
		
		if (LOG_TIMESTAMP){
			msg += "[" + timestamp() +  "] ";
		}
		
		string prefix = (is_warning) ? _("Warning") : _("Error");
		
		msg += prefix + ": " + message;
		
		if (highlight && LOG_COLORS){
			msg += "\033[0m";
		}
		
		msg += "\n";
		
		stdout.printf (msg);
		
		try {
			if (dos_log != null){
				dos_log.put_string ("[%s] %s: %s\n".printf(timestamp(), prefix, message));
			}
		} 
		catch (Error e) {
			stdout.printf (e.message);
		}
	}

	public void log_debug (string message){
		if (!LOG_ENABLE) { return; }
			
		if (LOG_DEBUG){
			log_msg (message);
		}

		try {
			if (dos_log != null){
				dos_log.put_string ("[%s] %s\n".printf(timestamp(), message));
			}
		} 
		catch (Error e) {
			stdout.printf (e.message);
		}
	}
}

namespace TeeJee.FileSystem{
	
	/* Convenience functions for handling files and directories */
	
	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.ProcessManagement;
	using TeeJee.Misc;
	
	public void file_delete(string filePath){
		
		/* Check and delete file */
		
		try {
			var file = File.new_for_path (filePath);
			if (file.query_exists ()) { 
				file.delete (); 
			}
		} catch (Error e) {
	        log_error (e.message);
	    }
	}
	
	public bool file_exists (string filePath){
		/* Check if file exists */
		return ( FileUtils.test(filePath, GLib.FileTest.EXISTS) && FileUtils.test(filePath, GLib.FileTest.IS_REGULAR));
	}
	
	public bool device_exists (string filePath){
		/* Check if device exists */
		return (FileUtils.test(filePath, GLib.FileTest.EXISTS));
	}
	
	public void file_copy (string src_file, string dest_file){
		try{
			var file_src = File.new_for_path (src_file);
			if (file_src.query_exists()) { 
				var file_dest = File.new_for_path (dest_file);
				file_src.copy(file_dest,FileCopyFlags.OVERWRITE,null,null);
			}
		}
		catch(Error e){
	        log_error (e.message);
		}
	}
	
	public bool dir_exists (string filePath){
		
		/* Check if directory exists */
		
		return ( FileUtils.test(filePath, GLib.FileTest.EXISTS) && FileUtils.test(filePath, GLib.FileTest.IS_DIR));
	}
	
	public bool create_dir (string filePath){
		
		/* Creates a directory along with parents */
		
		try{
			var dir = File.parse_name (filePath);
			if (dir.query_exists () == false) {
				dir.make_directory_with_parents (null);
			}
			return true;
		}
		catch (Error e) { 
			log_error (e.message); 
			return false;
		}
	}
	
	public bool move_file (string sourcePath, string destPath){
		
		/* Move file from one location to another */
		
		try{
			File fromFile = File.new_for_path (sourcePath);
			File toFile = File.new_for_path (destPath);
			fromFile.move (toFile, FileCopyFlags.NONE);
			return true;
		}
		catch (Error e) { 
			log_error (e.message); 
			return false;
		}
	}
	
	public bool copy_file (string sourcePath, string destPath){
		
		/* Copy file from one location to another */
		
		try{
			File fromFile = File.new_for_path (sourcePath);
			File toFile = File.new_for_path (destPath);
			fromFile.copy (toFile, FileCopyFlags.NONE);
			return true;
		}
		catch (Error e) { 
			log_error (e.message); 
			return false;
		}
	}
	
	public string? read_file (string file_path){
		
		/* Reads text from file */
		
		string txt;
		size_t size;
		
		try{
			GLib.FileUtils.get_contents (file_path, out txt, out size);
			return txt;	
		}
		catch (Error e){
	        log_error (e.message);
	    }
	    
	    return null;
	}
	
	public bool write_file (string file_path, string contents){
		
		/* Write text to file */
		
		try{
			var file = File.new_for_path (file_path);
			if (file.query_exists ()) { file.delete (); }
			var file_stream = file.create (FileCreateFlags.REPLACE_DESTINATION);
			var data_stream = new DataOutputStream (file_stream);
			data_stream.put_string (contents);
			data_stream.close();
			return true;
		}
		catch (Error e) {
	        log_error (e.message);
	        return false;
	    } 
	}
	
	public long get_file_count(string path){
				
		/* Return total count of files and directories */
		
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;
		
		cmd = "find \"%s\" | wc -l".printf(path);
		ret_val = execute_command_script_sync(cmd, out std_out, out std_err);
		return long.parse(std_out);
	}

	public long get_file_size(string path){
				
		/* Returns size of files and directories in KB*/
		
		string cmd = "";
		string output = "";
		
		cmd = "du -s \"%s\"".printf(path);
		output = execute_command_sync_get_output(cmd);
		return long.parse(output.split("\t")[0]);
	}

	public string get_file_size_formatted(string path){
				
		/* Returns size of files and directories in KB*/
		
		string cmd = "";
		string output = "";
		
		cmd = "du -s -h \"%s\"".printf(path);
		output = execute_command_sync_get_output(cmd);
		return output.split("\t")[0].strip();
	}
	
	public int chmod (string file, string permission){
				
		/* Change file permissions */
		
		return execute_command_sync ("chmod " + permission + " \"%s\"".printf(file));
	}
	
	public string resolve_relative_path (string filePath){
				
		/* Resolve the full path of given file using 'realpath' command */
		
		string filePath2 = filePath;
		if (filePath2.has_prefix ("~")){
			filePath2 = Environment.get_home_dir () + "/" + filePath2[2:filePath2.length];
		}
		
		try {
			string output = "";
			Process.spawn_command_line_sync("realpath \"%s\"".printf(filePath2), out output);
			output = output.strip ();
			if (FileUtils.test(output, GLib.FileTest.EXISTS)){
				return output;
			}
		}
		catch(Error e){
	        log_error (e.message);
	    }
	    
	    return filePath2;
	}
	
	public int rsync (string sourceDirectory, string destDirectory, bool updateExisting, bool deleteExtra){
				
		/* Sync files with rsync */
		
		string cmd = "rsync --recursive --perms --chmod=a=rwx";
		cmd += updateExisting ? "" : " --ignore-existing";
		cmd += deleteExtra ? " --delete" : "";
		cmd += " \"%s\"".printf(sourceDirectory + "//");
		cmd += " \"%s\"".printf(destDirectory);
		return execute_command_sync (cmd);
	}
}

namespace TeeJee.DiskPartition{
	
	/* Functions and classes for handling disk partitions */
		
	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.ProcessManagement;

	public class PartitionInfo : GLib.Object{
		
		/* Class for storing partition information */
		
		public string device = "";
		public string type = "";
		public long size_mb = 0;
		public long used_mb = 0;
		public string label = "";
		public string uuid = "";
		public string available = "";
		public string used_percent = "";
		public string dist_info = "";
		public Gee.ArrayList<string> mount_point_list;
		public string mount_options = "";
		
		public PartitionInfo(){
			mount_point_list = new Gee.ArrayList<string>();
		}
		
		public string description(){
			string s = "";
			s += device;
			s += (label.length > 0) ? " (" + label + ")": "";
			s += (type.length > 0) ? " ~ " + type : "";
			s += (used.length > 0) ? " ~ " + used + " / " + size + " GB used (" + used_percent + ")" : "";
			return s;
		}
		
		public string description_full(){
			string s = "";
			s += device;
			s += (label.length > 0) ? " (" + label + ")": "";
			s += (uuid.length > 0) ? " ~ " + uuid : "";
			s += (type.length > 0) ? " ~ " + type : "";
			s += (used.length > 0) ? " ~ " + used + " / " + size + " GB used (" + used_percent + ")" : "";
			
			string mps = "";
			foreach(string mp in mount_point_list){
				mps += mp + " ";
			}
			s += (mps.length > 0) ? " ~ " + mps.strip() : "";
			
			return s;
		}
		
		public string description_usage(){
			if (used.length > 0){
				return used + " / " + size + " used (" + used_percent + ")";
			}
			else{
				return "";
			}
		}
		
		public string size{
			owned get{
				return (size_mb == 0) ? "" : "%.1f".printf(size_mb/1024.0);
			}
		}
		
		public string used{
			owned get{
				return (used_mb == 0) ? "" : "%.1f".printf(used_mb/1024.0);
			}
		}
		
		public long free_mb{
			get{
				return (size_mb - used_mb);
			}
		}
		
		public bool is_mounted{
			get{
				return (mount_point_list.size > 0);
			}
		}
		
		public string free{
			owned get{
				return (free_mb == 0) ? "" : "%.1f GB".printf(free_mb/1024.0);
			}
		}

		public string partition_name{
			owned get{
				return device.replace("/dev/mapper/","").replace("/dev/","");
			}
		}
		
		public bool has_linux_filesystem(){
			switch(type){
				case "ext2":
				case "ext3":
				case "ext4":
				case "reiserfs":
				case "reiser4":
				case "xfs":
				case "jfs":
				case "btrfs":
					return true;
				default:
					return false;
			}
		}
	}
	
	public class DeviceInfo : GLib.Object{
		
		/* Class for storing device information */
		
		public string device = "";
		public bool removable = false;
		public string vendor = "";
		public string model = "";

		public string name{
			owned get{
				return vendor + " " + model;
			}
		}
		
		public string description{
			owned get{
				return device + " ~ " + vendor + " " + model;
			}
		}
	}


	public Gee.ArrayList<PartitionInfo?> get_partition_usage(bool exclude_unknown = true){
		
		/* Returns list of mounted partitions using 'df' command 
		   Populates device, type, size, used and mount_point_list */
		 
		var list = new Gee.ArrayList<PartitionInfo?>();
		
		string std_out = "";
		string std_err = "";
		int exit_code = execute_command_script_sync("df -T -BM", out std_out, out std_err);// | uniq -w 12
		
		if (exit_code != 0){ return list; }
		
		if (exit_code != 0){ 
			log_error ("Failed to get list of partitions");
			return list; //return empty list
		}
		
		/*
		sample output
		-----------------
		Filesystem     Type     1M-blocks    Used Available Use% Mounted on
		/dev/sda3      ext4        25070M  19508M     4282M  83% /
		none           tmpfs           1M      0M        1M   0% /sys/fs/cgroup
		udev           devtmpfs     3903M      1M     3903M   1% /dev
		tmpfs          tmpfs         789M      1M      788M   1% /run
		none           tmpfs           5M      0M        5M   0% /run/lock
		/dev/sda3      ext4        25070M  19508M     4282M  83% /mnt/timeshift
		*/
		
		string[] lines = std_out.split("\n");

		int line_num = 0;
		foreach(string line in lines){

			if (++line_num == 1) { continue; }
			if (line.strip().length == 0) { continue; }
			
			PartitionInfo pi = new PartitionInfo();
			
			//parse & populate fields ------------------
			
			int k = 1;
			foreach(string val in line.split(" ")){
				
				if (val.strip().length == 0){ continue; }

				switch(k++){
					case 1:
						pi.device = val.strip();
						break;
					case 2:
						pi.type = val.strip();
						break;
					case 3:
						pi.size_mb = long.parse(val.strip().replace("M",""));
						break;
					case 4:
						pi.used_mb = long.parse(val.strip().replace("M",""));
						break;
					case 5:
						pi.available = val.strip();
						break;
					case 6:
						pi.used_percent = val.strip();
						break;
					case 7:
						string mount_point = val.strip();
						if (!pi.mount_point_list.contains(mount_point)){
							pi.mount_point_list.add(mount_point);
						}
						break;
				}
			}
			
			//exclude unknown devices
			if (exclude_unknown){
				if (!(pi.device.has_prefix("/dev/sd") || pi.device.has_prefix("/dev/hd") || pi.device.has_prefix("/dev/mapper/"))) { 
					continue;
				}
			}
			
			//check for duplicates - no need to match uuids
			bool found = false;
			foreach(PartitionInfo pm in list){
				if (pm.device == pi.device){
					//add mount points and continue
					foreach(string mount_point in pi.mount_point_list){
						if (!pm.mount_point_list.contains(mount_point)){
							pm.mount_point_list.add(mount_point);
						}
					}
					found = true;
					//don't break
				}
			}
			
			//add to list
			if (!found){
				list.add(pi);
			}
		}
		
		/*
		//debug
		string list = "";
		foreach(string mp in info.mount_point_list){
			list += mp + ";";
		}
		stdout.printf(info.device + "=" + list + "\n");
		*/
		
		return list;
	}

	public Gee.ArrayList<PartitionInfo?> get_mounted_partitions_using_mtab(bool exclude_unknown = true){
		
		/* Returns list of mounted partitions using 'mount' command 
		   Populates device, type and mount_point_list */

		var list = new Gee.ArrayList<PartitionInfo?>();
		
		string mtab_path = "/etc/mtab";
		string mtab_lines = "";;
		
		File f;
		
		//find mtab file -----------
		
		mtab_path = "/etc/mtab";
		f = File.new_for_path(mtab_path);
		if(!f.query_exists()){
			mtab_path = "/proc/mounts";
			f = File.new_for_path(mtab_path);
			if(!f.query_exists()){
				mtab_path = "/proc/self/mounts";
				f = File.new_for_path(mtab_path);
				if(!f.query_exists()){
					return list; //empty list
				}
			}
		}
		
		//read -----------
		
		mtab_lines = read_file(mtab_path);
		
		/*
		sample mtab
		-----------------
		/dev/sda3 / ext4 rw,errors=remount-ro 0 0
		proc /proc proc rw,noexec,nosuid,nodev 0 0
		sysfs /sys sysfs rw,noexec,nosuid,nodev 0 0
		none /sys/fs/cgroup tmpfs rw 0 0
		none /sys/fs/fuse/connections fusectl rw 0 0
		none /sys/kernel/debug debugfs rw 0 0
		none /sys/kernel/security securityfs rw 0 0
		udev /dev devtmpfs rw,mode=0755 0 0

		device - the device or remote filesystem that is mounted.
		mountpoint - the place in the filesystem the device was mounted.
		filesystemtype - the type of filesystem mounted.
		options - the mount options for the filesystem
		dump - used by dump to decide if the filesystem needs dumping.
		fsckorder - used by fsck to detrmine the fsck pass to use. 
		*/
		
		//parse ------------
		
		foreach(string line in mtab_lines.split("\n")){

			if (line.strip().length == 0) { continue; }
			
			PartitionInfo pi = new PartitionInfo();

			//parse & populate fields ------------------
							
			int k = 1;
			foreach(string val in line.split(" ")){
				if (val.strip().length == 0){ continue; }
				switch(k++){
					case 1: //device
						pi.device = val.strip();
						break;
					case 2: //mountpoint
						string mount_point = val.strip();
						if (!pi.mount_point_list.contains(mount_point)){
							pi.mount_point_list.add(mount_point);
						}
						break;
					case 3: //filesystemtype
						pi.type = val.strip();
						break;
					case 4: //options
						pi.mount_options = val.strip();
						break;
					default:
						//ignore
						break;
				}
			}
			
			//exclude unknown device names
			if (exclude_unknown){
				if (pi.device.has_prefix("/dev/sd") || pi.device.has_prefix("/dev/hd") || pi.device.has_prefix("/dev/mapper/")) { 
					//ok
				}
				else if (pi.device.has_prefix("/dev/disk/by-uuid/")){
					//ok - get uuid
					pi.uuid = pi.device.replace("/dev/disk/by-uuid/","");
				}
				else{
					continue; //skip
				}
			}

			//check for duplicates - no need to match uuids
			bool found = false;
			foreach(PartitionInfo pm in list){
				if (pm.device == pi.device){
					//add mount points and continue
					foreach(string mount_point in pi.mount_point_list){
						if (!pm.mount_point_list.contains(mount_point)){
							pm.mount_point_list.add(mount_point);
						}
					}
					found = true;
					//don't break
				}
			}
			
			//add to list
			if (!found){
				list.add(pi);
			}
		}

		return list;
	}
	
	public Gee.ArrayList<PartitionInfo?> get_partitions_using_blkid(bool exclude_unknown = true){
		
		/* Returns list of mounted/unmounted, physical/LVM partitions 
		 * Populates device, uuid, type and label */
		
		var list = new Gee.ArrayList<PartitionInfo?>();

		string std_out;
		string std_err;
		int ret_val;
		Regex rex;
		MatchInfo match;
			
		ret_val = execute_command_script_sync("/sbin/blkid", out std_out, out std_err);
		
		if (ret_val != 0){
			log_error ("Failed to get list of partitions");
			return list; //return empty list
		}
			
		/*
		sample output
		-----------------
		/dev/sda1: LABEL="System Reserved" UUID="F476B08076B04560" TYPE="ntfs" 
		/dev/sda2: LABEL="windows" UUID="BE00B6DB00B69A3B" TYPE="ntfs" 
		/dev/sda3: UUID="03f3f35d-71fa-4dff-b740-9cca19e7555f" TYPE="ext4"
		*/
		
		try{
			foreach(string line in std_out.split("\n")){
				if (line.strip().length == 0) { continue; }
				
				PartitionInfo pi = new PartitionInfo();
				
				pi.device = line.split(":")[0].strip();
				
				if (pi.device.length == 0) { continue; }
				
				//exclude unknown devices
				if (exclude_unknown){
					if (!(pi.device.has_prefix("/dev/sd") || pi.device.has_prefix("/dev/hd") || pi.device.has_prefix("/dev/mapper/"))) { 
						continue;
					}
				}
				
				//parse & populate fields ------------------
				
				rex = new Regex("""LABEL=\"([^\"]*)\"""");
				if (rex.match (line, 0, out match)){
					pi.label = match.fetch(1).strip();
				}
				
				rex = new Regex("""UUID=\"([^\"]*)\"""");
				if (rex.match (line, 0, out match)){
					pi.uuid = match.fetch(1).strip();
				}
				
				rex = new Regex("""TYPE=\"([^\"]*)\"""");
				if (rex.match (line, 0, out match)){
					pi.type = match.fetch(1).strip();
				}
				
				//check for duplicates - no need to match uuids
				bool found = false;
				foreach(PartitionInfo pm in list){
					if (pm.device == pi.device){
						//add mount points and continue
						foreach(string mount_point in pi.mount_point_list){
							if (!pm.mount_point_list.contains(mount_point)){
								pm.mount_point_list.add(mount_point);
							}
						}
						found = true;
						//don't break
					}
				}
				
				//add to list
				if (!found){
					list.add(pi);
				}
			}
		}
		catch(Error e){
	        log_error (e.message);
	    }

		return list;
	}

	public Gee.ArrayList<PartitionInfo?> get_all_partitions(bool exclude_unknown = true, bool get_usage = true){
		
		/* Returns list of mounted/unmounted, physical/logical partitions */
		
		var list = new Gee.ArrayList<PartitionInfo?>();

		// get initial list --------
		
		var list_blkid = get_partitions_using_blkid(exclude_unknown);
		
		foreach (PartitionInfo pi in list_blkid){
			list.add(pi);
		}
		
		// add more devices ----------

		var list_mount = get_mounted_partitions_using_mtab(exclude_unknown);
		
		foreach (PartitionInfo pm in list_mount){
			bool found = false;
			foreach (PartitionInfo pi in list){
				if ((pm.device == pi.device) ||
				((pm.uuid.length > 0) && (pm.uuid == pi.uuid))){
					//add more mount points
					foreach(string mount_point in pm.mount_point_list){
						if (!pi.mount_point_list.contains(mount_point)){
							pi.mount_point_list.add(mount_point);
						}
					}
					found = true;
					//don't break
				}
			}
			
			if(!found){
				list.add(pm);
			}
		}
		
		// get usage info -------------

		if (get_usage){
			
			var list_df = get_partition_usage(exclude_unknown);

			for(int k = 0; k < list.size; k++){
				PartitionInfo pi = list[k];
				foreach(PartitionInfo pm in list_df){
					if (pm.device == pi.device){
						pi.size_mb = pm.size_mb;
						pi.used_mb = pm.used_mb;
						pi.used_percent = pm.used_percent;
						
						foreach(string mount_point in pm.mount_point_list){
							if (!pi.mount_point_list.contains(mount_point)){
								pi.mount_point_list.add(mount_point);
							}
						}
					}
				}
			}
		}
		
		return list;
	}

	public PartitionInfo refresh_partition_usage_info(PartitionInfo pi){
		
		/* Updates and returns the given PartitionInfo object */

		string std_out = "";
		string std_err = "";
		
		int exit_code = execute_command_script_sync("df -T -BM \"" + pi.device + "\"| uniq -w 12", out std_out, out std_err);
		
		if (exit_code != 0){ 
			return pi; 
		}

		string[] lines = std_out.split("\n");

		int k = 1;
		if (lines.length == 3){
			foreach(string part in lines[1].split(" ")){
				
				if (part.strip().length == 0){ continue; }
				
				switch(k++){
					case 3:
						pi.size_mb = long.parse(part.strip().replace("M",""));
						break;
					case 4:
						pi.used_mb = long.parse(part.strip().replace("M",""));
						break;
					case 5:
						pi.available = part.strip();
						break;
					case 6:
						pi.used_percent = part.strip();
						break;
					default:
						//ignore
						break;
				}
			}
		}

		return pi;
	}


	public bool mount(string device, string mount_point, string mount_options = ""){
		
		/* Mounts specified device at specified mount point.
		   Other devices will be un-mounted from the mount point*/
		
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;
		File file;
		
		try{
			//check if mount point exists
			file = File.new_for_path(mount_point);
			if (!file.query_exists()){
				file.make_directory_with_parents();
			}

			//check if mounted
			bool mounted = false;
			foreach(PartitionInfo info in get_mounted_partitions_using_mtab()){

				if (info.mount_point_list.contains(mount_point) && info.device == device){
					//device is already mounted at mount point
					mounted = true;
					break;
				}
				else if (info.mount_point_list.contains(mount_point) && info.device != device){
					//another device is mounted at mount point - unmount it -------
					cmd = "umount \"%s\"".printf(mount_point);
					Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
					if (ret_val != 0){
						log_error ("Failed to unmount device '%s' from mount point '%s'".printf(info.device, mount_point));
						log_error (std_err);
						return false;
					}
					else{
						log_msg ("Unmounted device '%s' from mount point '%s'".printf(info.device, mount_point));
					}
				}
			}

			if (!mounted){
				//mount --------------
				if (mount_options.length > 0){
					cmd = "mount -o %s \"%s\" \"%s\"".printf(mount_options, device, mount_point);
				} 
				else{
					cmd = "mount \"%s\" \"%s\"".printf(device, mount_point);
				}

				Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
				if (ret_val != 0){
					log_error ("Failed to mount device '%s' at mount point '%s'".printf(device, mount_point));
					log_error (std_err);
					return false;
				}
				else{
					log_msg ("Mounted device '%s' at mount point '%s'".printf(device, mount_point));
				}
			}
		}
		catch(Error e){
			log_error (e.message);
			return false;
		}
		
		return true;
	}

	public bool unmount(string mount_point, bool force = true){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;
		
		bool mounted = false;
			
		//check if mounted
		foreach(PartitionInfo info in get_mounted_partitions_using_mtab()){
			if (info.mount_point_list.contains(mount_point)){
				mounted = true;
				break;
			}
		}
			
		if (!mounted) { return true; }
		
		try{
			string cmd_unmount = "cat /proc/mounts | awk '{print $2}' | grep '%s' | sort -r | xargs umount".printf(mount_point);
			
			log_msg(_("Unmounting from") + ": '%s'".printf(mount_point));
			
			//sync before unmount
			cmd = "sync";
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
			//ignore success/failure
			
			//unmount
			ret_val = execute_command_script_sync(cmd_unmount, out std_out, out std_err);
			
			if (ret_val != 0){
				
				log_error (_("Failed to unmount"));
				log_error (std_err);
				
				if (force){
					//check if any process is using the mount_point
					cmd = "fuser -m \"" + mount_point + "\"";
					string proc_list = execute_command_sync_get_output(cmd);
					
					if ((proc_list != null) && (proc_list.length > 0)){
						
						log_msg (_("Killing all processes using the mount-point..."));
						
						//kill the process
						cmd = "fuser -mk \"" + mount_point + "\"";
						Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
						
						if (ret_val != 0){
							log_error (_("Failed to kill process"));
							log_error (std_err);
						}
						else{

							//ok, try again
							ret_val = execute_command_script_sync(cmd_unmount, out std_out, out std_err);
							
							if (ret_val != 0){
								log_error (_("Failed to unmount"));
								log_error (std_err);
							}
							else{
								//log_msg (_("Unmounted"));
							}
						}
					}
				}
			}
			else{
				//log_msg (_("Unmounted"));
			}
		}
		catch(Error e){
			log_error (e.message);
			return false;
		}
		
		//check if unmounted
		mounted = false;
		foreach(PartitionInfo info in get_mounted_partitions_using_mtab()){
			if (info.mount_point_list.contains(mount_point)){
				mounted = true;
				break;
			}
		}
			
		return !mounted;
	}
	
	public Gee.ArrayList<DeviceInfo> get_block_devices(){
		
		/* Returns a list of all storage devices including vendor and model number */
		
		var device_list = new Gee.ArrayList<DeviceInfo>();
		
		string letters = "abcdefghijklmnopqrstuvwxyz";
		string letter = "";
		string path = "";
		string device = "";
		string model = "";
		string vendor = "";
		string removable = "";
		File f;
		
		for(int i=0; i<26; i++){
			letter = letters[i:i+1];

			path = "/sys/block/sd%s".printf(letter);
			f = File.new_for_path(path); 
			if (f.query_exists()){
				
				device = "";
				model = "";
				removable = "0";
				
				f = File.new_for_path(path + "/device/vendor"); 
				if (f.query_exists()){
					vendor = read_file(path + "/device/vendor");
				}
				
				f = File.new_for_path(path + "/device/model"); 
				if (f.query_exists()){
					model = read_file(path + "/device/model");
				}
				
				f = File.new_for_path(path + "/removable"); 
				if (f.query_exists()){
					removable = read_file(path + "/removable");
				}

				if ((vendor.length > 0) || (model.length > 0)){
					var dev = new DeviceInfo();
					dev.device = "/dev/sd%s".printf(letter);
					dev.vendor = vendor.strip();
					dev.model = model.strip();
					dev.removable = (removable == "0") ? false : true;
					device_list.add(dev);
				}
			}
		}
		
		return device_list;
	}
	
}

namespace TeeJee.JSON{
	
	using TeeJee.Logging;

	/* Convenience functions for reading and writing JSON files */
	
	public string json_get_string(Json.Object jobj, string member, string def_value){
		if (jobj.has_member(member)){
			return jobj.get_string_member(member);
		}
		else{
			log_error ("Member not found in JSON object: " + member, false, true);
			return def_value;
		}
	}
	
	public bool json_get_bool(Json.Object jobj, string member, bool def_value){
		if (jobj.has_member(member)){
			return bool.parse(jobj.get_string_member(member));
		}
		else{
			log_error ("Member not found in JSON object: " + member, false, true);
			return def_value;
		}
	}
	
	public int json_get_int(Json.Object jobj, string member, int def_value){
		if (jobj.has_member(member)){
			return int.parse(jobj.get_string_member(member));
		}
		else{
			log_error ("Member not found in JSON object: " + member, false, true);
			return def_value;
		}
	}
	
}

namespace TeeJee.ProcessManagement{
	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.Misc;
	
	public string TEMP_DIR;

	/* Convenience functions for executing commands and managing processes */
	
    public static void init_tmp(){
		string std_out, std_err;
		
		TEMP_DIR = Environment.get_tmp_dir() + "/" + AppShortName;
		create_dir(TEMP_DIR);

		execute_command_script_sync("echo 'ok'",out std_out,out std_err);
		if ((std_out == null)||(std_out.strip() != "ok")){
			TEMP_DIR = Environment.get_home_dir() + "/.temp/" + AppShortName;
			execute_command_sync("rm -rf '%s'".printf(TEMP_DIR));
			create_dir(TEMP_DIR);
		}
	}

	public int execute_command_sync (string cmd){
		
		/* Executes single command synchronously and returns exit code 
		 * Pipes and multiple commands are not supported */
		
		try {
			int exitCode;
			Process.spawn_command_line_sync(cmd, null, null, out exitCode);
	        return exitCode;
		}
		catch (Error e){
	        log_error (e.message);
	        return -1;
	    }
	}
	
	public string execute_command_sync_get_output (string cmd){
				
		/* Executes single command synchronously and returns std_out
		 * Pipes and multiple commands are not supported */
		
		try {
			int exitCode;
			string std_out;
			Process.spawn_command_line_sync(cmd, out std_out, null, out exitCode);
	        return std_out;
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}

	public bool execute_command_script_async (string cmd){
				
		/* Creates a temporary bash script with given commands and executes it asynchronously 
		 * Return value indicates if script was started successfully */
		
		try {
			
			string scriptfile = create_temp_bash_script (cmd);
			
			string[] argv = new string[1];
			argv[0] = scriptfile;
			
			Pid child_pid;
			Process.spawn_async_with_pipes(
			    null, //working dir
			    argv, //argv
			    null, //environment
			    SpawnFlags.SEARCH_PATH,
			    null,
			    out child_pid);
			return true;
		}
		catch (Error e){
	        log_error (e.message);
	        return false;
	    }
	}
	
	public string? create_temp_bash_script (string script_text){
				
		/* Creates a temporary bash script with given commands 
		 * Returns the script file path */
		
		var sh = "";
		sh += "#!/bin/bash\n";
		sh += script_text;

		string script_path = get_temp_file_path() + ".sh";

		if (write_file (script_path, sh)){  // create file
			chmod (script_path, "u+x");      // set execute permission
			return script_path;
		}
		else{
			return null;
		}
	}
	
	public string get_temp_file_path(){
				
		/* Generates temporary file path */
		
		return TEMP_DIR + "/" + timestamp2() + (new Rand()).next_int().to_string();
	}
	
	public int execute_command_script_sync (string script, out string std_out, out string std_err){
				
		/* Executes commands synchronously
		 * Returns exit code, output messages and error messages.
		 * Commands are written to a temporary bash script and executed. */
		
		string path = create_temp_bash_script(script);

		try {
			
			string[] argv = new string[1];
			argv[0] = path;
		
			int exit_code;
			
			Process.spawn_sync (
			    TEMP_DIR, //working dir
			    argv, //argv
			    null, //environment
			    SpawnFlags.SEARCH_PATH,
			    null,   // child_setup
			    out std_out,
			    out std_err,
			    out exit_code
			    );
			    
			return exit_code;
		}
		catch (Error e){
	        log_error (e.message);
	        return -1;
	    }
	}
	
	public bool execute_command_script_in_terminal_sync (string script){
				
		/* Executes a command script in a terminal window */
		//TODO: Remove this
		
		try {
			
			string[] argv = new string[3];
			argv[0] = "x-terminal-emulator";
			argv[1] = "-e";
			argv[2] = script;
		
			Process.spawn_sync (
			    TEMP_DIR, //working dir
			    argv, //argv
			    null, //environment
			    SpawnFlags.SEARCH_PATH,
			    null   // child_setup
			    );
			    
			return true;
		}
		catch (Error e){
	        log_error (e.message);
	        return false;
	    }
	}

	public int execute_bash_script_fullscreen_sync (string script_file){
			
		/* Executes a bash script synchronously.
		 * Script is executed in a fullscreen terminal window */
		
		string path;
		
		path = get_cmd_path ("xfce4-terminal");
		if ((path != null)&&(path != "")){
			return execute_command_sync ("xfce4-terminal --fullscreen -e \"%s\"".printf(script_file));
		}
		
		path = get_cmd_path ("gnome-terminal");
		if ((path != null)&&(path != "")){
			return execute_command_sync ("gnome-terminal --full-screen -e \"%s\"".printf(script_file));
		}
		
		path = get_cmd_path ("xterm");
		if ((path != null)&&(path != "")){
			return execute_command_sync ("xterm --fullscreen -e \"%s\"".printf(script_file));
		}
		
		//default terminal - unknown, normal window
		path = get_cmd_path ("x-terminal-emulator");
		if ((path != null)&&(path != "")){
			return execute_command_sync ("x-terminal-emulator -e \"%s\"".printf(script_file));
		}
		
		return -1;
	}
	
	public int execute_bash_script_sync (string script_file){
			
		/* Executes a bash script synchronously in the default terminal window */
		
		string path = get_cmd_path ("x-terminal-emulator");
		if ((path != null)&&(path != "")){
			return execute_command_sync ("x-terminal-emulator -e \"%s\"".printf(script_file));
		}
		
		return -1;
	}
	
	public string get_cmd_path (string cmd){
				
		/* Returns the full path to a command */
		
		try {
			int exitCode; 
			string stdout, stderr;
			Process.spawn_command_line_sync("which " + cmd, out stdout, out stderr, out exitCode);
	        return stdout;
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}

	public int get_pid_by_name (string name){
				
		/* Get the process ID for a process with given name */
		
		try{
			string output = "";
			Process.spawn_command_line_sync("pidof \"%s\"".printf(name), out output);
			if (output != null){
				string[] arr = output.split ("\n");
				if (arr.length > 0){
					return int.parse (arr[0]);
				}
			}
		} 
		catch (Error e) { 
			log_error (e.message); 
		}
		
		return -1;
	}
	
	public bool process_is_running(long pid){
				
		/* Checks if given process is running */
		
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;
		
		try{
			cmd = "ps --pid %ld".printf(pid);
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
		}
		catch (Error e) { 
			log_error (e.message); 
			return false;
		}
		
		return (ret_val == 0);
	}

	public int[] get_process_children (Pid parentPid){
				
		/* Returns the list of child processes spawned by given process */
		
		string output;
		
		try {
			Process.spawn_command_line_sync("ps --ppid %d".printf(parentPid), out output);
		}
		catch(Error e){
	        log_error (e.message);
	    }
			
		int pid;
		int[] procList = {};
		string[] arr;
		
		foreach (string line in output.split ("\n")){
			arr = line.strip().split (" ");
			if (arr.length < 1) { continue; }
			
			pid = 0;
			pid = int.parse (arr[0]);
			
			if (pid != 0){
				procList += pid;
			}
		}
		return procList;
	}
	
	
	public void process_kill(Pid process_pid, bool killChildren = true){
				
		/* Kills specified process and its children (optional) */
		
		int[] child_pids = get_process_children (process_pid);
		Posix.kill (process_pid, 15);
		
		if (killChildren){
			Pid childPid;
			foreach (long pid in child_pids){
				childPid = (Pid) pid;
				Posix.kill (childPid, 15);
			}
		}
	}
	
	public int process_pause (Pid procID){
				
		/* Pause/Freeze a process */
		
		return execute_command_sync ("kill -STOP %d".printf(procID));
	}
	
	public int process_resume (Pid procID){
				
		/* Resume/Un-freeze a process*/
		
		return execute_command_sync ("kill -CONT %d".printf(procID));
	}

	public void command_kill(string cmd_name, string cmd){
				
		/* Kills a specific command */

		string txt = execute_command_sync_get_output ("ps w -C %s".printf(cmd_name));
		//use 'ps ew -C conky' for all users
		
		string pid = "";
		foreach(string line in txt.split("\n")){
			if (line.index_of(cmd) != -1){
				pid = line.strip().split(" ")[0];
				Posix.kill ((Pid) int.parse(pid), 15);
				log_debug(_("Stopped") + ": [PID=" + pid + "] ");
			}
		}
	}
	
	
	public void process_set_priority (Pid procID, int prio){
				
		/* Set process priority */
		
		if (Posix.getpriority (Posix.PRIO_PROCESS, procID) != prio)
			Posix.setpriority (Posix.PRIO_PROCESS, procID, prio);
	}
	
	public int process_get_priority (Pid procID){
				
		/* Get process priority */
		
		return Posix.getpriority (Posix.PRIO_PROCESS, procID);
	}
	
	public void process_set_priority_normal (Pid procID){
				
		/* Set normal priority for process */
		
		process_set_priority (procID, 0);
	}
	
	public void process_set_priority_low (Pid procID){
				
		/* Set low priority for process */
		
		process_set_priority (procID, 5);
	}
	

	public bool user_is_admin (){
				
		/* Check if current application is running with admin priviledges */
		
		try{
			// create a process
			string[] argv = { "sleep", "10" };
			Pid procId;
			Process.spawn_async(null, argv, null, SpawnFlags.SEARCH_PATH, null, out procId); 
			
			// try changing the priority
			Posix.setpriority (Posix.PRIO_PROCESS, procId, -5);
			
			// check if priority was changed successfully
			if (Posix.getpriority (Posix.PRIO_PROCESS, procId) == -5)
				return true;
			else
				return false;
		} 
		catch (Error e) { 
			//log_error (e.message); 
			return false;
		}
	}

	public string get_user_login(){
		/* 
		Returns Login ID of current user.
		If running as 'sudo' it will return Login ID of the actual user.
		*/

		string cmd = "echo ${SUDO_USER:-$(whoami)}";
		string std_out;
		string std_err;
		int ret_val;
		ret_val = execute_command_script_sync(cmd, out std_out, out std_err);
		
		string user_name;
		if ((std_out == null) || (std_out.length == 0)){
			user_name = "root";
		}
		else{
			user_name = std_out.strip();
		}
		
		return user_name;
	}

	public int get_user_id(string user_login){
		/* 
		Returns UID of specified user.
		*/
		
		int uid = -1;
		string cmd = "id %s -u".printf(user_login);
		string txt = execute_command_sync_get_output(cmd);
		if ((txt != null) && (txt.length > 0)){
			uid = int.parse(txt);
		}
		
		return uid;
	}
	
	
	public string get_app_path (){
				
		/* Get path of current process */
		
		try{
			return GLib.FileUtils.read_link ("/proc/self/exe");	
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}
	
	public string get_app_dir (){
				
		/* Get parent directory of current process */
		
		try{
			return (File.new_for_path (GLib.FileUtils.read_link ("/proc/self/exe"))).get_parent ().get_path ();	
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}

}

namespace TeeJee.GtkHelper{
	
	using Gtk;
	
	public void gtk_do_events (){
				
		/* Do pending events */
		
		while(Gtk.events_pending ())
			Gtk.main_iteration ();
	}

	public void gtk_set_busy (bool busy, Gtk.Window win) {
				
		/* Show or hide busy cursor on window */
		
		Gdk.Cursor? cursor = null;

		if (busy){
			cursor = new Gdk.Cursor(Gdk.CursorType.WATCH);
		}
		else{
			cursor = new Gdk.Cursor(Gdk.CursorType.ARROW);
		}
		
		var window = win.get_window ();
		
		if (window != null) {
			window.set_cursor (cursor);
		}
		
		gtk_do_events ();
	}
	
	public void gtk_messagebox(string title, string message, Gtk.Window? parent_win, bool is_error = false){
				
		/* Shows a simple message box */

		Gtk.MessageType type = Gtk.MessageType.INFO;
		if (is_error){
			type = Gtk.MessageType.ERROR;
		}
		else{
			type = Gtk.MessageType.INFO;
		}
		
		var dlg = new Gtk.MessageDialog.with_markup(null, Gtk.DialogFlags.MODAL, type, Gtk.ButtonsType.OK, message);
		dlg.title = title;
		dlg.set_default_size (200, -1);
		if (parent_win != null){
			dlg.set_transient_for(parent_win);
			dlg.set_modal(true);
		}
		dlg.run();
		dlg.destroy();
	}
	
	public bool gtk_combobox_set_value (ComboBox combo, int index, string val){
		
		/* Conveniance function to set combobox value */
		
		TreeIter iter;
		string comboVal;
		TreeModel model = (TreeModel) combo.model;
		
		bool iterExists = model.get_iter_first (out iter);
		while (iterExists){
			model.get(iter, 1, out comboVal);
			if (comboVal == val){
				combo.set_active_iter(iter);
				return true;
			}
			iterExists = model.iter_next (ref iter);
		} 
		
		return false;
	}
	
	public string gtk_combobox_get_value (ComboBox combo, int index, string default_value){
		
		/* Conveniance function to get combobox value */
		
		if (combo.model == null) { return default_value; }
		if (combo.active < 0) { return default_value; }
		
		TreeIter iter;
		string val = "";
		combo.get_active_iter (out iter);
		TreeModel model = (TreeModel) combo.model;
		model.get(iter, index, out val);
			
		return val;
	}

	public class CellRendererProgress2 : Gtk.CellRendererProgress{
		public override void render (Cairo.Context cr, Gtk.Widget widget, Gdk.Rectangle background_area, Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {
			if (text == "--") 
				return;
				
			int diff = (int) ((cell_area.height - height)/2);
			
			// Apply the new height into the bar, and center vertically:
			Gdk.Rectangle new_area = Gdk.Rectangle() ;
			new_area.x = cell_area.x;
			new_area.y = cell_area.y + diff;
			new_area.width = width - 5;
			new_area.height = height;
			
			base.render(cr, widget, background_area, new_area, flags);
		}
	} 
	
	public Gdk.Pixbuf? get_app_icon(int icon_size, string format = ".png"){
		var img_icon = get_shared_icon(AppShortName, AppShortName + format,icon_size,"pixmaps");
		if (img_icon != null){
			return img_icon.pixbuf;
		}
		else{
			return null;
		}
	}
	
	public Gtk.Image? get_shared_icon(string icon_name, string fallback_icon_file_name, int icon_size, string icon_directory = AppShortName + "/images"){
		Gdk.Pixbuf pix_icon = null;
		Gtk.Image img_icon = null;
		
		try {
			Gtk.IconTheme icon_theme = Gtk.IconTheme.get_default();
			pix_icon = icon_theme.load_icon (icon_name, icon_size, 0);
		} catch (Error e) {
			//log_error (e.message);
		}
		
		string fallback_icon_file_path = "/usr/share/%s/%s".printf(icon_directory, fallback_icon_file_name);
		
		if (pix_icon == null){ 
			try {
				pix_icon = new Gdk.Pixbuf.from_file_at_size (fallback_icon_file_path, icon_size, icon_size);
			} catch (Error e) {
				log_error (e.message);
			}
		}
		
		if (pix_icon == null){ 
			log_error (_("Missing Icon") + ": '%s', '%s'".printf(icon_name, fallback_icon_file_path));
		}
		else{
			img_icon = new Gtk.Image.from_pixbuf(pix_icon);
		}

		return img_icon; 
	}

}

namespace TeeJee.Multimedia{
	
	using TeeJee.Logging;
	
	/* Functions for working with audio/video files */
	
	public long get_file_duration(string filePath){
				
		/* Returns the duration of an audio/video file using MediaInfo */
		
		string output = "0";
		
		try {
			Process.spawn_command_line_sync("mediainfo \"--Inform=General;%Duration%\" \"" + filePath + "\"", out output);
		}
		catch(Error e){
	        log_error (e.message);
	    }
	    
		return long.parse(output);
	}
	
	public string get_file_crop_params (string filePath){
				
		/* Returns cropping parameters for a video file using avconv */
		
		string output = "";
		string error = "";
		
		try {
			Process.spawn_command_line_sync("avconv -i \"%s\" -vf cropdetect=30 -ss 5 -t 5 -f matroska -an -y /dev/null".printf(filePath), out output, out error);
		}
		catch(Error e){
	        log_error (e.message);
	    }
	    	    
	    int w=0,h=0,x=10000,y=10000;
		int num=0;
		string key,val;
	    string[] arr;
	    
	    foreach (string line in error.split ("\n")){
			if (line == null) { continue; }
			if (line.index_of ("crop=") == -1) { continue; }

			foreach (string part in line.split (" ")){
				if (part == null || part.length == 0) { continue; }
				
				arr = part.split (":");
				if (arr.length != 2) { continue; }
				
				key = arr[0].strip ();
				val = arr[1].strip ();
				
				switch (key){
					case "x":
						num = int.parse (arr[1]);
						if (num < x) { x = num; }
						break;
					case "y":
						num = int.parse (arr[1]);
						if (num < y) { y = num; }
						break;
					case "w":
						num = int.parse (arr[1]);
						if (num > w) { w = num; }
						break;
					case "h":
						num = int.parse (arr[1]);
						if (num > h) { h = num; }
						break;
				}
			}
		}
		
		if (x == 10000 || y == 10000)
			return "%i:%i:%i:%i".printf(0,0,0,0);
		else 
			return "%i:%i:%i:%i".printf(w,h,x,y);
	}
	
	public string get_mediainfo (string filePath){
				
		/* Returns the multimedia properties of an audio/video file using MediaInfo */
		
		string output = "";
		
		try {
			Process.spawn_command_line_sync("mediainfo \"%s\"".printf(filePath), out output);
		}
		catch(Error e){
	        log_error (e.message);
	    }
	    
		return output;
	}
	
	

}

namespace TeeJee.System{
	
	using TeeJee.ProcessManagement;
	using TeeJee.Logging;

	public double get_system_uptime_seconds(){
				
		/* Returns the system up-time in seconds */
		
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;
		
		try{
			cmd = "cat /proc/uptime";
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
			string uptime = std_out.split(" ")[0];
			double secs = double.parse(uptime);
			return secs;
		}
		catch(Error e){
			log_error (e.message);
			return 0;
		}
	}
	
	public string get_desktop_name(){
				
		/* Return the names of the current Desktop environment */
		
		int pid = -1;
		
		pid = get_pid_by_name("cinnamon");
		if (pid > 0){
			return "Cinnamon";
		}
		
		pid = get_pid_by_name("xfdesktop");
		if (pid > 0){
			return "Xfce";
		}

		pid = get_pid_by_name("lxsession");
		if (pid > 0){
			return "LXDE";
		}

		pid = get_pid_by_name("gnome-shell");
		if (pid > 0){
			return "Gnome";
		}
		
		pid = get_pid_by_name("wingpanel");
		if (pid > 0){
			return "Elementary";
		}
		
		pid = get_pid_by_name("unity-panel-service");
		if (pid > 0){
			return "Unity";
		}

		pid = get_pid_by_name("plasma-desktop");
		if (pid > 0){
			return "KDE";
		}
		
		return "Unknown";
	}

	public bool check_internet_connectivity(){
		int exit_code = -1;
		string std_err;
		string std_out;

		try {
			string cmd = "ping -c 1 google.com";
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out exit_code);
		}
		catch (Error e){
	        log_error (e.message);
	    }
		
	    return (exit_code == 0);
	}
	
	public bool shutdown (){
				
		/* Shutdown the system immediately */
		
		try{
			string[] argv = { "shutdown", "-h", "now" };
			Pid procId;
			Process.spawn_async(null, argv, null, SpawnFlags.SEARCH_PATH, null, out procId); 
			return true;
		} 
		catch (Error e) { 
			log_error (e.message); 
			return false;
		}
	}

	public bool xdg_open (string file){
		string path;
		path = get_cmd_path ("xdg-open");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("xdg-open \"" + file + "\"");
		}
		return false;
	}
	
	public bool exo_open_folder (string dir_path, bool xdg_open_try_first = true){
				
		/* Tries to open the given directory in a file manager */

		/*
		xdg-open is a desktop-independent tool for configuring the default applications of a user.
		Inside a desktop environment (e.g. GNOME, KDE, Xfce), xdg-open simply passes the arguments 
		to that desktop environment's file-opener application (gvfs-open, kde-open, exo-open, respectively).
		We will first try using xdg-open and then check for specific file managers if it fails. 
		*/
		
		string path;
		
		if (xdg_open_try_first){
			//try using xdg-open
			path = get_cmd_path ("xdg-open");
			if ((path != null)&&(path != "")){
				return execute_command_script_async ("xdg-open \"" + dir_path + "\"");
			}
		}
		
		path = get_cmd_path ("nemo");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("nemo \"" + dir_path + "\"");
		}
		
		path = get_cmd_path ("nautilus");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("nautilus \"" + dir_path + "\"");
		}
		
		path = get_cmd_path ("thunar");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("thunar \"" + dir_path + "\"");
		}

		path = get_cmd_path ("pantheon-files");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("pantheon-files \"" + dir_path + "\"");
		}
		
		path = get_cmd_path ("marlin");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("marlin \"" + dir_path + "\"");
		}

		if (xdg_open_try_first == false){
			//try using xdg-open
			path = get_cmd_path ("xdg-open");
			if ((path != null)&&(path != "")){
				return execute_command_script_async ("xdg-open \"" + dir_path + "\"");
			}
		}
		
		return false;
	}

	public bool exo_open_textfile (string txt){
				
		/* Tries to open the given text file in a text editor */
		
		string path;
		
		path = get_cmd_path ("exo-open");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("exo-open \"" + txt + "\"");
		}

		path = get_cmd_path ("gedit");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("gedit --new-document \"" + txt + "\"");
		}

		return false;
	}

	public bool exo_open_url (string url){
				
		/* Tries to open the given text file in a text editor */
		
		string path;
		
		path = get_cmd_path ("exo-open");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("exo-open \"" + url + "\"");
		}

		path = get_cmd_path ("firefox");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("firefox \"" + url + "\"");
		}

		path = get_cmd_path ("chromium-browser");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("chromium-browser \"" + url + "\"");
		}
		
		return false;
	}
	
	private DateTime dt_last_notification = null;
	private const int NOTIFICATION_INTERVAL = 3;
	
	public int notify_send (string title, string message, int durationMillis, string urgency, string dialog_type = "info"){
				
		/* Displays notification bubble on the desktop */

		int retVal = 0;
		
		switch (dialog_type){
			case "error":
			case "info":
			case "warning":
				//ok
				break;
			default:
				dialog_type = "info";
				break;
		}
		
		long seconds = 9999;
		if (dt_last_notification != null){
			DateTime dt_end = new DateTime.now_local();
			TimeSpan elapsed = dt_end.difference(dt_last_notification);
			seconds = (long)(elapsed * 1.0 / TimeSpan.SECOND);
		}
	
		if (seconds > NOTIFICATION_INTERVAL){
			string s = "notify-send -t %d -u %s -i %s \"%s\" \"%s\"".printf(durationMillis, urgency, "gtk-dialog-" + dialog_type, title, message);
			retVal = execute_command_sync (s);
			dt_last_notification = new DateTime.now_local();
		}

		return retVal;
	}
	
	public bool set_directory_ownership(string dir_name, string login_name){
		try {
			string cmd = "chown %s -R %s".printf(login_name, dir_name);
			int exit_code;
			Process.spawn_command_line_sync(cmd, null, null, out exit_code);
			
			if (exit_code == 0){
				//log_msg(_("Ownership changed to '%s' for files in directory '%s'").printf(login_name, dir_name));
				return true;
			}
			else{
				log_error(_("Failed to set ownership") + ": %s, %s".printf(login_name, dir_name));
				return false;
			}
		}
		catch (Error e){
			log_error (e.message);
			return false;
		}
	}
	
	public bool crontab_remove(string line){
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;
		
		cmd = "crontab -l | sed '/%s/d' | crontab -".printf(line);
		ret_val = execute_command_script_sync(cmd, out std_out, out std_err);
		
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
			write_file(temp_file, crontab);

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
}

namespace TeeJee.Misc {
	
	/* Various utility functions */
	
	using Gtk;
	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.ProcessManagement;
	
	public class DistInfo : GLib.Object{
				
		/* Class for storing information about linux distribution */
		
		public string dist_id = "";
		public string description = "";
		public string release = "";
		public string codename = "";
		
		public DistInfo(){
			dist_id = "";
			description = "";
			release = "";
			codename = "";
		}
		
		public string full_name(){
			if (dist_id == ""){
				return "";
			}
			else{
				string val = "";
				val += dist_id;
				val += (release.length > 0) ? " " + release : "";
				val += (codename.length > 0) ? " (" + codename + ")" : "";
				return val;
			}
		}
		
		public static DistInfo get_dist_info(string root_path){
				
			/* Returns information about the Linux distribution 
			 * installed at the given root path */
		
			DistInfo info = new DistInfo();
			
			string dist_file = root_path + "/etc/lsb-release";
			var f = File.new_for_path(dist_file);
			if (f.query_exists()){

				/*
					DISTRIB_ID=Ubuntu
					DISTRIB_RELEASE=13.04
					DISTRIB_CODENAME=raring
					DISTRIB_DESCRIPTION="Ubuntu 13.04"
				*/
				
				foreach(string line in read_file(dist_file).split("\n")){
					
					if (line.split("=").length != 2){ continue; }
					
					string key = line.split("=")[0].strip();
					string val = line.split("=")[1].strip();
					
					if (val.has_prefix("\"")){
						val = val[1:val.length];
					}
					
					if (val.has_suffix("\"")){
						val = val[0:val.length-1];
					}
					
					switch (key){
						case "DISTRIB_ID":
							info.dist_id = val;
							break;
						case "DISTRIB_RELEASE":
							info.release = val;
							break;
						case "DISTRIB_CODENAME":
							info.codename = val;
							break;
						case "DISTRIB_DESCRIPTION":
							info.description = val;
							break;
					}
				}
			}
			else{
				
				dist_file = root_path + "/etc/os-release";
				f = File.new_for_path(dist_file);
				if (f.query_exists()){
					
					/*
						NAME="Ubuntu"
						VERSION="13.04, Raring Ringtail"
						ID=ubuntu
						ID_LIKE=debian
						PRETTY_NAME="Ubuntu 13.04"
						VERSION_ID="13.04"
						HOME_URL="http://www.ubuntu.com/"
						SUPPORT_URL="http://help.ubuntu.com/"
						BUG_REPORT_URL="http://bugs.launchpad.net/ubuntu/"
					*/
					
					foreach(string line in read_file(dist_file).split("\n")){
					
						if (line.split("=").length != 2){ continue; }
						
						string key = line.split("=")[0].strip();
						string val = line.split("=")[1].strip();
						
						switch (key){
							case "ID":
								info.dist_id = val;
								break;
							case "VERSION_ID":
								info.release = val;
								break;
							//case "DISTRIB_CODENAME":
								//info.codename = val;
								//break;
							case "PRETTY_NAME":
								info.description = val;
								break;
						}
					}
				}
			}

			return info;
		}
		
	}

	public static Gdk.RGBA hex_to_rgba (string hex_color){
				
		/* Converts the color in hex to RGBA */
		
		string hex = hex_color.strip().down();
		if (hex.has_prefix("#") == false){
			hex = "#" + hex;
		}
		
		Gdk.RGBA color = Gdk.RGBA();
		if(color.parse(hex) == false){
			color.parse("#000000");
		}
		color.alpha = 255;
		
		return color;
	}
	
	public static string rgba_to_hex (Gdk.RGBA color, bool alpha = false, bool prefix_hash = true){
				
		/* Converts the color in RGBA to hex */
		
		string hex = "";
		
		if (alpha){
			hex = "%02x%02x%02x%02x".printf((uint)(Math.round(color.red*255)),
									(uint)(Math.round(color.green*255)),
									(uint)(Math.round(color.blue*255)),
									(uint)(Math.round(color.alpha*255)))
									.up();
		}
		else {														
			hex = "%02x%02x%02x".printf((uint)(Math.round(color.red*255)),
									(uint)(Math.round(color.green*255)),
									(uint)(Math.round(color.blue*255)))
									.up();
		}	
		
		if (prefix_hash){
			hex = "#" + hex;
		}	
		
		return hex;													
	}

	public string timestamp2 (){
				
		/* Returns a numeric timestamp string */
		
		return "%ld".printf((long) time_t ());
	}
	
	public string timestamp (){	
			
		/* Returns a formatted timestamp string */
		
		Time t = Time.local (time_t ());
		return t.format ("%H:%M:%S");
	}

	public string timestamp3 (){	
			
		/* Returns a formatted timestamp string */
		
		Time t = Time.local (time_t ());
		return t.format ("%Y-%d-%m_%H-%M-%S");
	}
	
	public string format_file_size (int64 size){
				
		/* Format file size in MB */
		
		return "%0.1f MB".printf (size / (1024.0 * 1024));
	}
	
	public string format_duration (long millis){
				
		/* Converts time in milliseconds to format '00:00:00.0' */
		
	    double time = millis / 1000.0; // time in seconds

	    double hr = Math.floor(time / (60.0 * 60));
	    time = time - (hr * 60 * 60);
	    double min = Math.floor(time / 60.0);
	    time = time - (min * 60);
	    double sec = Math.floor(time);
	    
        return "%02.0lf:%02.0lf:%02.0lf".printf (hr, min, sec);
	}
	
	public double parse_time (string time){
				
		/* Converts time in format '00:00:00.0' to milliseconds */
		
		string[] arr = time.split (":");
		double millis = 0;
		if (arr.length >= 3){
			millis += double.parse(arr[0]) * 60 * 60;
			millis += double.parse(arr[1]) * 60;
			millis += double.parse(arr[2]);
		}
		return millis;
	}
	
	public string escape_html(string html){
		return html
		.replace("&","&amp;")
		.replace("\"","&quot;")
		//.replace(" ","&nbsp;") //pango markup throws an error with &nbsp;
		.replace("<","&lt;")
		.replace(">","&gt;")
		;
	}
	
	public string unescape_html(string html){
		return html
		.replace("&amp;","&")
		.replace("&quot;","\"")
		//.replace("&nbsp;"," ") //pango markup throws an error with &nbsp;
		.replace("&lt;","<")
		.replace("&gt;",">")
		;
	}
}

