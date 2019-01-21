/*
 * ExcludeBox.vala
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

class ExcludeBox : Gtk.Box{
	
	private Gtk.TreeView treeview;
	private Gtk.Window parent_window;
	private UsersBox users_box;
	private Gtk.Label lbl_message;
	
	public ExcludeBox (Gtk.Window _parent_window) {

		log_debug("ExcludeBox: ExcludeBox()");
		
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		margin = 12;

		var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		add(box);
		
		add_label_header(box, _("Include / Exclude Patterns"), true);

		var buffer = add_label(box, "");
		buffer.hexpand = true;

		var label = add_label(box, _("Click to edit. Drag-drop to re-order."), false, true);
		lbl_message = label;

		init_treeview();

		init_actions();
		
		refresh_treeview();

		log_debug("ExcludeBox: ExcludeBox(): exit");
    }

    public void set_users_box(UsersBox _users_box){
		
		users_box = _users_box;
	}

    private void init_treeview(){
		
		// treeview
		treeview = new TreeView();
		treeview.get_selection().mode = SelectionMode.MULTIPLE;
		treeview.headers_visible = true;
		//treeview.rules_hint = true;
		treeview.reorderable = true;
		treeview.set_tooltip_text(_("Click to edit. Drag and drop to re-order."));
		//treeview.row_activated.connect(treeview_row_activated);

		// scrolled
		var scrolled = new ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.add (treeview);
		scrolled.expand = true;
		add(scrolled);

		// column
		var col = new TreeViewColumn();
		col.title = "+";
		treeview.append_column(col);
		
		// radio_include
		var cell_radio = new Gtk.CellRendererToggle();
		cell_radio.xpad = 2;
		cell_radio.radio = true;
		cell_radio.activatable = true;
		col.pack_start (cell_radio, false);

		col.set_attributes(cell_radio, "active", 2);
		
		cell_radio.toggled.connect((cell, path)=>{

			log_debug("cell_include.toggled()");
			
			var model = (Gtk.ListStore) treeview.model;
			string pattern;
			TreeIter iter;

			model.get_iter_from_string (out iter, path);
			model.get (iter, 0, out pattern);
			
			if (!pattern.has_prefix("+ ")){
				pattern = "+ %s".printf(pattern);
			}

			treeview_update_item(ref iter, pattern);
		});

		// column
		col = new TreeViewColumn();
		col.title = "-";
		treeview.append_column(col);

		// radio_exclude
		cell_radio = new Gtk.CellRendererToggle();
		cell_radio.xpad = 2;
		cell_radio.radio = true;
		cell_radio.activatable = true;
		col.pack_start (cell_radio, false);
		
		col.set_attributes(cell_radio, "active", 3);

		cell_radio.toggled.connect((cell, path)=>{

			log_debug("cell_exclude.toggled()");
			
			var model = (Gtk.ListStore) treeview.model;
			string pattern;
			TreeIter iter;
		
			model.get_iter_from_string (out iter, path);
			model.get (iter, 0, out pattern);

			//bool exclude = true;

			if (pattern.has_prefix("+ ")){
				pattern = pattern[2:pattern.length];
			}

			treeview_update_item(ref iter, pattern);
		});
		
		// column
		col = new TreeViewColumn();
		col.title = _("Pattern");
		treeview.append_column(col);
		
		// margin
		var cell_text = new CellRendererText ();
		cell_text.text = "";
		col.pack_start (cell_text, false);

		// icon
		var cell_icon = new CellRendererPixbuf ();
		col.pack_start (cell_icon, false);
		col.set_attributes(cell_icon, "icon-name", 1);

		// pattern
		cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);
		
		col.set_cell_data_func (cell_text, (cell_layout, cell, model, iter)=>{
			string pattern;
			model.get (iter, 0, out pattern, -1);
			(cell as Gtk.CellRendererText).text =
				pattern.has_prefix("+ ") ? pattern[2:pattern.length] : pattern;
		});

		cell_text.editable = true;
		cell_text.edited.connect ((path, new_text)=>{
			TreeIter iter;
			var model = (Gtk.ListStore) treeview.model;
			model.get_iter_from_string (out iter, path);

			bool include;
			model.get (iter, 2, out include, -1);

			string pattern = new_text;

			if (include){
				if (!pattern.has_prefix("+ ")){
					pattern = "+ %s".printf(pattern);
				}
			}
			else{
				if (pattern.has_prefix("+ ")){
					pattern = pattern[2:pattern.length];
				}
			}
			
			model.set (iter, 0, pattern, -1);
		});
	}

	private void init_actions(){


		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		add(hbox);

		var size_group = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var button = add_button(hbox, _("Add"), _("Add custom pattern"), size_group, null);
		
        button.clicked.connect(()=>{

			string pattern = gtk_inputbox(
						_("Exclude Pattern"),
						_("Enter the pattern to exclude (Ex: *.mp3, *.bak)"),
						parent_window, false);

			if ((pattern != null) && (pattern.strip().length > 0)){
				treeview_add_item(treeview, pattern); // don't strip
				Main.first_snapshot_size = 0; //re-calculate
			}
		});
		
		button = add_button(hbox, _("Add Files"), _("Add files"), size_group, null);
		
        button.clicked.connect(()=>{
			add_files_clicked();
		});

		button = add_button(hbox, _("Add Folders"), _("Add directories"), size_group, null);
		
        button.clicked.connect(()=>{
			add_folder_clicked();
		});

		// for exclude only - Including contents without including directory is not logical
		/*size_group = null;
		button = add_button(hbox, _("Add Contents"),
			_("Add directory contents"), ref size_group, null);
		button.clicked.connect(()=>{
			add_folder_contents_clicked();
		});*/

		button = add_button(hbox, _("Remove"), "", size_group, null);
        button.clicked.connect(()=>{
			remove_clicked();
		});

		button = add_button(hbox, _("Summary"), "", size_group, null);
        button.clicked.connect(()=>{
			new ExcludeListSummaryWindow(false);
		});
	}
	
	// actions
	
    private void remove_clicked(){
		
		var sel = treeview.get_selection();
		var store = (Gtk.ListStore) treeview.model;

		if (sel.count_selected_rows() == 0){
			string title = _("Items Not Selected");
			string message = _("Select the items to be removed from the list");
			gtk_messagebox(title, message, parent_window, true);
			return;
		}
		
		TreeIter iter;
		var iter_list = new Gee.ArrayList<TreeIter?>();
		
		bool iterExists = store.get_iter_first (out iter);
		while (iterExists) {
			if (sel.iter_is_selected (iter)){
				string pattern;
				store.get (iter, 0, out pattern);
				
				App.exclude_list_user.remove(pattern);
				iter_list.add(iter);
				
				log_debug("removed item: %s".printf(pattern));
				Main.first_snapshot_size = 0; //re-calculate
			}
			iterExists = store.iter_next (ref iter);
		}
		
		refresh_treeview();

		save_changes();
	}

	private void add_files_clicked(){

		var list = browse_files();

		if (list.length() > 0){
			foreach(string item in list){

				string pattern = item;

				if (!App.exclude_list_user.contains(pattern)){
					App.exclude_list_user.add(pattern);
					treeview_add_item(treeview, pattern);
					log_debug("file: %s".printf(pattern));
					Main.first_snapshot_size = 0; //re-calculate
				}
				else{
					log_debug("exclude_list_user contains: %s".printf(pattern));
				}
			}
		}

		save_changes();
	}

	private void add_folder_clicked(){

		var list = browse_folder();

		if (list.length() > 0){
			foreach(string item in list){

				string pattern = item;

				if (!pattern.has_suffix("/***")){
					pattern = "%s/***".printf(pattern);
				}
				
				/*
				NOTE:
				
				+ <dir>/*** will include the directory along with the contents
				+ <dir>/ will include only the directory without the contents
				
				<dir>/*** will exclude the directory along with the contents
				<dir>/ is same as exclude <dir>/***
				*/
				
				if (!App.exclude_list_user.contains(pattern)){
					App.exclude_list_user.add(pattern);
					treeview_add_item(treeview, pattern);
					log_debug("folder: %s".printf(pattern));
					Main.first_snapshot_size = 0; //re-calculate
				}
				else{
					log_debug("exclude_list_user contains: %s".printf(pattern));
				}
			}
		}

		save_changes();
	}

	private void add_folder_contents_clicked(){

		var list = browse_folder();

		if (list.length() > 0){
			foreach(string item in list){

				string pattern = item;
				
				if (!pattern.has_suffix("/**")){
					pattern = "%s/**".printf(pattern);
				}

				/*
				NOTE:
				
				+ <dir>/** will include the directory along with the contents
				+ <dir>/ will include only the directory without the contents
				
				<dir>/** will exclude the directory contents but include the empty directory
				<dir>/ will exclude the directory along with the contents
				*/
				
				if (!App.exclude_list_user.contains(pattern)){
					App.exclude_list_user.add(pattern);
					treeview_add_item(treeview, pattern);
					log_debug("contents: %s".printf(pattern));
					Main.first_snapshot_size = 0; //re-calculate
				}
				else{
					log_debug("exclude_list_user contains: %s".printf(pattern));
				}
			}
		}

		save_changes();
	}
	
	private SList<string> browse_files(){

		var list = new SList<string>();
		
		var dialog = new Gtk.FileChooserDialog(
			_("Select file(s)"), parent_window,
			Gtk.FileChooserAction.OPEN,
			"gtk-cancel", Gtk.ResponseType.CANCEL,
			"gtk-open", Gtk.ResponseType.ACCEPT);
			
		dialog.action = FileChooserAction.OPEN;
		dialog.set_transient_for(parent_window);
		dialog.local_only = true;
 		dialog.set_modal (true);
 		dialog.set_select_multiple (true);

		var resp = dialog.run();

		if (resp != Gtk.ResponseType.CANCEL){
			list = dialog.get_filenames();
		}
		
		dialog.destroy();

	 	return list;
	}

	private SList<string> browse_folder(){

		var list = new SList<string>();
		
		var dialog = new Gtk.FileChooserDialog(
			_("Select directory"), parent_window,
			Gtk.FileChooserAction.SELECT_FOLDER,
			"gtk-cancel", Gtk.ResponseType.CANCEL,
			"gtk-open", Gtk.ResponseType.ACCEPT);
			
		dialog.action = FileChooserAction.SELECT_FOLDER;
		dialog.local_only = true;
		dialog.set_transient_for(parent_window);
 		dialog.set_modal (true);
 		dialog.set_select_multiple (false);

		var resp = dialog.run();

		if (resp != Gtk.ResponseType.CANCEL){
			list = dialog.get_filenames();
		}
		
		dialog.destroy();

	 	return list;
	}

	// helpers

	public void refresh_treeview(){
		
		var model = new Gtk.ListStore(4, typeof(string), typeof(string), typeof(bool), typeof(bool));
		treeview.model = model;

		foreach(string pattern in App.exclude_list_user){
			treeview_add_item(treeview, pattern);
		}
	}

	private void treeview_add_item(Gtk.TreeView treeview, string pattern){
		
		log_debug("treeview_add_item(): %s".printf(pattern));

		TreeIter iter;
		var model = (Gtk.ListStore) treeview.model;
		model.append(out iter);

		bool include = pattern.has_prefix("+ ");

		model.set (iter, 0, pattern);
		model.set (iter, 1, include ? "list-add" : "list-remove");
		model.set (iter, 2, include);
		model.set (iter, 3, !include);

		var adj = treeview.get_hadjustment();
		adj.value = adj.upper;
	}

	private void treeview_update_item(ref TreeIter iter, string pattern){
		
		log_debug("treeview_update_item(): %s".printf(pattern));

	    bool include = pattern.has_prefix("+ ");

		var model = (Gtk.ListStore) treeview.model;
		model.set (iter, 0, pattern);
		model.set (iter, 1, include ? "list-add" : "list-remove");
		model.set (iter, 2, include);
		model.set (iter, 3, !include);
	}

	private void cell_exclude_text_edited(string path, string new_text) {
			
		string old_pattern;
		string new_pattern;

		TreeIter iter;
		var model = (Gtk.ListStore) treeview.model;
		model.get_iter_from_string (out iter, path);
		model.get (iter, 0, out old_pattern, -1);

		if (old_pattern.has_prefix("+ ")){
			new_pattern = "+ " + new_text;
		}
		else{
			new_pattern = new_text;
		}
		model.set (iter, 0, new_pattern);
	}

	public void save_changes(){

		App.exclude_list_user.clear();

		// add include patterns from treeview
		TreeIter iter;
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
		}

		log_debug("save_changes(): exclude_list_user:");
		foreach(var item in App.exclude_list_user){
			log_debug(item);
		}
		log_debug("");

		users_box.refresh();
	}
}
