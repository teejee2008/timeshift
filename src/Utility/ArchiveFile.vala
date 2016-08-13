/*
 * ArchiveFile.vala
 *
 * Copyright 2015 Tony George <teejee2008@gmail.com>
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
using Json;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class ArchiveFile : FileItem {

	// additional properties
	public int64 archive_size = 0;
	public int64 archive_unpacked_size = 0;
	public double compression_ratio = 0.0;
	public string archive_type = "";
	public string archive_method = "";
	public bool archive_is_encrypted = false;
	public bool archive_is_solid = false;
	public int archive_blocks = 0;
	public int64 archive_header_size = 0;
	public DateTime archive_modified;

	public string password = "";
	public string keyfile = "";
	
	// extraction
	public Gee.ArrayList<string> extract_list;
	
	// temp
	public string temp_dir = "";
	public string script_file = "";
	public string log_file = "";

	public ArchiveFile(string archive_file_path = "") {
		base.from_path_and_type(archive_file_path, FileType.REGULAR);
		is_archive = true;
		
		//this.tag = this;
		
		extract_list = new Gee.ArrayList<string>();
		temp_dir = TEMP_DIR + "/" + timestamp_for_path();
		log_file = temp_dir + "/log.txt";
		script_file = temp_dir + "/convert.sh";
		dir_create (temp_dir);
	}

	public void add_items(Gee.ArrayList<string> item_list){
		if (item_list.size > 0){
			foreach(string item in item_list){
				add_child_from_disk(item);
			}
		}
	}
}

