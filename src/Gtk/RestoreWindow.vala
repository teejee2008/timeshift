/*
 * RestoreWindow.vala
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

class RestoreWindow : Gtk.Window{
	private Gtk.Box vbox_main;
	private Gtk.Notebook notebook;
	private Gtk.ButtonBox bbox_action;

	// tabs
	//private TargetSystemBox system_box;
	private RestoreDeviceBox restore_device_box;
	private RestoreExcludeBox restore_exclude_box;
	private RestoreSummaryBox summary_box;
	private RestoreBox restore_box;

	// actions
	private Gtk.Button btn_prev;
	private Gtk.Button btn_next;
	private Gtk.Button btn_cancel;
	private Gtk.Button btn_close;

	private uint tmr_init;

	public RestoreWindow() {
		this.title = _("Restore");
        this.window_position = WindowPosition.CENTER;
        this.modal = true;
        this.set_default_size (500, 500);
		this.icon = get_app_icon(16);

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

		label = new Gtk.Label(_("Summary"));
		summary_box = new RestoreSummaryBox(this);
		summary_box.margin = 0;
		notebook.append_page (summary_box, label);

		label = new Gtk.Label(_("Restore"));
		restore_box = new RestoreBox(this);
		restore_box.margin = 0;
		notebook.append_page (restore_box, label);

		create_actions();

		show_all();

		tmr_init = Timeout.add(100, init_delayed);
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
		hbox.set_layout (Gtk.ButtonBoxStyle.EXPAND);
		hbox.margin = 0;
		hbox.margin_left = 24;
		hbox.margin_right = 24;
		hbox.margin_top = 6;
		//hbox.margin_bottom = 12;
        vbox_main.add(hbox);
        bbox_action = hbox;

		Gtk.SizeGroup size_group = null;
		
		// previous
		
		Gtk.Image img = new Image.from_stock("gtk-go-back", Gtk.IconSize.BUTTON);
		btn_prev = add_button(hbox, _("Previous"), "", ref size_group, img);
		
        btn_prev.clicked.connect(()=>{
			go_prev();
		});

		// next
		
		img = new Image.from_stock("gtk-go-forward", Gtk.IconSize.BUTTON);
		btn_next = add_button(hbox, _("Next"), "", ref size_group, img);

        btn_next.clicked.connect(()=>{
			go_next();
		});

		// close
		
		img = new Image.from_stock("gtk-close", Gtk.IconSize.BUTTON);
		btn_close = add_button(hbox, _("Close"), "", ref size_group, img);

        btn_close.clicked.connect(()=>{
			save_changes();
			this.destroy();
		});

		// cancel
		
		img = new Image.from_stock("gtk-cancel", Gtk.IconSize.BUTTON);
		btn_cancel = add_button(hbox, _("Cancel"), "", ref size_group, img);

        btn_cancel.clicked.connect(()=>{
			if (App.task != null){
				App.task.stop(AppStatus.CANCELLED);
			}
			
			this.destroy(); // TODO: Show error page
		});
	}
	

	// navigation

	private void go_first(){
		
		// set initial tab

		notebook.page = Tabs.TARGET_DEVICE;
		
		/*if (Main.first_snapshot_size == 0){
			notebook.page = Tabs.ESTIMATE;
		}
		else if (!App.repo.available() || !App.repo.has_space()){
			notebook.page = Tabs.BACKUP_DEVICE;
		}
		else{
			notebook.page = Tabs.BACKUP;
		}*/

		initialize_tab();
	}
	
	private void go_prev(){
		switch(notebook.page){
		case Tabs.RESTORE_EXCLUDE:
			notebook.page = Tabs.TARGET_DEVICE;
			break;
		case Tabs.SUMMARY:
			notebook.page = Tabs.RESTORE_EXCLUDE;
			break;
		case Tabs.TARGET_DEVICE:
		case Tabs.RESTORE:
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
			notebook.page = Tabs.RESTORE_EXCLUDE;
			break;
		case Tabs.RESTORE_EXCLUDE:
			notebook.page = Tabs.SUMMARY;
			break;
		case Tabs.SUMMARY:
			notebook.page = Tabs.RESTORE;
			break;
		case Tabs.RESTORE:
			destroy();
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

		switch(notebook.page){
		case Tabs.RESTORE:
			btn_prev.hide();
			btn_next.hide();
			btn_close.hide();
			btn_cancel.show();
			bbox_action.set_layout (Gtk.ButtonBoxStyle.CENTER);
			break;
		case Tabs.TARGET_DEVICE:
		case Tabs.RESTORE_EXCLUDE:
		case Tabs.SUMMARY:
			btn_prev.show();
			btn_next.show();
			btn_close.show();
			btn_cancel.hide();
			btn_prev.sensitive = false;
			btn_next.sensitive = true;
			btn_close.sensitive = true;
			bbox_action.set_layout (Gtk.ButtonBoxStyle.EXPAND);
			break;
		}
		
		// actions

		switch(notebook.page){
		case Tabs.TARGET_DEVICE:
			restore_device_box.refresh();
			break;
		case Tabs.RESTORE_EXCLUDE:
			restore_exclude_box.refresh();
			break;
		case Tabs.SUMMARY:
			summary_box.refresh();
			break;
		case Tabs.RESTORE:
			restore_box.restore();
			//go_next();
			break;
		}
	}

	private bool validate_current_tab(){
		
		if (notebook.page == Tabs.TARGET_DEVICE){
			
			// remove mount points which will remain on root fs
			for(int i = App.mount_list.size-1; i >= 0; i--){
				var entry = App.mount_list[i];
				if (entry.device == null){
					App.mount_list.remove(entry);
				}
			}
			
		}

		return true;
	}

	public enum Tabs{
		TARGET_DEVICE = 0,
		RESTORE_EXCLUDE = 1,
		SUMMARY = 2,
		RESTORE = 3
	}
}



