
/*
 * SnapshotListBox.vala
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

using Gtk;
using Gee;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

class SnapshotListBox : Gtk.Box{
	
	public Gtk.TreeView treeview;
    private Gtk.TreeViewColumn col_date;
    private Gtk.TreeViewColumn col_tags;
    private Gtk.TreeViewColumn col_size;
    private Gtk.TreeViewColumn col_unshared;
    private Gtk.TreeViewColumn col_system;
    private Gtk.TreeViewColumn col_desc;
	private int treeview_sort_column_index = 0;
	private bool treeview_sort_column_desc = true;

	private Gtk.Menu menu_snapshots;
	private Gtk.ImageMenuItem mi_browse;
	private Gtk.ImageMenuItem mi_remove;
	private Gtk.ImageMenuItem mi_mark;
	private Gtk.ImageMenuItem mi_view_log_create;
	private Gtk.ImageMenuItem mi_view_log_restore;
	
	private Gtk.Window parent_window;

	public signal void delete_selected();
	public signal void mark_selected();
	public signal void browse_selected();
	public signal void view_snapshot_log(bool show_restore_log);

	public SnapshotListBox (Gtk.Window _parent_window) {

		log_debug("SnapshotListBox: SnapshotListBox()");
		
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		margin = 6;

		init_treeview();
		
		init_list_view_context_menu();

		log_debug("SnapshotListBox: SnapshotListBox(): exit");
    }

    private void init_treeview(){
		//treeview
		treeview = new TreeView();
		treeview.get_selection().mode = SelectionMode.MULTIPLE;
		treeview.headers_clickable = true;
		treeview.has_tooltip = true;
		treeview.set_rules_hint (true);

		//sw_backups
		var sw_backups = new ScrolledWindow(null, null);
		sw_backups.set_shadow_type (ShadowType.ETCHED_IN);
		sw_backups.add (treeview);
		sw_backups.expand = true;
		add(sw_backups);

        //col_date
		col_date = new TreeViewColumn();
		col_date.title = _("Snapshot");
		col_date.clickable = true;
		col_date.resizable = true;
		col_date.spacing = 1;
		col_date.min_width = 200;

		var cell_backup_icon = new CellRendererPixbuf ();
		cell_backup_icon.surface = IconManager.lookup_surface("clock", 16, treeview.scale_factor);
		//cell_backup_icon.xpad = 1;
		cell_backup_icon.xpad = 4;
		cell_backup_icon.ypad = 6;
		col_date.pack_start (cell_backup_icon, false);

		var cell_date = new CellRendererText ();
		col_date.pack_start (cell_date, false);
		col_date.set_cell_data_func (cell_date, cell_date_render);

		treeview.append_column(col_date);

		col_date.clicked.connect(() => {
			if(treeview_sort_column_index == 0){
				treeview_sort_column_desc = !treeview_sort_column_desc;
			}
			else{
				treeview_sort_column_index = 0;
				treeview_sort_column_desc = true;
			}
			refresh();
		});

		//col_system
		col_system = new TreeViewColumn();
		col_system.title = _("System");
		col_system.resizable = true;
		col_system.clickable = true;
		col_system.min_width = 200;

		var cell_system = new CellRendererText ();
		cell_system.ellipsize = Pango.EllipsizeMode.END;
		col_system.pack_start (cell_system, false);
		col_system.set_cell_data_func (cell_system, cell_system_render);
		treeview.append_column(col_system);

		col_system.clicked.connect(() => {
			if(treeview_sort_column_index == 1){
				treeview_sort_column_desc = !treeview_sort_column_desc;
			}
			else{
				treeview_sort_column_index = 1;
				treeview_sort_column_desc = false;
			}
			refresh();
		});

		//col_tags
		col_tags = new TreeViewColumn();
		col_tags.title = _("Tags");
		col_tags.resizable = true;
		//col_tags.min_width = 80;
		col_tags.clickable = true;
		var cell_tags = new CellRendererText ();
		cell_tags.ellipsize = Pango.EllipsizeMode.END;
		col_tags.pack_start (cell_tags, false);
		col_tags.set_cell_data_func (cell_tags, cell_tags_render);
		treeview.append_column(col_tags);

		col_tags.clicked.connect(() => {
			if(treeview_sort_column_index == 2){
				treeview_sort_column_desc = !treeview_sort_column_desc;
			}
			else{
				treeview_sort_column_index = 2;
				treeview_sort_column_desc = false;
			}
			refresh();
		});

		//col_size
		var col = new TreeViewColumn();
		col.title = _("Size");
		col.resizable = true;
		col.min_width = 80;
		col.clickable = true;
		var cell_size = new CellRendererText ();
		cell_size.ellipsize = Pango.EllipsizeMode.END;
		cell_size.xalign = (float) 1.0;
		col.pack_start (cell_size, false);
		col.set_cell_data_func (cell_size, cell_size_render);
		col_size = col;
		treeview.append_column(col_size);
		
		col_size.clicked.connect(() => {
			if(treeview_sort_column_index == 2){
				treeview_sort_column_desc = !treeview_sort_column_desc;
			}
			else{
				treeview_sort_column_index = 2;
				treeview_sort_column_desc = false;
			}
			refresh();
		});

		//col_unshared
		col = new TreeViewColumn();
		col.title = _("Unshared");
		col.resizable = true;
		col.min_width = 80;
		col.clickable = true;
		var cell_unshared = new CellRendererText ();
		cell_unshared.ellipsize = Pango.EllipsizeMode.END;
		cell_unshared.xalign = (float) 1.0;
		col.pack_start (cell_unshared, false);
		col.set_cell_data_func (cell_unshared, cell_unshared_render);
		col_unshared = col;
		treeview.append_column(col_unshared);
		
		col_unshared.clicked.connect(() => {
			if(treeview_sort_column_index == 2){
				treeview_sort_column_desc = !treeview_sort_column_desc;
			}
			else{
				treeview_sort_column_index = 2;
				treeview_sort_column_desc = false;
			}
			refresh();
		});

		//cell_desc
		col_desc = new TreeViewColumn();
		col_desc.title = _("Comments");
		col_desc.resizable = true;
		col_desc.clickable = true;
		col_desc.expand = true;
		var cell_desc = new CellRendererText ();
		cell_desc.ellipsize = Pango.EllipsizeMode.END;
		col_desc.pack_start (cell_desc, false);
		col_desc.set_cell_data_func (cell_desc, cell_desc_render);
		treeview.append_column(col_desc);
		
		cell_desc.editable = true;
		cell_desc.edited.connect ((path, new_text)=>{
			Snapshot bak;
			TreeIter iter;
			var model = (Gtk.ListStore) treeview.model;
			model.get_iter_from_string (out iter, path);
			model.get (iter, 0, out bak, -1);
			bak.description = new_text;
			bak.update_control_file();
		});

		var col_buffer = new TreeViewColumn();
		var cell_text = new CellRendererText();
		cell_text.width = 20;
		col_buffer.pack_start (cell_text, false);
		treeview.append_column(col_buffer);
		
		//tooltips
		treeview.query_tooltip.connect ((x, y, keyboard_tooltip, tooltip) => {
			TreeModel model;
			TreePath path;
			TreeIter iter;
			TreeViewColumn column;
			if (treeview.get_tooltip_context (ref x, ref y, keyboard_tooltip, out model, out path, out iter)){
				int bx, by;
				treeview.convert_widget_to_bin_window_coords(x, y, out bx, out by);
				if (treeview.get_path_at_pos (bx, by, null, out column, null, null)){
					if (column == col_date){
						tooltip.set_markup(_("<b>Snapshot Date:</b> Date on which snapshot was created"));
						return true;
					}
					else if (column == col_desc){
						tooltip.set_markup(_("<b>Comments</b> (double-click to edit)"));
						return true;
					}
					else if (column == col_system){
						tooltip.set_markup(_("<b>System:</b> Installed Linux distribution"));
						return true;
					}
					else if (column == col_tags){
						tooltip.set_markup(
							"<b>%s</b>\n\nO \t%s\nB \t%s\nH \t%s\nD \t%s\nW \t%s\nM \t%s".printf(
								_("Snapshot Levels"),
								_("On demand (manual)"),
								_("Boot"),
								_("Hourly"),
								_("Daily"),
								_("Weekly"),
								_("Monthly"))
						);
						return true;
					}
				}
			}

			return false;
		});
	}

	private void init_list_view_context_menu(){
		Gdk.RGBA gray = Gdk.RGBA();
		gray.parse ("rgba(200,200,200,1)");

		// menu_file
		menu_snapshots = new Gtk.Menu();

		// mi_remove
		var item = new ImageMenuItem.with_label(_("Delete"));
		item.image = IconManager.lookup_image("edit-delete", 16);
		item.activate.connect(()=> { delete_selected(); });
		menu_snapshots.append(item);
		mi_remove = item;
		
		// mi_mark
		item = new ImageMenuItem.with_label(_("Mark for Deletion"));
		item.image = IconManager.lookup_image("edit-delete", 16);
		item.activate.connect(()=> { mark_selected(); });
		menu_snapshots.append(item);
		mi_mark = item;
		
		// mi_browse
		item = new ImageMenuItem.with_label(_("Browse Files"));
        item.image = IconManager.lookup_image(IconManager.GENERIC_ICON_DIRECTORY, 16);
		item.activate.connect(()=> { browse_selected(); });
		menu_snapshots.append(item);
		mi_browse = item;
		
		// mi_view_log_create
		item = new ImageMenuItem.with_label(_("View Log for Create"));
        item.image = IconManager.lookup_image(IconManager.GENERIC_ICON_FILE, 16);
		item.activate.connect(()=> { view_snapshot_log(false); });
		menu_snapshots.append(item);
		mi_view_log_create = item;
		
		// mi_view_log_restore
		item = new ImageMenuItem.with_label(_("View Log for Restore"));
        item.image = IconManager.lookup_image(IconManager.GENERIC_ICON_FILE, 16);
		item.activate.connect(()=> { view_snapshot_log(true); });
		menu_snapshots.append(item);
		mi_view_log_restore = item;
		
		menu_snapshots.show_all();

		// connect signal for shift+F10
        treeview.popup_menu.connect(treeview_popup_menu);
        
        // connect signal for right-click
		treeview.button_press_event.connect(treeview_button_press_event);
	}

	// signals
	
	private bool treeview_popup_menu(){
		return menu_snapshots_popup (menu_snapshots, null);
	}

	private bool treeview_button_press_event(Gdk.EventButton event){
		if (event.button == 3) {
			return menu_snapshots_popup (menu_snapshots, event);
		}

		return false;
	}
	
	// renderers
	
    private void cell_date_render(
		CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
			
		Snapshot bak;
		model.get (iter, 0, out bak, -1);
		
		var ctxt = (cell as Gtk.CellRendererText);
		ctxt.text = bak.date_formatted;
		ctxt.sensitive = !bak.marked_for_deletion;

		if (bak.live){
			ctxt.markup = "<b>%s</b>".printf(ctxt.text);
		}
		else{
			ctxt.markup = ctxt.text;
		}
		
		// Note: Avoid AM/PM as it may be hidden due to locale settings
	}

	private void cell_tags_render(
		CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
			
		Snapshot bak;
		model.get (iter, 0, out bak, -1);
		
		var ctxt = (cell as Gtk.CellRendererText);
		ctxt.text = bak.taglist_short;
		ctxt.sensitive = !bak.marked_for_deletion;

		if (bak.live){
			ctxt.markup = "<b>%s</b>".printf(ctxt.text);
		}
		else{
			ctxt.markup = ctxt.text;
		}
	}

	private void cell_size_render(
		CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
			
		Snapshot bak;
		model.get (iter, 0, out bak, -1);
		
		var ctxt = (cell as Gtk.CellRendererText);

		if (bak.btrfs_mode){
			int64 size = bak.subvolumes["@"].total_bytes;
			if (bak.subvolumes.has_key("@home")){
				size += bak.subvolumes["@home"].total_bytes;
			}
			ctxt.text = format_file_size(size);
		}
		else{
			ctxt.text = "";
		}
		
		ctxt.sensitive = !bak.marked_for_deletion;

		if (bak.live){
			ctxt.markup = "<b>%s</b>".printf(ctxt.text);
		}
		else{
			ctxt.markup = ctxt.text;
		}
	}

	private void cell_unshared_render(
		CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
			
		Snapshot bak;
		model.get (iter, 0, out bak, -1);
		
		var ctxt = (cell as Gtk.CellRendererText);

		if (bak.btrfs_mode){
			int64 size = bak.subvolumes["@"].unshared_bytes;
			if (bak.subvolumes.has_key("@home")){
				size += bak.subvolumes["@home"].unshared_bytes;
			}
			ctxt.text = format_file_size(size);
		}
		else{
			ctxt.text = "";
		}
		
		ctxt.sensitive = !bak.marked_for_deletion;

		if (bak.live){
			ctxt.markup = "<b>%s</b>".printf(ctxt.text);
		}
		else{
			ctxt.markup = ctxt.text;
		}
	}

	private void cell_system_render(
		CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
			
		Snapshot bak;
		model.get (iter, 0, out bak, -1);
		
		var ctxt = (cell as Gtk.CellRendererText);
		ctxt.text = bak.sys_distro;
		ctxt.sensitive = !bak.marked_for_deletion;

		if (bak.live){
			ctxt.markup = "<b>%s</b>".printf(ctxt.text);
		}
		else{
			ctxt.markup = ctxt.text;
		}
	}

	private void cell_desc_render(
		CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		Snapshot bak;
		model.get (iter, 0, out bak, -1);

		var ctxt = (cell as Gtk.CellRendererText);
		ctxt.text = bak.description;
		ctxt.sensitive = !bak.marked_for_deletion;
		if (bak.live){
			ctxt.text = "[" + _("LIVE") + "] " + ctxt.text;
		}

		if (bak.live){
			ctxt.markup = "<b>%s</b>".printf(ctxt.text);
		}
		else{
			ctxt.markup = ctxt.text;
		}
	}

	private bool menu_snapshots_popup (Gtk.Menu popup, Gdk.EventButton? event) {
		TreeSelection selection = treeview.get_selection();
		int count = selection.count_selected_rows();
		mi_remove.sensitive = (count > 0);
		mi_mark.sensitive = (count > 0);
		mi_view_log_create.sensitive = !App.btrfs_mode;
		mi_view_log_restore.sensitive = !App.btrfs_mode;

		if (event != null) {
			menu_snapshots.popup (null, null, null, event.button, event.time);
		} else {
			menu_snapshots.popup (null, null, null, 0, Gtk.get_current_event_time());
		}
		
		return true;
	}


	// actions
	
	public void refresh(){

		var model = new Gtk.ListStore(1, typeof(Snapshot));

		if ((App.repo == null) || !App.repo.available()){
			treeview.set_model (model);
			return;
		}

		App.repo.load_snapshots();
		
		var list = App.repo.snapshots;

		if (treeview_sort_column_index == 0){

			if (treeview_sort_column_desc)
			{
				list.sort((a,b) => {
					Snapshot t1 = (Snapshot) a;
					Snapshot t2 = (Snapshot) b;

					return (t1.date.compare(t2.date));
				});
			}
			else{
				list.sort((a,b) => {
					Snapshot t1 = (Snapshot) a;
					Snapshot t2 = (Snapshot) b;

					return -1 * (t1.date.compare(t2.date));
				});
			}
		}
		else{
			if (treeview_sort_column_desc)
			{
				list.sort((a,b) => {
					Snapshot t1 = (Snapshot) a;
					Snapshot t2 = (Snapshot) b;

					return strcmp(t1.taglist,t2.taglist);
				});
			}
			else{
				list.sort((a,b) => {
					Snapshot t1 = (Snapshot) a;
					Snapshot t2 = (Snapshot) b;

					return -1 * strcmp(t1.taglist,t2.taglist);
				});
			}
		}

		TreeIter iter;
		foreach(Snapshot bak in list) {
			model.append(out iter);
			model.set (iter, 0, bak);
		}

		col_size.visible = App.btrfs_mode;
		col_unshared.visible = App.btrfs_mode; 

		treeview.set_model (model);
		treeview.columns_autosize ();
	}

	public void hide_context_menu(){
		// disconnect signal for shift+F10
        treeview.popup_menu.disconnect(treeview_popup_menu);
        
        // disconnect signal for right-click
		treeview.button_press_event.disconnect(treeview_button_press_event);
	}

	public Gee.ArrayList<Snapshot> selected_snapshots(){
		var list = new Gee.ArrayList<Snapshot>();

		TreeIter iter;
		var store = (Gtk.ListStore) treeview.model;
		var sel = treeview.get_selection();
		bool iterExists = store.get_iter_first (out iter);
		while (iterExists) {
			if (sel.iter_is_selected (iter)){
				Snapshot bak;
				store.get (iter, 0, out bak);

				list.add(bak);
			}
			iterExists = store.iter_next (ref iter);
		}

		return list;
	}
}
