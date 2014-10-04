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
using TeeJee.DiskPartition;
using TeeJee.JSON;
using TeeJee.ProcessManagement;
using TeeJee.GtkHelper;
using TeeJee.Multimedia;
using TeeJee.System;
using TeeJee.Misc;

class MainWindow : Gtk.Window{
	
	private Box vbox_main;
	
	//snapshots
	private Toolbar toolbar;
	private ToolButton btn_backup;
	private ToolButton btn_restore;
	private ToolButton btn_delete_snapshot;
	private ToolButton btn_browse_snapshot;
	private ToolButton btn_settings;
	private ToolButton btn_clone;
	private ToolButton btn_refresh_snapshots;
	private ToolButton btn_view_snapshot_log;
	private ToolButton btn_view_app_logs;
	private ToolButton btn_about;
    private ToolButton btn_donate;
    
	//backup device
	private Box hbox_device;
	private Label lbl_backup_device;
	private ComboBox cmb_backup_device;
	private Button btn_refresh_backup_device_list;
	private Label lbl_backup_device_warning;
	
	//snapshots
	private ScrolledWindow sw_backups;
	private TreeView tv_backups;
    private TreeViewColumn col_date;
    private TreeViewColumn col_tags;
    private TreeViewColumn col_system;
    private TreeViewColumn col_desc;
	private int tv_backups_sort_column_index = 0;
	private bool tv_backups_sort_column_desc = true;
	
	//statusbar
	private Box hbox_statusbar;
	private Gtk.Image img_status_spinner;
	private Gtk.Image img_status_dot;
	private Label lbl_status;
	private Label lbl_status_scheduled;
	private Gtk.Image img_status_scheduled;
	private Label lbl_status_latest;
	private Gtk.Image img_status_latest;
	private Label lbl_status_device;
	private Gtk.Image img_status_device;
	private Gtk.Image img_status_progress;
	
	//timers
	private uint timer_status_message;
	private uint timer_progress;
	private uint timer_backup_device_init;
	
	//other
	private PartitionInfo snapshot_device_original;
	private int cmb_backup_device_index_default = -1;

