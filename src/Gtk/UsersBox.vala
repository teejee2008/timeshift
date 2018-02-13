/*
 * UsersBox.vala
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

using Gtk;
using Gee;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

class UsersBox : Gtk.Box{
	
	private Gtk.TreeView treeview;
	private Gtk.ScrolledWindow scrolled_treeview;
	private Gtk.Window parent_window;
	private ExcludeBox exclude_box;
	private Gtk.Label lbl_message;
	private Gtk.CheckButton chk_include_btrfs_home;
	private bool restore_mode = false;
	
	public UsersBox (Gtk.Window _parent_window, ExcludeBox _exclude_box, bool _restore_mode) {

		log_debug("UsersBox: UsersBox()");
		
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		margin = 12;

		restore_mode = _restore_mode;

		exclude_box = _exclude_box;

		var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		add(box);
		
		add_label_header(box, _("User Home Directories"), true);

		var buffer = add_label(box, "");
		buffer.hexpand = true;

		// ------------------------
		
		var label = add_label(this, _("User home directories are excluded by default unless you enable them here"));
		lbl_message = label;

		init_treeview();

		init_btrfs_home_option();

		refresh();

		log_debug("UsersBox: UsersBox(): exit");
    }

    private void init_treeview(){
		
		// treeview
		treeview = new TreeView();
		treeview.get_selection().mode = SelectionMode.MULTIPLE;
		treeview.headers_visible = true;
		treeview.rules_hint = true;
		treeview.reorderable = false;
		treeview.set_tooltip_text(_("Click to edit. Drag and drop to re-order."));
		//treeview.row_activated.connect(treeview_row_activated);

		// scrolled
		var scrolled = new ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.add (treeview);
		scrolled.expand = true;
		add(scrolled);
		scrolled_treeview = scrolled;
		
		// column
		var col = new TreeViewColumn();
		col.title = _("User");
		treeview.append_column(col);

		// name
		var cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);
		
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter)=>{
			SystemUser user;
			model.get(iter, 0, out user);
			(cell as Gtk.CellRendererText).text = user.name;
		});

		// column
		col = new TreeViewColumn();
		col.title = _("Home");
		treeview.append_column(col);

		// name
		cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);
		
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter)=>{
			SystemUser user;
			model.get(iter, 0, out user);
			(cell as Gtk.CellRendererText).text = user.home_path;
		});

		// column -------------------------------------------------
		
		col = new TreeViewColumn();
		col.title = _("Exclude All");
		treeview.append_column(col);
		
		// radio_exclude
		var cell_radio = new Gtk.CellRendererToggle();
		cell_radio.radio = true;
		cell_radio.xpad = 2;
		cell_radio.activatable = true;
		col.pack_start (cell_radio, false);

		col.set_attributes(cell_radio, "active", 3);
		
		cell_radio.toggled.connect((cell, path)=>{

			log_debug("cell_exclude.toggled()");
			
			var model = (Gtk.ListStore) treeview.model;
			TreeIter iter;
			
			model.get_iter_from_string (out iter, path);

			bool enabled;
			model.get(iter, 3, out enabled);
			
			SystemUser user;
			model.get(iter, 0, out user);

			string exc_pattern = "%s/**".printf(user.home_path);
			string inc_pattern = "+ %s/**".printf(user.home_path);
			string inc_hidden_pattern = "+ %s/.**".printf(user.home_path);

			if (user.has_encrypted_home){
				inc_pattern = "+ /home/.ecryptfs/%s/***".printf(user.name);
				exc_pattern = "/home/.ecryptfs/%s/***".printf(user.name);
			}
			
			enabled = !enabled;
			
			if (enabled){
				if (!App.exclude_list_user.contains(exc_pattern)){
					App.exclude_list_user.add(exc_pattern);
				}
				if (App.exclude_list_user.contains(inc_pattern)){
					App.exclude_list_user.remove(inc_pattern);
				}
				if (App.exclude_list_user.contains(inc_hidden_pattern)){
					App.exclude_list_user.remove(inc_hidden_pattern);
				}
			}

			this.refresh_treeview();
			
			//exclude_box.refresh_treeview();
		});

		// column -------------------------------------------------
		
		col = new TreeViewColumn();
		col.title = _("Include Hidden");
		treeview.append_column(col);
		
		// radio_include
		cell_radio = new Gtk.CellRendererToggle();
		cell_radio.radio = true;
		cell_radio.xpad = 2;
		cell_radio.activatable = true;
		col.pack_start (cell_radio, false);

		col.set_attributes(cell_radio, "active", 1);
		
		cell_radio.toggled.connect((cell, path)=>{

			log_debug("cell_include.toggled()");
			
			var model = (Gtk.ListStore) treeview.model;
			TreeIter iter;
			
			model.get_iter_from_string (out iter, path);

			bool enabled;
			model.get(iter, 1, out enabled);
			
			SystemUser user;
			model.get(iter, 0, out user);

			string exc_pattern = "%s/**".printf(user.home_path);
			string inc_pattern = "+ %s/**".printf(user.home_path);
			string inc_hidden_pattern = "+ %s/.**".printf(user.home_path);
			
			if (user.has_encrypted_home){
				inc_pattern = "+ /home/.ecryptfs/%s/***".printf(user.name);
				exc_pattern = "/home/.ecryptfs/%s/***".printf(user.name);
			}
			
			enabled = !enabled;
			
			if (enabled){
				
				if (user.has_encrypted_home){
					
					string txt = _("Encrypted Home Directory");

					string msg = _("Selected user has an encrypted home directory. It's not possible to include only hidden files.");
					
					gtk_messagebox(txt, msg, parent_window, true);

					return;
				}

				if (!App.exclude_list_user.contains(inc_hidden_pattern)){
					App.exclude_list_user.add(inc_hidden_pattern);
				}

				if (App.exclude_list_user.contains(inc_pattern)){
					App.exclude_list_user.remove(inc_pattern);
				}

				if (App.exclude_list_user.contains(exc_pattern)){
					App.exclude_list_user.remove(exc_pattern);
				}
			}

			this.refresh_treeview();

			//exclude_box.refresh_treeview();
		});

		// column --------------------------------------------
		
		col = new TreeViewColumn();
		col.title = _("Include All");
		treeview.append_column(col);

		// radio_exclude
		cell_radio = new Gtk.CellRendererToggle();
		cell_radio.radio = true;
		cell_radio.xpad = 2;
		cell_radio.activatable = true;
		col.pack_start (cell_radio, false);
		
		col.set_attributes(cell_radio, "active", 2);

		cell_radio.toggled.connect((cell, path)=>{

			var model = (Gtk.ListStore) treeview.model;
			TreeIter iter;
			model.get_iter_from_string (out iter, path);

			bool enabled;
			model.get(iter, 2, out enabled);
			enabled = !enabled;
			model.set(iter, 2, enabled);

			SystemUser user;
			model.get(iter, 0, out user);

			string exc_pattern = "%s/**".printf(user.home_path);
			string inc_pattern = "+ %s/**".printf(user.home_path);
			string inc_hidden_pattern = "+ %s/.**".printf(user.home_path);

			if (user.has_encrypted_home){
				inc_pattern = "+ /home/.ecryptfs/%s/***".printf(user.name);
				exc_pattern = "/home/.ecryptfs/%s/***".printf(user.name);
			}
			
			if (enabled){
				if (!App.exclude_list_user.contains(inc_pattern)){
					App.exclude_list_user.add(inc_pattern);
				}
				if (App.exclude_list_user.contains(exc_pattern)){
					App.exclude_list_user.remove(exc_pattern);
				}
				if (App.exclude_list_user.contains(inc_hidden_pattern)){
					App.exclude_list_user.remove(inc_hidden_pattern);
				}
			}

			this.refresh_treeview();

			//exclude_box.refresh_treeview();
		});

		col = new TreeViewColumn();
		cell_text = new CellRendererText();
		cell_text.width = 20;
		col.pack_start (cell_text, false);
		treeview.append_column(col);
	}

	private void init_btrfs_home_option(){

		if (restore_mode){
			
			chk_include_btrfs_home = new Gtk.CheckButton.with_label(_("Restore @home subvolume"));

			add(chk_include_btrfs_home);

			chk_include_btrfs_home.toggled.connect(()=>{
				App.include_btrfs_home_for_restore = chk_include_btrfs_home.active; 
			});
		
		}
		else {

			chk_include_btrfs_home = new Gtk.CheckButton.with_label(_("Include @home subvolume in backups"));
			
			add(chk_include_btrfs_home);

			chk_include_btrfs_home.toggled.connect(()=>{
				App.include_btrfs_home_for_backup = chk_include_btrfs_home.active; 
			});
		}
	}
	
	// helpers

	public void refresh(){

		if (App.btrfs_mode){

			lbl_message.hide();
			lbl_message.set_no_show_all(true);

			scrolled_treeview.hide();
			scrolled_treeview.set_no_show_all(true);

			chk_include_btrfs_home.show();
			chk_include_btrfs_home.set_no_show_all(false);

			if (restore_mode){
				chk_include_btrfs_home.active = App.include_btrfs_home_for_restore;
			}
			else{
				chk_include_btrfs_home.active = App.include_btrfs_home_for_backup;
			}
		}
		else{
			lbl_message.show();
			lbl_message.set_no_show_all(false);

			scrolled_treeview.show();
			scrolled_treeview.set_no_show_all(false);

			refresh_treeview();

			chk_include_btrfs_home.hide();
			chk_include_btrfs_home.set_no_show_all(true);
		}

		show_all();
	}
	
	private void refresh_treeview(){
		
		var model = new Gtk.ListStore(4, typeof(SystemUser), typeof(bool), typeof(bool), typeof(bool));
		treeview.model = model;

		TreeIter iter;
		
		foreach(var user in App.current_system_users.values){

			if (user.is_system){ continue; }

			string exc_pattern = "%s/**".printf(user.home_path);
			string inc_pattern = "+ %s/**".printf(user.home_path);
			string inc_hidden_pattern = "+ %s/.**".printf(user.home_path);

			if (user.has_encrypted_home){
				inc_pattern = "+ /home/.ecryptfs/%s/***".printf(user.name);
				exc_pattern = "/home/.ecryptfs/%s/***".printf(user.name);
			}
			
			bool include_hidden = App.exclude_list_user.contains(inc_hidden_pattern);
			bool include_all = App.exclude_list_user.contains(inc_pattern);
			bool exclude_all = !include_hidden && !include_all; //App.exclude_list_user.contains(exc_pattern);

			if (exclude_all){
				
				if (!App.exclude_list_user.contains(exc_pattern)){
					App.exclude_list_user.add(exc_pattern);
				}
				if (App.exclude_list_user.contains(inc_pattern)){
					App.exclude_list_user.remove(inc_pattern);
				}
				if (App.exclude_list_user.contains(inc_hidden_pattern)){
					App.exclude_list_user.remove(inc_hidden_pattern);
				}
			}
			
			model.append(out iter);
			model.set (iter, 0, user);
			model.set (iter, 1, include_hidden);
			model.set (iter, 2, include_all);
			model.set (iter, 3, exclude_all);
		}

		exclude_box.refresh_treeview();
	}

	public void save_changes(){

		//App.exclude_list_user.clear();

		// add include patterns from treeview
		/*TreeIter iter;
		var store = (Gtk.ListStore) treeview.model;
		bool iterExists = store.get_iter_first (out iter);
		while (iterExists) {
			string pattern;
			store.get(iter, 0, out pattern);

			if (!App.exclude_list_user.contains(pattern)
				&& !App.exclude_list_default.contains(pattern)
				&& !App.exclude_list_home.contains(pattern)){
				
				App.exclude_list_user.add(pattern);
			}
			
			iterExists = store.iter_next(ref iter);
		}*/

		log_debug("save_changes(): exclude_list_user:");
		foreach(var item in App.exclude_list_user){
			log_debug(item);
		}
		log_debug("");
	}
}
