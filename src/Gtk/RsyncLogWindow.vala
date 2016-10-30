/*
 * RsyncLogWindow.vala
 *
 * Copyright 2016 Tony George <teejeetech@gmail.com>
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

public class RsyncLogWindow : Window {

	private Gtk.Box vbox_main;
	private Gtk.Box vbox_progress;
	private Gtk.Box vbox_list;

	private Gtk.TreeView tv_files;
	private Gtk.TreeModelFilter filter_files;
	private Gtk.ComboBox cmb_filter;
	private Gtk.Box hbox_filter;

	public Gtk.Label lbl_header;
	private Gtk.Spinner spinner;
	public Gtk.Label lbl_msg;
	public Gtk.Label lbl_status;
	public Gtk.Label lbl_remaining;
	public Gtk.ProgressBar progressbar;
	
	//window
	private int def_width = 600;
	private int def_height = 450;

	//private uint tmr_task = 0;
	private uint tmr_init = 0;
	private bool thread_is_running = false;
	
	Gdk.Pixbuf pix_file = null;
	Gdk.Pixbuf pix_folder = null;

	private string rsync_log_file;
	private FileItem log_root;
	private bool flat_view = false;

	private string filter = "";
	
	public RsyncLogWindow(string _rsync_log_file) {

		log_debug("RsyncLogWindow: RsyncLogWindow()");
		
		//title = "rsync log for snapshot " + "%s".printf(bak.date.format ("%Y-%m-%d %I:%M %p"));
		title = _("Log Viewer");
		window_position = WindowPosition.CENTER;
		set_default_size(def_width, def_height);
		icon = get_app_icon(16);
		resizable = true;
		modal = true;

		this.delete_event.connect(on_delete_event);
		
		rsync_log_file = _rsync_log_file;
		
		//vbox_main
		vbox_main = new Box (Orientation.VERTICAL, 12);
		vbox_main.margin = 6;
		add (vbox_main);

		create_progressbar();

		create_treeview();

		create_toolbar();

		cmb_filter.changed.connect(() => {
			filter = gtk_combobox_get_value(cmb_filter, 0, "");
			log_debug("combo_changed(): filter=%s".printf(filter));

			hbox_filter.sensitive = false;
			gtk_set_busy(true, this);
			//filter_files.refilter();
			tv_files_refresh();
			hbox_filter.sensitive = true;
			gtk_set_busy(false, this);
		});

		show_all();

		tmr_init = Timeout.add(100, init_delayed);

		log_debug("RsyncLogWindow: RsyncLogWindow(): exit");
		
	}

	private void create_progressbar(){
		vbox_progress = new Gtk.Box(Orientation.VERTICAL, 6);
		vbox_main.add(vbox_progress);
		
		lbl_header = add_label_header(vbox_progress, _("Parsing log file..."), true);
		
		var hbox_status = new Box (Orientation.HORIZONTAL, 6);
		vbox_progress.add(hbox_status);
		
		spinner = new Gtk.Spinner();
		spinner.active = true;
		hbox_status.add(spinner);
		
		//lbl_msg
		lbl_msg = add_label(hbox_status, _("Preparing..."));
		lbl_msg.hexpand = true;
		lbl_msg.ellipsize = Pango.EllipsizeMode.END;
		lbl_msg.max_width_chars = 50;

		//lbl_remaining = add_label(hbox_status, "");

		//progressbar
		progressbar = new Gtk.ProgressBar();
		vbox_progress.add (progressbar);
	}

	public bool init_delayed(){

		log_debug("init_delayed()");
		
		if (tmr_init > 0){
			Source.remove(tmr_init);
			tmr_init = 0;
		}

		gtk_set_busy(true, this);

		parse_log_file();

		gtk_set_busy(false, this);

		log_debug("init_delayed(): finish");
		
		return false;
	}

	private void parse_log_file(){

		try {
			thread_is_running = true;
			Thread.create<void> (parse_log_file_thread, true);
		}
		catch (Error e) {
			log_error (e.message);
		}

		while (thread_is_running){
			double fraction = (App.task.prg_count * 1.0) / App.task.prg_count_total;
			if (fraction < 0.99){
				progressbar.fraction = fraction;
			}
			lbl_msg.label = _("Read %'d of %'d lines...").printf(
				App.task.prg_count, App.task.prg_count_total);
			sleep(200);
			gtk_do_events();
		}

		
		lbl_msg.label = _("Populating list...");
		gtk_do_events();
		tv_files_refresh();

		vbox_progress.hide();
		gtk_do_events();

		vbox_list.no_show_all = false;
		vbox_list.show_all();
	}
	
	private void parse_log_file_thread(){
		App.task = new RsyncTask();
		log_root = App.task.parse_log(rsync_log_file);
		thread_is_running = false;
	}
	
	private void create_toolbar(){
		log_debug("create_toolbar()");
		
		var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        vbox_list.add(hbox);
		hbox_filter = hbox;
		
		var label = add_label(hbox, _("View:"));

		int_combo_filter(hbox);

		label = add_label(hbox, "");
		label.hexpand = true;
		
		Gtk.SizeGroup size_group = null;
		/*var btn_flat = add_toggle_button(hbox, _("Flat View"), "", ref size_group, null);
		btn_flat.active = flat_view;
        btn_flat.toggled.connect(()=>{
			flat_view = btn_flat.active;
			tv_files_refresh();
		});*/

		size_group = null;
		/*var btn_exclude = add_button(hbox,
			_("Exclude Selected"),
			_("Exclude selected items from future snapshots (careful!)"),
			ref size_group, null);
			
        btn_exclude.clicked.connect(()=>{
			if (flat_view){
				gtk_messagebox(_("Cannot exclude files in flat view"),
					_("View has been changed to tree view. Select the parent item you want to exclude and click the 'Exclude' button."),this, true);

				flat_view = false;
			}
			else{
				exclude_selected_items();
			}
			
			tv_files_refresh();
		});*/

		// close

		size_group = null;
		var img = new Image.from_stock("gtk-close", Gtk.IconSize.BUTTON);
		var btn_close = add_button(hbox, _("Close"), "", ref size_group, img);

        btn_close.clicked.connect(()=>{
			this.destroy();
		});

		log_debug("init_toolbar(): finished");
	}

	private void create_treeview() {

		vbox_list = new Gtk.Box(Orientation.VERTICAL, 6);
		vbox_list.no_show_all = true;
		vbox_main.add(vbox_list);
		
		add_label(vbox_list,
			_("Following files have changed since previous snapshot:"));

		// tv_files
		tv_files = new TreeView();
		tv_files.get_selection().mode = SelectionMode.MULTIPLE;
		tv_files.headers_clickable = true;
		tv_files.rubber_banding = true;
		tv_files.has_tooltip = true;
		tv_files.set_rules_hint(true);

		// sw_files
		var sw_files = new ScrolledWindow(null, null);
		sw_files.set_shadow_type (ShadowType.ETCHED_IN);
		sw_files.add (tv_files);
		sw_files.vexpand = true;
		vbox_list.add(sw_files);
		
		// name ----------------------------------------------

		// column
		var col = new TreeViewColumn();
		col.title = _("Name");
		col.clickable = true;
		col.resizable = true;
		col.expand = true;
		tv_files.append_column(col);

		// cell icon
		var cell_pix = new CellRendererPixbuf ();
		cell_pix.stock_size = Gtk.IconSize.MENU;
		col.pack_start(cell_pix, false);
		col.set_attributes(cell_pix, "pixbuf", 3);

		// cell text
		var cell_text = new CellRendererText ();
		cell_text.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cell_text, false);
		col.set_attributes(cell_text, "text", 2);

		// name ----------------------------------------------

		// column
		col = new TreeViewColumn();
		col.title = _("Size");
		col.clickable = true;
		col.resizable = true;
		//col.expand = true;
		tv_files.append_column(col);

		// cell text
		cell_text = new CellRendererText ();
		//cell_text.ellipsize = Pango.EllipsizeMode.END;
		cell_text.xalign = (float) 1.0;
		col.pack_start (cell_text, false);
		col.set_attributes(cell_text, "text", 4);
		
		// status ------------------------------------------------

		col = new TreeViewColumn();
		col.title = "Change";
		//col.clickable = false;
		//col.resizable = false;
		tv_files.append_column(col);
		//var col_spacer = col;
		
		// cell text
		cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);
		col.set_attributes(cell_text, "text", 5);
		
		// buffer ------------------------------------------------

		col = new TreeViewColumn();
		col.title = "";
		col.clickable = false;
		col.resizable = false;
		col.min_width = 20;
		tv_files.append_column(col);
		//var col_spacer = col;
		
		// cell text
		cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);
	}

	private void int_combo_filter(Gtk.Box hbox){
		// combo
		var combo = new Gtk.ComboBox ();
		hbox.add(combo);
		cmb_filter = combo;
		
		var cell_text = new CellRendererText ();
		cell_text.text = "";
		combo.pack_start (cell_text, false);

		combo.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
			string val;
			model.get (iter, 1, out val, -1);
			(cell as Gtk.CellRendererText).text = val;
		});

		//populate combo
		var model = new Gtk.ListStore(2, typeof(string), typeof(string));
		cmb_filter.model = model;

		TreeIter iter;
		model.append(out iter);
		model.set (iter, 0, "", 1, "All");
		model.append(out iter);
		model.set (iter, 0, "created", 1, "Created");
		model.append(out iter);
		model.set (iter, 0, "deleted", 1, "Deleted");
		model.append(out iter);
		model.set (iter, 0, "changed", 1, "Changed");
		model.append(out iter);
		model.set (iter, 0, "checksum", 1, " └ Checksum");
		model.append(out iter);
		model.set (iter, 0, "size", 1, " └ Size");
		model.append(out iter);
		model.set (iter, 0, "timestamp", 1, " └ Timestamp");
		model.append(out iter);
		model.set (iter, 0, "permissions", 1, " └ Permissions");
		model.append(out iter);
		model.set (iter, 0, "owner", 1, " └ Owner");
		model.append(out iter);
		model.set (iter, 0, "group", 1, " └ Group");

		cmb_filter.active = 0;
	}
	
	private void tv_files_refresh() {
		log_debug("tv_files_refresh()");

		hbox_filter.sensitive = false;
		gtk_set_busy(true, this);

		tv_files.show_expanders = !flat_view;
		
		var model = new Gtk.TreeStore(6,
			typeof(FileItem), // object
			typeof(bool), // odd row
			typeof(string), // file_name
			typeof(Gdk.Pixbuf),
			typeof(string), // size text
			typeof(string) // file_status
		);

		var icon_theme = Gtk.IconTheme.get_default();
		
		try {
			pix_folder = icon_theme.load_icon_for_scale (
				"folder", Gtk.IconSize.MENU, 16, Gtk.IconLookupFlags.FORCE_SIZE);
			pix_file = get_shared_icon_pixbuf("gtk-file", "gtk-file.png", 16);
		}
		catch (Error e) {
			warning (e.message);
		}

		TreeIter iter0;

		// workaround for compiler error 'iter0 not set'
		model.append(out iter0, null);
		model.clear();
		
		bool odd_row = false;
		int row_index = -1;
		foreach(FileItem item in log_root.get_children_sorted()) {
			row_index++;
			odd_row = !odd_row;

			if ((!flat_view) || (item.file_type != FileType.DIRECTORY)){

				// add row
				model.append(out iter0, null);
				model.set (iter0, 0, item);
				model.set (iter0, 1, odd_row);

				if (flat_view){
					model.set (iter0, 2, "/%s".printf(item.file_path));
				}
				else{
					model.set (iter0, 2, "%s".printf(item.file_name));
				}
				
				if (item.file_type == FileType.DIRECTORY){
					model.set (iter0, 3, pix_folder);
				}
				else{
					model.set (iter0, 3, pix_file);
				}

				if (item.is_symlink){
					model.set (iter0, 4, "link");
				}
				else if (item.size >= 0){
					model.set (iter0, 4, format_file_size(item.size));
				}
				else{
					model.set (iter0, 4, "");
				}

				model.set (iter0, 5, item.file_status);
			}

			if (item.file_type == FileType.DIRECTORY){
				log_debug("Appending: %s".printf(item.file_path));
				tv_append_to_iter(ref model, ref iter0, item, odd_row, false);
			}
		}
		
		filter_files = new TreeModelFilter (model, null);
		filter_files.set_visible_func(filter_packages_func);
		tv_files.set_model (filter_files);
		
		//tv_files.set_model(model);
		//tv_files.columns_autosize();

		hbox_filter.sensitive = true;
		gtk_set_busy(false, this);
	}

	private bool filter_packages_func (Gtk.TreeModel model, Gtk.TreeIter iter) {
		FileItem item;
		model.get (iter, 0, out item, -1);

		if (item.file_type == FileType.DIRECTORY){
			return !flat_view; // show directories
		}
		// TODO: medium: hard: find a way to hide empty directories after filter

		if (filter.length == 0){
			return true;
		}
		else if (filter == "changed"){
			switch(item.file_status){
			case "checksum":
			case "size":
			case "timestamp":
			case "permissions":
			case "owner":
			case "group":
				return true;
			default:
				return false;
			}
		}
		else{
			return (item.file_status == filter);
		}
	}

	private TreeIter? tv_append_to_iter(
		ref TreeStore model, ref TreeIter iter0, FileItem? item,
		bool odd_row, bool addItem = true) {

		//append sub-directories

		TreeIter iter1 = iter0;

		if (addItem && (item.parent != null)) {

			//log_debug("add:%s".printf(item.file_path));

			if (check_visibility(item)){

				// add row
				if (flat_view){
					model.append (out iter1, null);
				}
				else{
					model.append (out iter1, iter0);
				}

				model.set (iter1, 0, item);
				model.set (iter1, 1, odd_row);

				if (flat_view){
					model.set (iter1, 2, "/%s".printf(item.file_path));
				}
				else{
					model.set (iter1, 2, "%s".printf(item.file_name));
				}

				if (item.file_type == FileType.DIRECTORY){
					model.set (iter1, 3, pix_folder);
				}
				else{
					model.set (iter1, 3, pix_file);
				}

				
				if (item.is_symlink){
					model.set (iter1, 4, "link");
				}
				else if (item.size >= 0){
					model.set (iter1, 4, format_file_size(item.size));
				}
				else{
					model.set (iter1, 4, "");
				}

				model.set (iter1, 5, item.file_status);
			}
		}

		// add new child iters -------------------------
		
		foreach(var child in item.get_children_sorted()) {
			odd_row = !odd_row;
			tv_append_to_iter(ref model, ref iter1, child, odd_row);
		}

		return iter1;
	}

	private bool check_visibility(FileItem item){

		if (item.file_type == FileType.DIRECTORY){
			return !flat_view;
		}
		
		if (filter.length == 0){
			return true;
		}
		else{
			return (item.file_status == filter);
		}
	}

	private void exclude_selected_items(){
		var list = new Gee.ArrayList<string>();
		foreach(var pattern in App.exclude_list_user){
			list.add(pattern);
		}
		App.exclude_list_user.clear();

		// TODO: medium: exclude selected items: not working
		
		// add include list
		TreeIter iter;
		var store = (Gtk.ListStore) tv_files.model;
		bool iterExists = store.get_iter_first (out iter);
		while (iterExists) {
			FileItem item;
			store.get (iter, 0, out item);

			string pattern = item.file_path;

			if (item.file_type == FileType.DIRECTORY){
				pattern = "%s/***".printf(pattern);
			}
			else{
				//pattern = "%s/***".printf(pattern);
			}
			
			if (!App.exclude_list_user.contains(pattern)
				&& !App.exclude_list_default.contains(pattern)
				&& !App.exclude_list_home.contains(pattern)){
				
				list.add(pattern);
			}
			
			iterExists = store.iter_next (ref iter);
		}

		App.exclude_list_user = list;

		log_debug("exclude_selected_items()");
		foreach(var item in App.exclude_list_user){
			log_debug(item);
		}
	}

	private bool on_delete_event(Gdk.EventAny event){
		if (thread_is_running){
			return true; // keep window open
		}
		else{
			this.delete_event.disconnect(on_delete_event); //disconnect this handler
			return false; // close window
		}
	}

}