	public MainWindow () {
		this.title = AppName + " v" + AppVersion; // + " by " + AppAuthor + " (" + "teejeetech.blogspot.in" + ")";
        this.window_position = WindowPosition.CENTER;
        this.modal = true;
        this.set_default_size (700, 500);
		this.delete_event.connect(on_delete_event);
		this.icon = get_app_icon(16);

	    //vboxMain
        vbox_main = new Box (Orientation.VERTICAL, 0);
        vbox_main.margin = 0;
        add (vbox_main);
        
        //toolbar ---------------------------------------------------
        
        //toolbar
		toolbar = new Gtk.Toolbar ();
		toolbar.toolbar_style = ToolbarStyle.BOTH_HORIZ;
		toolbar.get_style_context().add_class(Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
		//toolbar.set_size_request(-1,48);
		vbox_main.add(toolbar);

		//btn_backup
		btn_backup = new Gtk.ToolButton.from_stock ("gtk-save");
		btn_backup.is_important = true;
		btn_backup.label = _("Backup");
		btn_backup.set_tooltip_text (_("Take a manual (ondemand) snapshot"));
        toolbar.add(btn_backup);

        btn_backup.clicked.connect (btn_backup_clicked);

		//btn_restore
		btn_restore = new Gtk.ToolButton.from_stock ("gtk-apply");
		btn_restore.is_important = true;
		btn_restore.label = _("Restore");
		btn_restore.set_tooltip_text (_("Restore Snapshot"));
        toolbar.add(btn_restore);

		btn_restore.clicked.connect (btn_restore_clicked);
		
	    //btn_browse_snapshot
		btn_browse_snapshot = new Gtk.ToolButton.from_stock ("gtk-directory");
		btn_browse_snapshot.is_important = true;
		btn_browse_snapshot.label = _("Browse");
		btn_browse_snapshot.set_tooltip_text (_("Browse Snapshot"));
        toolbar.add(btn_browse_snapshot);

        btn_browse_snapshot.clicked.connect (btn_browse_snapshot_clicked);
        
		//btn_delete_snapshot
		btn_delete_snapshot = new Gtk.ToolButton.from_stock ("gtk-delete");
		btn_delete_snapshot.is_important = true;
		btn_delete_snapshot.label = _("Delete");
		btn_delete_snapshot.set_tooltip_text (_("Delete Snapshot"));
        toolbar.add(btn_delete_snapshot);

        btn_delete_snapshot.clicked.connect (btn_delete_snapshot_clicked);

        //btn_settings
		btn_settings = new Gtk.ToolButton.from_stock ("gtk-preferences");
		btn_settings.is_important = true;
		btn_settings.label = _("Settings");
		btn_settings.set_tooltip_text (_("Settings"));
        toolbar.add(btn_settings);

        btn_settings.clicked.connect (btn_settings_clicked);
        
        //separator
		var separator = new Gtk.SeparatorToolItem();
		separator.set_draw (false);
		separator.set_expand (true);
		toolbar.add (separator);

		//btn_clone
		btn_clone = new Gtk.ToolButton.from_stock ("gtk-copy");
		btn_clone.is_important = false;
		btn_clone.label = _("Clone");
		btn_clone.set_tooltip_text (_("Clone the current system on another device"));
        toolbar.add(btn_clone);

        btn_clone.clicked.connect (btn_clone_clicked);
        
        //btn_refresh_snapshots
        btn_refresh_snapshots = new Gtk.ToolButton.from_stock ("gtk-refresh");
		btn_refresh_snapshots.label = _("Refresh");
		btn_refresh_snapshots.set_tooltip_text (_("Refresh Snapshot List"));
        toolbar.add(btn_refresh_snapshots);

        btn_refresh_snapshots.clicked.connect (() => {
			if (!check_backup_device_online()) { return; }
			App.update_snapshot_list();
			refresh_tv_backups();
		});

		//btn_view_snapshot_log
        btn_view_snapshot_log = new Gtk.ToolButton.from_stock ("gtk-file");
		btn_view_snapshot_log.label = _("Log");
		btn_view_snapshot_log.set_tooltip_text (_("View rsync log for selected snapshot"));
        toolbar.add(btn_view_snapshot_log);

        btn_view_snapshot_log.clicked.connect (btn_view_snapshot_log_clicked);
		
		//btn_view_app_logs
        btn_view_app_logs = new Gtk.ToolButton.from_stock ("gtk-file");
		btn_view_app_logs.label = _("TimeShift Logs");
		btn_view_app_logs.set_tooltip_text (_("View TimeShift Logs"));
        toolbar.add(btn_view_app_logs);

        btn_view_app_logs.clicked.connect (btn_view_app_logs_clicked);
        
		//btn_donate
        btn_donate = new Gtk.ToolButton.from_stock ("gtk-missing-image");
		btn_donate.label = _("Donate");
		btn_donate.set_tooltip_text (_("Donate"));
		btn_donate.icon_widget = get_shared_icon("donate","donate.svg",24);
        toolbar.add(btn_donate);
		
		btn_donate.clicked.connect(btn_donate_clicked);

		//btn_about
        btn_about = new Gtk.ToolButton.from_stock ("gtk-about");
		btn_about.label = _("About");
		btn_about.set_tooltip_text (_("Application Info"));
		btn_about.icon_widget = get_shared_icon("","help-info.svg",24);
        toolbar.add(btn_about);

        btn_about.clicked.connect (btn_about_clicked);

		//backup device ------------------------------------------------
		
		//hbox_device
		hbox_device = new Box (Orientation.HORIZONTAL, 6);
        hbox_device.margin_top = 6;
        hbox_device.margin_left = 6;
        hbox_device.margin_right = 6;
        vbox_main.add (hbox_device);

        //lbl_backup_device
		lbl_backup_device = new Gtk.Label(_("Backup Device"));
		lbl_backup_device.xalign = (float) 0.0;
		hbox_device.add(lbl_backup_device);
		
		//cmb_backup_device
		cmb_backup_device = new ComboBox ();
		cmb_backup_device.hexpand = true;
		cmb_backup_device.set_tooltip_markup(_("Snapshots will be saved in path <b>/timeshift</b> on selected device"));
		hbox_device.add(cmb_backup_device);
		
		CellRendererText cell_backup_dev_margin = new CellRendererText ();
		cell_backup_dev_margin.text = "";
		cmb_backup_device.pack_start (cell_backup_dev_margin, false);
		
		CellRendererPixbuf cell_backup_dev_icon = new CellRendererPixbuf ();
		cell_backup_dev_icon.stock_id = "gtk-harddisk";
		cmb_backup_device.pack_start (cell_backup_dev_icon, false);
		
		CellRendererText cell_backup_device = new CellRendererText();
        cmb_backup_device.pack_start( cell_backup_device, false );
        cmb_backup_device.set_cell_data_func (cell_backup_device, cell_backup_device_render);

		cmb_backup_device.changed.connect(cmb_backup_device_changed);
		
		//btn_refresh_backup_device_list
		btn_refresh_backup_device_list = new Gtk.Button.with_label (" " + _("Refresh") + " ");
		btn_refresh_backup_device_list.set_size_request(50,-1);
		btn_refresh_backup_device_list.set_tooltip_text(_("Refresh Devices"));
		btn_refresh_backup_device_list.clicked.connect(()=>{ 
			App.update_partition_list();
			refresh_cmb_backup_device(); 
			refresh_tv_backups();
		});
		hbox_device.add(btn_refresh_backup_device_list);
		
		//lbl_backup_device_warning
		lbl_backup_device_warning = new Gtk.Label("");
		lbl_backup_device_warning.set_use_markup(true);
		lbl_backup_device_warning.xalign = (float) 0.0;
		lbl_backup_device_warning.no_show_all = true;
		lbl_backup_device_warning.margin_left = 6;
		lbl_backup_device_warning.margin_top = 6;
		lbl_backup_device_warning.margin_bottom = 6;
		vbox_main.add(lbl_backup_device_warning);

		//snapshot list ----------------------------------------------
		
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
		cell_backup_icon.stock_id = "gtk-floppy";
		cell_backup_icon.xpad = 1;
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
		CellRendererText cell_desc = new CellRendererText ();
		cell_desc.ellipsize = Pango.EllipsizeMode.END;
		col_desc.pack_start (cell_desc, false);
		col_desc.set_cell_data_func (cell_desc, cell_desc_render);
		tv_backups.append_column(col_desc);
		cell_desc.editable = true;
		
		cell_desc.edited.connect (cell_desc_edited);
		
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
		
		//hbox_statusbar
		hbox_statusbar = new Box (Orientation.HORIZONTAL, 6);
        hbox_statusbar.margin_bottom = 1;
        hbox_statusbar.margin_left = 6;
        hbox_statusbar.margin_right = 12;
        vbox_main.add (hbox_statusbar);

		//img_status_spinner
		img_status_spinner = new Gtk.Image();
		img_status_spinner.file = App.share_folder + "/timeshift/images/spinner.gif";
		img_status_spinner.no_show_all = true;
        hbox_statusbar.add(img_status_spinner);
        
        //img_status_dot
		img_status_dot = new Gtk.Image();
		img_status_dot.file = App.share_folder + "/timeshift/images/item-green.gif";
		img_status_dot.no_show_all = true;
        hbox_statusbar.add(img_status_dot);
		
        //lbl_status
		lbl_status = new Gtk.Label("");
		lbl_status.no_show_all = true;
		hbox_statusbar.add(lbl_status);

        //img_status_device
		img_status_device = new Gtk.Image();
		img_status_device.no_show_all = true;
        hbox_statusbar.add(img_status_device);
        
        //lbl_status_device
		lbl_status_device = new Gtk.Label("");
		lbl_status_device.set_use_markup(true);
		lbl_status_device.no_show_all = true;
		hbox_statusbar.add(lbl_status_device);
		
        //img_status_scheduled
		img_status_scheduled = new Gtk.Image();
		img_status_scheduled.no_show_all = true;
        hbox_statusbar.add(img_status_scheduled);
        
		//lbl_status_scheduled
		lbl_status_scheduled = new Gtk.Label("");
		lbl_status_scheduled.set_use_markup(true);
		lbl_status_scheduled.no_show_all = true;
		hbox_statusbar.add(lbl_status_scheduled);
				
        //img_status_latest
		img_status_latest = new Gtk.Image();
		img_status_latest.no_show_all = true;
        hbox_statusbar.add(img_status_latest);
        
        //lbl_status_latest
		lbl_status_latest = new Gtk.Label("");
		lbl_status_latest.set_use_markup(true);
		lbl_status_latest.no_show_all = true;
		hbox_statusbar.add(lbl_status_latest);
		
		//lbl_status_separator
		Label lbl_status_separator = new Gtk.Label("");
		hbox_statusbar.hexpand = true;
		hbox_statusbar.pack_start(lbl_status_separator,true,true,0);
		
		//img_status_progress
		img_status_progress = new Gtk.Image();
		img_status_progress.file = App.share_folder + "/timeshift/images/progress.gif";
		img_status_progress.no_show_all = true;
        hbox_statusbar.add(img_status_progress);
        
        snapshot_device_original = App.snapshot_device;
        
        if (App.live_system()){
			btn_backup.sensitive = false;
			btn_clone.sensitive = false;
			btn_settings.sensitive = false;
			btn_view_app_logs.sensitive = false;
		}
		
		refresh_cmb_backup_device();
		timer_backup_device_init = Timeout.add(100, initialize_backup_device);
    }

	private bool initialize_backup_device(){
		if (timer_backup_device_init > 0){
			Source.remove(timer_backup_device_init);
			timer_backup_device_init = -1;
		}
		
		update_ui(false);
		
		if (App.live_system()){
			statusbar_message(_("Checking backup device..."));
		}
		else{
			statusbar_message(_("Estimating system size..."));
		}
		
		//refresh_cmb_backup_device();
		refresh_tv_backups();
		check_status();
		update_ui(true);

		return false;
	}
	
	private bool on_delete_event(Gdk.EventAny event){
		
		this.delete_event.disconnect(on_delete_event); //disconnect this handler

		if (App.is_rsync_running()){
			log_error (_("Main window closed by user"));
			App.kill_rsync();
		}

		if (!App.is_scheduled){
			return false; //close window
		}
		
		//else - check backup device -------------------------------
		
		string message;
		int status_code = App.check_backup_device(out message);

		switch(status_code){
			case 1:
				string msg = message + "\n";
				msg += _("Scheduled snapshots will be disabled.");

				var dialog = new Gtk.MessageDialog.with_markup(this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.OK_CANCEL, msg);
				dialog.set_title(_("Disable Scheduled Snapshots"));
				dialog.set_default_size (300, -1);
				dialog.set_transient_for(this);
				dialog.set_modal(true);
				int response = dialog.run();
				dialog.destroy();
				
				if (response == Gtk.ResponseType.OK){
					App.is_scheduled = false;
					return false; //close window
				}
				else{
					this.delete_event.connect(on_delete_event); //reconnect this handler
					return true; //keep window open
				}

			case 2:
				string msg = _("Selected device does not have enough space.") + "\n";
				msg += _("Scheduled snapshots will be disabled till another device is selected.") + "\n";
				msg += _("Do you want to select another device now?") + "\n";
				
				var dialog = new Gtk.MessageDialog.with_markup(this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.YES_NO, msg);
				dialog.set_title(_("Disable Scheduled Snapshots"));
				dialog.set_default_size (300, -1);
				dialog.set_transient_for(this);
				dialog.set_modal(true);
				int response = dialog.run();
				dialog.destroy();
				
				if (response == Gtk.ResponseType.YES){
					this.delete_event.connect(on_delete_event); //reconnect this handler
					return true; //keep window open
				}
				else{
					App.is_scheduled = false;
					return false; //close window
				}
				
			case 3:
				string msg = _("Scheduled jobs will be enabled only after the first snapshot is taken.") + "\n";
				msg += message + (" space and 10 minutes to complete.") + "\n";
				msg += _("Do you want to take the first snapshot now?") + "\n";
				
				var dialog = new Gtk.MessageDialog.with_markup(this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.YES_NO, msg);
				dialog.set_title(_("First Snapshot"));
				dialog.set_default_size (300, -1);
				dialog.set_transient_for(this);
				dialog.set_modal(true);
				int response = dialog.run();
				dialog.destroy();
				
				if (response == Gtk.ResponseType.YES){
					btn_backup_clicked();
					this.delete_event.connect(on_delete_event); //reconnect this handler
					return true; //keep window open
				}
				else{
					App.is_scheduled = false;
					return false; //close window
				}
				
			case 0:
				if (App.snapshot_device.uuid != snapshot_device_original.uuid){
					log_debug(_("snapshot device changed"));
					
					string msg = _("Scheduled snapshots will be saved to ") + "<b>%s</b>\n".printf(App.snapshot_device.device);
					msg += _("Click 'OK' to confirm") + "\n";
					
					var dialog = new Gtk.MessageDialog.with_markup(this, Gtk.DialogFlags.MODAL, Gtk.MessageType.INFO, Gtk.ButtonsType.OK_CANCEL, msg);
					dialog.set_title(_("Backup Device Changed"));
					dialog.set_default_size (300, -1);
					dialog.set_transient_for(this);
					dialog.set_modal(true);
					int response = dialog.run();
					dialog.destroy();
					
					if (response == Gtk.ResponseType.CANCEL){
						this.delete_event.connect(on_delete_event); //reconnect this handler
						return true; //keep window open
					}
				}
				break;
				
			case -1:
				string msg = _("The backup device is not set or unavailable.") + "\n";
				msg += _("Scheduled snapshots will be disabled.") + "\n";
				msg += _("Do you want to select another device?");

				var dialog = new Gtk.MessageDialog.with_markup(this, Gtk.DialogFlags.MODAL, Gtk.MessageType.INFO, Gtk.ButtonsType.OK_CANCEL, msg);
				dialog.set_title(_("Backup Device Changed"));
				dialog.set_default_size (300, -1);
				dialog.set_transient_for(this);
				dialog.set_modal(true);
				int response = dialog.run();
				dialog.destroy();
				
				if (response == Gtk.ResponseType.YES){
					this.delete_event.connect(on_delete_event); //reconnect this handler
					return true; //keep window open
				}
				else{
					App.is_scheduled = false;
					return false; //close window
				}
			
		}

		return false;
	}
	
	private void cell_date_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		TimeShiftBackup bak;
		model.get (iter, 0, out bak, -1);
		(cell as Gtk.CellRendererText).text = bak.date.format ("%Y-%m-%d %I:%M %p");
	}
	
