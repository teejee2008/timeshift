
/*
 * SystemUser.vala
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
using TeeJee.ProcessHelper;

public class SystemUser : GLib.Object {
	
	public string name = "";
	public string password = "";
	public int uid = -1;
	public int gid = -1;
	public string user_info = "";
	public string home_path = "";
	public string shell_path = "";

	public string full_name = "";
	public string room_num = "";
	public string phone_work = "";
	public string phone_home = "";
	public string other_info = "";

	public bool has_encrypted_home = false;
	public bool has_encrypted_private_dirs = false;
	public Gee.ArrayList<string> encrypted_dirs = new Gee.ArrayList<string>();
	public Gee.ArrayList<string> encrypted_private_dirs = new Gee.ArrayList<string>();
	
	public bool is_selected = false;

	public static Gee.HashMap<string,SystemUser> all_users;

	public SystemUser(string name){
		this.name = name;
	}

	public static void query_users(){
		
		all_users = read_users_from_file("/etc/passwd");
	}

	public static Gee.ArrayList<SystemUser> all_users_sorted {
		owned get {
			var list = new Gee.ArrayList<SystemUser>();
			foreach(var user in all_users.values) {
				list.add(user);
			}
			list.sort((a,b) => { return strcmp(a.name, b.name); });
			return list;
		}
	}

	public static Gee.HashMap<string,SystemUser> read_users_from_file(string passwd_file){
		
		var list = new Gee.HashMap<string,SystemUser>();

		// read 'passwd' file ---------------------------------
		
		string txt = file_read(passwd_file);

		if (txt.length == 0){
			return list;
		}

		foreach(string line in txt.split("\n")){
			if ((line == null) || (line.length == 0)){
				continue;
			}
			var user = parse_line_passwd(line);
			if (user != null){
				list[user.name] = user;
			}
		}

		return list;
	}

	private static SystemUser? parse_line_passwd(string line){
		
		if ((line == null) || (line.length == 0)){
			return null;
		}
		
		SystemUser user = null;

		//teejee:x:504:504:Tony George:/home/teejee:/bin/bash
		string[] fields = line.split(":");

		if (fields.length == 7){
			user = new SystemUser(fields[0].strip());
			user.password = fields[1].strip();
			user.uid = int.parse(fields[2].strip());
			user.gid = int.parse(fields[3].strip());
			user.user_info = fields[4].strip();
			user.home_path = fields[5].strip();
			user.shell_path = fields[6].strip();

			string[] arr = user.user_info.split(",");
			if (arr.length >= 1){
				user.full_name = arr[0];
			}
			if (arr.length >= 2){
				user.room_num = arr[1];
			}
			if (arr.length >= 3){
				user.phone_work = arr[2];
			}
			if (arr.length >= 4){
				user.phone_home = arr[3];
			}
			if (arr.length >= 5){
				user.other_info = arr[4];
			}

			user.check_encrypted_dirs();
		}
		else{
			log_error("'passwd' file contains a record with non-standard fields" + ": %d".printf(fields.length));
			return null;
		}
		
		return user;
	}

	public void check_encrypted_dirs() {

		// check encrypted home ------------------------------
		
		string ecryptfs_mount_file = "/home/.ecryptfs/%s/.ecryptfs/Private.mnt".printf(name);
		
		if (file_exists(ecryptfs_mount_file)){

			string txt = file_read(ecryptfs_mount_file);

			foreach(string line in txt.split("\n")){

				string path = line.strip();

				if (path.length == 0){ continue; }
				
				if (path == home_path){
					has_encrypted_home = true;
				}

				encrypted_dirs.add(path);
			}
		}

		// check encrypted Private dirs --------------------------

		ecryptfs_mount_file = "%s/.ecryptfs/Private.mnt".printf(home_path);
		
		if (file_exists(ecryptfs_mount_file)){

			string txt = file_read(ecryptfs_mount_file);

			foreach(string line in txt.split("\n")){

				string path = line.strip();

				if (path.length == 0){ continue; }
				
				if (path != home_path){
					has_encrypted_private_dirs = true;
					encrypted_private_dirs.add(path);
				}

				encrypted_dirs.add(path);
			}
		}
	}
	
	public bool is_system{
		get {
			return ((uid != 0) && (uid < 1000)) || (uid == 65534) || (name == "PinguyBuilder"); // 65534 - nobody
		}
	}

	public string group_names{
		owned get {
			return "";
		}
	}
}

