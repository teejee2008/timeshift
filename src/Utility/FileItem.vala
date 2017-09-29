/*
 * FileItem.vala
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

public class FileItem : GLib.Object,Gee.Comparable<FileItem> {
	public string file_name = "";
	public string file_location = "";
	public string file_path = "";
	public string file_path_prefix = "";
	public FileType file_type = FileType.REGULAR;
	public DateTime modified;
	public string permissions = "";
	public string owner_user = "";
	public string owner_group = "";
	public string content_type = "";
	public string file_status = ""; 

	public bool is_selected = false;
	public bool is_symlink = false;
	public string symlink_target = "";
	public bool is_archive = false;
	public bool is_stale = false;

	public FileItem parent;
	public Gee.HashMap<string, FileItem> children = new Gee.HashMap<string, FileItem>();
	public FileItem? source_archive;

	public GLib.Object? tag;
	//public Gtk.TreeIter? treeiter;
	
	public long file_count = 0;
	public long dir_count = 0;
	private int64 _size = 0;
	private int64 _size_compressed = 0;

	public long file_count_total = 0;
	public long dir_count_total = 0;

	//public string icon_name = "gtk-file";
	public GLib.Icon icon;

	public bool is_dummy = false;

	public static string[] archive_extensions = {
		".tar",
		".tar.gz", ".tgz",
		".tar.bzip2", ".tar.bz2", ".tbz", ".tbz2", ".tb2",
		".tar.lzma", ".tar.lz", ".tlz",
		".tar.xz", ".txz",
		".tar.7z",
		".tar.zip",
		".7z", ".lzma",
		".bz2", ".bzip2",
		".gz", ".gzip",
		".zip", ".rar", ".cab", ".arj", ".z", ".taz", ".cpio",
		".rpm", ".deb",
		".lzh", ".lha",
		".chm", ".chw", ".hxs",
		".iso", ".dmg", ".xar", ".hfs", ".ntfs", ".fat", ".vhd", ".mbr",
		".wim", ".swm", ".squashfs", ".cramfs", ".scap"
	};
		

	// contructors -------------------------------
	
	public FileItem(string name = "New Archive") {
		file_name = name;
	}

	public FileItem.dummy(FileType _file_type) {
		is_dummy = true;
		file_type = _file_type;
	}

	public FileItem.dummy_root() {
		file_name = "dummy";
		file_location = "";
	}

	public FileItem.from_path_and_type(string _file_path, FileType _file_type) {
		file_path = _file_path;
		file_name = file_basename(_file_path);
		file_location = file_parent(_file_path);
		file_type = _file_type;
	}

	// properties --------------------------------------
	
	public int64 size {
		get{
			return _size;
		}
	}

	public int64 size_compressed {
		get{
			return _size_compressed;
		}
	}

	// helpers ---------------

	public int compare_to(FileItem b){
		if (this.file_type != b.file_type) {
			if (this.file_type == FileType.DIRECTORY) {
				return -1;
			}
			else {
				return +1;
			}
		}
		else {
			//if (view.sort_column_desc) {
				return strcmp(this.file_name.down(), b.file_name.down());
			//}
			//else {
				//return -1 * strcmp(a.file_name.down(), b.file_name.down());
			//}
		}
	}
			
	// instance methods ------------------------------------------

	public FileItem add_child_from_disk(string item_file_path, int depth = -1) {
		FileItem item = null;

		//log_debug("add_child_from_disk: %02d: %s".printf(depth, item_file_path));
		
		try {
			FileEnumerator enumerator;
			FileInfo info;
			File file = File.parse_name (item_file_path);

			if (file.query_exists()) {

				// query file type
				var item_file_type = file.query_file_type(FileQueryInfoFlags.NONE);
				
				//add item
				item = this.add_child(item_file_path, item_file_type, 0, 0, true);
				
				if ((item.file_type == FileType.DIRECTORY) && !item.is_symlink) {
					if (depth != 0){
						//recurse children
						enumerator = file.enumerate_children ("%s".printf(FileAttribute.STANDARD_NAME), 0);
						while ((info = enumerator.next_file()) != null) {
							string child_path = "%s/%s".printf(item_file_path, info.get_name());
							item.add_child_from_disk(child_path, depth - 1);
						}
					}
				}
			}
		}
		catch (Error e) {
			log_error (e.message);
		}

		return item;
	}

	public FileItem add_descendant(
		string _file_path,
		FileType ? _file_type,
		int64 item_size,
		int64 item_size_compressed) {

		//log_debug("add_descendant=%s".printf(_file_path));
		
		string item_path = _file_path.strip();
		FileType item_type = (_file_type == null) ? FileType.REGULAR : _file_type;

		if (item_path.has_suffix("/")) {
			item_path = item_path[0:item_path.length - 1];
			item_type = FileType.DIRECTORY;
		}

		if (item_path.has_prefix("/")) {
			item_path = item_path[1:item_path.length];
		}

		string dir_name = "";
		string dir_path = "";

		//create dirs and find parent dir
		FileItem current_dir = this;
		string[] arr = item_path.split("/");
		for (int i = 0; i < arr.length - 1; i++) {
			//get dir name
			dir_name = arr[i];

			//add dir
			if (!current_dir.children.keys.contains(dir_name)) {
				if ((current_dir == this) && current_dir.is_archive){
					dir_path = "";
				}
				else {
					dir_path = current_dir.file_path + "/";
				}
				dir_path = "%s%s".printf(dir_path, dir_name);
				current_dir.add_child(dir_path, FileType.DIRECTORY, 0, 0, false);
			}

			current_dir = current_dir.children[dir_name];
		}

		//get item name
		string item_name = arr[arr.length - 1];

		//add item
		if (!current_dir.children.keys.contains(item_name)) {
			
			//log_debug("add_descendant: add_child()");
			
			current_dir.add_child(
				item_path, item_type, item_size, item_size_compressed, false);
		}

		//log_debug("add_descendant: finished: %s".printf(item_path));
		
		return current_dir.children[item_name];
	}

	public FileItem add_child(
		string item_file_path,
		FileType item_file_type,
		int64 item_size,
		int64 item_size_compressed,
		bool item_query_file_info){
		
		// create new item ------------------------------

		//log_debug("add_child: %s".printf(item_file_path));
		
		FileItem item = new FileItem.from_path_and_type(item_file_path, item_file_type);
		//item.tag = this.tag;

		foreach(var ext in archive_extensions){
			if (item_file_path.has_suffix(ext)) {
				item = new ArchiveFile(item_file_path);
				item.is_archive = true;
				break;
			}
		}

		// check existing ----------------------------

		bool existing_file = false;
		if (!children.has_key(item.file_name)){
			children[item.file_name] = item;

			//set parent
			item.parent = this;
		}
		else{
			existing_file = true;
			item = this.children[item.file_name];

			// mark as fresh
			item.is_stale = false;
		}

		// copy prefix from parent
		item.file_path_prefix = this.file_path_prefix;

		// query file properties
		if (item_query_file_info){
			//log_debug("add_child: query_file_info()");
			item.query_file_info();
		}

		if (item_file_type == FileType.REGULAR) {

			//log_debug("add_child: regular file");
			
			// set file sizes
			if (item_size > 0) {
				item._size = item_size;
			}
			if (item_size_compressed > 0) {
				item._size_compressed = item_size_compressed;
			}

			// update file counts
			if (!existing_file){
				this.file_count++;
				this.file_count_total++;
				this._size += item_size;
				this._size_compressed += item_size_compressed;

				// update file count and size of parent dirs
				var temp = this;
				while (temp.parent != null) {
					temp.parent.file_count_total++;
					temp.parent._size += item_size;
					temp.parent._size_compressed += item_size_compressed;
					temp = temp.parent;
				}
			}
		}
		else if (item_file_type == FileType.DIRECTORY) {

			//log_debug("add_child: directory");
			
			if (!existing_file){
	
				// update dir counts
				this.dir_count++;
				this.dir_count_total++;
				//this.size += _size;
				//size will be updated when children are added

				// update dir count of parent dirs
				var temp = this;
				while (temp.parent != null) {
					temp.parent.dir_count_total++;
					temp = temp.parent;
				}
			}
		}
		
		//log_debug("add_child: finished: fc=%lld dc=%lld path=%s".printf(
		//	file_count, dir_count, item_file_path));
		
		return item;
	}

	public void query_file_info() {
		
		try {
			FileInfo info;
			File file = File.parse_name (file_path);

			if (file.query_exists()) {

				// get type without following symlinks
				
				info = file.query_info("%s,%s,%s".printf(
				                           FileAttribute.STANDARD_TYPE,
				                           FileAttribute.STANDARD_ICON,
				                           FileAttribute.STANDARD_SYMLINK_TARGET),
				                       FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

				var item_file_type = info.get_file_type();

				this.icon = info.get_icon();
				
				if (item_file_type == FileType.SYMBOLIC_LINK) {
					//this.icon = GLib.Icon.new_for_string("emblem-symbolic-link");
					this.is_symlink = true;
					this.symlink_target = info.get_symlink_target();
				}
				else {
					
					this.is_symlink = false;
					this.symlink_target = "";

					if (item_file_type == FileType.REGULAR){
						//log_msg(file_basename(file_path) + " (gicon): " + icon.to_string());

						/*var themed_icon = (GLib.ThemedIcon) icon;
						
						string txt = "-> ";
						foreach(var name in themed_icon.names){
							txt += ", " + name;
						}
						log_msg(txt);*/
					}
				}

				// get file info - follow symlinks
				
				info = file.query_info("%s,%s,%s,%s,%s,%s,%s,%s".printf(
				                           FileAttribute.STANDARD_TYPE,
				                           FileAttribute.STANDARD_SIZE,
				                           FileAttribute.STANDARD_ICON,
				                           FileAttribute.STANDARD_CONTENT_TYPE,
				                           FileAttribute.TIME_MODIFIED,
				                           FileAttribute.OWNER_USER,
				                           FileAttribute.OWNER_GROUP,
				                           FileAttribute.FILESYSTEM_FREE
				                           ), 0);

				if (this.is_symlink){
					// get icon for the resolved file
					this.icon = info.get_icon();
				}

				// file type resolved
				this.file_type = info.get_file_type();

				// content type
				this.content_type = info.get_content_type();
				
				// size
				if (!this.is_symlink && (this.file_type == FileType.REGULAR)) {
					this._size = info.get_size();
				}

				// modified
				this.modified = (new DateTime.from_timeval_utc(info.get_modification_time())).to_local();

				// owner_user
				this.owner_user = info.get_attribute_string(FileAttribute.OWNER_USER);

				// owner_group
				this.owner_group = info.get_attribute_string(FileAttribute.OWNER_GROUP);
	
			}
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	public void query_children(int depth = -1) {
		FileEnumerator enumerator;
		FileInfo info;
		File file = File.parse_name (file_path);

		if (!file.query_exists()) {
			return;
		}
		
		if (file_type == FileType.DIRECTORY) {
			if (depth == 0){
				return;
			}
				
			try{
				// mark existing children as stale
				foreach(var child in children.values){
					child.is_stale = true;
				}

				// recurse children
				enumerator = file.enumerate_children ("%s".printf(FileAttribute.STANDARD_NAME), 0);
				while ((info = enumerator.next_file()) != null) {
					string child_name = info.get_name();
					string child_path = GLib.Path.build_filename(file_path, child_name);
					this.add_child_from_disk(child_path, depth - 1);
				}

				// remove stale children
				var list = new Gee.ArrayList<string>();
				foreach(var key in children.keys){
					if (children[key].is_stale){
						list.add(key);
					}
				}
				foreach(var key in list){
					//log_debug("Unset:%s".printf(key));
					children.unset(key);
				}
			}
			catch (Error e) {
				log_error (e.message);
			}
		}
	}
	
	public void clear_children() {
		this.children.clear();
	}
	
	public FileItem remove_child(string child_name) {
		FileItem child = null;

		if (this.children.has_key(child_name)) {
			child = this.children[child_name];
			this.children.unset(child_name);

			if (child.file_type == FileType.REGULAR) {
				//update file counts
				this.file_count--;
				this.file_count_total--;

				//subtract child size
				this._size -= child.size;
				this._size_compressed -= child.size_compressed;

				//update file count and size of parent dirs
				var temp = this;
				while (temp.parent != null) {
					temp.parent.file_count_total--;

					temp.parent._size -= child.size;
					temp.parent._size_compressed -= child.size_compressed;

					temp = temp.parent;
				}
			}
			else {
				//update dir counts
				this.dir_count--;
				this.dir_count_total--;

				//subtract child counts
				this.file_count_total -= child.file_count_total;
				this.dir_count_total -= child.dir_count_total;
				this._size -= child.size;
				this._size_compressed -= child.size_compressed;

				//update dir count of parent dirs
				var temp = this;
				while (temp.parent != null) {
					temp.parent.dir_count_total--;

					temp.parent.file_count_total -= child.file_count_total;
					temp.parent.dir_count_total -= child.dir_count_total;
					temp.parent._size -= child.size;
					temp.parent._size_compressed -= child.size_compressed;

					temp = temp.parent;
				}
			}
		}

		//log_debug("%3ld %3ld %s".printf(file_count, dir_count, file_path));

		return child;
	}

	public FileItem? find_descendant(string path){
		var child = this;

		foreach(var part in path.split("/")){

			// query children if needed
			if (child.children.size == 0){
				child.query_children(1);
				if (child.children.size == 0){
					break;
				}
			}
		
			if (child.children.has_key(part)){
				child = child.children[part];
			}
		}

		if (child.file_path == path){
			return child;
		}
		else{
			return null;
		}
	}

	public void set_file_path_prefix(string prefix){
		file_path_prefix = prefix;
		foreach(var child in this.children.values){
			child.set_file_path_prefix(prefix);
		}
	}
	
	public void print(int level) {

		if (level == 0) {
			stdout.printf("\n");
			stdout.flush();
		}

		stdout.printf("%s%s\n".printf(string.nfill(level * 2, ' '), file_name));
		stdout.flush();

		foreach (var key in this.children.keys) {
			this.children[key].print(level + 1);
		}
	}

	public Gee.ArrayList<FileItem> get_children_sorted(){
		var list = new Gee.ArrayList<FileItem>();
		
		foreach(string key in children.keys) {
			var item = children[key];
			list.add(item);
		}

		list.sort((a, b) => {
			if ((a.file_type == FileType.DIRECTORY) && (b.file_type != FileType.DIRECTORY)){
				return -1;
			}
			else if ((a.file_type != FileType.DIRECTORY) && (b.file_type == FileType.DIRECTORY)){
				return 1;
			}
			else{
				return strcmp(a.file_name.down(), b.file_name.down());
			}
		});
		
		return list;
	}
}