	private void cell_tags_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		TimeShiftBackup bak;
		model.get (iter, 0, out bak, -1);
		(cell as Gtk.CellRendererText).text = bak.taglist_short;
	}

	private void cell_system_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		TimeShiftBackup bak;
		model.get (iter, 0, out bak, -1);
		(cell as Gtk.CellRendererText).text = bak.sys_distro;
	}
	
	private void cell_desc_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		TimeShiftBackup bak;
		model.get (iter, 0, out bak, -1);
		(cell as Gtk.CellRendererText).text = bak.description;
	}
	
	private void cell_desc_edited (string path, string new_text) {
		TimeShiftBackup bak;

		TreeIter iter;
		ListStore model = (ListStore) tv_backups.model;
		model.get_iter_from_string (out iter, path);
		model.get (iter, 0, out bak, -1);
		bak.description = new_text;
		bak.update_control_file();
	}

	private void cell_backup_device_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		PartitionInfo info;
		model.get (iter, 0, out info, -1);
		(cell as Gtk.CellRendererText).text = info.description();
	}

	private void refresh_tv_backups(){
		
		App.update_snapshot_list();
		
		ListStore model = new ListStore(1, typeof(TimeShiftBackup));
		
		var list = App.snapshot_list;
		
		if (tv_backups_sort_column_index == 0){
			
			if (tv_backups_sort_column_desc)
			{
				list.sort((a,b) => { 
					TimeShiftBackup t1 = (TimeShiftBackup) a;
					TimeShiftBackup t2 = (TimeShiftBackup) b;
					
					return (t1.date.compare(t2.date));
				});
			}
			else{
				list.sort((a,b) => { 
					TimeShiftBackup t1 = (TimeShiftBackup) a;
					TimeShiftBackup t2 = (TimeShiftBackup) b;
					
					return -1 * (t1.date.compare(t2.date));
				});
			}
		}
		else{
			if (tv_backups_sort_column_desc)
			{
				list.sort((a,b) => { 
					TimeShiftBackup t1 = (TimeShiftBackup) a;
					TimeShiftBackup t2 = (TimeShiftBackup) b;
					
					return strcmp(t1.taglist,t2.taglist);
				});
			}
			else{
				list.sort((a,b) => { 
					TimeShiftBackup t1 = (TimeShiftBackup) a;
					TimeShiftBackup t2 = (TimeShiftBackup) b;
					
					return -1 * strcmp(t1.taglist,t2.taglist);
				});
			}
		}

		TreeIter iter;
		foreach(TimeShiftBackup bak in list) {
			model.append(out iter);
			model.set (iter, 0, bak);
		}
			
		tv_backups.set_model (model);
		tv_backups.columns_autosize ();
	}

	private void refresh_cmb_backup_device(){
		ListStore store = new ListStore(1, typeof(PartitionInfo));

		TreeIter iter;

		int index = -1;
		int index_selected = -1;
		cmb_backup_device_index_default = -1;

		foreach(PartitionInfo pi in App.partition_list) {
			
			if (!pi.has_linux_filesystem()) { continue; }

			store.append(out iter);
			store.set (iter, 0, pi);

			index++;
			if ((App.root_device != null) && (pi.uuid == App.root_device.uuid)){
				cmb_backup_device_index_default = index;
			}
			if ((App.snapshot_device != null) && (pi.uuid == App.snapshot_device.uuid)){
				index_selected = index;
			}
		}

		if (index_selected > -1){
			//ok
		}
		else if (cmb_backup_device_index_default > -1){
			index_selected = cmb_backup_device_index_default;
		}
		else if (index > -1){
			index_selected = 0;
		}
		
		cmb_backup_device.set_model (store);
		cmb_backup_device.active = index_selected;
	}
	
	private void cmb_backup_device_changed(){
		ComboBox combo = cmb_backup_device;
		if (combo.model == null) { return; }
		
		string txt;
		if (combo.active < 0) { 
			txt = "<b>" + _("WARNING:") + "</b>\n";
			txt += "Ø " + _("Please select a device for saving snapshots.") + "\n";
			txt = "<span foreground=\"#8A0808\">" + txt + "</span>";
			lbl_backup_device_warning.label = txt;
			App.snapshot_device = null;
			return; 
		}

		//get new device reference
		TreeIter iter;
		PartitionInfo pi;
		combo.get_active_iter (out iter);
		TreeModel model = (TreeModel) combo.model;
		model.get(iter, 0, out pi);
		
		//check if device has changed
		if ((App.snapshot_device != null) && (pi.uuid == App.snapshot_device.uuid)){ return; }

		gtk_set_busy(true, this);
		
		//try changing backup device ------------------
		
		App.snapshot_device = pi;
		
		long size_before = App.snapshot_device.size_mb;

		bool status = App.mount_backup_device();
		if (status == false){
			string msg = _("Failed to mount device") + ": %s".printf(App.snapshot_device.device);
			var dlg = new Gtk.MessageDialog.with_markup(this, Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR, Gtk.ButtonsType.OK, msg);
			dlg.set_title(_("Error"));
			dlg.set_default_size (200, -1);
			dlg.set_transient_for(this);
			dlg.set_modal(true);
			dlg.run();
			dlg.destroy();

			cmb_backup_device.active = cmb_backup_device_index_default;
			gtk_set_busy(false, this);
			return;
		}
		
		//get disk space after mounting
		App.update_partition_list();
		long size_after = App.snapshot_device.size_mb;
		
		gtk_set_busy(false, this);
		
		if (size_after > size_before){
			refresh_cmb_backup_device();
		}
		else{
			timer_backup_device_init = Timeout.add(100, initialize_backup_device);
		}
	}
	
	private void btn_backup_clicked(){
		
		//check root device --------------
		
		if (App.check_btrfs_root_layout() == false){
			return;
		}
		
		//check snapshot device -----------
		
		string msg;
		int status_code = App.check_backup_device(out msg);
		
		switch(status_code){
			case -1:
				check_backup_device_online();
				return;
			case 1:
			case 2:
				gtk_messagebox(_("Low Disk Space"),_("Backup device does not have enough space"),null, true);
				check_status();
				return;
		}

		//update UI ------------------
		
		update_ui(false);

		statusbar_message(_("Taking snapshot..."));
		
		update_progress_start();
		
		//take snapshot ----------------
		
		bool is_success = App.take_snapshot(true); 

		update_progress_stop();
		
		if (is_success){
			statusbar_message_with_timeout(_("Snapshot saved successfully"), true);
		}
		else{
			statusbar_message_with_timeout(_("Error: Unable to save snapshot"), false);
		}
		
		//update UI -------------------
		
		App.update_partition_list();
		refresh_cmb_backup_device();
		refresh_tv_backups();
		check_status();
		
		update_ui(true);
	}

	private void btn_delete_snapshot_clicked(){
		TreeIter iter;
		TreeIter iter_delete;
		TreeSelection sel;
		bool is_success = true;
		
		//check if device is online
		if (!check_backup_device_online()) { return; }
		
		//check selected count ----------------
		
		sel = tv_backups.get_selection ();
		if (sel.count_selected_rows() == 0){ 
			gtk_messagebox(_("No Snapshots Selected"),_("Please select the snapshots to delete"),null,false);
			return; 
		}
		
		//update UI ------------------
		
		update_ui(false);
		
		statusbar_message(_("Removing selected snapshots..."));
		
		//get list of snapshots to delete --------------------

		var list_of_snapshots_to_delete = new Gee.ArrayList<TimeShiftBackup>();
		ListStore store = (ListStore) tv_backups.model;
		
		bool iterExists = store.get_iter_first (out iter);
		while (iterExists && is_success) { 
			if (sel.iter_is_selected (iter)){
				TimeShiftBackup bak;
				store.get (iter, 0, out bak);
				list_of_snapshots_to_delete.add(bak);
			}
			iterExists = store.iter_next (ref iter);
		}
		
		//clear selection ---------------
		
		tv_backups.get_selection().unselect_all();
		
		//delete snapshots --------------------------
		
		foreach(TimeShiftBackup bak in list_of_snapshots_to_delete){
			
			//find the iter being deleted
			iterExists = store.get_iter_first (out iter_delete);
			while (iterExists) { 
				TimeShiftBackup bak_current;
				store.get (iter_delete, 0, out bak_current);
				if (bak_current.path == bak.path){
					break;
				}
				iterExists = store.iter_next (ref iter_delete);
			}
			
			//select the iter being deleted
			tv_backups.get_selection().select_iter(iter_delete);
			
			statusbar_message(_("Deleting snapshot") + ": '%s'...".printf(bak.name));
			
			is_success = App.delete_snapshot(bak); 
			
			if (!is_success){
				statusbar_message_with_timeout(_("Error: Unable to delete snapshot") + ": '%s'".printf(bak.name), false);
				break;
			}
			
			//remove iter from tv_backups
			store.remove(iter_delete);
		}
		
		App.update_snapshot_list();
		if (App.snapshot_list.size == 0){
			statusbar_message(_("Deleting snapshot") + ": '.sync'...");
			App.delete_all_snapshots();
		}
		
		if (is_success){
			statusbar_message_with_timeout(_("Snapshots deleted successfully"), true);
		}
		
		//update UI -------------------
		
		App.update_partition_list();
		refresh_cmb_backup_device();
		refresh_tv_backups();
		check_status();

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
				gtk_messagebox(_("No Snapshots Selected"), _("Please select the snapshot to restore"),null,false);
				return; 
			}
			else if (sel.count_selected_rows() > 1){ 
				gtk_messagebox(_("Multiple Snapshots Selected"), _("Please select a single snapshot"),null,false);
				return; 
			}
			
			//get selected snapshot ------------------
			
			TimeShiftBackup snapshot_to_restore = null;
			
			ListStore store = (ListStore) tv_backups.model;
			sel = tv_backups.get_selection();
			bool iterExists = store.get_iter_first (out iter);
			while (iterExists) { 
				if (sel.iter_is_selected (iter)){
					store.get (iter, 0, out snapshot_to_restore);
					break;
				}
				iterExists = store.iter_next (ref iter);
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
				statusbar_message(_("Taking snapshot..."));
			
				update_progress_start();
				
				bool is_success = App.take_snapshot(true); 
				
				update_progress_stop();
				
				if (is_success){
					App.update_snapshot_list();
					var latest = App.get_latest_snapshot("ondemand");
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
			statusbar_message(_("Restoring snapshot..."));
		}
		else{
			log_msg("Cloning current system to device '%s'".printf(App.restore_target.device),true);
			statusbar_message(_("Cloning system..."));
		}
		
		if (App.reinstall_grub2){
			log_msg("GRUB will be installed on '%s'".printf(App.grub_device),true);
		}

		bool is_success = App.restore_snapshot(); 
		
		string msg;
		if (is_success){
			if (App.mirror_system){
				msg = _("System was cloned successfully on target device");
			}
			else{
				msg = _("Snapshot was restored successfully on target device");
			}
			statusbar_message_with_timeout(msg, true);
			
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

			statusbar_message_with_timeout(msg, true);

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
		var dialog = new SettingsWindow();
		dialog.set_transient_for (this);
		dialog.response.connect ((response_id) => {
			if (response_id == Gtk.ResponseType.CANCEL || response_id == Gtk.ResponseType.DELETE_EVENT) {
				dialog.hide_on_delete ();
			}
		});
		
		dialog.show_all();
		dialog.run();
		check_status();
	}
	
	private void btn_browse_snapshot_clicked(){
		
		//check if device is online
		if (!check_backup_device_online()) { 
			return; 
		}
		
		TreeSelection sel = tv_backups.get_selection ();
		if (sel.count_selected_rows() == 0){
			var f = File.new_for_path(App.snapshot_dir);
			if (f.query_exists()){
				exo_open_folder(App.snapshot_dir);
			}
			else{
				exo_open_folder(App.mount_point_backup);
			}
			return;
		}
		
		TreeIter iter;
		ListStore store = (ListStore)tv_backups.model;
		
		bool iterExists = store.get_iter_first (out iter);
		while (iterExists) { 
			if (sel.iter_is_selected (iter)){
				TimeShiftBackup bak;
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
			gtk_messagebox(_("Select Snapshot"),_("Please select a snapshot to view the log!"),null,false);
			return;
		}
		
		TreeIter iter;
		ListStore store = (ListStore)tv_backups.model;
		
		bool iterExists = store.get_iter_first (out iter);
		while (iterExists) { 
			if (sel.iter_is_selected (iter)){
				TimeShiftBackup bak;
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
			"Debaru, Nikos, alienus (French):launchpad.net/~lp-l10n-fr",
			"tomberry88 (Italian):launchpad.net/~tomberry",
			"박정규(Jung-Kyu Park) (Korean):bagjunggyu@gmail.com"
		}; 
		
		dialog.documenters = null; 
		dialog.artists = null;
		dialog.donations = null;

		dialog.program_name = AppName;
		dialog.comments = _("A System Restore Utility for Linux");
		dialog.copyright = "Copyright © 2014 Tony George (%s)".printf(AppAuthorEmail);
		dialog.version = AppVersion;
		dialog.logo = get_app_icon(128);

		dialog.license = "This program is free for personal and commercial use and comes with absolutely no warranty. You use this program entirely at your own risk. The author will not be liable for any damages arising from the use of this program.";
		dialog.website = "http://teejeetech.in";
		dialog.website_label = "http://teejeetech.blogspot.in";

		dialog.initialize();
		dialog.show_all();
	}


	private void show_statusbar_icons(bool visible){
		img_status_dot.visible = false;
		img_status_spinner.visible = !visible;
		img_status_progress.visible = !visible;
		lbl_status.visible = !visible;
		lbl_status.label = "";
		
		img_status_device.visible = visible;
		lbl_status_device.visible = visible;
		
		//if (App.is_live_system()){
			//visible = false;
		//}
		
		img_status_scheduled.visible = visible;
		lbl_status_scheduled.visible = visible;
		img_status_latest.visible = visible;
		lbl_status_latest.visible = visible;
	}

	private void statusbar_message (string message){
		if (timer_status_message > 0){
			Source.remove (timer_status_message);
			timer_status_message = -1;
		}

		lbl_status.label = message;
	}
	
	private void statusbar_message_with_timeout (string message, bool success){
		if (timer_status_message > 0){
			Source.remove (timer_status_message);
			timer_status_message = -1;
		}

		lbl_status.label = message;
		
		img_status_spinner.visible = false;
		img_status_progress.visible = false;
		img_status_dot.visible = true;
		
		if (success){
			img_status_dot.file =  App.share_folder + "/timeshift/images/item-green.png";
		}
		else{
			img_status_dot.file =  App.share_folder + "/timeshift/images/item-red.png";
		}
		
		timer_status_message = Timeout.add_seconds (5, statusbar_clear);
	}
	
    private bool statusbar_clear (){
		if (timer_status_message > 0){
			Source.remove (timer_status_message);
			timer_status_message = -1;
		}
		lbl_status.label = "";
		show_statusbar_icons(true);
		return true;
	}
	
	private void update_ui(bool enable){
		toolbar.sensitive = enable;
		hbox_device.sensitive = enable;
		sw_backups.sensitive = enable;
		show_statusbar_icons(enable);
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
			gtk_messagebox(_("Device Offline"),_("Backup device is not available"), null, true);
			check_status();
			return false;
		}
		else{
			return true;
		}
	}

	private bool check_status(){
		string img_dot_red = App.share_folder + "/timeshift/images/item-red.png";
		string img_dot_green = App.share_folder + "/timeshift/images/item-green.png";
		
		//check free space on backup device ---------------------------
			
		string message = "";
		int status_code = App.check_backup_device(out message);
		string txt;

		switch(status_code){
			case -1:
				if (App.snapshot_device == null){
					txt = _("Please select the backup device");
				}
				else{
					txt = _("Backup device is not mounted!");;
				}
				txt = "<span foreground=\"#8A0808\">" + txt + "</span>";
				lbl_backup_device_warning.label = txt;
				lbl_backup_device_warning.visible = true;
				break;
				
			case 1:
				txt = _("Backup device does not have enough space!");
				txt = "<span foreground=\"#8A0808\">" + txt + "</span>";
				lbl_backup_device_warning.label = txt;
				lbl_backup_device_warning.visible = true;
				break;
				
			case 2:
				long required = App.calculate_size_of_first_snapshot();
				txt = _("Backup device does not have enough space!") + " ";
				txt += _("First snapshot needs") + " %.1f GB".printf(required/1024.0);
				txt = "<span foreground=\"#8A0808\">" + txt + "</span>";
				lbl_backup_device_warning.label = txt;
				lbl_backup_device_warning.visible = true;
				break;
			 
			default:
				lbl_backup_device_warning.label = "";
				lbl_backup_device_warning.visible = false;
				break;
		}
		
		if ((status_code == 0)||(status_code == 3)){
			img_status_device.file = img_dot_green;
		}
		else{
			img_status_device.file = img_dot_red;
		}
		lbl_status_device.label = message;
		
		img_status_device.visible = (message.strip().length > 0);
		lbl_status_device.visible = (message.strip().length > 0);
		
		// statusbar icons ---------------------------------------------------------
		
		//status - scheduled snapshots -----------
		
		if (App.live_system()){
			img_status_scheduled.file = img_dot_green;
			lbl_status_scheduled.label = _("Running from Live CD/USB");
			lbl_status_scheduled.set_tooltip_text(_("TimeShift is running in a live system"));
		}
		else{
			if (App.is_scheduled){
				img_status_scheduled.file = img_dot_green;
				lbl_status_scheduled.label = _("Scheduled snapshots") + " " + _("Enabled");
				lbl_status_scheduled.set_tooltip_text(_("System snapshots will be taken at regular intervals"));
			}else{
				img_status_scheduled.file = img_dot_red;
				lbl_status_scheduled.label = _("Scheduled snapshots") + " " + _("Disabled");
				lbl_status_scheduled.set_tooltip_text("");
			}
		}

		//status - last snapshot -----------
		
		if (status_code >= 0){
			DateTime now = new DateTime.now_local();
			TimeShiftBackup last_snapshot = App.get_latest_snapshot();
			DateTime last_snapshot_date = (last_snapshot == null) ? null : last_snapshot.date;
			
			if (last_snapshot == null){
				img_status_latest.file = img_dot_red;
				lbl_status_latest.label = _("No snapshots on device");
			}
			else{
				float days = ((float) now.difference(last_snapshot_date) / TimeSpan.DAY);
				float hours = ((float) now.difference(last_snapshot_date) / TimeSpan.HOUR);
				
				if (days > 1){
					img_status_latest.file = img_dot_red;
					lbl_status_latest.label = _("Last snapshot is") +  " %.0f ".printf(days) + _("days old") + "!";
				}
				else if (hours > 1){
					img_status_latest.file = img_dot_green;
					lbl_status_latest.label = _("Last snapshot is") +  " %.0f ".printf(hours) + _("hours old");
				}
				else{
					img_status_latest.file = img_dot_green;
					lbl_status_latest.label = _("Last snapshot is less than 1 hour old");
				}
			}
		}
		else{
			img_status_latest.visible = false;
			lbl_status_latest.visible = false;
		}
		
		return true;
	}
	
}
