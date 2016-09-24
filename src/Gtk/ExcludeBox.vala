/*
 * EstimateBox.vala
 *
 * Copyright 2016 Tony George <tony.george.kol@gmail.com>
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
using TeeJee.Devices;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

class ExcludeBox : Gtk.Box{
	private Gtk.TreeView treeview;
	private Gtk.Window parent_window;
	public bool include = false;
	
	public ExcludeBox (Gtk.Window _parent_window, bool include_mode) {
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		include = include_mode;
		margin = 12;

		var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		add(box);
		
		if (include){
			add_label_header(box, _("Include Files"), true);
		}
		else{
			add_label_header(box, _("Exclude Files"), true);
		}

		//if (include){
		//	add_label(box, _("Include these items in snapshots:"));
		//}
		//else{
		//	add_label(box, _("Exclude these items in snapshots:"));
		//}

		var buffer = add_label(box, "");
		buffer.hexpand = true;

		init_exclude_summary_link(box);

		init_treeview();

		init_actions();
		
		refresh_treeview();
    }

    private void init_treeview(){
		// treeview
		treeview = new TreeView();
		treeview.get_selection().mode = SelectionMode.MULTIPLE;
		treeview.headers_visible = false;
		treeview.rules_hint = true;
		treeview.reorderable = true;
		//treeview.row_activated.connect(treeview_row_activated);

		// scrolled
		var scrolled = new ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.add (treeview);
		scrolled.expand = true;
		add(scrolled);

        // column
		var col = new TreeViewColumn();
		col.expand = true;
		treeview.append_column(col);
		
		// margin
		var cell_text = new CellRendererText ();
		cell_text.text = "";
		col.pack_start (cell_text, false);

		// icon
		var cell_icon = new CellRendererPixbuf ();
		col.pack_start (cell_icon, false);
		col.set_attributes(cell_icon, "pixbuf", 1);

		// pattern
		cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);
		col.set_cell_data_func (cell_text, cell_exclude_text_render);
	}

    private void init_exclude_summary_link(Gtk.Box box){
		// link
		var link = new LinkButton.with_label("",_("Summary"));
		link.xalign = (float) 0.0;
		box.add(link);

		link.activate_link.connect((uri)=>{
			new ExcludeListSummaryWindow(false);
			return true;
		});
	}

	private void init_actions(){
		// actions
		
		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		add(hbox);

		Gtk.SizeGroup size_group = null;
		var button = add_button(hbox, _("Add Files"),
			_("Add files to this list"), ref size_group, null);
        button.clicked.connect(()=>{
			add_files_clicked();
		});

		size_group = null;
		button = add_button(hbox, _("Add Folders"),
			_("Add folders to this list"), ref size_group, null);
        button.clicked.connect(()=>{
			add_folder_clicked();
		});

		if (!include){
			// for exclude only - Including contents without including directory is not logical
			size_group = null;
			button = add_button(hbox, _("Add Contents"),
				_("Add the contents of a folder to this list"), ref size_group, null);
			button.clicked.connect(()=>{
				add_folder_contents_clicked();
			});
		}
		
		size_group = null;
		button = add_button(hbox, _("Remove"), "", ref size_group, null);
        button.clicked.connect(()=>{
			remove_clicked();
		});
	}
	
	// actions
	
    private void remove_clicked(){
		var sel = treeview.get_selection();
		var store = (Gtk.ListStore) treeview.model;
		
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
		
		foreach(var item in iter_list){
			store.remove(item);
		}

		save_changes();
	}

	private void add_files_clicked(){

		var list = browse_files();

		if (list.length() > 0){
			foreach(string item in list){

				string pattern = item;
				if (include && !pattern.has_prefix("+ ")){
					pattern = "+ %s".printf(pattern);
				}
				else if (!include && pattern.has_prefix("+ ")){
					pattern = pattern[2:pattern.length];
				}
	
				if (!App.exclude_list_user.contains(pattern)){
					App.exclude_list_user.add(pattern);
					treeview_add_item(treeview, pattern);
					log_debug("%s file: %s".printf(action_name, pattern));
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
				if (include && !pattern.has_prefix("+ ")){
					pattern = "+ %s".printf(pattern);
				}
				else if (!include && pattern.has_prefix("+ ")){
					pattern = pattern[2:pattern.length];
				}

				if (include){
					// Note: *** matches / also, includes everything under the directory
					if (!pattern.has_suffix("/***")){
						pattern = "%s/***".printf(pattern);
					}
				}
				else{
					if (!pattern.has_suffix("/")){
						pattern = "%s/".printf(pattern);
					}
				}

				if (!App.exclude_list_user.contains(pattern)){
					App.exclude_list_user.add(pattern);
					treeview_add_item(treeview, pattern);
					log_debug("%s folder: %s".printf(action_name, pattern));
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
				if (include && !pattern.has_prefix("+ ")){
					pattern = "+ %s".printf(pattern);
				}
				else if (!include && pattern.has_prefix("+ ")){
					pattern = pattern[2:pattern.length];
				}
				
				if (!pattern.has_suffix("/*")){
					pattern = "%s/*".printf(pattern);
				}
				
				if (!App.exclude_list_user.contains(pattern)){
					App.exclude_list_user.add(pattern);
					treeview_add_item(treeview, pattern);
					log_debug("%s contents: %s".printf(action_name, pattern));
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

		dialog.run();
		var list = dialog.get_filenames();
	 	dialog.destroy ();

	 	return list;
	}

	private SList<string> browse_folder(){
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

		dialog.run();
		var list = dialog.get_filenames();
	 	dialog.destroy ();

	 	return list;
	}

	// helpers

	public void refresh_treeview(){
		var model = new Gtk.ListStore(2, typeof(string), typeof(Gdk.Pixbuf));
		treeview.model = model;

		foreach(string pattern in App.exclude_list_user){
			if ((include && pattern.has_prefix("+ "))
				||(!include && !pattern.has_prefix("+ "))){
					
				treeview_add_item(treeview, pattern);
			}
		}
	}

	private void treeview_add_item(Gtk.TreeView treeview, string pattern){
		Gdk.Pixbuf pix_exclude = null;
		Gdk.Pixbuf pix_include = null;
		Gdk.Pixbuf pix_selected = null;

		log_debug("treeview_add_item():%s".printf(pattern));

		try{
			pix_exclude = new Gdk.Pixbuf.from_file (
				App.share_folder + "/timeshift/images/item-gray.png");
			pix_include = new Gdk.Pixbuf.from_file (
				App.share_folder + "/timeshift/images/item-blue.png");
		}
        catch(Error e){
	        log_error (e.message);
	    }

		TreeIter iter;
		var model = (Gtk.ListStore) treeview.model;
		model.append(out iter);

		if (pattern.has_prefix("+ ")){
			pix_selected = pix_include;
		}
		else{
			pix_selected = pix_exclude;
		}

		model.set (iter, 0, pattern, 1, pix_selected, -1);

		var adj = treeview.get_hadjustment();
		adj.value = adj.upper;
	}

	private void cell_exclude_text_render (
		CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
			
		string pattern;
		model.get (iter, 0, out pattern, -1);
		(cell as Gtk.CellRendererText).text =
			pattern.has_prefix("+ ") ? pattern[2:pattern.length] : pattern;
	}

	private void cell_exclude_text_edited (
		string path, string new_text) {
			
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

		//int index = temp_exclude_list.index_of(old_pattern);
		//temp_exclude_list.insert(index, new_pattern);
		//temp_exclude_list.remove(old_pattern);
	}

	public void save_changes(){

		var list_exclude = new Gee.ArrayList<string>();
		var list_include = new Gee.ArrayList<string>();
		foreach (var item in App.exclude_list_user){
			if (item.has_prefix("+ ")){
				list_include.add(item);
			}
			else{
				list_exclude.add(item);
			}
		}
		
		App.exclude_list_user.clear();

		if (include){
			
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

			// add existing exclude patterns
			App.exclude_list_user.add_all(list_exclude);
		}
		else{

			// add existing include patterns
			App.exclude_list_user.add_all(list_include);
			
			// add exclude patterns from treeview
			TreeIter iter;
			var store = (Gtk.ListStore) treeview.model;
			bool iterExists = store.get_iter_first (out iter);
			while (iterExists) {
				string path;
				store.get(iter, 0, out path);

				if (!App.exclude_list_user.contains(path)
					&& !App.exclude_list_default.contains(path)
					&& !App.exclude_list_home.contains(path)){
					
					App.exclude_list_user.add(path);
				}
				
				iterExists = store.iter_next(ref iter);
			}
		}

		log_debug("save_changes(): exclude_list_user:");
		foreach(var item in App.exclude_list_user){
			log_debug(item);
		}
		log_debug("");
	}

	public string action_name{
		owned get{
			return include ? _("Include") : _("Exclude");
		}
	}
	
/*
	private void btn_warning_clicked(){
		string msg = "";
		msg += _("Documents, music and other folders in your home directory are excluded by default.") + " ";
		msg += _("Please do NOT include these folders in your snapshot unless you have a very good reason for doing so.") + " ";
		msg += _("If you include any specific folders then these folders will get overwritten with previous contents when you restore a snapshot.");

		var dialog = new Gtk.MessageDialog.with_markup(null, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.OK, msg);
		dialog.set_title("Warning");
		dialog.set_default_size (200, -1);
		dialog.set_transient_for(this);
		dialog.set_modal(true);
		dialog.run();
		dialog.destroy();
	}

	private void btn_reset_exclude_list_clicked(){
		//create a temp exclude list ----------------------------

		temp_exclude_list = new Gee.ArrayList<string>();

		//refresh treeview --------------------------

		refresh_treeview();
	}

	private bool lnk_default_list_activate(){
		//show message window -----------------
		var dialog = new ExcludeMessageWindow();
		dialog.set_transient_for (this);
		dialog.show_all();
		dialog.run();
		dialog.destroy();
		return true;
	}
*/
	// TODO: Add link for default exclude items
}
