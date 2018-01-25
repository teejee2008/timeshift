/*
 * RestoreWindow.vala
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

class RestoreWindow : Gtk.Window{
	
	private Gtk.Box vbox_main;
	private Gtk.Notebook notebook;
	private Gtk.ButtonBox bbox_action;

	// tabs
	private RestoreDeviceBox restore_device_box;
	private RestoreExcludeBox restore_exclude_box;
	private ExcludeAppsBox exclude_apps_box;
	private RestoreSummaryBox summary_box;
	private RestoreBox check_box;
	private RsyncLogBox log_box;
	private RestoreBox restore_box;
	private RestoreFinishBox restore_finish_box;

	// actions
	private Gtk.Button btn_prev;
	private Gtk.Button btn_next;
	private Gtk.Button btn_cancel;
	private Gtk.Button btn_close;

	private uint tmr_init;
	private int def_width = 500;
	private int def_height = 500;
	private bool success = false;

	public bool check_before_restore = true; 
	
	public RestoreWindow() {

		log_debug("RestoreWindow: RestoreWindow()");
		
		this.title = App.mirror_system ? _("Clone System") : _("Restore Snapshot");
        this.window_position = WindowPosition.CENTER;
        this.modal = true;
        this.set_default_size (def_width, def_height);
		this.icon = IconManager.lookup("timeshift",16);

		this.delete_event.connect(on_delete_event);

	    // vbox_main
        vbox_main = new Box (Orientation.VERTICAL, 6);
        vbox_main.margin = 12;
        add(vbox_main);

		// add notebook
		notebook = add_notebook(vbox_main, false, false);

		Gtk.Label label;
		
		label = new Gtk.Label(_("Restore Device"));
		restore_device_box = new RestoreDeviceBox(this);
		restore_device_box.margin = 0;
		notebook.append_page (restore_device_box, label);

		label = new Gtk.Label(_("Restore Exclude"));
		restore_exclude_box = new RestoreExcludeBox(this);
		restore_exclude_box.margin = 0;
		notebook.append_page (restore_exclude_box, label);
		
		label = new Gtk.Label(_("Exclude Apps"));
		exclude_apps_box = new ExcludeAppsBox(this);
		exclude_apps_box.margin = 0;
		notebook.append_page (exclude_apps_box, label);

		label = new Gtk.Label(_("Checking Restore Actions (Dry Run)"));
		check_box = new RestoreBox(this);
		check_box.margin = 0;
		notebook.append_page (check_box, label);

		label = new Gtk.Label(_("Confirm Actions"));
		log_box = new RsyncLogBox(this);
		log_box.margin = 0;
		notebook.append_page (log_box, label);

		label = new Gtk.Label(_("Summary"));
		summary_box = new RestoreSummaryBox(this);
		summary_box.margin = 0;
		notebook.append_page (summary_box, label);

		label = new Gtk.Label(_("Restore"));
		restore_box = new RestoreBox(this);
		restore_box.margin = 0;
		notebook.append_page (restore_box, label);

		label = new Gtk.Label(_("Finished"));
		restore_finish_box = new RestoreFinishBox(this);
		restore_finish_box.margin = 0;
		notebook.append_page (restore_finish_box, label);

		create_actions();

		show_all();

		tmr_init = Timeout.add(100, init_delayed);

		log_debug("RestoreWindow: RestoreWindow(): exit");
    }
    
	private bool init_delayed(){

		if (tmr_init > 0){
			Source.remove(tmr_init);
			tmr_init = 0;
		}

		go_first();

		return false;
	}

	private bool on_delete_event(Gdk.EventAny event){

		save_changes();
		
		return false; // close window
	}
	
	private void save_changes(){
		App.cron_job_update();
	}
	
	private void create_actions(){
		
		var hbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
		hbox.margin = 0;
		hbox.margin_left = 24;
		hbox.margin_right = 24;
		hbox.margin_top = 6;
        vbox_main.add(hbox);
        bbox_action = hbox;

        #if GTK3_18
			hbox.set_layout (Gtk.ButtonBoxStyle.EXPAND);	
		#endif

		Gtk.SizeGroup size_group = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		
		// previous
		
		btn_prev = add_button(hbox, _("Previous"), "", size_group, null);
		
        btn_prev.clicked.connect(()=>{
			go_prev();
		});

		// next
		
		btn_next = add_button(hbox, _("Next"), "", size_group, null);

        btn_next.clicked.connect(()=>{
			go_next();
		});

		// close
		
		btn_close = add_button(hbox, _("Close"), "", size_group, null);

        btn_close.clicked.connect(()=>{
			save_changes();
			this.destroy();
		});

		// cancel
		
		btn_cancel = add_button(hbox, _("Cancel"), "", size_group, null);

        btn_cancel.clicked.connect(()=>{

			var title = _("Cancel restore?");
				
			var msg = _("Cancelling the restore process will leave the target system in an inconsistent state. The system may fail to boot or you may run into various issues. After cancelling, you need to restore another snapshot, to bring the system to a consistent state. Click Yes to confirm.");
			
			var type = Gtk.MessageType.ERROR;
			var buttons_type = Gtk.ButtonsType.YES_NO;
			
			var dlg = new CustomMessageDialog(title, msg, type, this, buttons_type);
			var response = dlg.run();
			dlg.destroy();
			
			if (response != Gtk.ResponseType.YES){
				return;
			}
			
			if (App.task != null){
				App.task.stop(AppStatus.CANCELLED);
			}
			
			this.destroy(); // TODO: low: Show error page
		});

		btn_prev.hexpand = btn_next.hexpand = btn_cancel.hexpand = btn_close.hexpand = true;

		action_buttons_set_no_show_all(true);
	}

	private void action_buttons_set_no_show_all(bool val){
		
		btn_prev.no_show_all = val;
		btn_next.no_show_all = val;
		btn_close.no_show_all = val;
		btn_cancel.no_show_all = val;
	}
	
	// navigation ----------------------------------------------------

	private void go_first(){
		
		// set initial tab

		if (App.btrfs_mode){
			notebook.page = Tabs.SUMMARY;
		}
		else{
			notebook.page = Tabs.TARGET_DEVICE;
		}
			
		initialize_tab();
	}
	
	private void go_prev(){
		
		switch(notebook.page){
		case Tabs.RESTORE_EXCLUDE:
			notebook.page = Tabs.TARGET_DEVICE;
			break;
			
		case Tabs.EXCLUDE_APPS:
			notebook.page = Tabs.RESTORE_EXCLUDE;
			//notebook.page = Tabs.TARGET_DEVICE;
			break;
			
		case Tabs.SUMMARY:
			notebook.page = Tabs.RESTORE_EXCLUDE; // go to parent (RESTORE_EXCLUDE)
			break;
			
		case Tabs.TARGET_DEVICE:
		case Tabs.RESTORE:
		case Tabs.FINISH:
			// btn_previous is disabled for this page
			break;
		}
		
		initialize_tab();
	}
	
	private void go_next(){
		
		if (!validate_current_tab()){
			return;
		}
		
		switch(notebook.page){
		case Tabs.TARGET_DEVICE:
			if (!App.btrfs_mode && check_before_restore){
				notebook.page = Tabs.CHECK;
			}
			else{
				notebook.page = Tabs.SUMMARY;
			}
			break;
			
		/*case Tabs.RESTORE_EXCLUDE:
			if (restore_exclude_box.show_all_apps()){
				notebook.page = Tabs.EXCLUDE_APPS;
			}
			else{
				notebook.page = Tabs.SUMMARY;
			}	
			break;
			
		case Tabs.EXCLUDE_APPS:
			notebook.page = Tabs.SUMMARY;
			break;*/
			
		case Tabs.CHECK:
			notebook.page = Tabs.SHOW_LOG;
			break;

		case Tabs.SHOW_LOG:
			notebook.page = Tabs.SUMMARY;
			break;

		case Tabs.SUMMARY:
			notebook.page = Tabs.RESTORE;
			break;
			
		case Tabs.RESTORE:
			notebook.page = Tabs.FINISH;
			break;
			
		case Tabs.FINISH:
			destroy();
			break;
		}
		
		initialize_tab();
	}

	private void initialize_tab(){

		if (notebook.page < 0){ return; }

		log_debug("page: %d".printf(notebook.page));

		// show/hide actions -----------------------------------

		action_buttons_set_no_show_all(false);
		
		switch(notebook.page){
		case Tabs.RESTORE:
			btn_prev.hide();
			btn_next.hide();
			btn_close.hide();
			btn_cancel.show();
			#if GTK3_18
			bbox_action.set_layout (Gtk.ButtonBoxStyle.CENTER);
			#endif
			break;
			
		case Tabs.TARGET_DEVICE:
		case Tabs.RESTORE_EXCLUDE:
		case Tabs.EXCLUDE_APPS:
		case Tabs.SUMMARY:
			btn_prev.show();
			btn_next.show();
			btn_close.show();
			btn_cancel.hide();
			btn_prev.sensitive = false;
			btn_next.sensitive = true;
			btn_close.sensitive = true;
			#if GTK3_18
			bbox_action.set_layout (Gtk.ButtonBoxStyle.EXPAND);
			#endif
			break;

		case Tabs.SHOW_LOG:
			btn_prev.show();
			btn_next.show();
			btn_close.show();
			btn_cancel.hide();
			btn_prev.sensitive = false;
			btn_next.sensitive = true;
			btn_close.sensitive = true;
			#if GTK3_18
			bbox_action.set_layout (Gtk.ButtonBoxStyle.EXPAND);
			#endif
			break;
			
		case Tabs.FINISH:
			btn_prev.show();
			btn_next.show();
			btn_close.show();
			btn_cancel.hide();
			btn_prev.sensitive = false;
			btn_next.sensitive = false;
			btn_close.sensitive = true;
			#if GTK3_18
			bbox_action.set_layout (Gtk.ButtonBoxStyle.EXPAND);
			#endif
			break;
		}
		
		// actions ---------------------------------------------------
		
		switch(notebook.page){
		case Tabs.TARGET_DEVICE:
			restore_device_box.refresh(false); // false: App.init_mount_list() will be called before this window is shown
			break;
			
		case Tabs.RESTORE_EXCLUDE:
			restore_exclude_box.refresh();
			break;
			
		case Tabs.EXCLUDE_APPS:
			exclude_apps_box.refresh();
			break;
		
		case Tabs.CHECK:
			App.dry_run = true;
			success = check_box.restore();
			go_next();
			break;
			
		case Tabs.SHOW_LOG:
			if (file_exists(App.snapshot_to_restore.rsync_restore_log_file)){
				log_box.open_log(App.snapshot_to_restore.rsync_restore_log_file);
			}
			else{
				notebook.page = Tabs.FINISH;
				initialize_tab();
				restore_finish_box.update_message(false, _("Error running Rsync"), "");
			}
			break;

		case Tabs.SUMMARY:
			summary_box.refresh();
			break;
			
		case Tabs.RESTORE:
			App.dry_run = false;
			success = restore_box.restore();
			go_next();
			break;
			
		case Tabs.FINISH:
			restore_finish_box.update_message(success,"","");
			//wait_and_close_window(1000, this); // do not auto-close restore window.
			break;
		}
	}

	private bool validate_current_tab(){
		
		if (notebook.page == Tabs.TARGET_DEVICE){

			bool ok = restore_device_box.check_and_mount_devices();

			if (ok){
				App.add_app_exclude_entries();
			}

			return ok;
		}
		else if (notebook.page == Tabs.RESTORE_EXCLUDE){
		    App.save_exclude_list_selections();
		}
		else if (notebook.page == Tabs.EXCLUDE_APPS){
		    App.save_exclude_list_selections();
		}

		return true;
	}

	public enum Tabs{
		// indexes here should match the order in which tabs were added to Notebook
		TARGET_DEVICE = 0,
		RESTORE_EXCLUDE = 1,
		EXCLUDE_APPS = 2,
		CHECK = 3,
		SHOW_LOG = 4,
		SUMMARY = 5,
		RESTORE = 6,
		FINISH = 7
	}
}



