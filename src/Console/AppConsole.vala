/*
 * AppConsole.vala
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

using GLib;
using Gtk;
using Gee;
//using Soup;
using Json;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public Main App;
public const string AppName = "Timeshift";
public const string AppShortName = "timeshift";
public const string AppVersion = "18.9";
public const string AppAuthor = "Tony George";
public const string AppAuthorEmail = "teejeetech@gmail.com";

const string GETTEXT_PACKAGE = "";
const string LOCALE_DIR = "/usr/share/locale";

extern void exit(int exit_code);

public class AppConsole : GLib.Object {

	public int snapshot_list_start_index = 0;

	public static int main (string[] args) {
		
		set_locale();

		LOG_TIMESTAMP = false;

		if (args.length > 1) {
			switch (args[1].down()) {
				case "--help":
				case "-h":
					stdout.printf (help_message ());
					return 0;
			}
		}
		else if (args.length == 1){
			stdout.printf (help_message ());
			return 0;
		}

		LOG_ENABLE = false;
		init_tmp(AppShortName);
		LOG_ENABLE = true;
		
		check_if_admin();

		App = new Main(args, false);
		parse_arguments(args);
		App.initialize();
		
		var console =  new AppConsole();
		bool ok = console.start_application();
		App.exit_app((ok) ? 0 : 1);

		return (ok) ? 0 : 1;
	}

	private static void set_locale() {
		
		log_debug("setting locale...");
		Intl.setlocale(GLib.LocaleCategory.MESSAGES, "timeshift");
		Intl.textdomain(GETTEXT_PACKAGE);
		Intl.bind_textdomain_codeset(GETTEXT_PACKAGE, "utf-8");
		Intl.bindtextdomain(GETTEXT_PACKAGE, LOCALE_DIR);
	}

	public static void check_if_admin(){
		
		if (!user_is_admin()) {
			log_msg(_("Application needs admin access."));
			log_msg(_("Please run the application as admin (using 'sudo' or 'su')"));
			App.exit_app(1);
		}
	}

	// console members --------------

	private static void parse_arguments(string[] args){

		log_debug("AppConsole: parse_arguments()");
		
		for (int k = 1; k < args.length; k++) // Oth arg is app path
		{
			switch (args[k].down()){
				//case "--backup": // deprecated
				case "--check":
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					App.app_mode = "backup";
					break;

				case "--delete":
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					App.app_mode = "delete";
					break;

				case "--delete-all":
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					App.app_mode = "delete-all";
					break;

				case "--restore":
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					App.mirror_system = false;
					App.app_mode = "restore";
					break;

				case "--clone":
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					App.mirror_system = true;
					App.app_mode = "restore";
					break;

				//case "--backup-now": // deprecated
				case "--create":
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					App.app_mode = "ondemand";
					break;

				case "--comment":
				case "--comments":
					App.cmd_comments = args[++k];
					break; 

				case "--skip-grub":
					App.cmd_skip_grub = true;
					break;

				case "--verbose":
					App.cmd_verbose = true;
					break;

				case "--quiet":
					App.cmd_verbose = false;
					break;

				case "--scripted":
					App.cmd_scripted = true;
					break;

				case "--yes":
					App.cmd_confirm = true;
					break;

				case "--grub":
				case "--grub-device":
					App.reinstall_grub2 = true;
					App.cmd_grub_device = args[++k];
					break;

				case "--target":
				case "--target-device":
					App.cmd_target_device = args[++k];
					break;

				case "--backup-device":
				case "--snapshot-device":
					App.cmd_backup_device = args[++k];
					break;

				case "--snapshot":
				case "--snapshot-name":
					App.cmd_snapshot = args[++k];
					break;

				case "--tags":
					App.cmd_tags = args[++k];
					App.validate_cmd_tags();
					break;

				case "--debug":
					LOG_COMMANDS = true;
					LOG_DEBUG = true;
					break;

				case "--list":
				case "--list-snapshots":
					App.app_mode = "list-snapshots";
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					break;

				case "--list-devices":
					App.app_mode = "list-devices";
					LOG_TIMESTAMP = false;
					LOG_DEBUG = false;
					break;

				case "--btrfs":
					App.btrfs_mode = true;
					App.cmd_btrfs_mode = true;
					break;

				case "--rsync":
					App.btrfs_mode = false;
					App.cmd_btrfs_mode = false;
					break;

				case "--backup":
					log_error("Option --backup has been replaced by option --check");
					log_error("Run 'timeshift --help' to list all available options");
					App.exit_app(1);
					break;

				case "--backup-now":
					log_error("Option --backup-now has been replaced by option --create");
					log_error("Run 'timeshift --help' to list all available options");
					App.exit_app(1);
					break;
					
				default:
					LOG_TIMESTAMP = false;
					log_error("%s: %s".printf(
						_("Invalid command line arguments"), args[k]), true);
					log_msg(help_message());
					App.exit_app(1);
					break;
			}
		}

		/* LOG_ENABLE = false; 		disables all console output
		 * LOG_TIMESTAMP = false;	disables the timestamp prepended to every line in terminal output
		 * LOG_DEBUG = false;		disables additional console messages
		 * LOG_COMMANDS = true;		enables printing of all commands on terminal
		 * */

		//if (app_mode == ""){
			//Initialize GTK
		//	LOG_TIMESTAMP = true;
		//}

		//Gtk.init(ref args);
		//X.init_threads();
	}

	public bool start_application(){

		log_debug("AppConsole: start_application()");
		
		bool is_success = true;

		if (App.live_system()){
			switch(App.app_mode){
			case "backup":
			case "ondemand":
				log_error(_("Snapshots cannot be created in Live CD mode"));
				return false;
			}
		}

		switch(App.app_mode){
			case "backup":
				is_success = create_snapshot(false);
				return is_success;

			case "restore":
				is_success = restore_snapshot();
				return is_success;

			case "delete":
				is_success = delete_snapshot();
				return is_success;

			case "delete-all":
				is_success = delete_all_snapshots();
				return is_success;

			case "ondemand":
				is_success = create_snapshot(true);
				return is_success;

			case "list-snapshots":
				LOG_ENABLE = true;

				App.repo.print_status();

				if (App.repo.has_snapshots()){
					list_snapshots(false);
					log_msg("");
					return true;
				}
				else{
					log_msg(_("No snapshots found"));
					return false;
				}

			case "list-devices":
				LOG_ENABLE = true;
				log_msg("\n" + _("Devices with Linux file systems") + ":\n");
				list_all_devices();
				log_msg("");
				return true;

			default:
				return true;
		}
	}

	private static string help_message (){
		
		string msg = "\n%s v%s by Tony George (%s)\n".printf(
			AppName, AppVersion, AppAuthorEmail);
			
		msg += "\n";
		msg += "Syntax:\n";
		msg += "\n";
		msg += "  timeshift --check\n";
		msg += "  timeshift --create [OPTIONS]\n";
		msg += "  timeshift --restore [OPTIONS]\n";
		msg += "  timeshift --delete-[all] [OPTIONS]\n";
		msg += "  timeshift --list-{snapshots|devices} [OPTIONS]\n";
		msg += "\n";
		msg += _("Options") + ":\n";
		msg += "\n";
		msg += _("List") + ":\n";
		msg += "  --list[-snapshots]         " + _("List snapshots") + "\n";
		msg += "  --list-devices             " + _("List devices") + "\n";
		msg += "\n";
		msg += _("Backup") + ":\n";
		msg += "  --check                    " + _("Create snapshot if scheduled") + "\n";
		msg += "  --create                   " + _("Create snapshot (even if not scheduled)") + "\n";
		msg += "  --comments <string>        " + _("Set snapshot description") + "\n";
		msg += "  --tags {O,B,H,D,W,M}       " + _("Add tags to snapshot (default: O)") + "\n";;
		msg += "\n";
		msg += _("Restore") + ":\n";
		msg += "  --restore                  " + _("Restore snapshot") + "\n";
		msg += "  --clone                    " + _("Clone current system") + "\n";
		msg += "  --snapshot <name>          " + _("Specify snapshot to restore") + "\n";
		msg += "  --target[-device] <device> " + _("Specify target device") + "\n";
		msg += "  --grub[-device] <device>   " + _("Specify device for installing GRUB2 bootloader") + "\n";
		msg += "  --skip-grub                " + _("Skip GRUB2 reinstall") + "\n";
		msg += "\n";
		msg += _("Delete") + ":\n";
		msg += "  --delete                   " + _("Delete snapshot") + "\n";
		msg += "  --delete-all               " + _("Delete all snapshots") + "\n";
		msg += "\n";
		msg += _("Global") + ":\n";
		msg += "  --snapshot-device <device> " + _("Specify backup device (default: config)") + "\n";
		msg += "  --yes                      " + _("Answer YES to all confirmation prompts") + "\n";
		msg += "  --btrfs                    " + _("Switch to BTRFS mode (default: config)") + "\n";
		msg += "  --rsync                    " + _("Switch to RSYNC mode (default: config)") + "\n";
		msg += "  --debug                    " + _("Show additional debug messages") + "\n";
		msg += "  --verbose                  " + _("Show rsync output (default)") + "\n";
		msg += "  --quiet                    " + _("Hide rsync output") + "\n";
		msg += "  --scripted                 " + _("Run in non-interactive mode") + "\n";
		msg += "  --help                     " + _("Show all options") + "\n";
		msg += "\n";

		msg += _("Examples") + ":\n";
		msg += "\n";
		msg += "timeshift --list\n";
		msg += "timeshift --list --snapshot-device /dev/sda1\n";
		msg += "timeshift --create --comments \"after update\" --tags D\n";
		msg += "timeshift --restore \n";
		msg += "timeshift --restore --snapshot '2014-10-12_16-29-08' --target /dev/sda1\n";
		msg += "timeshift --delete  --snapshot '2014-10-12_16-29-08'\n";
		msg += "timeshift --delete-all \n";
		msg += "\n";

		msg += _("Notes") + ":\n";
		msg += "\n";
		msg += "  1) --create will always create a new snapshot\n";
		msg += "  2) --check will create a snapshot only if a scheduled snapshot is due\n";
		msg += "  3) Use --restore without other options to select options interactively\n";
		msg += "  4) UUID can be specified instead of device name\n";
		msg += "  5) Default values will be loaded from app config if options are not specified\n";
		msg += "\n";
		return msg;
	}

	//console functions

	private void list_snapshots(bool paginate, int page_size = 20){
		int count = 0;
		for(int index = 0; index < App.repo.snapshots.size; index++){
			if (!paginate || ((index >= snapshot_list_start_index) && (index < snapshot_list_start_index + page_size))){
				count++;
			}
		}

		string[,] grid = new string[count+1,5];
		bool[] right_align = { false, false, false, false, false};

		int row = 0;
		int col = -1;
		grid[row, ++col] = _("Num");
		grid[row, ++col] = "";
		grid[row, ++col] = _("Name");
		grid[row, ++col] = _("Tags");
		grid[row, ++col] = _("Description");
		row++;

		for(int index = 0; index < App.repo.snapshots.size; index++){
			Snapshot bak = App.repo.snapshots[index];
			if (!paginate || ((index >= snapshot_list_start_index) && (index < snapshot_list_start_index + page_size))){
				col = -1;
				grid[row, ++col] = "%d".printf(index);
				grid[row, ++col] = ">";
				grid[row, ++col] = "%s".printf(bak.name);
				grid[row, ++col] = "%s".printf(bak.taglist_short);
				grid[row, ++col] = "%s".printf(bak.description);
				row++;
			}
		}

		print_grid(grid, right_align);
	}

	private void list_devices(Gee.ArrayList<Device> device_list){
		
		string[,] grid = new string[device_list.size+1,6];
		bool[] right_align = { false, false, false, true, true, false};

		int row = 0;
		int col = -1;
		grid[row, ++col] = _("Num");
		grid[row, ++col] = "";
		grid[row, ++col] = _("Device");
		//grid[row, ++col] = _("UUID");
		grid[row, ++col] = _("Size");
		grid[row, ++col] = _("Type");
		grid[row, ++col] = _("Label");
		row++;

		foreach(var pi in device_list) {
			col = -1;
			grid[row, ++col] = "%d".printf(row - 1);
			grid[row, ++col] = ">";
			grid[row, ++col] = "%s".printf(pi.device_name_with_parent);
			//grid[row, ++col] = "%s".printf(pi.uuid);
			grid[row, ++col] = "%s".printf((pi.size_bytes > 0) ? "%s".printf(pi.size) : "?? GB");
			grid[row, ++col] = "%s".printf(pi.fstype);
			grid[row, ++col] = "%s".printf(pi.label);
			row++;
		}

		print_grid(grid, right_align);
	}

	private Gee.ArrayList<Device> list_all_devices(){

		//add devices
		var device_list = new Gee.ArrayList<Device>();
		foreach(var dev in Device.get_block_devices_using_lsblk()) {
			if (dev.has_linux_filesystem()){
				device_list.add(dev);
			}
		}

		string[,] grid = new string[device_list.size+1,6];
		bool[] right_align = { false, false, false, true, true, false};

		int row = 0;
		int col = -1;
		grid[row, ++col] = _("Num");
		grid[row, ++col] = "";
		grid[row, ++col] = _("Device");
		//grid[row, ++col] = _("UUID");
		grid[row, ++col] = _("Size");
		grid[row, ++col] = _("Type");
		grid[row, ++col] = _("Label");
		row++;

		foreach(var pi in device_list) {
			col = -1;
			grid[row, ++col] = "%d".printf(row - 1);
			grid[row, ++col] = ">";
			grid[row, ++col] = "%s".printf(pi.device_name_with_parent);
			//grid[row, ++col] = "%s".printf(pi.uuid);
			grid[row, ++col] = "%s".printf((pi.size_bytes > 0) ? format_file_size(pi.size_bytes): "?? GB");
			grid[row, ++col] = "%s".printf(pi.fstype);
			grid[row, ++col] = "%s".printf(pi.label);
			row++;
		}

		print_grid(grid, right_align);

		return device_list;
	}

	private Gee.ArrayList<Device> list_grub_devices(bool print_to_console = true){
		//add devices
		var grub_device_list = new Gee.ArrayList<Device>();
		foreach(var dev in Device.get_block_devices_using_lsblk()) {
			if (dev.type == "disk"){
				grub_device_list.add(dev);
			}
			else if (dev.type == "part"){ 
				if (dev.has_linux_filesystem()){
					grub_device_list.add(dev);
				}
			}
			// skip crypt/loop
		}

		/*Note: Lists are already sorted. No need to sort again */

		string[,] grid = new string[grub_device_list.size+1,4];
		bool[] right_align = { false, false, false, false };

		int row = 0;
		int col = -1;
		grid[row, ++col] = _("Num");
		grid[row, ++col] = "";
		grid[row, ++col] = _("Device");
		grid[row, ++col] = _("Description");
		row++;

		string desc = "";
		foreach(Device pi in grub_device_list) {
			col = -1;
			grid[row, ++col] = "%d".printf(row - 1);
			grid[row, ++col] = ">";
			grid[row, ++col] = "%s".printf(pi.short_name_with_alias);

			if (pi.type == "disk"){
				desc = "%s".printf(((pi.vendor.length > 0)||(pi.model.length > 0)) ? (pi.vendor + " " + pi.model  + " [MBR]") : "");
			}
			else{
				desc = "%5s, ".printf(pi.fstype);
				desc += "%10s".printf((pi.size_bytes > 0) ? "%s GB".printf(pi.size) : "?? GB");
				desc += "%s".printf((pi.label.length > 0) ? ", " + pi.label : "");
			}
			grid[row, ++col] = "%s".printf(desc);
			row++;
		}

		print_grid(grid, right_align);

		return grub_device_list;
	}

	private void print_grid(string[,] grid, bool[] right_align, bool has_header = true){
		int[] col_width = new int[grid.length[1]];

		for(int col=0; col<grid.length[1]; col++){
			for(int row=0; row<grid.length[0]; row++){
				if (grid[row,col].length > col_width[col]){
					col_width[col] = grid[row,col].length;
				}
			}
		}

		for(int row=0; row<grid.length[0]; row++){
			for(int col=0; col<grid.length[1]; col++){
				string fmt = "%" + (right_align[col] ? "+" : "-") + col_width[col].to_string() + "s  ";
				stdout.printf(fmt.printf(grid[row,col]));
			}
			stdout.printf("\n");

			if (has_header && (row == 0)){
				stdout.printf(string.nfill(78, '-'));
				stdout.printf("\n");
			}
		}
	}

	// create

	private bool create_snapshot(bool ondemand){
		select_snapshot_device(false);
		return App.create_snapshot(ondemand, null);
	}
	
	// restore
	
	private bool restore_snapshot(){

		select_snapshot_device(true);

		select_snapshot_for_restore();
		
		stdout.printf("\n\n");
		log_msg(string.nfill(78, '*'));
		stdout.printf(_("To restore with default options, press the ENTER key for all prompts!") + "\n");
		log_msg(string.nfill(78, '*'));
		stdout.printf(_("\nPress ENTER to continue..."));
		stdout.flush();
		stdin.read_line();

		init_mounts();
		
		if (!App.btrfs_mode){

			map_devices();

			select_grub_device();
		}

		confirm_restore();

		bool ok = App.mount_target_devices();
		if (!ok){
			return false;
		}

		return App.restore_snapshot(null);
	}

	private void select_snapshot_device(bool prompt_if_empty){

		if (App.mirror_system){
			return;
		}

		var list = new Gee.ArrayList<Device>();
		foreach(var pi in App.partitions){
			if (pi.has_linux_filesystem()){
				list.add(pi);
			}
		}
					
		if ((App.repo.device == null) || (prompt_if_empty && (App.repo.snapshots.size == 0))){
			//prompt user for backup device
			log_msg("");

			if (App.cmd_scripted){
				
				if (App.repo.device == null){
					if (App.backup_uuid.length == 0){
						log_debug("device is null");
						string status_message = _("Snapshot device not selected");
						log_msg(status_message);
					}
					else{
						string status_message = _("Snapshot device not available");
						string status_details = _("Device not found") + ": UUID='%s'".printf(App.backup_uuid);
						log_msg(status_message);
						log_msg(status_details);
					}
				}

				App.exit_app(1);
			}

			log_msg(_("Select backup device") + ":\n");
			list_devices(list);
			log_msg("");

			Device dev = null;
			int attempts = 0;
			while (dev == null){
				attempts++;
				if (attempts > 3) { break; }
				stdout.printf("" +
					_("Enter device name or number (a=Abort)") + ": ");
				stdout.flush();

				dev = read_stdin_device(list, "");

				if (App.btrfs_mode && !App.check_device_for_backup(dev, true)){
					log_error(_("Selected snapshot device is not a system disk"));
					log_error(_("Select BTRFS system disk with root subvolume (@)"));
					dev = null;
				}
			}

			log_msg("");
			
			if (dev == null){
				log_error(_("Failed to get input from user in 3 attempts"));
				log_msg(_("Aborted."));
				App.exit_app(1);
			}

			App.repo = new SnapshotRepo.from_device(dev, null, App.btrfs_mode);
			if (!App.repo.available()){
				App.exit_app(1);
			}
		}
	}

	private Snapshot? select_snapshot(){

		Snapshot selected_snapshot = null;
		
		log_debug("AppConsole: select_snapshot()");
		
		if (App.mirror_system){
			return null;
		}
		
		if (App.cmd_snapshot.length > 0){

			//check command line arguments
			bool found = false;
			foreach(var bak in App.repo.snapshots) {
				if (bak.name == App.cmd_snapshot){
					return bak;
				}
			}

			//check if found
			if (!found){
				log_error(_("Could not find snapshot") + ": '%s'".printf(App.cmd_snapshot));
				return null;
			}
		}

		//prompt user for snapshot
		if (selected_snapshot == null){

			if (!App.repo.has_snapshots()){
				log_error(_("No snapshots found on device") + ": '%s'".printf(App.repo.device.device));
				App.exit_app(0);
				return null;
			}

			log_msg("");
			log_msg(_("Select snapshot") + ":\n");
			list_snapshots(true);
			log_msg("");

			int attempts = 0;
			while (selected_snapshot == null){
				attempts++;
				if (attempts > 3) { break; }
				stdout.printf(_("Enter snapshot number (a=Abort, p=Previous, n=Next)") + ": ");
				stdout.flush();
				selected_snapshot = read_stdin_snapshot();
			}
			log_msg("");
			
			if (selected_snapshot == null){
				log_error(_("Failed to get input from user in 3 attempts"));
				log_msg(_("Aborted."));
				App.exit_app(0);
			}
		}

		return selected_snapshot;
	}

	private void select_snapshot_for_restore(){
		App.snapshot_to_restore = select_snapshot();
		if (App.snapshot_to_restore == null){
			log_error("Snapshot not selected");
			App.exit_app(1);
		}
	}

	private void select_snapshot_for_deletion(){
		App.snapshot_to_delete = select_snapshot();
		if (App.snapshot_to_delete == null){
			log_error("Snapshot not selected");
			App.exit_app(1);
		}
	}
	
	private void init_mounts(){

		log_debug("AppConsole: init_mounts()");
		
		App.init_mount_list();

		// remove mount points which will remain on root fs
		for(int i = App.mount_list.size-1; i >= 0; i--){
			
			var entry = App.mount_list[i];
			
			if (entry.device == null){
				App.mount_list.remove(entry);
			}
		}
	}

	private void map_devices(){

		log_debug("AppConsole: map_devices()");
		
		if (App.cmd_target_device.length > 0){

			//check command line arguments
			bool found = false;
			foreach(Device pi in App.partitions) {
				
				if (!pi.has_linux_filesystem()) { continue; }
				
				if ((pi.device == App.cmd_target_device)||((pi.uuid == App.cmd_target_device))){
					App.dst_root = pi;
					found = true;
					break;
				}
				else {
					foreach(string symlink in pi.symlinks){
						if (symlink == App.cmd_target_device){
							App.dst_root = pi;
							found = true;
							break;
						}
					}
					if (found){ break; }
				}
			}

			//check if found
			if (!found){
				log_error(_("Could not find device") + ": '%s'".printf(App.cmd_target_device));
				App.exit_app(1);
				return;
			}
		}

		for(int i = 0; i < App.mount_list.size; i++){
			
			MountEntry mnt = App.mount_list[i];
			Device dev = null;
			string default_device = "";

			log_debug("selecting: %s".printf(mnt.mount_point));

			// no need to ask user to map remaining devices if restoring same system
			if ((App.dst_root != null) && (App.sys_root != null)
				&& (App.dst_root.uuid == App.sys_root.uuid)){
					
				break;
			}

			if (App.mirror_system){
				default_device = (App.dst_root != null) ? App.dst_root.device : "";
			}
			else{
				if (mnt.device != null){
					default_device = mnt.device.device;
				}
				else{
					default_device = (App.dst_root != null) ? App.dst_root.device : "";
				}
			}

			//prompt user for device
			if (dev == null){
				log_msg("");
				log_msg(_("Select '%s' device (default = %s)").printf(
					mnt.mount_point, default_device) + ":\n");
				var device_list = list_all_devices();
				log_msg("");

				int attempts = 0;
				while (dev == null){
					attempts++;
					if (attempts > 3) { break; }
					
					stdout.printf("" +
						_("[ENTER = Default (%s), r = Root device, a = Abort]").printf(default_device) + "\n\n");
						
					stdout.printf(
						_("Enter device name or number")
							+ ": ");
							
					stdout.flush();
					dev = read_stdin_device_mounts(device_list, mnt);
				}
				log_msg("");

				if (dev == null){
					log_error(_("Failed to get input from user in 3 attempts"));
					log_msg(_("Aborted."));
					App.exit_app(0);
				}
			}

			if (dev != null){

				log_debug("selected: %s".printf(dev.uuid));
				
				mnt.device = dev;

				log_msg(string.nfill(78, '*'));
				
				if ((mnt.mount_point != "/")
					&& (App.dst_root != null)
					&& (dev.device == App.dst_root.device)){
						
					log_msg(_("'%s' will be on root device").printf(mnt.mount_point), true);
				}
				else{
					log_msg(_("'%s' will be on '%s'").printf(
						mnt.mount_point, mnt.device.short_name_with_alias), true);
						
					//log_debug("UUID=%s".printf(dst_root.uuid));
				}
				log_msg(string.nfill(78, '*'));
			}
		
		}
	}

	private void select_grub_device(){

		string grub_device_default = App.grub_device;
		bool grub_reinstall_default = App.reinstall_grub2;
		App.reinstall_grub2 = false;
		App.grub_device = "";
		
		if (App.cmd_grub_device.length > 0){

			log_debug("Grub device is specified as command argument");
			
			//check command line arguments
			bool found = false;
			var device_list = list_grub_devices(false);
			
			foreach(Device dev in device_list) {
				
				if ((dev.device == App.cmd_grub_device)
					||((dev.uuid.length > 0) && (dev.uuid == App.cmd_grub_device))){

					App.grub_device = dev.device;
					found = true;
					break;
				}
				else {
					if (dev.type == "part"){
						foreach(string symlink in dev.symlinks){
							if (symlink == App.cmd_grub_device){
								App.grub_device = dev.device;
								found = true;
								break;
							}
						}
						if (found){ break; }
					}
				}
			}

			//check if found
			if (!found){
				log_error(_("Could not find device") + ": '%s'".printf(App.cmd_grub_device));
				App.exit_app(1);
				return;
			}
		}
		
		if (App.mirror_system){
			App.reinstall_grub2 = true;
		}
		else {
			if ((App.cmd_skip_grub == false) && (App.reinstall_grub2 == false)){
				log_msg("");

				int attempts = 0;
				while ((App.cmd_skip_grub == false) && (App.reinstall_grub2 == false)){
					attempts++;
					if (attempts > 3) { break; }
					stdout.printf(_("Re-install GRUB2 bootloader?") + (grub_reinstall_default ? " (recommended)" : "") + " (y/n): ");
					stdout.flush();
					read_stdin_grub_install(grub_reinstall_default);
				}

				if ((App.cmd_skip_grub == false) && (App.reinstall_grub2 == false)){
					log_error(_("Failed to get input from user in 3 attempts"));
					log_msg(_("Aborted."));
					App.exit_app(0);
				}
			}
		}

		if ((App.reinstall_grub2) && (App.grub_device.length == 0)){
			
			log_msg("");
			log_msg(_("Select GRUB device") + ":\n");
			var device_list = list_grub_devices();
			log_msg("");

			int attempts = 0;
			while (App.grub_device.length == 0){
				
				attempts++;
				if (attempts > 3) { break; }

				if (grub_device_default.length > 0){
					stdout.printf("" +
						_("[ENTER = Default (%s), a = Abort]").printf(grub_device_default) + "\n\n");
				}

				stdout.printf(_("Enter device name or number (a=Abort)") + ": ");
				stdout.flush();

				// TODO: provide option for default boot device

				var list = new Gee.ArrayList<Device>();
				foreach(var pi in App.partitions){
					if (pi.has_linux_filesystem()){
						list.add(pi);
					}
				}
				
				Device dev = read_stdin_device(device_list, grub_device_default);
				if (dev != null) { App.grub_device = dev.device; }
			}
			
			log_msg("");

			if (App.grub_device.length == 0){
				
				log_error(_("Failed to get input from user in 3 attempts"));
				log_msg(_("Aborted."));
				App.exit_app(0);
			}
		}

		if ((App.reinstall_grub2) && (App.grub_device.length > 0)){
			
			log_msg(string.nfill(78, '*'));
			log_msg(_("GRUB Device") + ": %s".printf(App.grub_device));
			log_msg(string.nfill(78, '*'));
		}
		else{
			log_msg(string.nfill(78, '*'));
			log_msg(_("GRUB will NOT be reinstalled"));
			log_msg(string.nfill(78, '*'));
		}
	}

	private void confirm_restore(){
		
		if (App.cmd_confirm == false){

			string msg_devices = "";
			string msg_reboot = "";
			string msg_disclaimer = "";

			App.get_restore_messages(
				false, out msg_devices, out msg_reboot,
				out msg_disclaimer);

			int attempts = 0;
			while (App.cmd_confirm == false){
				attempts++;
				if (attempts > 3) { break; }
				stdout.printf(_("Continue with restore? (y/n): "));
				stdout.flush();
				read_stdin_restore_confirm();
			}

			if (App.cmd_confirm == false){
				log_error(_("Failed to get input from user in 3 attempts"));
				log_msg(_("Aborted."));
				App.exit_app(0);
			}
		}
	}
	
	private Device? read_stdin_device(Gee.ArrayList<Device> device_list, string device_default){
		
		var counter = new TimeoutCounter();
		counter.exit_on_timeout();
		string? line = stdin.read_line();
		counter.stop();

		line = (line != null) ? line.strip() : "";

		Device selected_device = null;

		if (line.down() == "a"){
			log_msg(_("Aborted."));
			App.exit_app(0);
		}
		else if ((line == null)||(line.length == 0)||(line.down() == "c")||(line.down() == "d")){
			if (device_default.length > 0){
				selected_device = Device.get_device_by_name(device_default);
			}
			else{
				log_error("Invalid input");
			}
		}
		else if (line.contains("/")){
			selected_device = Device.get_device_by_name(line);
			if (selected_device == null){
				log_error("Invalid input");
			}
		}
		else{
			selected_device = get_device_from_index(device_list, line);
			if (selected_device == null){
				log_error("Invalid input");
			}
		}

		return selected_device;
	}

	private Device? read_stdin_device_mounts(Gee.ArrayList<Device> device_list, MountEntry mnt){
		var counter = new TimeoutCounter();
		counter.exit_on_timeout();
		string? line = stdin.read_line();
		counter.stop();

		line = (line != null) ? line.strip() : "";

		Device selected_device = null;

		if ((line == null)||(line.length == 0)||(line.down() == "c")||(line.down() == "d")){
			//set default
			if (App.mirror_system){
				return App.dst_root; //root device
			}
			else{
				return mnt.device; //keep current
			}
		}
		else if (line.down() == "a"){
			log_msg("Aborted.");
			App.exit_app(0);
		}
		else if ((line.down() == "n")||(line.down() == "r")){
			return App.dst_root; //root device
		}
		else if (line.contains("/")){
			selected_device = Device.get_device_by_name(line);
			if (selected_device == null){
				log_error("Invalid input");
			}
		}
		else{
			selected_device = get_device_from_index(device_list, line);
			if (selected_device == null){
				log_error("Invalid input");
			}
		}

		return selected_device;
	}

	private Device? get_device_from_index(Gee.ArrayList<Device> device_list, string index_string){
		int64 index;
		if (int64.try_parse(index_string, out index)){
			int i = -1;
			foreach(Device pi in device_list) {
				if (++i == index){
					return pi;
				}
			}
		}

		return null;
	}

	private Snapshot read_stdin_snapshot(){
		var counter = new TimeoutCounter();
		counter.exit_on_timeout();
		string? line = stdin.read_line();
		counter.stop();

		line = (line != null) ? line.strip() : "";

		Snapshot selected_snapshot = null;

		if (line.down() == "a"){
			log_msg("Aborted.");
			App.exit_app(0);
		}
		else if (line.down() == "p"){
			snapshot_list_start_index -= 10;
			if (snapshot_list_start_index < 0){
				snapshot_list_start_index = 0;
			}
			log_msg("");
			list_snapshots(true);
			log_msg("");
		}
		else if (line.down() == "n"){
			if ((snapshot_list_start_index + 10) < App.repo.snapshots.size){
				snapshot_list_start_index += 10;
			}
			log_msg("");
			list_snapshots(true);
			log_msg("");
		}
		else if (line.contains("_")||line.contains("-")){
			//TODO: read name
			log_error("Invalid input");
		}
		else if ((line == null)||(line.length == 0)){
			log_error("Invalid input");
		}
		else{
			int64 index;
			if (int64.try_parse(line, out index)){
				if (index < App.repo.snapshots.size){
					selected_snapshot = App.repo.snapshots[(int) index];
				}
				else{
					log_error("Invalid input");
				}
			}
			else{
				log_error("Invalid input");
			}
		}

		return selected_snapshot;
	}

	private bool read_stdin_grub_install(bool reinstall_default){
		var counter = new TimeoutCounter();
		counter.exit_on_timeout();
		string? line = stdin.read_line();
		counter.stop();

		line = (line != null) ? line.strip() : line;

		if ((line == null)||(line.length == 0)){
			App.reinstall_grub2 = reinstall_default;
			App.cmd_skip_grub = !reinstall_default;
			return true;
		}
		else if (line.down() == "a"){
			log_msg("Aborted.");
			App.exit_app(0);
			return true;
		}
		else if (line.down() == "y"){
			App.cmd_skip_grub = false;
			App.reinstall_grub2 = true;
			return true;
		}
		else if (line.down() == "n"){
			App.cmd_skip_grub = true;
			App.reinstall_grub2 = false;
			return true;
		}
		else if ((line == null)||(line.length == 0)){
			log_error("Invalid input");
			return false;
		}
		else{
			log_error("Invalid input");
			return false;
		}
	}

	private bool read_stdin_restore_confirm(){
		var counter = new TimeoutCounter();
		counter.exit_on_timeout();
		
		string? line = stdin.read_line();
		counter.stop();

		line = (line != null) ? line.strip() : "";

		if ((line.down() == "a")||(line.down() == "n")){
			log_msg("Aborted.");
			App.exit_app(0);
			return true;
		}
		else if ((line == null)||(line.length == 0)){
			log_error("Invalid input");
			return false;
		}
		else if (line.down() == "y"){
			App.cmd_confirm = true;
			return true;
		}
		else if ((line == null)||(line.length == 0)){
			log_error("Invalid input");
			return false;
		}
		else{
			log_error("Invalid input");
			return false;
		}
	}

	// delete

	public bool delete_snapshot(){

		select_snapshot_device(true);

		select_snapshot_for_deletion();

		if (App.snapshot_to_delete != null){
			App.snapshot_to_delete.remove(true);
		}

		return true;
	}

	public bool delete_all_snapshots(){
		
		select_snapshot_device(true);
		
		//return App.repo.remove_all();
		
		foreach(var snap in App.repo.snapshots){
			snap.remove(true);
		}

		return true;
	}

}

