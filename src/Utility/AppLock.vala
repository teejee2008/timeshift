
/*
 * AppLock.vala
 *
 * Copyright 2012-17 Tony George <teejeetech@gmail.com>
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
using TeeJee.Misc;
 
public class AppLock : GLib.Object {
	public string lock_file = "";
	public string lock_message = "";
	
	public bool create(string app_name, string message){

		var lock_dir = "/var/run/lock/%s".printf(app_name);
		dir_create(lock_dir);
		lock_file = path_combine(lock_dir, "lock");
		
		try{
			var file = File.new_for_path(lock_file);
			if (file.query_exists()) {

				string txt = file_read(lock_file);
				string process_id = txt.split(";")[0].strip();
				lock_message = txt.split(";")[1].strip();
				long pid = long.parse(process_id);

				if (process_is_running(pid)){
					log_msg(_("Another instance of this application is running")
						+ " (PID=%ld)".printf(pid));
					return false;
				}
				else{
					log_msg(_("[Warning] Deleted invalid lock"));
					file.delete();
					write_lock_file(message);
					return true;
				}
			}
			else{
				write_lock_file(message);
				return true;
			}
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}
	}

	private void write_lock_file(string message){
		string current_pid = ((long) Posix.getpid()).to_string();
		file_write(lock_file, "%s;%s".printf(current_pid, message));
	}
	
	public void remove(){
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

}
