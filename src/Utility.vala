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

/*
using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.DiskPartition;
using TeeJee.JSON;
using TeeJee.ProcessManagement;
using TeeJee.GtkHelper;
using TeeJee.Multimedia;
using TeeJee.System;
using TeeJee.Misc;

extern void exit(int exit_code);

public static int main (string[] args) {
	return 0;
}
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
		else{
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
		public string mount_point = "";
		public string dist_info = "";
		
		public string description(){
			string s = "";
			s += device;
			s += (type.length > 0) ? " ~ " + type : "";
			s += (used.length > 0) ? " ~ " + used + " / " + size + " used (" + used_percent + ")" : "";
			return s;
		}
		
		public string description_device(){
			string s = "";
			s += device;
			s += (uuid.length == 0) ? "" : ", UUID=" + uuid;
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
				return (size_mb == 0) ? "" : "%.1f GB".printf(size_mb/1024.0);
			}
		}
		
		public string used{
			owned get{
				return (used_mb == 0) ? "" : "%.1f GB".printf(used_mb/1024.0);
			}
		}
		
		public long free_mb{
			get{
				return (size_mb - used_mb);
			}
		}
		
		public bool is_mounted{
			get{
				return (mount_point.length > 0);
			}
		}
		
		public string free{
			owned get{
				return (free_mb == 0) ? "" : "%.1f GB".printf(free_mb/1024.0);
			}
		}

		public string partition_name{
			owned get{
				return device[5:device.length];
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

	public PartitionInfo get_partition_info(string path){
		
		/* Returns partition info for specified path or device name */

		PartitionInfo info = new PartitionInfo();
		
		string std_out = "";
		string std_err = "";
		int exit_code = execute_command_script_sync("df -T -BM \"" + path + "\"| uniq -w 12", out std_out, out std_err);
		if (exit_code != 0){ return info; }

		string[] lines = std_out.split("\n");

		int k = 1;
		if (lines.length == 3){
			foreach(string part in lines[1].split(" ")){
				
				if (part.strip().length == 0){ continue; }
				
				switch(k++){
					case 1:
						info.device = part.strip();
						break;
					case 2:
						info.type = part.strip();
						break;
					case 3:
						info.size_mb = long.parse(part.strip().replace("M",""));
						break;
					case 4:
						info.used_mb = long.parse(part.strip().replace("M",""));
						break;
					case 5:
						info.available = part.strip();
						break;
					case 6:
						info.used_percent = part.strip();
						break;
					case 7:
						info.mount_point = part.strip();
						break;
				}
			}
		}

		foreach(PartitionInfo pi in get_all_partitions()){
			if (pi.device == info.device){
				info.label = pi.label;
				info.uuid = pi.uuid;
				break;
			}
		}
		
		return info;
	}

	public Gee.ArrayList<PartitionInfo?> get_mounted_partitions(){
		
		/* Returns list of mounted partitions */
		 
		var list = new Gee.ArrayList<PartitionInfo?>();
		
		string std_out = "";
		string std_err = "";
		int exit_code = execute_command_script_sync("df -T -BM", out std_out, out std_err);// | uniq -w 12
		
		if (exit_code != 0){ return list; }
		
		string[] lines = std_out.split("\n");

		int line_num = 0;
		foreach(string line in lines){

			if (++line_num == 1) { continue; }
			if (line.strip().length == 0) { continue; }
			
			PartitionInfo info = new PartitionInfo();
			
			int k = 1;
			foreach(string part in line.split(" ")){
				
				if (part.strip().length == 0){ continue; }

				switch(k++){
					case 1:
						info.device = part.strip();
						break;
					case 2:
						info.type = part.strip();
						break;
					case 3:
						info.size_mb = long.parse(part.strip().replace("M",""));
						break;
					case 4:
						info.used_mb = long.parse(part.strip().replace("M",""));
						break;
					case 5:
						info.available = part.strip();
						break;
					case 6:
						info.used_percent = part.strip();
						break;
					case 7:
						info.mount_point = part.strip();
						break;
				}
			}

			list.add(info);
		}
		
		return list;
	}
	
	public Gee.ArrayList<PartitionInfo?> get_all_partitions(){
		
		/* Returns list of mounted/unmounted, physical/LVM partitions */
		
		var list = new Gee.ArrayList<PartitionInfo?>();
		var list_mounted = get_mounted_partitions();
		
		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;
		Regex rex;
		MatchInfo match;
			
		try{
			
			cmd = "/sbin/blkid";
			ret_val = execute_command_script_sync(cmd, out std_out, out std_err);
			
			if (ret_val != 0){
				log_error ("Failed to get list of partitions");
				log_error (std_err);
				return list_mounted; //return list of mounted devices
			}

			foreach(string line in std_out.split("\n")){
				if (line.strip().length == 0) { continue; }
				
				PartitionInfo pi = new PartitionInfo();
				
				pi.device = line.split(":")[0].strip();
				
				if (pi.device.length == 0) { 
					continue; 
				}
				
				if (pi.device.has_prefix("/dev/sd") || pi.device.has_prefix("/dev/hd") || pi.device.has_prefix("/dev/mapper/")) { 
					//ok
				}
				else{
					continue; 
				}
				
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
				
				//get usage info 
				foreach(PartitionInfo pm in list_mounted){
					if (pm.device == pi.device){
						pi.size_mb = pm.size_mb;
						pi.used_mb = pm.used_mb;
						pi.used_percent = pm.used_percent;
						pi.mount_point = pm.mount_point;
					}
				}
				
				list.add(pi);
			}
		}
		catch(Error e){
	        log_error (e.message);
	    }

		return list;
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
			foreach(PartitionInfo info in get_mounted_partitions()){

				if (info.mount_point == mount_point && info.device == device){
					//device is already mounted at mount point
					mounted = true;
					break;
				}
				else if (info.mount_point == mount_point && info.device != device){
					//another device is mounted at mount point - unmount it -------
					cmd = "sudo umount \"%s\"".printf(mount_point);
					Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
					if (ret_val != 0){
						log_error ("Failed to unmount device '%s' from mount point '%s'".printf(info.device, info.mount_point));
						log_error (std_err);
						return false;
					}
					else{
						log_msg ("Unmounted device '%s' from mount point '%s'".printf(info.device, info.mount_point));
					}
				}
			}

			if (!mounted){
				//mount --------------
				if (mount_options.length > 0){
					cmd = "sudo mount -o %s \"%s\" \"%s\"".printf(mount_options, device, mount_point);
				} 
				else{
					cmd = "sudo mount \"%s\" \"%s\"".printf(device, mount_point);
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
		bool quit_app = false;
		
		try{
			//check if mounted and unmount
			foreach(PartitionInfo info in get_mounted_partitions()){
				if (info.mount_point == mount_point){
					
					log_msg(_("Unmounting device") + " '%s' ".printf(info.device) + _("from") + " '%s'".printf(info.mount_point));
					
					//sync before unmount
					cmd = "sync";
					Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
					//ignore success/failure
					
					//unmount
					cmd = "umount \"" + mount_point + "\"";
					Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
					
					if (ret_val != 0){
						
						log_error (_("Failed to unmount device"));
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
									quit_app = true;
								}
								else{

									//ok, try again
									cmd = "umount \"" + mount_point + "\"";
									Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
									
									if (ret_val != 0){
										log_error (_("Failed to unmount device") + " '%s' ".printf(info.device) + _("from") + " '%s'".printf(info.mount_point));
										log_error (std_err);
										quit_app = true;
									}
									else{
										log_msg (_("Device unmounted"));
									}
								}
							}
							else{
								quit_app = true;
							}
						}
					}
					else{
						log_msg (_("Device unmounted"));
					}
				}
			}
		}
		catch(Error e){
			log_error (e.message);
			return false;
		}
		
		return true;
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
	
	/* Convenience functions for executing commands and managing processes */

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
				
		/* Executes single command synchronously and returns console output 
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

	public bool execute_command_async (string cmd){
				
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
		
		return Environment.get_tmp_dir () + "/" + timestamp2() + (new Rand()).next_int().to_string();
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
			    Environment.get_tmp_dir (), //working dir
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
			    Environment.get_tmp_dir (), //working dir
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
			log_error (e.message); 
			return false;
		}
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
	
	public void gtk_messagebox_show(string title, string message, bool is_error = false){
				
		/* Conveniance function to show message box */
		
		Gtk.MessageType type = Gtk.MessageType.INFO;
		
		if (is_error)
			type = Gtk.MessageType.ERROR;
			
		var dialog = new Gtk.MessageDialog.with_markup(null,Gtk.DialogFlags.MODAL, type, Gtk.ButtonsType.OK, message);
		dialog.set_title(title);
		dialog.run();
		dialog.destroy();
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
		
		string s = execute_command_sync_get_output("ps -C xfdesktop");
		if (s.split("\n").length > 2) {
			return "Xfce";
		}
		
		s = execute_command_sync_get_output("ps -C wingpanel");
		if (s.split("\n").length > 2) {
			return "Elementary";
		}
		
		s = execute_command_sync_get_output("ps -C cinnamon");
		if (s.split("\n").length > 2) {
			return "Cinnamon";
		}
		
		s = execute_command_sync_get_output("ps -C unity-panel-service");
		if (s.split("\n").length > 2) {
			return "Unity";
		}
		
		return "Unknown";
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
	
	public bool exo_open_folder (string dir_path){
				
		/* Tries to open the given directory in a file manager */
		
		string path;
		
		path = get_cmd_path ("exo-open");
		if ((path != null)&&(path != "")){
			return execute_command_async ("exo-open \"" + dir_path + "\"");
		}

		path = get_cmd_path ("nemo");
		if ((path != null)&&(path != "")){
			return execute_command_async ("nemo \"" + dir_path + "\"");
		}
		
		path = get_cmd_path ("nautilus");
		if ((path != null)&&(path != "")){
			return execute_command_async ("nautilus \"" + dir_path + "\"");
		}
		
		path = get_cmd_path ("thunar");
		if ((path != null)&&(path != "")){
			return execute_command_async ("thunar \"" + dir_path + "\"");
		}

		return false;
	}

	public int exo_open_textfile (string txt){
				
		/* Tries to open the given text file in a text editor */
		
		string path;
		
		path = get_cmd_path ("exo-open");
		if ((path != null)&&(path != "")){
			return execute_command_sync ("exo-open \"" + txt + "\"");
		}

		path = get_cmd_path ("gedit");
		if ((path != null)&&(path != "")){
			return execute_command_sync ("gedit --new-document \"" + txt + "\"");
		}

		return -1;
	}

	public int notify_send (string title, string message, int durationMillis, string urgency){
				
		/* Displays notification bubble on the desktop */
		
		string s = "notify-send -t %d -u %s -i %s \"%s\" \"%s\"".printf(durationMillis, urgency, Gtk.Stock.INFO, title, message);
		return execute_command_sync (s);
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
}

