/*
 * MainWindow.vala
 *
 * Copyright 2013 Tony George <teejee@tony-pc>
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

class MainWindow : Gtk.Window{

	private Gtk.Box vbox_main;

	//snapshots
	private Gtk.Toolbar toolbar;
	private Gtk.ToolButton btn_backup;
	private Gtk.ToolButton btn_restore;
	private Gtk.ToolButton btn_delete_snapshot;
	private Gtk.ToolButton btn_browse_snapshot;
	private Gtk.ToolButton btn_settings;
	private Gtk.ToolButton btn_wizard;
	private Gtk.Menu menu_extra;
	private Gtk.Menu menu_snapshots;
	private Gtk.ImageMenuItem mi_remove;
	private Gtk.ImageMenuItem mi_mark;
	
	//backup device
	//private Gtk.Box hbox_device;
	//private Gtk.Label lbl_backup_device;
	//private Gtk.ComboBox cmb_backup_device;
	//private Gtk.Button btn_refresh_backup_device_list;
	//private Gtk.Label lbl_backup_device_warning;

	//snapshots
	private Gtk.ScrolledWindow sw_backups;
	private Gtk.TreeView tv_backups;
    private Gtk.TreeViewColumn col_date;
    private Gtk.TreeViewColumn col_tags;
    private Gtk.TreeViewColumn col_system;
    private Gtk.TreeViewColumn col_desc;
	private int tv_backups_sort_column_index = 0;
	private bool tv_backups_sort_column_desc = true;

	//statusbar
	private Gtk.Box statusbar;
	private Gtk.Image img_shield;
	private Gtk.Label lbl_shield;
	private Gtk.Label lbl_shield_subnote;
	private Gtk.Label lbl_status;
	private Gtk.Label lbl_snap_count;
	private Gtk.Label lbl_free_space;
	private Gtk.Box vbox_snap_count;
	private Gtk.Box vbox_free_space;

	//timers
	private uint timer_progress;
	private uint timer_backup_device_init;
	private uint tmr_init;

	//other
	//private Device snapshot_device_original;

	public MainWindow () {
		this.title = AppName + " v" + AppVersion;
        this.window_position = WindowPosition.CENTER;
        this.modal = true;
        this.set_default_size (700, 500);
		this.delete_event.connect(on_delete_event);
		this.icon = get_app_icon(16);

	    //vbox_main
        vbox_main = new Box (Orientation.VERTICAL, 0);
        vbox_main.margin = 0;
        add (vbox_main);

        init_ui_toolbar();

        init_ui_snapshot_list();

		init_ui_statusbar();

        if (App.live_system()){
			btn_backup.sensitive = false;
			btn_settings.sensitive = false;
		}

		tmr_init = Timeout.add(100, init_delayed);
    }

    private bool init_delayed(){
		if (tmr_init > 0){
			Source.remove(tmr_init);
			tmr_init = 0;
		}

		init_ui_for_backup_device();

		init_list_view_context_menu();
		
		if (App.first_run){
			btn_wizard_clicked();
		}

		return false;
	}

	private void init_ui_toolbar(){
		//toolbar
		toolbar = new Gtk.Toolbar ();
		toolbar.toolbar_style = ToolbarStyle.BOTH_HORIZ;
		toolbar.get_style_context().add_class(Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
		//toolbar.set_size_request(-1,48);
		vbox_main.add(toolbar);

		//btn_backup
		btn_backup = new Gtk.ToolButton.from_stock ("gtk-save");
		btn_backup.is_important = true;
		btn_backup.label = _("Create");
		btn_backup.set_tooltip_text (_("Create snapshot of current system"));
        toolbar.add(btn_backup);

        btn_backup.clicked.connect (btn_backup_clicked);

		//btn_restore
		btn_restore = new Gtk.ToolButton.from_stock ("gtk-apply");
		btn_restore.is_important = true;
		btn_restore.label = _("Restore");
		btn_restore.set_tooltip_text (_("Restore selected snapshot"));
        toolbar.add(btn_restore);

		btn_restore.clicked.connect (btn_restore_clicked);

	    //btn_browse_snapshot
		btn_browse_snapshot = new Gtk.ToolButton.from_stock ("gtk-directory");
		btn_browse_snapshot.is_important = true;
		btn_browse_snapshot.label = _("Browse");
		btn_browse_snapshot.set_tooltip_text (_("Browse selected snapshot"));
        toolbar.add(btn_browse_snapshot);

        btn_browse_snapshot.clicked.connect (btn_browse_snapshot_clicked);

		//btn_delete_snapshot
		btn_delete_snapshot = new Gtk.ToolButton.from_stock ("gtk-delete");
		btn_delete_snapshot.is_important = true;
		btn_delete_snapshot.label = _("Delete");
		btn_delete_snapshot.set_tooltip_text (_("Delete selected snapshot"));
        toolbar.add(btn_delete_snapshot);

        btn_delete_snapshot.clicked.connect (btn_mark_for_deletion_clicked);

        //btn_settings
		btn_settings = new Gtk.ToolButton.from_stock ("gtk-preferences");
		btn_settings.is_important = true;
		btn_settings.label = _("Settings");
		btn_settings.set_tooltip_text (_("Settings"));
        toolbar.add(btn_settings);

        btn_settings.clicked.connect (btn_settings_clicked);

        //btn_wizard
		btn_wizard = new Gtk.ToolButton.from_stock ("tools-wizard");
		btn_wizard.is_important = true;
		btn_wizard.label = _("Wizard");
		btn_wizard.set_tooltip_text (_("Settings wizard"));
		btn_wizard.icon_widget = get_shared_icon("tools-wizard","tools-wizard.svg",24);
        toolbar.add(btn_wizard);

        btn_wizard.clicked.connect (btn_wizard_clicked);

        //separator
		var separator = new Gtk.SeparatorToolItem();
		separator.set_draw (false);
		separator.set_expand (true);
		toolbar.add (separator);

		//btn_hamburger
        var button = new Gtk.ToolButton.from_stock ("gtk-menu");
		button.label = _("Menu");
		button.set_tooltip_text (_("Open Menu"));
		button.icon_widget = get_shared_icon("","open-menu.svg",24);
        toolbar.add(button);

        // click event
		button.clicked.connect(()=>{
			menu_extra_popup(null);
		});
	}

	private void init_ui_snapshot_list(){
        //tv_backups
		tv_backups = new TreeView();
		tv_backups.get_selection().mode = SelectionMode.MULTIPLE;
		tv_backups.headers_clickable = true;
		tv_backups.has_tooltip = true;
		tv_backups.set_rules_hint (true);

		//sw_backups
		sw_backups = new ScrolledWindow(null, null);
		sw_backups.set_shadow_type (ShadowType.ETCHED_IN);
		sw_backups.add (tv_backups);
		sw_backups.expand = true;
		sw_backups.margin_left = 6;
		sw_backups.margin_right = 6;
		sw_backups.margin_top = 6;
		sw_backups.margin_bottom = 6;
		vbox_main.add(sw_backups);

        //col_date
		col_date = new TreeViewColumn();
		col_date.title = _("Snapshot");
		col_date.clickable = true;
		col_date.resizable = true;
		col_date.spacing = 1;

		CellRendererPixbuf cell_backup_icon = new CellRendererPixbuf ();
		cell_backup_icon.pixbuf = get_shared_icon_pixbuf("clock","clock.png",16);
		//cell_backup_icon.xpad = 1;
		cell_backup_icon.xpad = 4;
		cell_backup_icon.ypad = 6;
		col_date.pack_start (cell_backup_icon, false);

		CellRendererText cell_date = new CellRendererText ();
		col_date.pack_start (cell_date, false);
		col_date.set_cell_data_func (cell_date, cell_date_render);

		tv_backups.append_column(col_date);

		col_date.clicked.connect(() => {
			if(tv_backups_sort_column_index == 0){
				tv_backups_sort_column_desc = !tv_backups_sort_column_desc;
			}
			else{
				tv_backups_sort_column_index = 0;
				tv_backups_sort_column_desc = true;
			}
			refresh_tv_backups();
		});

		//col_system
		col_system = new TreeViewColumn();
		col_system.title = _("System");
		col_system.resizable = true;
		col_system.clickable = true;
		col_system.min_width = 150;

		CellRendererText cell_system = new CellRendererText ();
		cell_system.ellipsize = Pango.EllipsizeMode.END;
		col_system.pack_start (cell_system, false);
		col_system.set_cell_data_func (cell_system, cell_system_render);
		tv_backups.append_column(col_system);

		col_system.clicked.connect(() => {
			if(tv_backups_sort_column_index == 1){
				tv_backups_sort_column_desc = !tv_backups_sort_column_desc;
			}
			else{
				tv_backups_sort_column_index = 1;
				tv_backups_sort_column_desc = false;
			}
			refresh_tv_backups();
		});

		//col_tags
		col_tags = new TreeViewColumn();
		col_tags.title = _("Tags");
		col_tags.resizable = true;
		//col_tags.min_width = 80;
		col_tags.clickable = true;
		CellRendererText cell_tags = new CellRendererText ();
		cell_tags.ellipsize = Pango.EllipsizeMode.END;
		col_tags.pack_start (cell_tags, false);
		col_tags.set_cell_data_func (cell_tags, cell_tags_render);
		tv_backups.append_column(col_tags);

		col_tags.clicked.connect(() => {
			if(tv_backups_sort_column_index == 2){
				tv_backups_sort_column_desc = !tv_backups_sort_column_desc;
			}
			else{
				tv_backups_sort_column_index = 2;
				tv_backups_sort_column_desc = false;
			}
			refresh_tv_backups();
		});

		//cell_desc
		col_desc = new TreeViewColumn();
		col_desc.title = _("Comments");
		col_desc.resizable = true;
		col_desc.clickable = true;
		//col_desc.expand = true;
		CellRendererText cell_desc = new CellRendererText ();
		cell_desc.ellipsize = Pango.EllipsizeMode.END;
		col_desc.pack_start (cell_desc, false);
		col_desc.set_cell_data_func (cell_desc, cell_desc_render);
		tv_backups.append_column(col_desc);
		cell_desc.editable = true;

		cell_desc.edited.connect (cell_desc_edited);

		var col_buffer = new TreeViewColumn();
		var cell_text = new CellRendererText();
		cell_text.width = 20;
		col_buffer.pack_start (cell_text, false);
		tv_backups.append_column(col_buffer);
		
		//tooltips
		tv_backups.query_tooltip.connect ((x, y, keyboard_tooltip, tooltip) => {
			TreeModel model;
			TreePath path;
			TreeIter iter;
			TreeViewColumn col;
			if (tv_backups.get_tooltip_context (ref x, ref y, keyboard_tooltip, out model, out path, out iter)){
				int bx, by;
				tv_backups.convert_widget_to_bin_window_coords(x, y, out bx, out by);
				if (tv_backups.get_path_at_pos (bx, by, null, out col, null, null)){
					if (col == col_date){
						tooltip.set_markup(_("<b>Snapshot Date:</b> Date on which snapshot was created"));
						return true;
					}
					else if (col == col_desc){
						tooltip.set_markup(_("<b>Comments</b> (double-click to edit)"));
						return true;
					}
					else if (col == col_system){
						tooltip.set_markup(_("<b>System:</b> Installed Linux distribution"));
						return true;
					}
					else if (col == col_tags){
						tooltip.set_markup(_("<b>Backup Levels</b>\n\nO	On demand (manual)\nB	Boot\nH	Hourly\nD	Daily\nW	Weekly\nM	Monthly"));
						return true;
					}
				}
			}

			return false;
		});
	}

	private void init_ui_statusbar(){

		// hbox_shield
		var box = new Box (Orientation.HORIZONTAL, 6);
        box.margin_bottom = 6;
        box.margin_left = 6;
        box.margin_right = 12;
        vbox_main.add (box);
		statusbar = box;
		
        // img_shield
		img_shield = new Gtk.Image();
		img_shield.pixbuf = get_shared_icon("security-high", "security-high.svg", 48).pixbuf;
        statusbar.add(img_shield);

		var vbox = new Box (Orientation.VERTICAL, 6);
		vbox.margin_bottom = 0;
        statusbar.add (vbox);
        
		//lbl_shield
		lbl_shield = add_label(vbox, "");
        lbl_shield.margin_bottom = 0;
        lbl_shield.yalign = (float) 0.5;
        lbl_shield.hexpand = true;

        //lbl_shield_subnote
		lbl_shield_subnote = add_label(vbox, "");
		lbl_shield_subnote.yalign = (float) 0.5;
		lbl_shield_subnote.hexpand = true;
		
		// snap_count
		vbox = new Box (Orientation.VERTICAL, 6);
		vbox.set_no_show_all(true);
        statusbar.add (vbox);
        vbox_snap_count = vbox;

		lbl_snap_count = new Label("<b>" + _("0.0%") + "</b>");
		lbl_snap_count.set_use_markup(true);
		lbl_snap_count.justify = Gtk.Justification.CENTER;
		vbox.add(lbl_snap_count);

		// free space
		vbox = new Box (Orientation.VERTICAL, 6);
		vbox.set_no_show_all(true);
        statusbar.add(vbox);
        vbox_free_space = vbox;

		lbl_free_space = new Label("<b>" + _("0.0%") + "</b>");
		lbl_free_space.set_use_markup(true);
		lbl_free_space.justify = Gtk.Justification.CENTER;
		vbox.add(lbl_free_space);

	}
	
    private bool menu_extra_popup(Gdk.EventButton? event){

		menu_extra = new Gtk.Menu();
		menu_extra.reserve_toggle_size = false;

		Gtk.MenuItem menu_item = null;
				
		if (!App.live_system()){
			// clone
			menu_item = create_menu_item(_("Clone"), "gtk-copy", "", 16,
				_("Clone the current system on another device"));
				
			menu_extra.append(menu_item);
			menu_item.activate.connect(btn_clone_clicked);
		}

		// refresh
		menu_item = create_menu_item(_("Refresh Snapshot List"),"gtk-refresh","",16);
		menu_extra.append(menu_item);
		menu_item.activate.connect(() => {
			if (!check_backup_device_online()) { return; }
			App.repo.load_snapshots();
			refresh_tv_backups();
		});
		
		// snapshot logs
		menu_item = create_menu_item(_("View rsync log for selected snapshot"), "gtk-file", "", 16);
		menu_extra.append(menu_item);
		menu_item.activate.connect(btn_view_snapshot_log_clicked);

		if (!App.live_system()){
			// app logs
			menu_item = create_menu_item(_("View TimeShift Logs"), "gtk-file", "", 16);
			menu_extra.append(menu_item);
			menu_item.activate.connect(btn_view_app_logs_clicked);
		}

		// separator
		menu_item = create_menu_item_separator();
		menu_extra.append(menu_item);
		
		// donate
		menu_item = create_menu_item(_("Donate"), "donate", "donate.svg", 16);
		menu_extra.append(menu_item);
		menu_item.activate.connect(btn_donate_clicked);

		// about
		menu_item = create_menu_item(_("About"), "help-info", "help-info.svg", 16);
		menu_extra.append(menu_item);
		menu_item.activate.connect(btn_about_clicked);
		
		menu_extra.show_all();
		
		if (event != null) {
			menu_extra.popup (null, null, null, event.button, event.time);
		}
		else {
			menu_extra.popup (null, null, null, 0, Gtk.get_current_event_time());
		}

		return true;
	}

	private Gtk.MenuItem create_menu_item(
		string label_text, string icon_name_stock, string icon_name_custom,
		int icon_size, string tooltip_text = ""){
			
		var menu_item = new Gtk.MenuItem();
	
		var box = new Gtk.Box (Orientation.HORIZONTAL, 3);
		menu_item.add(box);

		var icon = get_shared_icon(icon_name_stock, icon_name_custom, icon_size);
		icon.set_tooltip_text(tooltip_text);
		box.add(icon);
				
		var label = new Gtk.Label(label_text);
		label.xalign = (float) 0.0;
		label.margin_right = 6;
		label.set_tooltip_text((tooltip_text.length > 0) ? tooltip_text : label_text);
		box.add(label);

		return menu_item;
	}
	
	private Gtk.MenuItem create_menu_item_separator(){
			
		var menu_item = new Gtk.MenuItem();
		menu_item.sensitive = false;
		
		var box = new Gtk.Box (Orientation.HORIZONTAL, 3);
		menu_item.add(box);

		box.add(new Gtk.Separator(Gtk.Orientation.HORIZONTAL));
				
		return menu_item;
	}

	
	private bool init_ui_for_backup_device(){

		/* updates statusbar messages and snapshot list after backup device is changed */

		if (timer_backup_device_init > 0){
			Source.remove(timer_backup_device_init);
			timer_backup_device_init = 0;
		}

		update_ui(false);

		if (App.live_system()){
			//statusbar_message(_("Checking backup device..."));
		}
		else{
			//statusbar_message(_("Estimating system size..."));
		}

		refresh_tv_backups();
		update_statusbar();
		update_ui(true);

		return false;
	}

	private bool on_delete_event(Gdk.EventAny event){

		this.delete_event.disconnect(on_delete_event); //disconnect this handler

		if (App.task.status == AppStatus.RUNNING){
			log_error (_("Main window closed by user"));
			App.task.stop();
		}

		//else - check backup device -------------------------------

		string message,details;
		int status_code = App.check_backup_location(out message, out details);

		//message = escape_html(message);
		//details = escape_html(details);
		
		switch(status_code){
			case SnapshotLocationStatus.HAS_SNAPSHOTS_NO_SPACE:
			case SnapshotLocationStatus.NO_SNAPSHOTS_NO_SPACE:
			case SnapshotLocationStatus.NOT_AVAILABLE:
			case SnapshotLocationStatus.READ_ONLY_FS:
			case SnapshotLocationStatus.HARDLINKS_NOT_SUPPORTED:
			
				var title = message;
				
				var msg = _("Select another device?");
				
				var type = Gtk.MessageType.ERROR;
				var buttons_type = Gtk.ButtonsType.YES_NO;
				
				var dlg = new CustomMessageDialog(title, msg, type, this, buttons_type);
				var response = dlg.run();
				dlg.destroy();
				
				if (response == Gtk.ResponseType.YES){
					this.delete_event.connect(on_delete_event); // reconnect this handler
					btn_wizard_clicked(); // open wizard
					return true; // keep window open
				}
				else{
					return false; // close window
				}

			case SnapshotLocationStatus.NO_SNAPSHOTS_HAS_SPACE:
			case SnapshotLocationStatus.HAS_SNAPSHOTS_HAS_SPACE:
				// TODO: Allow scheduled snapshots when first snapshot not taken
				break;
		}

		return false;
	}

	private void cell_date_render(
		CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
			
		Snapshot bak;
		model.get (iter, 0, out bak, -1);
		(cell as Gtk.CellRendererText).text = bak.date.format ("%Y-%m-%d %I:%M %p");
		(cell as Gtk.CellRendererText).sensitive = !bak.marked_for_deletion;
	}

	private void cell_tags_render(
		CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		Snapshot bak;
		model.get (iter, 0, out bak, -1);
		(cell as Gtk.CellRendererText).text = bak.taglist_short;
		(cell as Gtk.CellRendererText).sensitive = !bak.marked_for_deletion;
	}

	private void cell_system_render(
		CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		Snapshot bak;
		model.get (iter, 0, out bak, -1);
		(cell as Gtk.CellRendererText).text = bak.sys_distro;
		(cell as Gtk.CellRendererText).sensitive = !bak.marked_for_deletion;
	}

	private void cell_desc_render(
		CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		Snapshot bak;
		model.get (iter, 0, out bak, -1);
		(cell as Gtk.CellRendererText).text = bak.description;
		(cell as Gtk.CellRendererText).sensitive = !bak.marked_for_deletion;
	}

	private void cell_desc_edited (string path, string new_text) {
		Snapshot bak;

		TreeIter iter;
		var model = (Gtk.ListStore) tv_backups.model;
		model.get_iter_from_string (out iter, path);
		model.get (iter, 0, out bak, -1);
		bak.description = new_text;
		bak.update_control_file();
	}

	private void init_list_view_context_menu(){
		Gdk.RGBA gray = Gdk.RGBA();
		gray.parse ("rgba(200,200,200,1)");

		// menu_file
		menu_snapshots = new Gtk.Menu();

		// mi_remove
		mi_remove = new ImageMenuItem.with_label("Delete");
		mi_remove.image = get_shared_icon("gtk-delete","",16);
		mi_remove.activate.connect(btn_delete_clicked);
		menu_snapshots.append(mi_remove);

		// mi_mark
		mi_mark = new ImageMenuItem.with_label("Mark for deletion");
		mi_mark.image = get_shared_icon("gtk-delete","",16);
		mi_mark.activate.connect(btn_mark_for_deletion_clicked);
		menu_snapshots.append(mi_mark);

		
		// miFileSeparator0
		//var miFileSeparator0 = new Gtk.MenuItem();
		//miFileSeparator0.override_color (StateFlags.NORMAL, gray);
		//menu_file.append(miFileSeparator0);

		// miFileSeparator1
		//miFileSeparator1 = new Gtk.MenuItem();
		//miFileSeparator1.override_color (StateFlags.NORMAL, gray);
		//menu_file.append(miFileSeparator1);

		// mi_file_open_temp_dir
		//mi_file_open_temp_dir = new ImageMenuItem.from_stock("gtk-directory", null);
		//mi_file_open_temp_dir.label = _("Open Temp Folder");
		//mi_file_open_temp_dir.activate.connect(mi_file_open_temp_dir_clicked);
		//menu_file.append(mi_file_open_temp_dir);

		// mi_file_open_logfile
		//mi_file_open_logfile = new ImageMenuItem.from_stock("gtk-info", null);
		//mi_file_open_logfile.label = _("Open Log File");
		//mi_file_open_logfile.activate.connect(mi_file_open_logfile_clicked);
		//menu_file.append(mi_file_open_logfile);

		
		// mi_file_info
		//mi_file_info = new ImageMenuItem.from_stock("gtk-properties", null);
		//mi_file_info.label = _("File Info (Source)");
		//mi_file_info.activate.connect(mi_file_info_clicked);
		//menu_file.append(mi_file_info);

		menu_snapshots.show_all();

		// connect signal for shift+F10
        tv_backups.popup_menu.connect(() => {
			return menu_snapshots_popup (menu_snapshots, null);
		});
        
        // connect signal for right-click
		tv_backups.button_press_event.connect ((w, event) => {
			if (event.button == 3) {
				return menu_snapshots_popup (menu_snapshots, event);
			}

			return false;
		});
	}

	 private bool menu_snapshots_popup (Gtk.Menu popup, Gdk.EventButton? event) {
		TreeSelection selection = tv_backups.get_selection();
		int count = selection.count_selected_rows();
		mi_remove.sensitive = (count > 0);
		mi_mark.sensitive = (count > 0);

		if (event != null) {
			menu_snapshots.popup (null, null, null, event.button, event.time);
		} else {
			menu_snapshots.popup (null, null, null, 0, Gtk.get_current_event_time());
		}
		
		return true;
	}

	private void refresh_tv_backups(){

		App.repo.load_snapshots();

		var model = new Gtk.ListStore(1, typeof(Snapshot));

		var list = App.repo.snapshots;

		if (tv_backups_sort_column_index == 0){

			if (tv_backups_sort_column_desc)
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
			if (tv_backups_sort_column_desc)
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

		tv_backups.set_model (model);
		tv_backups.columns_autosize ();
	}

	private void btn_backup_clicked(){

		//check root device --------------

		if (App.check_btrfs_root_layout() == false){
			return;
		}

		//check snapshot device -----------

		string message, details;
		int status_code = App.check_backup_location(out message, out details);

		switch(status_code){
		case SnapshotLocationStatus.HAS_SNAPSHOTS_HAS_SPACE:
		case SnapshotLocationStatus.NO_SNAPSHOTS_HAS_SPACE:
			//ok
			break;
		default:
			gtk_messagebox(message, details, this, true);
			return;
		}

		// run wizard window
		
		var win = new WizardWindow("create");
		win.set_transient_for(this);
		win.show_all();
		win.destroy.connect(()=>{
			App.update_partitions();
			timer_backup_device_init = Timeout.add(100, init_ui_for_backup_device);
		});
	}

	private void btn_delete_clicked(){
		TreeIter iter;
		TreeIter iter_delete;
		TreeSelection sel;
		bool is_success = true;

		//check if device is online
		if (!check_backup_device_online()) { return; }

		//check selected count ----------------

		sel = tv_backups.get_selection ();
		if (sel.count_selected_rows() == 0){
			gtk_messagebox(
				_("No Snapshots Selected"),
				_("Select snapshots to be marked for deletion"),
				this, false);
				
			return;
		}

		//update UI ------------------

		update_ui(false);

		//get list of snapshots to delete --------------------

		var list_of_snapshots_to_delete = new Gee.ArrayList<Snapshot>();
		var store = (Gtk.ListStore) tv_backups.model;

		bool iterExists = store.get_iter_first (out iter);
		while (iterExists && is_success) {
			if (sel.iter_is_selected (iter)){
				Snapshot bak;
				store.get (iter, 0, out bak);
				list_of_snapshots_to_delete.add(bak);
			}
			iterExists = store.iter_next (ref iter);
		}

		//clear selection ---------------

		tv_backups.get_selection().unselect_all();

		//delete snapshots --------------------------

		foreach(Snapshot bak in list_of_snapshots_to_delete){

			//find the iter being deleted
			iterExists = store.get_iter_first (out iter_delete);
			while (iterExists) {
				Snapshot bak_current;
				store.get (iter_delete, 0, out bak_current);
				if (bak_current.path == bak.path){
					break;
				}
				iterExists = store.iter_next (ref iter_delete);
			}

			//select the iter being deleted
			tv_backups.get_selection().select_iter(iter_delete);

			//statusbar_message(_("Deleting snapshot") + ": '%s'...".printf(bak.name));

			is_success = bak.remove();

			// TODO: use rsync to delete and show progress??
			// It's much slower (10x)

			if (!is_success){
				//statusbar_message_with_timeout(_("Error: Unable to delete snapshot") + ": '%s'".printf(bak.name), false);
				break;
			}

			//remove iter from tv_backups
			store.remove(iter_delete);
		}

		App.repo.load_snapshots();
		if (!App.repo.has_snapshots()){
			//statusbar_message(_("Deleting snapshot") + ": '.sync'...");
			App.repo.remove_all();
		}

		if (is_success){
			//statusbar_message_with_timeout(_("Snapshots deleted successfully"), true);
		}

		//update UI -------------------

		App.update_partitions();
		refresh_tv_backups();
		update_statusbar();

		update_ui(true);
	}

	private void btn_mark_for_deletion_clicked(){
		TreeIter iter;
		TreeSelection sel;
		bool is_success = true;

		// check if device is online
		if (!check_backup_device_online()) { return; }

		// check selected count ----------------

		sel = tv_backups.get_selection ();
		if (sel.count_selected_rows() == 0){
			gtk_messagebox(
				_("No Snapshots Selected"),
				_("Select the snapshots to mark for deletion"),
				this, false);
				
			return;
		}

		// get selected snapshots --------------------

		var store = (Gtk.ListStore) tv_backups.model;
		bool iterExists = store.get_iter_first (out iter);
		while (iterExists && is_success) {
			if (sel.iter_is_selected (iter)){
				Snapshot bak;
				store.get (iter, 0, out bak);
				// mark for deletion
				bak.mark_for_deletion();
			}
			iterExists = store.iter_next (ref iter);
		}

		App.repo.load_snapshots();

		gtk_messagebox(_("Marked for deletion"), 
			_("Snapshots will be removed during the next scheduled run") + ".\n\n"
			+ _("To delete the snapshots immediately, right-click and select 'Delete'."),
			this, false);

		//update UI -------------------

		App.update_partitions();
		refresh_tv_backups();
		update_statusbar();
		update_ui(true);
	}


	private void btn_restore_clicked(){
		App.mirror_system = false;
		restore();
	}

	private void btn_clone_clicked(){
		App.mirror_system = true;
		restore();
	}

	private void restore(){
		TreeIter iter;
		TreeSelection sel;

		if (!App.mirror_system){
			//check if backup device is online (check #1)
			if (!check_backup_device_online()) { return; }
		}

		if (!App.mirror_system){

			//check if single snapshot is selected -------------

			sel = tv_backups.get_selection ();
			if (sel.count_selected_rows() == 0){
				gtk_messagebox(
					_("No snapshots selected"),
					_("Select the snapshot to restore"),
					this, false);
				return;
			}
			else if (sel.count_selected_rows() > 1){
				gtk_messagebox(
					_("Multiple snapshots selected"),
					_("Select a single snapshot to restore"),
					this, false);
				return;
			}
			
			//get selected snapshot ------------------

			Snapshot snapshot_to_restore = null;

			var store = (Gtk.ListStore) tv_backups.model;
			sel = tv_backups.get_selection();
			bool iterExists = store.get_iter_first (out iter);
			while (iterExists) {
				if (sel.iter_is_selected (iter)){
					store.get (iter, 0, out snapshot_to_restore);
					break;
				}
				iterExists = store.iter_next (ref iter);
			}

			if ((snapshot_to_restore != null) && (snapshot_to_restore.marked_for_deletion)){
				gtk_messagebox(
					_("Invalid snapshot"),
					_("Selected snapshot is marked for deletion and cannot be restored"),
					this, false);
				return;
			}

			App.snapshot_to_restore = snapshot_to_restore;
			App.restore_target = App.root_device;
		}
		else{
			App.snapshot_to_restore = null;
			App.restore_target = null;
		}

		//show restore window -----------------

		var dialog = new RestoreWindow();
		dialog.set_transient_for (this);
		dialog.show_all();
		int response = dialog.run();
		dialog.destroy();

		if (response != Gtk.ResponseType.OK){
			App.unmount_target_device();
			return; //cancel
		}

		if (!App.mirror_system){
			//check if backup device is online (check #2)
			if (!check_backup_device_online()) { return; }
		}

		//update UI ----------------

		update_ui(false);

		//take a snapshot if current system is being restored -----------------

		if (!App.live_system() && (App.restore_target.device == App.root_device.device) && (App.restore_target.uuid == App.root_device.uuid)){

			string msg = _("Do you want to take a snapshot of the current system before restoring the selected snapshot?");

			var dlg = new Gtk.MessageDialog.with_markup(this, Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO, msg);
			dlg.set_title(_("Take Snapshot"));
			dlg.set_default_size (200, -1);
			dlg.set_transient_for(this);
			dlg.set_modal(true);
			response = dlg.run();
			dlg.destroy();

			if (response == Gtk.ResponseType.YES){
				//statusbar_message(_("Taking snapshot..."));

				update_progress_start();

				bool is_success = App.take_snapshot(true,"",this);

				update_progress_stop();

				if (is_success){
					App.repo.load_snapshots();
					var latest = App.repo.get_latest_snapshot("ondemand");
					latest.description = _("Before restoring") + " '%s'".printf(App.snapshot_to_restore.name);
					latest.update_control_file();
				}
			}
		}

		if (!App.mirror_system){
			//check if backup device is online (check #3)
			if (!check_backup_device_online()) { return; }
		}

		//restore the snapshot --------------------

		if (App.snapshot_to_restore != null){
			log_msg("Restoring snapshot '%s' to device '%s'".printf(App.snapshot_to_restore.name,App.restore_target.device),true);
			//statusbar_message(_("Restoring snapshot..."));
		}
		else{
			log_msg("Cloning current system to device '%s'".printf(App.restore_target.device),true);
			//statusbar_message(_("Cloning system..."));
		}

		if (App.reinstall_grub2){
			log_msg("GRUB will be installed on '%s'".printf(App.grub_device),true);
		}

		bool is_success = App.restore_snapshot(this);

		string msg;
		if (is_success){
			if (App.mirror_system){
				msg = _("System was cloned successfully on target device");
			}
			else{
				msg = _("Snapshot was restored successfully on target device");
			}
			//statusbar_message_with_timeout(msg, true);

			var dlg = new Gtk.MessageDialog.with_markup(this,Gtk.DialogFlags.MODAL, Gtk.MessageType.INFO, Gtk.ButtonsType.OK, msg);
			dlg.set_title(_("Finished"));
			dlg.set_modal(true);
			dlg.set_transient_for(this);
			dlg.run();
			dlg.destroy();
		}
		else{
			if (App.mirror_system){
				msg = _("Cloning Failed!");
			}
			else{
				msg = _("Restore Failed!");
			}

			//statusbar_message_with_timeout(msg, true);

			var dlg = new Gtk.MessageDialog.with_markup(this,Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR, Gtk.ButtonsType.OK, msg);
			dlg.set_title(_("Error"));
			dlg.set_modal(true);
			dlg.set_transient_for(this);
			dlg.run();
			dlg.destroy();
		}

		//update UI ----------------

		update_ui(true);
	}

	private void btn_settings_clicked(){
		btn_settings.sensitive = false;
		
		var win = new WizardWindow("settings");
		win.set_transient_for(this);
		win.show_all();
		win.destroy.connect(()=>{
			btn_settings.sensitive = true;
			timer_backup_device_init = Timeout.add(100, init_ui_for_backup_device);
		});
	}

	private void btn_wizard_clicked(){
		btn_wizard.sensitive = false;
		
		var win = new WizardWindow("wizard");
		win.set_transient_for(this);
		win.show_all();
		win.destroy.connect(()=>{
			btn_wizard.sensitive = true;
			timer_backup_device_init = Timeout.add(100, init_ui_for_backup_device);
		});
	}

	private void btn_browse_snapshot_clicked(){

		//check if device is online
		if (!check_backup_device_online()) {
			return;
		}

		TreeSelection sel = tv_backups.get_selection ();
		if (sel.count_selected_rows() == 0){
			string snapshot_dir = path_combine(App.repo.snapshot_location, "timeshift/snapshots");
			var f = File.new_for_path(snapshot_dir);
			if (f.query_exists()){
				exo_open_folder(snapshot_dir);
			}
			else{
				exo_open_folder(App.repo.snapshot_location);
			}
			return;
		}

		TreeIter iter;
		var store = (Gtk.ListStore)tv_backups.model;

		bool iterExists = store.get_iter_first (out iter);
		while (iterExists) {
			if (sel.iter_is_selected (iter)){
				Snapshot bak;
				store.get (iter, 0, out bak);

				exo_open_folder(bak.path + "/localhost");
				return;
			}
			iterExists = store.iter_next (ref iter);
		}
	}

	private void btn_view_snapshot_log_clicked(){
		TreeSelection sel = tv_backups.get_selection ();
		if (sel.count_selected_rows() == 0){
			gtk_messagebox(
				_("Select Snapshot"),
				_("Please select a snapshot to view the log!"),
				this, false);
			return;
		}

		TreeIter iter;
		var store = (Gtk.ListStore)tv_backups.model;

		bool iterExists = store.get_iter_first (out iter);
		while (iterExists) {
			if (sel.iter_is_selected (iter)){
				Snapshot bak;
				store.get (iter, 0, out bak);

				exo_open_textfile(bak.path + "/rsync-log");
				return;
			}
			iterExists = store.iter_next (ref iter);
		}
	}

	private void btn_view_app_logs_clicked(){
		exo_open_folder(App.log_dir);
	}

	public void btn_donate_clicked(){
		var dialog = new DonationWindow();
		dialog.set_transient_for(this);
		dialog.show_all();
		dialog.run();
		dialog.destroy();
	}

	private void btn_about_clicked (){
		var dialog = new AboutWindow();
		dialog.set_transient_for (this);

		dialog.authors = {
			"Tony George:teejeetech@gmail.com"
		};

		dialog.translators = {
			"BennyBeat (Catalan):https://launchpad.net/~bennybeat",
			"Pavel Borecki (Czech):https://launchpad.net/~pavel-borecki",
			"Jerre van Erp, cropr (Dutch):https://launchpad.net/~lp-l10n-nl",
			"Anne, Debaru, Nikos, alienus (French):launchpad.net/~lp-l10n-fr",
			"tomberry88 (Italian):launchpad.net/~tomberry",
			"B.W.Knight, Jung-Kyu Park (Korean):https://launchpad.net/~lp-l10n-ko",
			"Michał Olber, eloaders (Polish):https://translations.launchpad.net/+groups/launchpad-translators",
			"Eugene Marshal, admin_x, Владимир Шаталин (Russian):https://launchpad.net/~lp-l10n-ru",
			"Adolfo Jayme (Spanish):https://launchpad.net/~lp-l10n-es",
			"Ultimate (Turkish):https://launchpad.net/~lolcat"
		};

		dialog.contributors = {
			"Maxim Taranov:png2378@gmail.com"
		};

		dialog.third_party = {
			"Timeshift is powered by the following tools and components. Please visit the links for more information.",
			"rsync by Andrew Tridgell, Wayne Davison, and others.:http://rsync.samba.org/"
		};

		dialog.documenters = null;
		dialog.artists = null;
		dialog.donations = null;

		dialog.program_name = AppName;
		dialog.comments = _("A System Restore Utility for Linux");
		dialog.copyright = "Copyright © 2016 Tony George (%s)".printf(AppAuthorEmail);
		dialog.version = AppVersion;
		dialog.logo = get_app_icon(128);

		dialog.license = "This program is free for personal and commercial use and comes with absolutely no warranty. You use this program entirely at your own risk. The author will not be liable for any damages arising from the use of this program.";
		dialog.website = "http://teejeetech.in";
		dialog.website_label = "http://teejeetech.blogspot.in";

		dialog.initialize();
		dialog.show_all();
	}


	private void update_ui(bool enable){
		toolbar.sensitive = enable;
		sw_backups.sensitive = enable;
		gtk_set_busy(!enable, this);
	}

	private void update_progress_start(){
		timer_progress = Timeout.add_seconds(1, update_progress);
	}

    private bool update_progress (){
		if (timer_progress > 0){
			Source.remove(timer_progress);
			timer_progress = 0;
		}

		lbl_status.label = App.progress_text;

		timer_progress = Timeout.add_seconds(1, update_progress);
		return true;
	}

	private void update_progress_stop(){
		if (timer_progress > 0){
			Source.remove(timer_progress);
			timer_progress = 0;
		}
	}

	private bool check_backup_device_online(){
		if (!App.backup_device_online()){
			// TODO: use message and details
			gtk_messagebox(
				_("Snapshot location is not available"),
				"",
				this, true);
			update_statusbar();
			return false;
		}
		else{
			return true;
		}
	}

	private void update_statusbar(){		
		string message, details;
		int status_code = App.check_backup_location(out message, out details);
		
		DateTime last_snapshot_date = null;
		DateTime oldest_snapshot_date = null;

		//message = escape_html(message);
		//details = escape_html(details);

		// TODO; change this
		
		switch (status_code){
		case SnapshotLocationStatus.HAS_SNAPSHOTS_HAS_SPACE:
		case SnapshotLocationStatus.HAS_SNAPSHOTS_NO_SPACE:
			var last_snapshot = App.repo.get_latest_snapshot();
			last_snapshot_date = (last_snapshot == null) ? null : last_snapshot.date;
			var oldest_snapshot = App.repo.get_oldest_snapshot();
			oldest_snapshot_date = (oldest_snapshot == null) ? null : oldest_snapshot.date;
			break;
		}

		if (App.live_system()){
			statusbar.visible = true;
			statusbar.show_all();

			img_shield.pixbuf =
				get_shared_icon("media-optical", "media-optical.png", Main.SHIELD_ICON_SIZE).pixbuf;
			set_shield_label(_("Live USB Mode (Restore Only)"));
			set_shield_subnote("");

			switch (status_code){
			case SnapshotLocationStatus.NOT_SELECTED:
			case SnapshotLocationStatus.NOT_AVAILABLE:
				set_shield_subnote(details);
				break;
			
			case SnapshotLocationStatus.HAS_SNAPSHOTS_NO_SPACE:
			case SnapshotLocationStatus.HAS_SNAPSHOTS_HAS_SPACE:
				set_shield_subnote(_("Snapshots available for restore"));
				break;

			case SnapshotLocationStatus.NO_SNAPSHOTS_NO_SPACE:
			case SnapshotLocationStatus.NO_SNAPSHOTS_HAS_SPACE:
				set_shield_subnote(_("No snapshots found"));
				break;
			}
		}
		else{
			statusbar.visible = true;
			statusbar.show_all();

			switch (status_code){
			case SnapshotLocationStatus.READ_ONLY_FS:
			case SnapshotLocationStatus.HARDLINKS_NOT_SUPPORTED:
			case SnapshotLocationStatus.NOT_SELECTED:
			case SnapshotLocationStatus.NOT_AVAILABLE:
			case SnapshotLocationStatus.HAS_SNAPSHOTS_NO_SPACE:
			case SnapshotLocationStatus.NO_SNAPSHOTS_NO_SPACE:
				img_shield.pixbuf =
					get_shared_icon("", "security-low.svg", Main.SHIELD_ICON_SIZE).pixbuf;
				set_shield_label(message);
				set_shield_subnote(details);
				break;

			case SnapshotLocationStatus.NO_SNAPSHOTS_HAS_SPACE:
			case SnapshotLocationStatus.HAS_SNAPSHOTS_HAS_SPACE:
				// has space
				if (App.scheduled){
					// is scheduled
					if (App.repo.has_snapshots()){
						// has snaps
						img_shield.pixbuf =
							get_shared_icon("", "security-high.svg", Main.SHIELD_ICON_SIZE).pixbuf;
						//set_shield_label(_("System is protected"));
						set_shield_label(_("Timeshift is active"));
						set_shield_subnote(
							_("Latest snapshot:")
							+ last_snapshot_date.format (" %B %d, %Y %I:%M %p") + "\n" +
							_("Oldest snapshot:")
							+ oldest_snapshot_date.format (" %B %d, %Y %I:%M %p")
							//_("Latest snapshot:") + format_date(last_snapshot_date) + "\n" +
							//_("Oldest snapshot:") + format_date(oldest_snapshot_date)
							);

					}
					else{
						// no snaps
						img_shield.pixbuf =
							get_shared_icon("", "security-high.svg", Main.SHIELD_ICON_SIZE).pixbuf;
						//set_shield_label(_("No snapshots available"));
						//set_shield_subnote(_("Create a snapshot to start using Timeshift"));
						set_shield_label(_("Timeshift is active"));
						set_shield_subnote(_("Snapshots will be created at selected intervals"));
						//set_shield_subnote(_("Snapshots will be created at scheduled intervals"));
						//TODO: enable scheduled snaps without first snap
					}

					//TODO: show more info, count and free space
				}
				else {
					// not scheduled
					if (App.repo.has_snapshots()){
						// has snaps
						img_shield.pixbuf =
							get_shared_icon("", "security-medium.svg", Main.SHIELD_ICON_SIZE).pixbuf;
						set_shield_label(_("Scheduled snapshots are disabled"));
						set_shield_subnote(_("Enable scheduled snapshots to protect your system"));
					}
					else{
						// no snaps
						img_shield.pixbuf =
							get_shared_icon("", "security-low.svg", Main.SHIELD_ICON_SIZE).pixbuf;
						set_shield_label(_("No snapshots available"));
						set_shield_subnote(_("Create snapshots manually or enable scheduled snapshots to protect your system"));
					}
				}
				
				break;
			}

			vbox_snap_count.hide();
			vbox_free_space.hide();
			
			switch (status_code){
			case SnapshotLocationStatus.NO_SNAPSHOTS_NO_SPACE:
			case SnapshotLocationStatus.NO_SNAPSHOTS_HAS_SPACE:
			case SnapshotLocationStatus.HAS_SNAPSHOTS_NO_SPACE:
			case SnapshotLocationStatus.HAS_SNAPSHOTS_HAS_SPACE:
				vbox_snap_count.no_show_all = false;
				vbox_snap_count.show_all();
				
				lbl_snap_count.label = format_text_large(
					"%0d".printf(App.repo.snapshots.size))
					+ "\n%s".printf(_("Snapshots"));

				vbox_free_space.no_show_all = false;
				vbox_free_space.show_all();
				
				lbl_free_space.label = format_text_large(
					"%s".printf(format_file_size(App.repo.device.free_bytes)))
					+ "\n%s\n%s".printf(_("Free"), App.repo.device.device);
					
				break;
			}
		}
	}

	private string format_text_large(string text){
		return "<span size='xx-large'><b>" + text + "</b></span>";
	}
	
	// TODO: Move this to GtkHelper
	private Gtk.Label add_label(
		Gtk.Box box, string text, bool is_bold = false, bool is_italic = false, bool is_large = false){
			
		string msg = "<span%s%s%s>%s</span>".printf(
			(is_bold ? " weight=\"bold\"" : ""),
			(is_italic ? " style=\"italic\"" : ""),
			(is_large ? " size=\"x-large\"" : ""),
			text);
			
		var label = new Gtk.Label(msg);
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		box.add(label);
		return label;
	}

	private Gtk.Label add_label_header(
		Gtk.Box box, string text, bool large_heading = false){
		
		var label = add_label(box, text, true, false, large_heading);
		label.margin_bottom = 12;
		return label;
	}

	private void set_shield_label(
		string text, bool is_bold = true, bool is_italic = false, bool is_large = true){
			
		string msg = "<span%s%s%s>%s</span>".printf(
			(is_bold ? " weight=\"bold\"" : ""),
			(is_italic ? " style=\"italic\"" : ""),
			(is_large ? " size=\"x-large\"" : ""),
			escape_html(text));
			
		lbl_shield.label = msg;
	}

	private void set_shield_subnote(
		string text, bool is_bold = false, bool is_italic = true, bool is_large = false){
			
		string msg = "<span%s%s%s>%s</span>".printf(
			(is_bold ? " weight=\"bold\"" : ""),
			(is_italic ? " style=\"italic\"" : ""),
			(is_large ? " size=\"x-large\"" : ""),
			escape_html(text));
			
		lbl_shield_subnote.label = msg;
	}
}
