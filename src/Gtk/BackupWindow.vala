/*
 * BackupWindow.vala
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

class BackupWindow : Gtk.Window{
	
	private Gtk.Box vbox_main;
	private Gtk.Notebook notebook;
	private Gtk.ButtonBox bbox_action;
	
	// tabs
	private EstimateBox estimate_box;
	private BackupDeviceBox backup_dev_box;
	private BackupBox backup_box;
	private BackupFinishBox backup_finish_box;

	// actions
	private Gtk.Button btn_prev;
	private Gtk.Button btn_next;
	private Gtk.Button btn_cancel;
	private Gtk.Button btn_close;

	private uint tmr_init;
	private int def_width = 500;
	private int def_height = 500;
	private bool success = false;

	public BackupWindow() {

		log_debug("BackupWindow: BackupWindow()");
		
		this.title = _("Create Snapshot");
        this.window_position = WindowPosition.CENTER;
        this.modal = true;
        this.set_default_size (def_width, def_height);
		this.icon = IconManager.lookup("timeshift",16);

		this.delete_event.connect(on_delete_event);

	    // vbox_main
        vbox_main = new Gtk.Box(Orientation.VERTICAL, 6);
        vbox_main.margin = 0;
        add(vbox_main);

        this.resize(def_width, def_height);

		// add notebook
		notebook = add_notebook(vbox_main, false, false);

		Gtk.Label label;
		
		label = new Gtk.Label(_("Estimate"));
		estimate_box = new EstimateBox(this);
		estimate_box.margin = 12;
		notebook.append_page (estimate_box, label);

		label = new Gtk.Label(_("Location"));
		backup_dev_box = new BackupDeviceBox(this);
		backup_dev_box.margin = 12;
		notebook.append_page (backup_dev_box, label);

		label = new Gtk.Label(_("Backup"));
		backup_box = new BackupBox(this);
		backup_box.margin = 12;
		notebook.append_page (backup_box, label);

		label = new Gtk.Label(_("Finish"));
		backup_finish_box = new BackupFinishBox(this);
		backup_finish_box.margin = 12;
		notebook.append_page (backup_finish_box, label);

		create_actions();

		show_all();

		tmr_init = Timeout.add(100, init_delayed);

		log_debug("BackupWindow: BackupWindow(): exit");
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
		
		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		 
		var bbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
		bbox.margin = 12;
		bbox.spacing = 6;
		bbox.hexpand = true;
        hbox.add(bbox);
        
        bbox_action = bbox;

		#if GTK3_18
			bbox.set_layout (Gtk.ButtonBoxStyle.CENTER);	
		#endif
		
		Gtk.SizeGroup size_group = null; //new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		
		// previous
		
		btn_prev = add_button(bbox, _("Previous"), "", size_group, null);
		
        btn_prev.clicked.connect(()=>{
			go_prev();
		});

		// next
		
		btn_next = add_button(bbox, _("Next"), "", size_group, null);

        btn_next.clicked.connect(()=>{
			go_next();
		});

		// close
		
		btn_close = add_button(bbox, _("Close"), "", size_group, null);

        btn_close.clicked.connect(()=>{
			save_changes();
			this.destroy();
		});

		// cancel
		
		btn_cancel = add_button(bbox, _("Cancel"), "", size_group, null);

        btn_cancel.clicked.connect(()=>{
			if (App.task != null){
				App.task.stop(AppStatus.CANCELLED);
			}
			
			this.destroy(); // TODO: Show error page
		});

		action_buttons_set_no_show_all(true);
	}

	private void action_buttons_set_no_show_all(bool val){
		
		btn_prev.no_show_all = val;
		btn_next.no_show_all = val;
		btn_close.no_show_all = val;
		btn_cancel.no_show_all = val;
	}
	

	// navigation

	private void go_first(){
		
		// set initial tab

		if (App.btrfs_mode){
			notebook.page = Tabs.BACKUP;
		}
		else{
			if (Main.first_snapshot_size == 0){
				notebook.page = Tabs.ESTIMATE;
			}
			else if (!App.repo.available() || !App.repo.has_space()){
				notebook.page = Tabs.BACKUP_DEVICE;
			}
			else{
				notebook.page = Tabs.BACKUP;
			}
		}

		initialize_tab();
	}
	
	private void go_prev(){
		
		switch(notebook.page){
		case Tabs.ESTIMATE:
		case Tabs.BACKUP_DEVICE:
		case Tabs.BACKUP:
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
		case Tabs.ESTIMATE:
			notebook.page = Tabs.BACKUP_DEVICE;
			break;
		case Tabs.BACKUP_DEVICE:
			notebook.page = Tabs.BACKUP;
			break;
		case Tabs.BACKUP:
			notebook.page = Tabs.BACKUP_FINISH;
			break;
		case Tabs.BACKUP_FINISH:
			destroy();
			break;
		}
		
		initialize_tab();
	}

	private void initialize_tab(){

		if (notebook.page < 0){ return; }

		log_msg("");
		log_debug("page: %d".printf(notebook.page));

		// show/hide actions -----------------------------------

		action_buttons_set_no_show_all(false);
		
		switch(notebook.page){
		case Tabs.ESTIMATE:
		case Tabs.BACKUP:
			btn_prev.hide();
			btn_next.hide();
			btn_close.hide();
			btn_cancel.show();
			break;
		case Tabs.BACKUP_DEVICE:
			btn_prev.show();
			btn_next.show();
			btn_close.show();
			btn_cancel.hide();
			btn_prev.sensitive = false;
			btn_next.sensitive = true;
			btn_close.sensitive = true;
			break;
		case Tabs.BACKUP_FINISH:
			btn_prev.hide();
			btn_next.hide();
			btn_close.show();
			btn_close.sensitive = true;
			btn_cancel.hide();
			break;
		}

		// actions

		switch(notebook.page){
		case Tabs.ESTIMATE:
			estimate_box.estimate_system_size();
			go_next(); // validate and go next
			break;
		case Tabs.BACKUP_DEVICE:
			backup_dev_box.refresh();
			go_next(); // validate and go next
			break;
		case Tabs.BACKUP:
			success = backup_box.take_snapshot();
			go_next(); // close window
			break;
		case Tabs.BACKUP_FINISH:
			backup_finish_box.update_message(success);
            if (App.repo.status_code == SnapshotLocationStatus.HAS_SNAPSHOTS_NO_SPACE)
            {
                this.hide();
                gtk_messagebox(App.repo.status_message, App.repo.status_details, this, true);
                this.destroy();
            }
            else
            {
                backup_finish_box.update_message(success);
                wait_and_close_window(1000, this);
            }
			break;
		}
	}

	private bool validate_current_tab(){
		
		if (notebook.page == Tabs.BACKUP_DEVICE){
			if (!App.repo.available() || !App.repo.has_space()){
				
				gtk_messagebox(App.repo.status_message,
					App.repo.status_details, this, true);
					
				return false;
			}
		}

		return true;
	}

	public enum Tabs{
		ESTIMATE = 0,
		BACKUP_DEVICE = 1,
		BACKUP = 2,
		BACKUP_FINISH = 3
	}
}



