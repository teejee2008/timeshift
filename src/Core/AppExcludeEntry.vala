using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.Devices;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class AppExcludeEntry : GLib.Object{
	public string relpath = "";
	public bool is_include = false;
	public bool is_file = false;
	public bool enabled = false;

	public AppExcludeEntry(string _relpath, bool _is_file, bool _is_include = false){
		relpath = _relpath;
		is_file = _is_file;
		is_include = _is_include;
	}

	public string pattern(bool root_home = false){
		string str = (is_include) ? "+ " : "";
		str += (root_home) ? "/root" : "/home/*";
		str += relpath[1:relpath.length];
		str += (is_file) ? "" : "/**";
		return str.strip();
	}

}
