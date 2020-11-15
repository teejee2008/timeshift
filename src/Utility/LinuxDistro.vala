
/*
 * LinuxDistro.vala
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

public class LinuxDistro : GLib.Object{

	/* Class for storing information about Linux distribution */

	public string dist_id = "";
	public string description = "";
	public string release = "";
	public string codename = "";

	public LinuxDistro(){
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

	public static LinuxDistro get_dist_info(string root_path){

		/* Returns information about the Linux distribution
		 * installed at the given root path */

		LinuxDistro info = new LinuxDistro();

		string dist_file = root_path + "/etc/lsb-release";
		var f = File.new_for_path(dist_file);
		if (f.query_exists()){

			/*
				DISTRIB_ID=Ubuntu
				DISTRIB_RELEASE=13.04
				DISTRIB_CODENAME=raring
				DISTRIB_DESCRIPTION="Ubuntu 13.04"
			*/

			foreach(string line in file_read(dist_file).split("\n")){

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

				foreach(string line in file_read(dist_file).split("\n")){

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

	public static string get_running_desktop_name(){

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

	public string dist_type {
		
		owned get{
			
			if (dist_id == "fedora"){
				return "redhat";
			}
			else if (dist_id.down().contains("manjaro") || dist_id.down().contains("arch")){
				return "arch";
			}
			else if (dist_id.down().contains("ubuntu") || dist_id.down().contains("debian")){
				return "debian";
			}
			else{
				return "";
			}

		}
	}
}


