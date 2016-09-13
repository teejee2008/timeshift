
/*
 * TeeJee.Devices.vala
 *
 * Copyright 2016 Tony George <teejee2008@gmail.com>
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
 
namespace TeeJee.Devices{

	/* Functions and classes for handling disk partitions */

	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.ProcessHelper;

	public class Device : GLib.Object{

		/* Class for storing disk information */

		public static double KB = 1000;
		public static double MB = 1000 * KB;
		public static double GB = 1000 * MB;

		public static double KiB = 1024;
		public static double MiB = 1024 * KiB;
		public static double GiB = 1024 * MiB;
		
		//GUdev.Device udev_device;
		public string device = "";
		public string kname = "";
		public string pkname = "";
		public string name = "";
		public string mapped_name = "";
		
		public string type = ""; // disk, part, crypt, loop
		public string fstype = "";

		public string label = "";
		public string uuid = "";
		public int order = -1;
		
		public string vendor = "";
		public string model = "";
		public string serial = "";
		public string revision = "";

		public bool removable = false;
		public bool read_only = false;
		
		public int64 size_bytes = 0;
		public int64 used_bytes = 0;
		public int64 available_bytes = 0;
		
		public string used_percent = "";
		public string dist_info = "";
		public Gee.ArrayList<MountEntry> mount_points;
		public Gee.ArrayList<string> symlinks;

		public Device parent = null;
		public Gee.ArrayList<Device> children = null;

		private static Gee.ArrayList<Device> device_list;

		public static Bash bash_admin_shell = null;
		
		public Device(){
			mount_points = new Gee.ArrayList<MountEntry>();
			//mount_options = new Gee.ArrayList<string>();
			symlinks = new Gee.ArrayList<string>();
			children = new Gee.ArrayList<Device>();
		}

		/* Returns:
		 * 'sda3' for '/dev/sda3'
		 * 'luks' for '/dev/mapper/luks'
		 * */

		public string full_name_with_alias{
			owned get{
				string text = "";
				string symlink = "";
				foreach(string sym in symlinks){
					if (sym.has_prefix("/dev/mapper/")){
						symlink = sym;
					}
				}
				text = device + ((symlink.length > 0) ? " → " + symlink + "" : ""); //→
				if (type == "part"){
					return text;
				}
				else{
					return name;
				}
			}
		}

		public string short_name_with_alias{
			owned get{
				string text = "";
				string symlink = "";
				foreach(string sym in symlinks){
					if (sym.has_prefix("/dev/mapper/")){
						symlink = sym.replace("/dev/mapper/","").replace("/dev/","");
					}
				}

				if (symlink.length > 15){
					symlink = symlink[0:14] + "...";
				}
				text = device.replace("/dev/mapper/","") + ((symlink.length > 0) ? " (" + symlink + ")" : ""); //→
				return text;
			}
		}

		public string description(){
			return description_formatted().replace("<b>","").replace("</b>","");
		}

		public string description_formatted(){
			string s = "";

			if (type == "disk"){
				s += "<b>" + kname + "</b> ~";
				if (vendor.length > 0){
					s += " " + vendor;
				}
				if (model.length > 0){
					s += " " + model;
				}
				if (size_bytes > 0) {
					s += " (%s)".printf(format_file_size(size_bytes));
				}
			}
			else{
				s += "<b>" + kname + "</b>" ;
				s += (label.length > 0) ? " (" + label + ")": "";
				s += (fstype.length > 0) ? " ~ " + fstype : "";
				if (size_bytes > 0) {
					s += " (%s)".printf(format_file_size(size_bytes));
				}
			}

			return s;
		}

		public string description_full_free(){
			string s = "";

			if (type == "disk"){
				s += "%s %s".printf(model, vendor).strip();
				if (s.length == 0){
					s = "%s Disk".printf(format_file_size(size_bytes));
				}
				else{
					s += " (%s Disk)".printf(format_file_size(size_bytes));
				}
			}
			else{
				s += kname;
				if (label.length > 0){
					s += " (%s)".printf(label);
				}
				if (fstype.length > 0){
					s += " ~ %s".printf(fstype);
				}
				if (free_bytes > 0){
					s += " ~ %s".printf(description_free());
				}
			}

			return s;
		}

		public string description_full(){
			string s = "";
			s += device;
			s += (label.length > 0) ? " (" + label + ")": "";
			s += (uuid.length > 0) ? " ~ " + uuid : "";
			s += (fstype.length > 0) ? " ~ " + fstype : "";
			s += (used.length > 0) ? " ~ " + used + " / " + size + " GB used (" + used_percent + ")" : "";
			
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

		public string description_free(){
			if (used.length > 0){
				return format_file_size(free_bytes, false, "g", false)
					+ " / " + format_file_size(size_bytes, false, "g", true) + " free";
			}
			else{
				return "";
			}
		}

		public string tooltip_text(){
			string tt = "";

			if (type == "disk"){
				tt += "%-15s: %s\n".printf(_("Device"), device);
				tt += "%-15s: %s\n".printf(_("Vendor"), vendor);
				tt += "%-15s: %s\n".printf(_("Model"), model);
				tt += "%-15s: %s\n".printf(_("Serial"), serial);
				tt += "%-15s: %s\n".printf(_("Revision"), revision);

				tt += "%-15s: %s\n".printf( _("Size"),
					(size_bytes > 0) ? format_file_size(size_bytes) : "N/A");
			}
			else{
				tt += "%-15s: %s\n".printf(_("Device"),
					(mapped_name.length > 0) ? "%s → %s".printf(device, mapped_name) : device);
					
				if (has_parent()){
					tt += "%-15s: %s\n".printf(_("Parent Device"), parent.device);
				}
				tt += "%-15s: %s\n".printf(_("UUID"),uuid);
				tt += "%-15s: %s\n".printf(_("Type"),type);
				tt += "%-15s: %s\n".printf(_("Filesystem"),fstype);
				tt += "%-15s: %s\n".printf(_("Label"),label);
				
				tt += "%-15s: %s\n".printf(_("Size"),
					(size_bytes > 0) ? format_file_size(size_bytes) : "N/A");
					
				tt += "%-15s: %s\n".printf(_("Used"),
					(used_bytes > 0) ? format_file_size(used_bytes) : "N/A");

				tt += "%-15s: %s\n".printf(_("System"),dist_info);
			}

			return "<tt>%s</tt>".printf(tt);
		}

		public int64 free_bytes{
			get{
				return (size_bytes - used_bytes);
			}
		}

		public string size{
			owned get{
				if (size_bytes < GB){
					return "%.1f MB".printf(size_bytes / MB);
				}
				else if (size_bytes > 0){
					return "%.1f GB".printf(size_bytes / GB);
				} 
				else{
					return "";
				}
			}
		}

		public string used{
			owned get{
				return (used_bytes == 0) ? "" : "%.1f GB".printf(used_bytes / GB);
			}
		}

		public string free{
			owned get{
				return (free_bytes == 0) ? "" : "%.1f GB".printf(free_bytes / GB);
			}
		}

		public bool is_mounted{
			get{
				return (mount_points.size > 0);
			}
		}

		public bool has_linux_filesystem(){
			switch(fstype){
				case "ext2":
				case "ext3":
				case "ext4":
				case "reiserfs":
				case "reiser4":
				case "xfs":
				case "jfs":
				case "btrfs":
				case "luks":
				case "crypt":
				case "crypto_luks":
					return true;
				default:
					return false;
			}
		}

		public bool is_encrypted(){
			return (type.contains("crypt") || fstype.contains("luks") || fstype.contains("crypt"));
		}

		public bool has_children(){
			return (children.size > 0);
		}

		public Device? first_linux_child(){
			foreach(var child in children){
				if (child.has_linux_filesystem()){
					return child;
				}
			}
			return null;
		}

		public bool has_parent(){
			return (parent != null);
		}

		// methods ---------------------------

		public void copy_fields(Device dev2){
			this.device = dev2.device;
			this.name = dev2.name;
			this.kname = dev2.kname;
			this.pkname = dev2.pkname;
			this.label = dev2.label;
			this.uuid = dev2.uuid;
			
			this.type = dev2.type;
			this.fstype = dev2.fstype;
			//this.devtype = dev2.devtype;
			
			this.size_bytes = dev2.size_bytes;
			this.used_bytes = dev2.used_bytes;
			
			this.mount_points = dev2.mount_points;
			//this.mount_options = dev2.mount_options;
			
			this.vendor = dev2.vendor;
			this.model = dev2.model;
			this.removable = dev2.removable;
		}

		public void query_disk_space(){

			/* Updates disk space info and returns the given Device object */

			var list_df = get_disk_space_using_df(device);
			
			var dev_df = find_device_in_list(list_df, device, uuid);
			
			if (dev_df != null){
				// update dev fields
				size_bytes = dev_df.size_bytes;
				used_bytes = dev_df.used_bytes;
				available_bytes = dev_df.available_bytes;
				used_percent = dev_df.used_percent;
			}
		}

		// static --------------------------------
		
		public static Gee.ArrayList<Device> get_filesystems(
			bool get_space = true,
			bool get_mounts = true){

			/* Returns list of block devices
			   Populates all fields in Device class */

			var list = get_block_devices_using_lsblk();

			if (get_space){
				//get used space for mounted filesystems
				var list_df = get_disk_space_using_df();
				foreach(var dev_df in list_df){
					var dev = find_device_in_list(list, dev_df.device, dev_df.uuid);
					if (dev != null){
						dev.size_bytes = dev_df.size_bytes;
						dev.used_bytes = dev_df.used_bytes;
						dev.available_bytes = dev_df.available_bytes;
						dev.used_percent = dev_df.used_percent;
					}
				}
			}

			if (get_mounts){
				//get mount points
				var list_mtab = get_mounted_filesystems_using_mtab();
				foreach(var dev_mtab in list_mtab){
					var dev = find_device_in_list(list, dev_mtab.device, dev_mtab.uuid);
					if (dev != null){
						dev.mount_points = dev_mtab.mount_points;
					}
				}
			}

			foreach (var part in list){
				find_child_devices(list, part);
			}

			//print_device_list(list);

			//print_device_mounts(list);
			
			return list;
		}

		private static void find_child_devices(Gee.ArrayList<Device> list, Device parent){
			foreach (var part in list){
				if (part.pkname == parent.kname){
					parent.children.add(part);
					part.parent = parent;
				}
			}
		}

		public static Gee.ArrayList<Device> get_block_devices_using_lsblk(
			string device_file = ""){

			/* Returns list of mounted partitions using 'lsblk' command
			   Populates device, type, uuid, label */

			var list = new Gee.ArrayList<Device>();

			string std_out;
			string std_err;
			string cmd;
			int ret_val;
			Regex rex;
			MatchInfo match;

			cmd = "lsblk --bytes --pairs --output NAME,KNAME,PKNAME,LABEL,UUID,TYPE,FSTYPE,SIZE,MOUNTPOINT,HOTPLUG,RO,VENDOR,MODEL,SERIAL,REV %s".printf(
				(device_file.length > 0) ? device_file : "");

			if (LOG_DEBUG){
				log_debug(cmd);
			}
				
			ret_val = exec_sync(cmd, out std_out, out std_err);
			if (ret_val != 0){
				var msg = "lsblk: " + _("Failed to get partition list");
				msg += (device_file.length > 0) ? ": " + device_file : "";
				log_error (msg);
				return list; //return empty map
			}

			/*
			sample output
			-----------------
			NAME="sda" KNAME="sda" PKNAME="" LABEL="" UUID="" FSTYPE="" SIZE="119.2G" MOUNTPOINT="" HOTPLUG="0"
			
			NAME="sda1" KNAME="sda1" PKNAME="sda" LABEL="" UUID="5345-E139" FSTYPE="vfat" SIZE="47.7M" MOUNTPOINT="/boot/efi" HOTPLUG="0"
			
			NAME="mmcblk0p1" KNAME="mmcblk0p1" PKNAME="mmcblk0" LABEL="" UUID="3c0e4bbf" FSTYPE="crypto_LUKS" SIZE="60.4G" MOUNTPOINT="" HOTPLUG="1"
			
			NAME="luks-3c0" KNAME="dm-1" PKNAME="mmcblk0p1" LABEL="" UUID="f0d933c0-" FSTYPE="ext4" SIZE="60.4G" MOUNTPOINT="/mnt/sdcard" HOTPLUG="0"
			*/

			/*
			Note: Multiple loop devices can have same UUIDs.
			Example: Loop devices created by mounting the same ISO multiple times.
			*/

			//parse output and build filesystem map -------------

			int index = -1;
			
			foreach(string line in std_out.split("\n")){
				if (line.strip().length == 0) { continue; }

				try{
					rex = new Regex("""NAME="(.*)" KNAME="(.*)" PKNAME="(.*)" LABEL="(.*)" UUID="(.*)" TYPE="(.*)" FSTYPE="(.*)" SIZE="(.*)" MOUNTPOINT="(.*)" HOTPLUG="([0-9]+)" RO="([0-9]+)" VENDOR="(.*)" MODEL="(.*)" SERIAL="(.*)" REV="(.*)"""");
					if (rex.match (line, 0, out match)){

						Device pi = new Device();
						pi.name = match.fetch(1).strip();
						pi.kname = match.fetch(2).strip();
						pi.pkname = match.fetch(3).strip();
						pi.label = match.fetch(4).strip();
						pi.uuid = match.fetch(5).strip();
						pi.type = match.fetch(6).strip().down();
						pi.fstype = match.fetch(7).strip().down();
						pi.size_bytes = int64.parse(match.fetch(8).strip());

						pi.fstype = (pi.fstype == "crypto_luks") ? "luks" : pi.fstype;
						
						var mp = match.fetch(9).strip();
						if (mp.length > 0){
							pi.mount_points.add(new MountEntry(pi,mp,""));
						}
						
						pi.removable = (match.fetch(10).strip() == "1");
						pi.read_only = (match.fetch(11).strip() == "1");

						pi.vendor = match.fetch(12).strip();
						pi.model = match.fetch(13).strip();
						pi.serial = match.fetch(14).strip();
						pi.revision = match.fetch(15).strip();
						
						pi.order = ++index;
						pi.device = "/dev/%s".printf(pi.kname);

						if ((pi.type == "crypt") && (pi.pkname.length > 0)){
							pi.name = "%s (unlocked)".printf(pi.pkname);
						}

						//if ((pi.uuid.length > 0) && (pi.pkname.length > 0)){
							list.add(pi);
						//}
					}
				}
				catch(Error e){
					log_error (e.message);
				}
			}

			// already sorted
			/*list.sort((a,b)=>{
				return (a.order - b.order);
			});*/

			// add aliases from /dev/disk/by-uuid/

			foreach(var dev in list){
				var dev_by_uuid = path_combine("/dev/disk/by-uuid/", dev.uuid);
				if (file_exists(dev_by_uuid)){
					dev.symlinks.add(dev_by_uuid);
				}
			}

			// add aliases from /dev/mapper/
			
			try
			{
				File f_dev_mapper = File.new_for_path ("/dev/mapper");
				
				FileEnumerator enumerator = f_dev_mapper.enumerate_children (
					"%s,%s".printf(
						FileAttribute.STANDARD_NAME, FileAttribute.STANDARD_SYMLINK_TARGET),
				    FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
				    
				FileInfo info;
				while ((info = enumerator.next_file ()) != null) {
					
					File f_mapped = f_dev_mapper.resolve_relative_path(info.get_name());
					
					string mapped_file = f_mapped.get_path();
					string mapped_device = info.get_symlink_target();
					mapped_device = mapped_device.replace("..","/dev");
					log_debug("info.get_name(): %s".printf(info.get_name()));
					log_debug("info.get_symlink_target(): %s".printf(info.get_symlink_target()));
					log_debug("mapped_file: %s".printf(mapped_file));
					log_debug("mapped_device: %s".printf(mapped_device));
					
					foreach(var dev in list){
						if (dev.device == mapped_device){
							dev.mapped_name = mapped_file;
							dev.symlinks.add(mapped_file);
							log_debug("found link: %s -> %s".printf(mapped_file, dev.device));
							break;
						}
					}
				}
			}
			catch (Error e) {
				log_error (e.message);
			}

			device_list = list;

			print_device_list(list);

			return list;
		}

		// deprecated: use get_block_devices_using_lsblk() instead
		public static Gee.ArrayList<Device> get_block_devices_using_blkid(
			string device_file = ""){

			/* Returns list of mounted partitions using 'blkid' command
			   Populates device, type, uuid, label */

			var list = new Gee.ArrayList<Device>();

			string std_out;
			string std_err;
			string cmd;
			int ret_val;
			Regex rex;
			MatchInfo match;

			cmd = "/sbin/blkid" + ((device_file.length > 0) ? " " + device_file: "");

			if (LOG_DEBUG){
				log_debug(cmd);
			}
			
			ret_val = exec_script_sync(cmd, out std_out, out std_err);
			if (ret_val != 0){
				var msg = "blkid: " + _("Failed to get partition list");
				msg += (device_file.length > 0) ? ": " + device_file : "";
				log_error(msg);
				return list; //return empty list
			}

			/*
			sample output
			-----------------
			/dev/sda1: LABEL="System Reserved" UUID="F476B08076B04560" TYPE="ntfs"
			/dev/sda2: LABEL="windows" UUID="BE00B6DB00B69A3B" TYPE="ntfs"
			/dev/sda3: UUID="03f3f35d-71fa-4dff-b740-9cca19e7555f" TYPE="ext4"
			*/

			//parse output and build filesystem map -------------

			foreach(string line in std_out.split("\n")){
				if (line.strip().length == 0) { continue; }

				Device pi = new Device();

				pi.device = line.split(":")[0].strip();

				if (pi.device.length == 0) { continue; }

				//exclude non-standard devices --------------------

				if (!pi.device.has_prefix("/dev/")){
					continue;
				}

				if (pi.device.has_prefix("/dev/sd") || pi.device.has_prefix("/dev/hd") || pi.device.has_prefix("/dev/mapper/") || pi.device.has_prefix("/dev/dm")) {
					//ok
				}
				else if (pi.device.has_prefix("/dev/disk/by-uuid/")){
					//ok, get uuid
					pi.uuid = pi.device.replace("/dev/disk/by-uuid/","");
				}
				else{
					continue; //skip
				}

				//parse & populate fields ------------------

				try{
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
						pi.fstype = match.fetch(1).strip();
					}
				}
				catch(Error e){
					log_error (e.message);
				}

				//add to map -------------------------

				if (pi.uuid.length > 0){
					list.add(pi);
				}
			}

			return list;
		}

		public static Gee.ArrayList<Device> get_disk_space_using_df(
			string device_or_mount_point = ""){

			/*
			Returns list of mounted partitions using 'df' command
			Populates device, type, size, used and mount_point_list
			*/

			var list = new Gee.ArrayList<Device>();

			string std_out;
			string std_err;
			string cmd;
			int ret_val;

			cmd = "df -T -B1";

			if (device_or_mount_point.length > 0){
				cmd += " '%s'".printf(escape_single_quote(device_or_mount_point));
			}

			if (LOG_DEBUG){
				log_debug(cmd);
			}

			ret_val = exec_script_sync(cmd, out std_out, out std_err);
			//ret_val is not reliable, no need to check

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

				Device pi = new Device();

				//parse & populate fields ------------------

				int k = 1;
				foreach(string val in line.split(" ")){

					if (val.strip().length == 0){ continue; }

					switch(k++){
						case 1:
							pi.device = val.strip();
							break;
						case 2:
							pi.fstype = val.strip();
							break;
						case 3:
							pi.size_bytes = int64.parse(val.strip());
							break;
						case 4:
							pi.used_bytes = int64.parse(val.strip());
							break;
						case 5:
							pi.available_bytes = int64.parse(val.strip());
							break;
						case 6:
							pi.used_percent = val.strip();
							break;
						case 7:
							//string mount_point = val.strip();
							//if (!pi.mount_point_list.contains(mount_point)){
							//	pi.mount_point_list.add(mount_point);
							//}
							break;
					}
				}

				/* Note:
				 * The mount points displayed by 'df' are not reliable.
				 * For example, if same device is mounted at 2 locations, 'df' displays only the first location.
				 * Hence, we will not populate the 'mount_points' field in Device object
				 * Use get_mounted_filesystems_using_mtab() if mount info is required
				 * */

				// resolve device name --------------------

				pi.device = resolve_device_name(pi.device);
				
				// get uuid ---------------------------

				pi.uuid = get_device_uuid(pi.device);

				// add to map -------------------------

				if (pi.uuid.length > 0){
					list.add(pi);
				}
			}

			return list;
		}

		public static Gee.ArrayList<Device> get_mounted_filesystems_using_mtab(){

			/* Returns list of mounted partitions by reading /proc/mounts
			   Populates device, type and mount_point_list */

			var list = new Gee.ArrayList<Device>();

			string mtab_path = "/etc/mtab";
			string mtab_lines = "";

			File f;

			// find mtab file -----------

			mtab_path = "/proc/mounts";
			f = File.new_for_path(mtab_path);
			if(!f.query_exists()){
				mtab_path = "/proc/self/mounts";
				f = File.new_for_path(mtab_path);
				if(!f.query_exists()){
					mtab_path = "/etc/mtab";
					f = File.new_for_path(mtab_path);
					if(!f.query_exists()){
						return list; //empty list
					}
				}
			}

			/* Note:
			 * /etc/mtab represents what 'mount' passed to the kernel
			 * whereas /proc/mounts shows the data as seen inside the kernel
			 * Hence /proc/mounts is always up-to-date whereas /etc/mtab might not be
			 * */

			//read -----------

			mtab_lines = file_read(mtab_path);

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

			/* Note:
			 * We are interested only in the last device that was mounted at a given mount point
			 * Hence the lines must be parsed in reverse order (from last to first)
			 * */

			//parse ------------

			string[] lines = mtab_lines.split("\n");
			var mount_list = new Gee.ArrayList<string>();

			for (int i = lines.length - 1; i >= 0; i--){

				string line = lines[i].strip();
				if (line.length == 0) { continue; }

				var pi = new Device();

				var mp = new MountEntry(pi,"","");

				//parse & populate fields ------------------

				int k = 1;
				foreach(string val in line.split(" ")){
					if (val.strip().length == 0){ continue; }
					switch(k++){
						case 1: //device
							pi.device = val.strip();
							break;
						case 2: //mountpoint
							mp.mount_point = val.strip();
							if (!mount_list.contains(mp.mount_point)){
								mount_list.add(mp.mount_point);
								pi.mount_points.add(mp);
							}
							break;
						case 3: //filesystemtype
							pi.fstype = val.strip();
							break;
						case 4: //options
							mp.mount_options = val.strip();
							break;
						default:
							//ignore
							break;
					}
				}

				// resolve device names ----------------

				pi.device = resolve_device_name(pi.device);

				// get uuid ---------------------------

				pi.uuid = get_device_uuid(pi.device);

				// add to map -------------------------

				if (pi.uuid.length > 0){
					var dev = find_device_in_list(list, pi.device, pi.uuid);
					if (dev == null){
						list.add(pi);
					}
					else{
						// add mount points to existing device
						foreach(var item in pi.mount_points){
							dev.mount_points.add(item);
						}
					}
				}
			}

			return list;
		}


		// helpers ----------------------------------

		public static Device? find_device_in_list(
			Gee.ArrayList<Device> list,
			string dev_device,
			string dev_uuid){
			
			foreach(var dev in list){
				if ((dev.device == dev_device) && (dev.uuid == dev_uuid)){
					return dev;
				}
			}
			return null;
		}

		public static Device? get_device_by_uuid(string uuid){
			foreach(var dev in device_list){
				if (dev.uuid == uuid){
					return dev;
				}
			}
			
			return null;
		}

		public static Device? get_device_by_name(string file_name){

			var device_name = resolve_device_name(file_name);
			
			foreach(var dev in device_list){
				if (dev.device == device_name){
					return dev;
				}
			}
			
			return null;
		}

		public static Device? get_device_by_path(string path_to_check){
			var list = Device.get_disk_space_using_df(path_to_check);
			if (list.size > 0){
				return list[0];
			}
			return null;
		}
		
		public static string get_device_uuid(string device){
			if (device_list == null){
				device_list = get_block_devices_using_lsblk();
			}
			foreach(Device dev in device_list){
				if (dev.device == device){
					return dev.uuid;
				}
			}
			return "";
		}

		public static Gee.ArrayList<MountEntry> get_device_mount_points(string device_or_uuid){
			string device = "";
			string uuid = "";

			if (device_or_uuid.has_prefix("/dev")){
				device = device_or_uuid;
				uuid = get_device_uuid(device_or_uuid);
			}
			else{
				uuid = device_or_uuid;
				device = "/dev/disk/by-uuid/%s".printf(uuid);
				device = resolve_device_name(device);
			}

			var list_mtab = get_mounted_filesystems_using_mtab();
			
			var dev = find_device_in_list(list_mtab, device, uuid);

			if (dev != null){
				return dev.mount_points;
			}
			else{
				return (new Gee.ArrayList<MountEntry>());
			}
		}

		public static bool device_is_mounted(string device_or_uuid){

			var mps = Device.get_device_mount_points(device_or_uuid);
			if (mps.size > 0){
				return true;
			}

			return false;
		}

		public static bool mount_point_in_use(string mount_point){
			var list = Device.get_mounted_filesystems_using_mtab();
			foreach (var dev in list){
				foreach(var mp in dev.mount_points){
					if (mp.mount_point.has_prefix(mount_point)){
						// check for any mount point at or under the given mount_point
						return true;
					}
				}
			}
			return false;
		}

		public static string resolve_device_name(string dev_device){

			string resolved = dev_device;
			
			if (dev_device.has_prefix("/dev/mapper/")){
				var link_path = file_get_symlink_target(dev_device);
				if (link_path.has_prefix("../")){
					resolved = link_path.replace("../","/dev/");
				}
			}

			if (dev_device.has_prefix("/dev/disk/")){
				var link_path = file_get_symlink_target(dev_device);
				if (link_path.has_prefix("../../")){
					resolved = link_path.replace("../../","/dev/");
				}
			}

			if (dev_device != resolved){
				//log_msg("resolved '%s' to '%s'".printf(dev_device, resolved));
			}

			return resolved;
		}
		
		// mounting ---------------------------------
		
		public static bool automount_udisks(string device){
			var cmd = "udisksctl mount -b '%s'".printf(device);
			log_debug(cmd);
			int status = Posix.system(cmd);
			return (status == 0);
		}

		public static bool automount_udisks_iso(string iso_file_path, out string loop_device){

			loop_device = "";
			
			var cmd = "udisksctl loop-setup -r -f '%s'".printf(
				escape_single_quote(iso_file_path));
				
			log_debug(cmd);
			string std_out, std_err;
			int exit_code = exec_sync(cmd, out std_out, out std_err);
			
			if (exit_code == 0){
				log_msg("%s".printf(std_out));
				//log_msg("%s".printf(std_err));

				if (!std_out.contains(" as ")){
					log_error("Could not determine loop device");
					return false;
				}

				loop_device = std_out.split(" as ")[1].replace(".","").strip();
				log_msg("loop_device: %s".printf(loop_device));
			
				var list = get_block_devices_using_lsblk();
				foreach(var dev in list){
					if ((dev.pkname == loop_device.replace("/dev/","")) && (dev.fstype == "iso9660")){
						loop_device = dev.device;
						return automount_udisks(dev.device);
					}
				}
			}
			
			return false;
		}

		public static bool unmount_udisks(string device_or_uuid){
			var cmd = "udisksctl unmount -b '%s'".printf(device_or_uuid);
			log_debug(cmd);
			int status = Posix.system(cmd);
			return (status == 0);
		}

		public static Device? luks_unlock(
			Device luks_device, string mapped_name, string luks_pass,
			out string message, out string details){
				
			Device unlocked_device = null;

			// check if not encrypted
			if (!luks_device.fstype.contains("luks") && !luks_device.fstype.contains("crypt")){
				message = _("This device is not encrypted");
				details = _("Failed to unlock device");
				return null;
			}

			// check if already unlocked
			var list = get_filesystems();
			foreach(var part in list){
				if (part.pkname == luks_device.kname){
					unlocked_device = part;
					message = _("Device is unlocked");
					details = _("Unlocked device is mapped to '%s'").printf(part.mapped_name);
					return part; 
				}
			}
		

			var cmd = "echo -n -e '%s' | cryptsetup luksOpen --key-file - %s %s\n".printf(
				luks_pass, luks_device.device, mapped_name);
			
			log_debug(cmd);

			string std_out, std_err;
			int status = exec_script_sync(cmd, out std_out, out std_err, false, true);

			switch (status){
				case 512: // invalid passphrase
					message = _("Wrong password");
					details = _("Failed to unlock device");
					log_error(message);
					log_error(details);
					break;
			}

			// find unlocked device
			list = get_filesystems();
			foreach(var part in list){
				if (part.pkname == luks_device.kname){
					unlocked_device = part;
					break; 
				}
			}

			if (unlocked_device == null){
				message = _("Failed to unlock device") + " '%s'".printf(luks_device.device);
				details = std_err;
			}
			else{
				message = _("Unlocked successfully");
				details = _("Unlocked device is mapped to '%s'").printf(unlocked_device.mapped_name);
			}
			
			return unlocked_device;
		}

		public static bool luks_lock(string kname){
			var cmd = "cryptsetup luksClose /dev/%s".printf(kname);
			
			log_debug(cmd);
			
			if (bash_admin_shell != null){
				int status = bash_admin_shell.execute(cmd);
				return (status == 0);
			}
			else{
				int status = exec_script_sync(cmd,null,null,false,true);
				return (status == 0);
			}
		}

		public static bool mount(
			string device_or_uuid, string mount_point, string mount_options = ""){

			/*
			 * Mounts specified device at specified mount point.
			 * 
			 * */

			string cmd = "";
			string std_out;
			string std_err;
			int ret_val;

			string device = "";
			string uuid = "";

			if (device_or_uuid.has_prefix("/dev")){
				device = device_or_uuid;
				uuid = get_device_uuid(device_or_uuid);
			}
			else{
				uuid = device_or_uuid;
				device = "/dev/disk/by-uuid/%s".printf(uuid);
			}

			if (dir_exists(mount_point)){
				dir_create(mount_point);
			}
			
			// check if already mounted ------------------
			
			var mps = Device.get_device_mount_points(device_or_uuid);
			foreach(var mp in mps){
				if (mp.mount_point.contains(mount_point)){
					log_msg("Device '%s' is mounted at '%s'".printf(device_or_uuid, mount_point));
					return true;
				}
			}
			

			try{
				// check and create mount point -------------

				File file = File.new_for_path(mount_point);
				if (!file.query_exists()){
					file.make_directory_with_parents();
				}

				// mount the device -----------------------------

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
					return true;
				}
			}
			catch(Error e){
				log_error (e.message);
				return false;
			}

			// check if mounted successfully ------------------

			/*mps = Device.get_device_mount_points(device_or_uuid);
			if (mps.contains(mount_point)){
				log_msg("Device '%s' is mounted at '%s'".printf(device_or_uuid, mount_point));
				return true;
			}
			else{
				return false;
			}*/
		}

		public static string automount(
			string device_or_uuid, string mount_options = "", string mount_prefix = "/mnt"){

			/* Returns the mount point of specified device.
			 * If unmounted, mounts the device to /mnt/<uuid> and returns the mount point.
			 * */

			string device = "";
			string uuid = "";

			// get uuid -----------------------------

			if (device_or_uuid.has_prefix("/dev")){
				device = device_or_uuid;
				uuid = Device.get_device_uuid(device_or_uuid);
			}
			else{
				uuid = device_or_uuid;
				device = "/dev/disk/by-uuid/%s".printf(uuid);
			}

			// check if already mounted and return mount point -------------

			var list = Device.get_block_devices_using_lsblk();
			var dev = find_device_in_list(list, device, uuid);
			if (dev != null){
				return dev.mount_points[0].mount_point;
			}

			// check and create mount point -------------------

			string mount_point = "%s/%s".printf(mount_prefix, uuid);

			try{
				File file = File.new_for_path(mount_point);
				if (!file.query_exists()){
					file.make_directory_with_parents();
				}
			}
			catch(Error e){
				log_error (e.message);
				return "";
			}

			// mount the device and return mount_point --------------------

			if (mount(uuid, mount_point, mount_options)){
				return mount_point;
			}
			else{
				return "";
			}
		}

		public static bool unmount(string mount_point){

			/* Recursively unmounts all devices at given mount_point and subdirectories
			 * */

			string cmd = "";
			string std_out;
			string std_err;
			int ret_val;

			// check if mount point is in use
			if (!Device.mount_point_in_use(mount_point)) {
				return true;
			}

			// try to unmount ------------------

			try{

				string cmd_unmount = "cat /proc/mounts | awk '{print $2}' | grep '%s' | sort -r | xargs umount".printf(mount_point);

				log_debug(_("Unmounting from") + ": '%s'".printf(mount_point));

				//sync before unmount
				cmd = "sync";
				Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
				//ignore success/failure

				//unmount
				ret_val = exec_script_sync(cmd_unmount, out std_out, out std_err);

				if (ret_val != 0){
					log_error (_("Failed to unmount"));
					log_error (std_err);
				}
			}
			catch(Error e){
				log_error (e.message);
				return false;
			}

			// check if mount point is in use
			if (!Device.mount_point_in_use(mount_point)) {
				return true;
			}
			else{
				return false;
			}
		}

		// testing -----------------------------------

		public static void test_all(){
			var list = get_block_devices_using_lsblk();
			log_msg("\n> get_block_devices_using_lsblk()");
			print_device_list(list);

			log_msg("");
			
			//list = get_block_devices_using_blkid();
			//log_msg("\nget_block_devices_using_blkid()\n");
			//print_device_list(list);

			list = get_mounted_filesystems_using_mtab();
			log_msg("\n> get_mounted_filesystems_using_mtab()");
			print_device_mounts(list);

			log_msg("");

			list = get_disk_space_using_df();
			log_msg("\n> get_disk_space_using_df()");
			print_device_disk_space(list);

			log_msg("");

			list = get_filesystems();
			log_msg("\n> get_filesystems()");
			print_device_list(list);
			print_device_mounts(list);
			print_device_disk_space(list);
			
			log_msg("");
		}

		public static void print_device_list(Gee.ArrayList<Device> list){

			stdout.printf("\n");
			
			stdout.printf("%-20s %-25s %-10s %-10s %s\n".printf(
				"device",
				"label",
				"pkname",
				"kname",
				"uuid"));

			stdout.printf(string.nfill(100, '-'));
			stdout.printf("\n");
			
			foreach(var dev in list){
				stdout.printf("%-20s %-25s %-10s %-10s %s\n".printf(
					dev.device + ((dev.mapped_name.length > 0) ? " -> " + dev.mapped_name : ""),
					dev.label,
					dev.pkname,
					dev.kname,
					dev.uuid
					));
			}

			stdout.printf("\n");
			
			stdout.printf("%-20s %-10s %-10s %s %s %s %s\n".printf(
				"device",
				"pkname",
				"kname",
				"vendor",
				"model",
				"serial",
				"rev"));

			stdout.printf(string.nfill(100, '-'));
			stdout.printf("\n");
			
			foreach(var dev in list){
				stdout.printf("%-20s %-10s %-10s %s %s %s %s\n".printf(
					dev.device + ((dev.mapped_name.length > 0) ? " -> " + dev.mapped_name : ""),
					//dev.name,
					dev.pkname,
					dev.kname,
					dev.vendor,
					dev.model,
					dev.serial,
					dev.revision
					));
			}

			stdout.printf("\n");
			
			stdout.printf("%-20s %-10s %-15s %-10s %10s %10s %10s\n".printf(
				"device",
				"type",
				"fstype",
				"REM",
				"RO",
				"size",
				"used"));

			stdout.printf(string.nfill(100, '-'));
			stdout.printf("\n");
			
			foreach(var dev in list){
				stdout.printf("%-20s %-10s %-15s %-10s %10s %10s %10s\n".printf(
					dev.device,
					dev.type,
					dev.fstype,
					dev.removable ? "1" : "0",
					dev.read_only ? "1" : "0",
					format_file_size(dev.size_bytes, true),
					format_file_size(dev.used_bytes, true)
					));
			}

			stdout.printf("\n");
		}

		public static void print_device_mounts(Gee.ArrayList<Device> list){

			stdout.printf("\n");
			
			stdout.printf("%-15s %s\n".printf(
				"device",
				//"fstype",
				"> mount_points (mount_options)"
			));

			stdout.printf(string.nfill(100, '-'));
			stdout.printf("\n");
			
			foreach(var dev in list){

				string mps = "";
				foreach(var mp in dev.mount_points){
					mps += "\n    %s -> ".printf(mp.mount_point);
					if (mp.mount_options.length > 0){
						mps += " %s".printf(mp.mount_options);
					}
				}

				stdout.printf("%-15s %s\n\n".printf(
					dev.device,
					//dev.fstype,
					mps
				));
				
			}

			stdout.printf("\n");
		}

		public static void print_device_disk_space(Gee.ArrayList<Device> list){
			stdout.printf("\n");
			
			stdout.printf("%-15s %-12s %15s %15s %15s %10s\n".printf(
				"device",
				"fstype",
				"size",
				"used",
				"available",
				"used_percent"
			));

			stdout.printf(string.nfill(100, '-'));
			stdout.printf("\n");
			
			foreach(var dev in list){
				stdout.printf("%-15s %-12s %15s %15s %15s %10s\n".printf(
					dev.device,
					dev.fstype,
					format_file_size(dev.size_bytes, true),
					format_file_size(dev.used_bytes, true),
					format_file_size(dev.available_bytes, true),
					dev.used_percent
				));
			}

			stdout.printf("\n");
		}
	}

	public class MountEntry : GLib.Object{
		public Device device = null;
		public string mount_point = "";
		public string mount_options = "";
		
		public MountEntry(Device? device, string mount_point, string mount_options){
			this.device = device;
			this.mount_point = mount_point;
			this.mount_options = mount_options;
		}

		public string subvolume_name(){
			if (mount_options.contains("subvol=")){
				return mount_options.split("subvol=")[1].split(",")[0].strip();
			}
			else{
				return "";
			}
		}
	}

}





