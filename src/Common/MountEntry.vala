using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.Devices;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class MountEntry : GLib.Object{
	public Device device = null;
	public string mount_point = "";

	public MountEntry(Device device, string mount_point){
		this.device = device;
		this.mount_point = mount_point;
	}
}
