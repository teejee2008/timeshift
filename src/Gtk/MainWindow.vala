/*
 * MainWindow.vala
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
	private Gtk.ToolButton btn_donate;
	private Gtk.Menu menu_extra;

	private SnapshotListBox snapshot_list_box;
	
	//statusbar
	private Gtk.ScrolledWindow statusbar;
	private Gtk.Image img_shield;
	private Gtk.Label lbl_shield;
	private Gtk.Label lbl_shield_subnote;
	private Gtk.Label lbl_snap_count;
	private Gtk.Label lbl_snap_count_subnote;
	private Gtk.Label lbl_free_space;
	private Gtk.Label lbl_free_space_subnote;
	private Gtk.ScrolledWindow scrolled_snap_count;
	private Gtk.ScrolledWindow scrolled_free_space;
	
	//timers
	private uint tmr_init;
	private int def_width = 800;
	private int def_height = 600;

    //private int TOOLBAR_ICON_SIZE = 24;

	public MainWindow () {

		log_debug("MainWindow: MainWindow()");
		
		this.title = AppName;
        this.window_position = WindowPosition.CENTER;
        this.modal = true;
        this.set_default_size (def_width, def_height);
		this.delete_event.connect(on_delete_event);
		this.icon = IconManager.lookup("timeshift",16);

	    //vbox_main
        vbox_main = new Gtk.Box(Orientation.VERTICAL, 0);
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

		log_debug("MainWindow: MainWindow(): exit");
    }

    private bool init_delayed(){
		
		if (tmr_init > 0){
			Source.remove(tmr_init);
			tmr_init = 0;
		}

		log_debug("MainWindow(): init_delayed()");

		if ((App.repo == null) || !App.repo.available()){
			if (App.backup_parent_uuid.length > 0){
				log_debug("repo: creating from parent uuid");
				App.repo = new SnapshotRepo.from_uuid(App.backup_parent_uuid, this, App.btrfs_mode);
			}
		}

		refresh_all();

		if (App.first_run){
			btn_wizard_clicked();
		}

		log_debug("MainWindow(): init_delayed(): exit");
		
		return false;
	}

	private void init_ui_toolbar(){
		
		//toolbar
		toolbar = new Gtk.Toolbar ();
		toolbar.toolbar_style = ToolbarStyle.BOTH;
		toolbar.get_style_context().add_class(Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
		vbox_main.add(toolbar);

        Gtk.Image img = new Gtk.Image.from_icon_name("document-save-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
		btn_backup = new Gtk.ToolButton (img, null);
		btn_backup.is_important = true;
		btn_backup.label = _("Create");
		btn_backup.set_tooltip_text (_("Create snapshot of current system"));
        toolbar.add(btn_backup);

        btn_backup.clicked.connect (create_snapshot);

		//btn_restore
        img = new Gtk.Image.from_icon_name("document-open-recent-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
		btn_restore = new Gtk.ToolButton (img, null);
		btn_restore.is_important = true;
		btn_restore.label = _("Restore");
		btn_restore.set_tooltip_text (_("Restore selected snapshot"));
        toolbar.add(btn_restore);

		btn_restore.clicked.connect (btn_restore_clicked);

		//btn_delete_snapshot
		img = new Gtk.Image.from_icon_name("edit-delete-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
		btn_delete_snapshot = new Gtk.ToolButton (img, null);
		btn_delete_snapshot.is_important = true;
		btn_delete_snapshot.label = _("Delete");
		btn_delete_snapshot.set_tooltip_text (_("Delete selected snapshot"));
        toolbar.add(btn_delete_snapshot);

        btn_delete_snapshot.clicked.connect (delete_selected);
        
	    //btn_browse_snapshot
        img = new Gtk.Image.from_icon_name("folder-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
		btn_browse_snapshot = new Gtk.ToolButton (img, null);
		btn_browse_snapshot.is_important = true;
		btn_browse_snapshot.label = _("Browse");
		btn_browse_snapshot.set_tooltip_text (_("Browse selected snapshot"));
        toolbar.add(btn_browse_snapshot);

        btn_browse_snapshot.clicked.connect (browse_selected);

        //btn_settings
        img = new Gtk.Image.from_icon_name("preferences-system-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
		btn_settings = new Gtk.ToolButton (img, null);
		btn_settings.is_important = true;
		btn_settings.label = _("Settings");
		btn_settings.set_tooltip_text (_("Settings"));
        toolbar.add(btn_settings);

        btn_settings.clicked.connect (btn_settings_clicked);

        //btn_wizard
        img = new Gtk.Image.from_icon_name("emblem-default-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
		btn_wizard = new Gtk.ToolButton (img, null);
		btn_wizard.is_important = true;
		btn_wizard.label = _("Wizard");
		btn_wizard.set_tooltip_text (_("Settings wizard"));
        toolbar.add(btn_wizard);

        btn_wizard.clicked.connect (btn_wizard_clicked);

		// TODO: replace gtk icon names with desktop-neutral names
		
        //separator
		var separator = new Gtk.SeparatorToolItem();
		separator.set_draw (false);
		separator.set_expand (true);
		toolbar.add (separator);

		// donate
		img = new Gtk.Image.from_icon_name("donate", Gtk.IconSize.LARGE_TOOLBAR);
		btn_donate = new Gtk.ToolButton (img, null);
		btn_donate.is_important = true;
		btn_donate.label = _("Donate");
		btn_donate.set_tooltip_text (_("Donate"));
        toolbar.add(btn_donate);

        btn_donate.clicked.connect(btn_donate_clicked);

		//btn_hamburger
        img = new Gtk.Image.from_icon_name("open-menu-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
		var button = new Gtk.ToolButton (img, null);
		button.label = _("Menu");
		button.set_tooltip_text (_("Open Menu"));
		toolbar.add(button);

        // click event
		button.clicked.connect(()=>{
			menu_extra_popup(null);
		});
	}

	private void init_ui_snapshot_list(){
		
		snapshot_list_box = new SnapshotListBox(this);
		snapshot_list_box.vexpand = true;
		vbox_main.add(snapshot_list_box);

		snapshot_list_box.delete_selected.connect(delete_selected);
		
		snapshot_list_box.mark_selected.connect(mark_selected);

		snapshot_list_box.browse_selected.connect(browse_selected);

		snapshot_list_box.view_snapshot_log.connect(view_snapshot_log);
    }

	private void init_ui_statusbar(){

		// hbox_shield
		var hbox_status = new Gtk.Box(Orientation.HORIZONTAL, 6);
		hbox_status.margin = 6;
		hbox_status.margin_top = 0;
		vbox_main.add(hbox_status);
		
		// scrolled
		var scrolled = new Gtk.ScrolledWindow(null, null);
		//scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		//scrolled.margin = 6;
		//scrolled.margin_top = 0;
		scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
		scrolled.vscrollbar_policy = Gtk.PolicyType.NEVER;
		hbox_status.add(scrolled);
		statusbar = scrolled;
		
		// hbox_shield
		var box = new Gtk.Box(Orientation.HORIZONTAL, 6);
		box.margin = 6;
        //box.margin_right = 12;
		scrolled.add (box);

        // img_shield
		img_shield = new Gtk.Image();
		img_shield.surface = IconManager.lookup_surface(IconManager.SHIELD_HIGH, IconManager.SHIELD_ICON_SIZE, img_shield.scale_factor);
		//img_shield.margin_bottom = 6;
        box.add(img_shield);

		// status text
		var vbox = new Gtk.Box(Orientation.VERTICAL, 6);
		//vbox.margin_right = 6;
        box.add (vbox);
        
		//lbl_shield
		lbl_shield = add_label(vbox, "");
		//lbl_shield.margin_top = 6;
        lbl_shield.yalign = 0.5f;
		lbl_shield.hexpand = true;
		
        //lbl_shield_subnote
		lbl_shield_subnote = add_label(vbox, "");
		lbl_shield_subnote.yalign = 0.5f;
		lbl_shield_subnote.wrap = true;
		lbl_shield_subnote.wrap_mode = Pango.WrapMode.WORD_CHAR;
		lbl_shield_subnote.max_width_chars = 50;
		//vbox.set_child_packing(lbl_shield, true, true, 0, PackType.START);
		//vbox.set_child_packing(lbl_shield_subnote, true, false, 0, PackType.START);

		// snap_count
		//vbox = new Gtk.Box(Orientation.VERTICAL, 6);
		//vbox.set_no_show_all(true);
        //box.add (vbox);
        //vbox_snap_count = vbox;

		// scrolled
        scrolled = new Gtk.ScrolledWindow(null, null);
		//scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
		scrolled.vscrollbar_policy = Gtk.PolicyType.NEVER;
		scrolled.set_no_show_all(true);
		hbox_status.add (scrolled);
		
		vbox = new Gtk.Box(Orientation.VERTICAL, 6);
		vbox.margin = 6;
		vbox.margin_left = 12;
		vbox.margin_right = 12;
        scrolled.add(vbox);
        scrolled_snap_count = scrolled;

        var label = new Gtk.Label("<b>" + "0.0%" + "</b>");
		label.set_use_markup(true);
		label.justify = Gtk.Justification.CENTER;
		vbox.pack_start(label, true, true, 0);
		lbl_snap_count = label;
		
		label = new Gtk.Label(_("Snapshots"));
		label.justify = Gtk.Justification.CENTER;
		vbox.pack_start(label, false, false, 0);

		label = new Gtk.Label("");
		label.set_use_markup(true);
		label.justify = Gtk.Justification.CENTER;
		vbox.pack_start(label, false, false, 0);
		lbl_snap_count_subnote = label;
		
		// free space
		//vbox = new Gtk.Box(Orientation.VERTICAL, 6);
		//vbox.set_no_show_all(true);
        //box.add(vbox);
        //vbox_free_space = vbox;

        scrolled = new Gtk.ScrolledWindow(null, null);
		//scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
		scrolled.vscrollbar_policy = Gtk.PolicyType.NEVER;
		scrolled.set_no_show_all(true);
		hbox_status.add (scrolled);
		
		vbox = new Gtk.Box(Orientation.VERTICAL, 6);
		vbox.margin = 6;
		vbox.margin_left = 12;
		vbox.margin_right = 12;
        scrolled.add(vbox);
        scrolled_free_space = scrolled;

		label = new Gtk.Label("<b>" + "0.0%" + "</b>");
		label.set_use_markup(true);
		label.justify = Gtk.Justification.CENTER;
		vbox.pack_start(label, true, true, 0);
		lbl_free_space = label;
		
		label = new Gtk.Label(_("Available"));
		label.justify = Gtk.Justification.CENTER;
		vbox.pack_start(label, false, false, 0);

		label = new Gtk.Label("");
		label.set_use_markup(true);
		label.justify = Gtk.Justification.CENTER;
		vbox.pack_start(label, false, false, 0);
		lbl_free_space_subnote = label;
		
		// TODO: medium: add a refresh button for device when device is offline

		// TODO: low: refresh device list automatically when a device is plugged in
	}
	
    private bool menu_extra_popup(Gdk.EventButton? event){

		menu_extra = new Gtk.Menu();
		menu_extra.reserve_toggle_size = false;

		Gtk.MenuItem menu_item = null;

		if (!App.live_system()){
			// app logs
			menu_item = create_menu_item(_("View TimeShift Logs"), "", "", 16);
			menu_extra.append(menu_item);
			menu_item.activate.connect(btn_view_app_logs_clicked);
		}

		// about
		menu_item = create_menu_item(_("About"), "", "", 16);
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
	
		var box = new Gtk.Box(Orientation.HORIZONTAL, 3);
		menu_item.add(box);

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
		
		var box = new Gtk.Box(Orientation.HORIZONTAL, 3);
		menu_item.add(box);

		box.add(new Gtk.Separator(Gtk.Orientation.HORIZONTAL));
				
		return menu_item;
	}

	private bool refresh_all(){

		/* updates statusbar messages and snapshot list after backup device is changed */

		ui_sensitive(false);

		snapshot_list_box.refresh();
		update_statusbar();
		
		ui_sensitive(true);

		return false;
	}

	private bool on_delete_event(Gdk.EventAny event){

		this.delete_event.disconnect(on_delete_event); //disconnect this handler

		if (App.task.status == AppStatus.RUNNING){
			log_error (_("Main window closed by user"));
			App.task.stop();
		}

		// stop deletion task if running
		if (App.thread_delete_running){
			// clear queue
			App.delete_list.clear();
			// kill current task
			if (App.delete_file_task != null){
				App.delete_file_task.stop(AppStatus.CANCELLED);
			}
		}

		// check backup device -------------------------------

		if (!App.live_system()){
			
			if (!App.repo.available() || !App.repo.has_space()){

				var title = App.repo.status_message;
				
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
			}
		}
		
		App.exit_app(0);

		return false;
	}

	// context menu
	
	public void create_snapshot(){

		if (check_if_deletion_running()){
			return;
		}
		
		ui_sensitive(false);
		
		// check root device --------------

		if (App.btrfs_mode && (App.check_btrfs_layout_system(this) == false)){
			ui_sensitive(true);
			return;
		}

		// check snapshot device -----------

		if (!App.repo.available()){
			gtk_messagebox(App.repo.status_message, App.repo.status_details, this, true);
			// allow user to continue after showing message
		}

		// run wizard window ------------------

		var win = new BackupWindow();
		win.set_transient_for(this);
		win.destroy.connect(()=>{
			refresh_all();
			ui_sensitive(true);
		});
	}

	public void delete_selected(){

		log_debug("main window: delete_selected()");
		
		// check snapshot device -----------

		if (!App.repo.available()){
			gtk_messagebox(
				App.repo.status_message,
				_("Select another device to delete snasphots"),
				this, false);
			return;
		}
		else if (!App.repo.has_snapshots()){
			gtk_messagebox(
				_("No snapshots on device"),
				_("Select another device to delete snasphots"),
				this, false);
			return;
		}

		// check if selected snapshot is live ------------------

		foreach(var bak in snapshot_list_box.selected_snapshots()){
			if (bak.live){
				string title = _("Cannot Delete Live Snapshot");
				string msg = _("Snapshot '%s' is being used by the system and cannot be deleted. Restart the system to activate the restored snapshot.").printf(bak.date_formatted);
				gtk_messagebox(title,msg,this,false);
				return;
			}
		}
		
		// get selected snapshots

		if (!App.thread_delete_running){
			// check and add by name since snapshot_list would have changed
			foreach (var item in snapshot_list_box.selected_snapshots()){
				bool already_in_list = false;
				foreach(var bak in App.delete_list){
					if (bak.name == item.name){
						already_in_list = true;
						break;
					}
				}
				if (!already_in_list){
					App.delete_list.add(item);
				}
			}
		}

		log_debug("main window: delete_selected(): count=%d".printf(
			App.delete_list.size));

		// run wizard window ------------------

		ui_sensitive(false);
		
		var win = new DeleteWindow();
		win.set_transient_for(this);
		win.destroy.connect(()=>{
			refresh_all();
			ui_sensitive(true);
		});
	}

	public void mark_selected(){
		
		TreeIter iter;
		bool is_success = true;

		// check selected count ----------------

		var sel = snapshot_list_box.treeview.get_selection();
		
		if (sel.count_selected_rows() == 0){
			
			gtk_messagebox(
				_("No Snapshots Selected"),
				_("Select the snapshots to mark for deletion"),
				this, false);
				
			return;
		}

		// get selected snapshots --------------------

		var store = (Gtk.ListStore) snapshot_list_box.treeview.model;
		bool iterExists = store.get_iter_first (out iter);
		bool marked = false;
		
		while (iterExists && is_success) {
			
			if (sel.iter_is_selected (iter)){
				
				Snapshot bak;
				store.get (iter, 0, out bak);
				// mark for deletion
				bak.mark_for_deletion();
				// have any snapshots been marked?
				marked = marked || bak.marked_for_deletion;
			}
			iterExists = store.iter_next (ref iter);
		}

		App.repo.load_snapshots();

		string title = (marked ? "Marked " : "Unmarked ") + "for deletion";
		string message = (marked ? "Snapshots will " : "Snapshots will not ") + "be removed during the next scheduled run";

		gtk_messagebox(_(title),
			_(message),
			this, false);

		snapshot_list_box.refresh();
	}

	public void browse_selected(){
		
		var sel = snapshot_list_box.treeview.get_selection ();
		
		if (sel.count_selected_rows() == 0){
			
			var f = File.new_for_path(App.repo.snapshots_path);
			
			if (f.query_exists()){
				exo_open_folder(App.repo.snapshots_path);
			}
			else{
				exo_open_folder(App.repo.mount_path);
			}
			return;
		}

		TreeIter iter;
		var store = (Gtk.ListStore) snapshot_list_box.treeview.model;

		bool iterExists = store.get_iter_first (out iter);
		
		while (iterExists) {
			if (sel.iter_is_selected (iter)){
				
				Snapshot bak;
				store.get (iter, 0, out bak);

				if (App.btrfs_mode){
					exo_open_folder(bak.path, false);
				}
				else{
					exo_open_folder(bak.path + "/localhost", false);
				}
				return;
			}
			iterExists = store.iter_next (ref iter);
		}
	}

	public void view_snapshot_log(bool view_restore_log){
		
		var sel = snapshot_list_box.treeview.get_selection ();
		
		if (sel.count_selected_rows() == 0){
			gtk_messagebox(
				_("Select Snapshot"),
				_("Please select a snapshot to view the log!"),
				this, false);
			return;
		}

		TreeIter iter;
		var store = (Gtk.ListStore) snapshot_list_box.treeview.model;

		bool iterExists = store.get_iter_first (out iter);
		
		while (iterExists) {
			
			if (sel.iter_is_selected (iter)){
				
				Snapshot bak;
				store.get (iter, 0, out bak);

				string log_file_name = bak.rsync_log_file;
				if (view_restore_log){
					log_file_name = bak.rsync_restore_log_file;;
				}

				if (file_exists(log_file_name) || file_exists(log_file_name + "-changes")){

					this.hide();
					
					var win = new RsyncLogWindow(log_file_name);
					win.set_transient_for(this);
					win.destroy.connect(()=>{
						this.show();
					});
				}

				return;
			}
			iterExists = store.iter_next (ref iter);
		}
	}

	private void btn_restore_clicked(){

		if (check_if_deletion_running()){
			return;
		}
		
		App.mirror_system = false;
		restore();
	}

	private void btn_clone_clicked(){
		
		if (check_if_deletion_running()){
			return;
		}
		
		App.mirror_system = true;
		restore();
	}

	private bool check_if_deletion_running(){

		if (App.thread_delete_running){

			ui_sensitive(true);
			
			gtk_messagebox(
				_("Snapshot deletion in progress..."),
				_("Please wait for snapshots to be deleted."), this, true);
			
			ui_sensitive(false);
		
			var win = new DeleteWindow();
			win.set_transient_for(this);
			win.destroy.connect(()=>{
				refresh_all();
				ui_sensitive(true);
			});
			
			return true;
		}

		return false;
	}


	private void restore(){
		
		TreeIter iter;
		TreeSelection sel;

		if (!App.mirror_system){

			//check if single snapshot is selected -------------

			sel = snapshot_list_box.treeview.get_selection();
			
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

			var store = (Gtk.ListStore) snapshot_list_box.treeview.model;
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
		}
		else{
			App.snapshot_to_restore = null;
		}

		App.init_mount_list();
		
		//show restore window -----------------

		var window = new RestoreWindow();
		window.set_transient_for (this);
		//window.show_all();

		window.destroy.connect(()=>{
			App.dry_run = false;
			App.repo.load_snapshots();
			refresh_all();
		});
	}

	private void btn_settings_clicked(){

		log_debug("MainWindow: btn_settings_clicked()");
		
		btn_settings.sensitive = false;
		btn_wizard.sensitive = false;

		this.hide();

		bool btrfs_mode_prev = App.btrfs_mode;
		
		var win = new SettingsWindow();
		win.set_transient_for(this);
		win.destroy.connect(()=>{
			btn_settings.sensitive = true;
			btn_wizard.sensitive = true;
			settings_changed(btrfs_mode_prev);
		});
	}

	private void btn_wizard_clicked(){

		log_debug("MainWindow: btn_wizard_clicked()");
		
		btn_settings.sensitive = false;
		btn_wizard.sensitive = false;

		this.hide();
		
		bool btrfs_mode_prev = App.btrfs_mode;
		
		var win = new SetupWizardWindow();
		win.set_transient_for(this);
		win.destroy.connect(()=>{
			btn_settings.sensitive = true;
			btn_wizard.sensitive = true;
			settings_changed(btrfs_mode_prev);
		});
	}

	private void settings_changed(bool btrfs_mode_prev){

		if (btrfs_mode_prev != App.btrfs_mode){
			if ((App.repo != null) && (App.repo.device != null) && (App.repo.device.uuid.length > 0)){
				App.repo = new SnapshotRepo.from_uuid(App.repo.device.uuid, this, App.btrfs_mode);
			}
			else{
				if ((App.sys_root != null) && (App.sys_root.fstype == "btrfs")){
					App.repo = new SnapshotRepo.from_uuid(App.sys_root.uuid, this, App.btrfs_mode);
				}
				else{
					App.repo = new SnapshotRepo.from_null();
				}
			}
		}

		App.save_app_config();
		App.repo.load_snapshots();
		refresh_all();
		this.show();
	}

	private void btn_view_app_logs_clicked(){
		
		exo_open_folder(App.log_dir);
	}

	public void btn_donate_clicked(){
		
		var dialog = new DonationWindow(this);
		dialog.show_all();
	}

	private void btn_about_clicked (){
		
		var dialog = new AboutWindow(this);
		dialog.set_transient_for(this);

		dialog.authors = {
			"Tony George:teejeetech@gmail.com"
		};

		dialog.program_name = AppName;
		dialog.comments = _("System Restore Utility");
		dialog.copyright = "Copyright © 2012-22 Tony George (%s)".printf(AppAuthorEmail);
		dialog.version = AppVersion;
		dialog.logo = IconManager.lookup("timeshift", 256);

		dialog.website = "https://teejeetech.com/";
		dialog.website_label = "https://teejeetech.com/";
		
		dialog.initialize();
		dialog.show_all();
	}

	private void ui_sensitive(bool enable){
		
		toolbar.sensitive = enable;
		snapshot_list_box.treeview.sensitive = enable;
		gtk_set_busy(!enable, this);
	}

	private void update_statusbar(){
		
		App.repo.check_status();
		string message = App.repo.status_message;
		string details = App.repo.status_details;
		int status_code = App.repo.status_code;
		
		DateTime? last_snapshot_date = null;
		DateTime? oldest_snapshot_date = null;

		if (App.repo.has_snapshots()){
			string sys_uuid = (App.sys_root == null) ? "" : App.sys_root.uuid;
			var last_snapshot = App.repo.get_latest_snapshot("", sys_uuid);
			last_snapshot_date = (last_snapshot == null) ? null : last_snapshot.date;
			var oldest_snapshot = App.repo.get_oldest_snapshot("", sys_uuid);
			oldest_snapshot_date = (oldest_snapshot == null) ? null : oldest_snapshot.date;
		}

		if (App.live_system()){
			statusbar.visible = true;
			statusbar.show_all();

			img_shield.surface = IconManager.lookup_surface(IconManager.SHIELD_LIVE, IconManager.SHIELD_ICON_SIZE, img_shield.scale_factor);
			set_shield_label(_("Live USB Mode (Restore Only)"));
			set_shield_subnote("");

			switch (status_code){
			case SnapshotLocationStatus.NOT_SELECTED:
			case SnapshotLocationStatus.NOT_AVAILABLE:
			case SnapshotLocationStatus.NO_BTRFS_SYSTEM:
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
			case SnapshotLocationStatus.NO_BTRFS_SYSTEM:
			case SnapshotLocationStatus.HAS_SNAPSHOTS_NO_SPACE:
			case SnapshotLocationStatus.NO_SNAPSHOTS_NO_SPACE:
				img_shield.surface = IconManager.lookup_surface(IconManager.SHIELD_LOW, IconManager.SHIELD_ICON_SIZE, img_shield.scale_factor);
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
						img_shield.surface = IconManager.lookup_surface(IconManager.SHIELD_HIGH, IconManager.SHIELD_ICON_SIZE, img_shield.scale_factor);
						//set_shield_label(_("System is protected"));
						set_shield_label(_("Timeshift is active"));
						set_shield_subnote("%s: %s\n%s: %s".printf(
							_("Latest snapshot"),
							(last_snapshot_date == null) ? _("None") : last_snapshot_date.format(App.date_format),
							_("Oldest snapshot"),
							(oldest_snapshot_date == null) ? _("None") : oldest_snapshot_date.format(App.date_format)
							));
					}
					else{
						// no snaps
						img_shield.surface = IconManager.lookup_surface(IconManager.SHIELD_HIGH, IconManager.SHIELD_ICON_SIZE, img_shield.scale_factor);
						set_shield_label(_("Timeshift is active"));
						set_shield_subnote(_("Snapshots will be created at selected intervals"));
					}
				}
				else {
					// not scheduled
					if (App.repo.has_snapshots()){
						// has snaps
						img_shield.surface = IconManager.lookup_surface(IconManager.SHIELD_MED, IconManager.SHIELD_ICON_SIZE, img_shield.scale_factor);
						set_shield_label(_("Scheduled snapshots are disabled"));
						set_shield_subnote(_("Enable scheduled snapshots to protect your system"));
					}
					else{
						// no snaps
						img_shield.surface = IconManager.lookup_surface(IconManager.SHIELD_LOW, IconManager.SHIELD_ICON_SIZE, img_shield.scale_factor);
						set_shield_label(_("No snapshots available"));
						set_shield_subnote(_("Create snapshots manually or enable scheduled snapshots to protect your system"));
					}
				}
				
				break;
			}

			scrolled_snap_count.hide();
			scrolled_free_space.hide();
			
			switch (status_code){
			case SnapshotLocationStatus.NO_SNAPSHOTS_NO_SPACE:
			case SnapshotLocationStatus.NO_SNAPSHOTS_HAS_SPACE:
			case SnapshotLocationStatus.HAS_SNAPSHOTS_NO_SPACE:
			case SnapshotLocationStatus.HAS_SNAPSHOTS_HAS_SPACE:
				scrolled_snap_count.no_show_all = false;
				scrolled_snap_count.show_all();
				
				lbl_snap_count.label = format_text_large("%0d".printf(App.repo.snapshots.size));
				string mode = App.btrfs_mode ? "btrfs" : "rsync";
				lbl_snap_count_subnote.label = format_text(mode, false, true, false);
				
				scrolled_free_space.no_show_all = false;
				scrolled_free_space.show_all();
				
				lbl_free_space.label = format_text_large("%s".printf(format_file_size(App.repo.device.free_bytes)));

				string devname = "(??)";
				if ((App.repo != null) && (App.repo.device != null)){
					devname = "%s".printf(App.repo.device.device);
				}
				lbl_free_space_subnote.label = format_text(devname, false, true, false);
				break;
			}
		}
	}

	// ui helpers --------
	
	private string format_text_large(string text){
		
		return "<span size='xx-large'><b>" + text + "</b></span>";
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
