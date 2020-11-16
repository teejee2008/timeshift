/*
 * FileItem.vala
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

	public long file_count = 0;
	public long dir_count = 0;
	private int64 _size = 0;

	public GLib.Icon icon;

	// contructors -------------------------------
	
	public FileItem(string name) {
		file_name = name;
	}

	public FileItem.from_disk_path_with_basic_info(string _file_path) {
		file_path = _file_path;
		file_name = file_basename(_file_path);
		file_location = file_parent(_file_path);
		query_file_info_basic();
	}

	public FileItem.from_path_and_type(string _file_path, FileType _file_type) {
		file_path = _file_path;
		file_name = file_basename(_file_path);
		file_location = file_parent(_file_path);
		file_type = _file_type;
	}

	// properties -------------------------------------------------
	
	public int64 size {
		get{
			return _size;
		}
	}

	// helpers ----------------------------------------------------

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
			
	// instance methods -------------------------------------------
	
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

	public void query_file_info_basic() {
		
		try {
			FileInfo info;
			File file = File.parse_name(file_path);

			if (file.query_exists()) {

				// get type and icon -- follow symlinks
				
				info = file.query_info("%s,%s".printf(
				                           FileAttribute.STANDARD_TYPE,
				                           FileAttribute.STANDARD_ICON
				                           ), 0);
				                           
				this.icon = info.get_icon();

				this.file_type = info.get_file_type();
			}
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	// icons ------------------------------------------------------

	public Gdk.Pixbuf? get_icon(int icon_size, bool add_transparency, bool add_emblems){

		Gdk.Pixbuf? pixbuf = null;

		if (icon != null) {
			pixbuf = IconManager.lookup_gicon(icon, icon_size);
		}

		if (pixbuf == null){
			if (file_type == FileType.DIRECTORY) {
				pixbuf = IconManager.lookup("folder", icon_size, false);
			}
			else{
				pixbuf = IconManager.lookup("text-x-preview", icon_size, false);
			}
		}

		return pixbuf;
	}
}
