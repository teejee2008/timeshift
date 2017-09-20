
/*
 * SystemGroup.vala
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

public class SystemGroup : GLib.Object {
	public string name = "";
	public string password = "";
	public int gid = -1;
	public string user_names = "";

	public string shadow_line = "";
	public string password_hash = "";
	public string admin_list = "";
	public string member_list = "";

	public bool is_selected = false;
	public Gee.ArrayList<string> users;
	
	public static Gee.HashMap<string,SystemGroup> all_groups;

	public SystemGroup(string name){
		this.name = name;
		this.users = new Gee.ArrayList<string>();
	}

	public static void query_groups(bool no_passwords = true){
		if (no_passwords){
			all_groups = read_groups_from_file("/etc/group","","");
		}
		else{
			all_groups = read_groups_from_file("/etc/group","/etc/gshadow","");
		}
	}

	public static Gee.ArrayList<SystemGroup> all_groups_sorted {
		owned get {
			var list = new Gee.ArrayList<SystemGroup>();
			foreach(var group in all_groups.values) {
				list.add(group);
			}
			list.sort((a,b) => { return strcmp(a.name, b.name); });
			return list;
		}
	}
	
	public bool is_installed{
		get{
			return SystemGroup.all_groups.has_key(name);
		}
	}

	public static Gee.HashMap<string,SystemGroup> read_groups_from_file(string group_file, string gshadow_file, string password){
		var list = new Gee.HashMap<string,SystemGroup>();

		// read 'group' file -------------------------------
		
		string txt = "";
		
		if (group_file.has_suffix(".tar.gpg")){
			txt = file_decrypt_untar_read(group_file, password);
		}
		else{
			txt = file_read(group_file);
		}
		
		if (txt.length == 0){
			return list;
		}
		
		foreach(string line in txt.split("\n")){
			if ((line == null) || (line.length == 0)){
				continue;
			}
			
			var group = parse_line_group(line);
			if (group != null){
				list[group.name] = group;
			}
		}

		if (gshadow_file.length == 0){
			return list;
		}

		// read 'gshadow' file -------------------------------

		txt = "";
		
		if (gshadow_file.has_suffix(".tar.gpg")){
			txt = file_decrypt_untar_read(gshadow_file, password);
		}
		else{
			txt = file_read(gshadow_file);
		}
		
		if (txt.length == 0){
			return list;
		}
		
		foreach(string line in txt.split("\n")){
			if ((line == null) || (line.length == 0)){
				continue;
			}
			
			parse_line_gshadow(line, list);
		}

		return list;
	}

	private static SystemGroup? parse_line_group(string line){
		if ((line == null) || (line.length == 0)){
			return null;
		}
		
		SystemGroup group = null;

		//cdrom:x:24:teejee,user2
		string[] fields = line.split(":");

		if (fields.length == 4){
			group = new SystemGroup(fields[0].strip());
			group.password = fields[1].strip();
			group.gid = int.parse(fields[2].strip());
			group.user_names = fields[3].strip();
			foreach(string user_name in group.user_names.split(",")){
				group.users.add(user_name);
			}
		}
		else{
			log_error("'group' file contains a record with non-standard fields" + ": %d".printf(fields.length));
			return null;
		}
		
		return group;
	}

	private static SystemGroup? parse_line_gshadow(string line, Gee.HashMap<string,SystemGroup> list){
		if ((line == null) || (line.length == 0)){
			return null;
		}
		
		SystemGroup group = null;

		//adm:*::syslog,teejee
		//<groupname>:<encrypted-password>:<admins>:<members>
		string[] fields = line.split(":");

		if (fields.length == 4){
			string group_name = fields[0].strip();
			if (list.has_key(group_name)){
				group = list[group_name];
				group.shadow_line = line;
				group.password_hash = fields[1].strip();
				group.admin_list = fields[2].strip();
				group.member_list = fields[3].strip();
				return group;
			}
			else{
				log_error("group in file 'gshadow' does not exist in file 'group'" + ": %s".printf(group_name));
				return null;
			}
		}
		else{
			log_error("'gshadow' file contains a record with non-standard fields" + ": %d".printf(fields.length));
			return null;
		}
	}

	public static int add_group(string group_name, bool system_account = false){
		string std_out, std_err;
		string cmd = "groupadd%s %s".printf((system_account)? " --system" : "", group_name);
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
		return add_group(name,is_system);
	}

	public static int add_user_to_group(string user_name, string group_name){
		string std_out, std_err;
		string cmd = "adduser %s %s".printf(user_name, group_name);
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

	public int add_to_group(string user_name){
		return add_user_to_group(user_name, name);
	}
	
	public bool is_system{
		get {
			return (gid < 1000);
		}
	}

	public bool update_group_file(){
		string file_path = "/etc/group";
		string txt = file_read(file_path);
		
		var txt_new = "";
		foreach(string line in txt.split("\n")){
			if (line.strip().length == 0) {
				continue;
			}

			string[] parts = line.split(":");
			
			if (parts.length != 4){
				log_error("'group' file contains a record with non-standard fields" + ": %d".printf(parts.length));
				return false;
			}

			if (parts[0].strip() == name){
				txt_new += get_group_line() + "\n";
			}
			else{
				txt_new += line + "\n";
			}
		}

		file_write(file_path, txt_new);
		
		log_msg("Updated group settings in /etc/group" + ": %s".printf(name));
		
		return true;
	}

	public string get_group_line(){
		string txt = "";
		txt += "%s".printf(name);
		txt += ":%s".printf(password);
		txt += ":%d".printf(gid);
		txt += ":%s".printf(user_names);
		return txt;
	}

	public bool update_gshadow_file(){
		string file_path = "/etc/gshadow";
		string txt = file_read(file_path);
		
		var txt_new = "";
		foreach(string line in txt.split("\n")){
			if (line.strip().length == 0) {
				continue;
			}

			string[] parts = line.split(":");
			
			if (parts.length != 4){
				log_error("'gshadow' file contains a record with non-standard fields" + ": %d".printf(parts.length));
				return false;
			}

			if (parts[0].strip() == name){
				txt_new += get_gshadow_line() + "\n";
			}
			else{
				txt_new += line + "\n";
			}
		}

		file_write(file_path, txt_new);
		
		log_msg("Updated group settings in /etc/gshadow" + ": %s".printf(name));
		
		return true;
	}

	public string get_gshadow_line(){
		string txt = "";
		txt += "%s".printf(name);
		txt += ":%s".printf(password_hash);
		txt += ":%s".printf(admin_list);
		txt += ":%s".printf(member_list);
		return txt;
	}
}

