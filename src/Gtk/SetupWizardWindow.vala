/*
 * SetupWizardWindow.vala
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

class SetupWizardWindow : Gtk.Window{
	
	private Gtk.Box vbox_main;
	private Gtk.Notebook notebook;

	// tabs
	private SnapshotBackendBox backend_box;
	private EstimateBox estimate_box;
	private BackupDeviceBox backup_dev_box;
	private FinishBox finish_box;
	private ScheduleBox schedule_box;
	private UsersBox users_box;

	// actions
	private Gtk.Button btn_prev;
	private Gtk.Button btn_next;
	private Gtk.Button btn_cancel;
	private Gtk.Button btn_close;

	private bool schedule_accepted = false;

	private uint tmr_init;
	private int def_width = 600;
	private int def_height = 500;
	
	public SetupWizardWindow() {

		log_debug("SetupWizardWindow: SetupWizardWindow()");
		
		this.title = _("Setup Wizard");
        this.window_position = WindowPosition.CENTER;
        this.modal = true;
        //this.set_default_size (def_width, def_height);
		this.icon = IconManager.lookup("timeshift",16);

		this.delete_event.connect(on_delete_event);
		
	    // vbox_main
        vbox_main = new Gtk.Box(Orientation.VERTICAL, 6);
        vbox_main.margin = 0;
        vbox_main.set_size_request(def_width, def_height);
        add(vbox_main);

        this.resize(def_width, def_height);

        if (App.first_run && !schedule_accepted){
			App.schedule_boot = false;
			App.schedule_hourly = false;
			App.schedule_daily = true; // set
			log_debug("Setting schedule_daily for first run");
			App.schedule_weekly = false;
			App.schedule_monthly = false;
		}

		// add notebook
		notebook = add_notebook(vbox_main, false, false);

		Gtk.Label label;

		label = new Gtk.Label(_("Backend"));
		backend_box = new SnapshotBackendBox(this);
		backend_box.margin = 12;
		notebook.append_page (backend_box, label);
		
		label = new Gtk.Label(_("Estimate"));
		estimate_box = new EstimateBox(this);
		estimate_box.margin = 12;
		notebook.append_page (estimate_box, label);

		label = new Gtk.Label(_("Location"));
		backup_dev_box = new BackupDeviceBox(this);
		backup_dev_box.margin = 12;
		notebook.append_page (backup_dev_box, label);

		label = new Gtk.Label(_("Schedule"));
		schedule_box = new ScheduleBox(this);
		schedule_box.margin = 12;
		notebook.append_page (schedule_box, label);

		label = new Gtk.Label(_("User"));
		var exclude_box = new ExcludeBox(this);
		users_box = new UsersBox(this, exclude_box, false);
		users_box.margin = 12;
		notebook.append_page (users_box, label);

		label = new Gtk.Label(_("Finished"));
		finish_box = new FinishBox(this, false);
		finish_box.margin = 12;
		notebook.append_page (finish_box, label);

		// TODO: Add a tab for excluding browser cache and other items
		
		create_actions();

		show_all();

		tmr_init = Timeout.add(100, init_delayed);

		log_debug("SetupWizardWindow: SetupWizardWindow(): exit");
    }
    
	private bool init_delayed(){

		if (tmr_init > 0){
			Source.remove(tmr_init);
			tmr_init = 0;
		}

		this.resize(def_width, def_height);

		go_first();

		return false;
	}

	private bool on_delete_event(Gdk.EventAny event){

		if (App.first_run && !schedule_accepted){
			App.schedule_boot = false;
			App.schedule_hourly = false;
			App.schedule_daily = false; // unset
			App.schedule_weekly = false;
			App.schedule_monthly = false;
		}

		save_changes();
		
		return false; // close window
	}
	
	private void save_changes(){
		
		App.cron_job_update();

		App.first_run = false;
		
		//App.check_encrypted_home(this);

		//App.check_encrypted_private_dirs(this);
	}
	
	private void create_actions(){

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);
		 
		var bbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
		bbox.margin = 12;
		bbox.spacing = 6;
		bbox.hexpand = true;
        hbox.add(bbox);
        
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
		
		btn_close = add_button(bbox, _("Finish"), "", size_group, null);

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

		btn_prev.hexpand = btn_next.hexpand = btn_close.hexpand = true;
		btn_cancel.hexpand = true;
		
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

		notebook.page = Tabs.SNAPSHOT_BACKEND;
		
		/*if (App.live_system()){
			// skip estimate_box and go to backup_dev_box
			notebook.page = Tabs.SNAPSHOT_BACKEND;
		}
		else{
			if (Main.first_snapshot_size == 0){
				notebook.page = Tabs.ESTIMATE;
			}
			else{
				notebook.page = Tabs.BACKUP_DEVICE;
			}
		}*/

		initialize_tab();
	}
	
	private void go_prev(){
		
		switch(notebook.page){
		case Tabs.SNAPSHOT_BACKEND:
		case Tabs.ESTIMATE:
			// btn_previous is disabled for this page
			break;
		case Tabs.BACKUP_DEVICE:
			notebook.page = Tabs.SNAPSHOT_BACKEND;
			break;
		case Tabs.SCHEDULE:
			notebook.page = Tabs.BACKUP_DEVICE;
			break;
		case Tabs.USERS:
			notebook.page = Tabs.SCHEDULE;
			break;
		case Tabs.FINISH:
			notebook.page = Tabs.USERS;
			break;
		}
		
		initialize_tab();
	}
	
	private void go_next(){
		
		if (!validate_current_tab()){
			return;
		}

		switch(notebook.page){
		case Tabs.SNAPSHOT_BACKEND:
			if (App.btrfs_mode){
				notebook.page = Tabs.BACKUP_DEVICE;
			}
			else{
				notebook.page = Tabs.ESTIMATE; // rsync mode only
			}
			break;
			
		case Tabs.ESTIMATE:
			notebook.page = Tabs.BACKUP_DEVICE;
			break;
			
		case Tabs.BACKUP_DEVICE:
			if (App.live_system()){
				destroy();
			}
			else{
				notebook.page = Tabs.SCHEDULE;
			}
			break;
			
		case Tabs.SCHEDULE:
			notebook.page = Tabs.USERS;
			schedule_accepted = true;
			break;

		case Tabs.USERS:
			notebook.page = Tabs.FINISH;
			break;
			
		case Tabs.FINISH:
			// btn_next is disabled for this page
			break;
		}
	
		initialize_tab();
	}

	private void initialize_tab(){

		if (notebook.page < 0){
			return;
		}

		log_msg("");
		log_debug("page: %d".printf(notebook.page));

		// show/hide actions -----------------------------------

		action_buttons_set_no_show_all(false);
		
		btn_cancel.hide(); // TODO: remove this

		btn_prev.show();
		btn_next.show();
		btn_close.show();
			
		switch(notebook.page){
		case Tabs.SNAPSHOT_BACKEND:
			btn_prev.sensitive = false;
			btn_next.sensitive = true;
			btn_close.sensitive = true;
			break;
		case Tabs.ESTIMATE:
			btn_prev.sensitive = false;
			btn_next.sensitive = false;
			btn_close.sensitive = false;
			break;
		case Tabs.BACKUP_DEVICE:
			btn_prev.sensitive = true;
			btn_next.sensitive = true;
			btn_close.sensitive = true;
			break;
		case Tabs.SCHEDULE:
		case Tabs.USERS:
			btn_prev.sensitive = true;
			btn_next.sensitive = true;
			btn_close.sensitive = true;
			break;
		case Tabs.FINISH:
			btn_prev.sensitive = false;
			btn_next.sensitive = false;
			btn_close.sensitive = true;
			break;
		}

		// actions

		switch(notebook.page){
		case Tabs.SNAPSHOT_BACKEND:
			backend_box.refresh();
			break;
		case Tabs.ESTIMATE:
			if (App.btrfs_mode){
				go_next();
			}
			else{
				estimate_box.estimate_system_size();
				go_next();
			}
			break;
		case Tabs.BACKUP_DEVICE:
			backup_dev_box.refresh();
			break;
		case Tabs.SCHEDULE:
			schedule_box.update_statusbar();
			break;
		case Tabs.USERS:
			users_box.refresh();
			break;
		case Tabs.FINISH:
			finish_box.refresh();
			break;
		}
	}

	private bool validate_current_tab(){

		if (notebook.page == Tabs.SNAPSHOT_BACKEND){
			return true;
		}
		else if (notebook.page == Tabs.BACKUP_DEVICE){
			if (!App.repo.available() || !App.repo.has_space()){
				
				gtk_messagebox(App.repo.status_message,
					App.repo.status_details, this, true);
					
				return false;
			}
		}

		return true;
	}

	public enum Tabs{
		SNAPSHOT_BACKEND = 0,
		ESTIMATE = 1,
		BACKUP_DEVICE = 2,
		SCHEDULE = 3,
		USERS = 4,
		FINISH = 5
	}
}



