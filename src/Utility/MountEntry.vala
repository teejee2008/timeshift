using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;
using Json;

public class MountEntry : GLib.Object{
	
	public Device device = null;
	public string mount_point = "";
	public string mount_options = "";
	public bool read_only = false;
	
	public MountEntry(Device? device, string mount_point, string mount_options){
		this.device = device;
		this.mount_point = mount_point;
		this.mount_options = mount_options;

		foreach (string option in mount_options.split(",")) {
			option = option.strip();

			if ("ro" == option) {
				this.read_only = true;
				break;
			} else if ("rw" == option) {
				this.read_only = false;
				break;
			} 
		}
	}

	public string subvolume_name(){
		
		if (mount_options.contains("subvol=")){
			
			string txt = mount_options.split("subvol=")[1].split(",")[0].strip();
			
			if (txt.has_prefix("/") && (txt.split("/").length == 2)){
				txt = txt.split("/")[1];
			}
			
			return txt;
		}
		else{
			return "";
		}
	}

	public string lvm_name(){
		if ((device != null) && (device.type == "lvm") && (device.mapped_name.length > 0)){
			return device.mapped_name.strip();
		}
		else{
			return "";
		}
	}

	public static MountEntry? find_entry_by_mount_point(
		Gee.ArrayList<MountEntry> entries, string mount_path){
			
		foreach(var entry in entries){
			if (entry.mount_point == mount_path){
				return entry;
			}
		}
		return null;
	}
}
