
/*
 * SystemUser.vala
 *
 * Copyright 2017 Tony George <teejeetech@gmail.com>
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

	//public string
	public string shadow_line = "";
	public string pwd_hash = "";
	public string pwd_last_changed = "";
	public string pwd_age_min = "";
	public string pwd_age_max = "";
	public string pwd_warning_period = "";
	public string pwd_inactivity_period = "";
	public string pwd_expiraton_date = "";
	public string reserved_field = "";

	public bool has_encrypted_home = false;
	public bool has_encrypted_private_dirs = false;
	public Gee.ArrayList<string> encrypted_dirs = new Gee.ArrayList<string>();
	public Gee.ArrayList<string> encrypted_private_dirs = new Gee.ArrayList<string>();
	
	public bool is_selected = false;

	public static Gee.HashMap<string,SystemUser> all_users;

	public SystemUser(string name){
		this.name = name;
	}

	public static void query_users(bool no_passwords = true){
		if (no_passwords){
			all_users = read_users_from_file("/etc/passwd","","");
		}
		else{
			all_users = read_users_from_file("/etc/passwd","/etc/shadow","");
		}
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

	public bool is_installed{
		get {
			return SystemUser.all_users.has_key(name);
		}
	}

	public static Gee.HashMap<string,SystemUser> read_users_from_file(
		string passwd_file, string shadow_file, string password){
		
		var list = new Gee.HashMap<string,SystemUser>();

		// read 'passwd' file ---------------------------------
		
		string txt = "";

		if (passwd_file.has_suffix(".tar.gpg")){
			txt = file_decrypt_untar_read(passwd_file, password);
		}
		else{
			txt = file_read(passwd_file);
		}

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

		if (shadow_file.length == 0){
			return list;
		}

		// read 'shadow' file ---------------------------------
		
		txt = "";
		
		if (shadow_file.has_suffix(".tar.gpg")){
			txt = file_decrypt_untar_read(shadow_file, password);
		}
		else{
			txt = file_read(shadow_file);
		}

		if (txt.length == 0){
			return list;
		}

		foreach(string line in txt.split("\n")){
			if ((line == null) || (line.length == 0)){
				continue;
			}
			parse_line_shadow(line, list);
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

	private static SystemUser? parse_line_shadow(string line, Gee.HashMap<string,SystemUser> list){
		if ((line == null) || (line.length == 0)){
			return null;
		}
		
		SystemUser user = null;

		//root:$1$Etg2ExUZ$F9NTP7omafhKIlqaBMqng1:15651:0:99999:7:::
		//<username>:$<hash-algo>$<salt>$<hash>:<last-changed>:<change-interval-min>:<change-interval-max>:<change-warning-interval>:<disable-expired-account-after-days>:<days-since-account-disbaled>:<not-used>

		string[] fields = line.split(":");

		if (fields.length == 9){
			string user_name = fields[0].strip();
			if (list.has_key(user_name)){
				user = list[user_name];
				user.shadow_line = line;
				user.pwd_hash = fields[1].strip();
				user.pwd_last_changed = fields[2].strip();
				user.pwd_age_min = fields[3].strip();
				user.pwd_age_max = fields[4].strip();
				user.pwd_warning_period = fields[5].strip();
				user.pwd_inactivity_period = fields[6].strip();
				user.pwd_expiraton_date = fields[7].strip();
				user.reserved_field = fields[8].strip();
				return user;
			}
			else{
				log_error("user in file 'shadow' does not exist in file 'passwd'" + ": %s".printf(user_name));
				return null;
			}
		}
		else{
			log_error("'shadow' file contains a record with non-standard fields" + ": %d".printf(fields.length));
			return null;
		}
	}

	public static int add_user(string user_name, bool system_account = false){
		string std_out, std_err;
		string cmd = "adduser%s --gecos '' --disabled-login %s".printf((system_account ? " --system" : ""), user_name);
		log_debug(cmd);
		int status = exec_sync(cmd, out std_out, out std_err);
		if (status != 0){
			log_error(std_err);
		}
		else{
			//log_msg(std_out);
		}
		return status;
	}

	public int add(){
		return add_user(name, is_system);
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

	public bool update_passwd_file(){
		string file_path = "/etc/passwd";
		string txt = file_read(file_path);
		
		var txt_new = "";
		foreach(string line in txt.split("\n")){
			if (line.strip().length == 0) {
				continue;
			}
			
			string[] parts = line.split(":");

			if (parts.length != 7){
				log_error("'passwd' file contains a record with non-standard fields" + ": %d".printf(parts.length));
				return false;
			}
			
			if (parts[0].strip() == name){
				txt_new += get_passwd_line() + "\n";
			}
			else{
				txt_new += line + "\n";
			}
		}

		file_write(file_path, txt_new);
		
		log_msg("Updated user settings in /etc/passwd" + ": %s".printf(name));
		
		return true;
	}

	public string get_passwd_line(){
		string txt = "";
		txt += "%s".printf(name);
		txt += ":%s".printf(password);
		txt += ":%d".printf(uid);
		txt += ":%d".printf(gid);
		txt += ":%s".printf(user_info);
		txt += ":%s".printf(home_path);
		txt += ":%s".printf(shell_path);
		return txt;
	}
	
	public bool update_shadow_file(){
		string file_path = "/etc/shadow";
		string txt = file_read(file_path);
		
		var txt_new = "";
		foreach(string line in txt.split("\n")){
			if (line.strip().length == 0) {
				continue;
			}
			
			string[] parts = line.split(":");

			if (parts.length != 9){
				log_error("'shadow' file contains a record with non-standard fields" + ": %d".printf(parts.length));
				return false;
			}
			
			if (parts[0].strip() == name){
				txt_new += get_shadow_line() + "\n";
			}
			else{
				txt_new += line + "\n";
			}
		}

		file_write(file_path, txt_new);
		
		log_msg("Updated user settings in /etc/shadow" + ": %s".printf(name));
		
		return true;
	}

	public string get_shadow_line(){
		string txt = "";
		txt += "%s".printf(name);
		txt += ":%s".printf(pwd_hash);
		txt += ":%s".printf(pwd_last_changed);
		txt += ":%s".printf(pwd_age_min);
		txt += ":%s".printf(pwd_age_max);
		txt += ":%s".printf(pwd_warning_period);
		txt += ":%s".printf(pwd_inactivity_period);
		txt += ":%s".printf(pwd_expiraton_date);
		txt += ":%s".printf(reserved_field);
		return txt;
	}
}

