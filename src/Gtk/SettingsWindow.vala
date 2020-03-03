/*
 * SettingsWindow.vala
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

class SettingsWindow : Gtk.Window{
	
	private Gtk.Box vbox_main;
	private Gtk.StackSwitcher switcher;
	private Gtk.Stack stack;
	
	private SnapshotBackendBox backend_box;
	private BackupDeviceBox backup_dev_box;
	private ScheduleBox schedule_box;
	private ExcludeBox exclude_box;
	private UsersBox users_box;
	private MiscBox misc_box;
	
	private uint tmr_init;
	private int def_width = 640;
	private int def_height = 500;
	
	public SettingsWindow() {

		log_debug("SettingsWindow: SettingsWindow()");

		this.title = _("Settings");
        this.window_position = WindowPosition.CENTER;
        this.modal = true;
        //this.set_default_size (def_width, def_height);
		this.icon = IconManager.lookup("timeshift",16);

		this.delete_event.connect(on_delete_event);

        vbox_main = new Gtk.Box(Orientation.VERTICAL, 0);
        vbox_main.set_size_request(def_width, def_height);
        add(vbox_main);

        this.resize(def_width, def_height);

		var hbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
		hbox.set_layout (Gtk.ButtonBoxStyle.CENTER);
		hbox.get_style_context().add_class(Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
        vbox_main.add(hbox);
        
		switcher = new Gtk.StackSwitcher();
		switcher.margin = 6;
		hbox.add (switcher);

		stack = new Gtk.Stack();
		stack.set_transition_duration(100);
        stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
		vbox_main.add(stack);

		switcher.set_stack(stack);
		
		backend_box = new SnapshotBackendBox(this);
		stack.add_titled (backend_box, "type", _("Type"));
		
		backup_dev_box = new BackupDeviceBox(this);
		stack.add_titled (backup_dev_box, "location", _("Location"));

		schedule_box = new ScheduleBox(this);
		stack.add_titled (schedule_box, "schedule", _("Schedule"));

		exclude_box = new ExcludeBox(this);
		users_box = new UsersBox(this, exclude_box, false);
		exclude_box.set_users_box(users_box);

		misc_box = new MiscBox(this, false);
		
		stack.add_titled (users_box, "users", _("Users"));

		stack.add_titled (exclude_box, "filters", _("Filters"));

		stack.add_titled (misc_box, "misc", _("Misc"));

		backend_box.type_changed.connect(()=>{
			exclude_box.visible = !App.btrfs_mode;
			backup_dev_box.refresh();
			users_box.refresh();
		});

		stack.set_visible_child_name("type");

		//var hbox = new Gtk.ButtonBox(Gtk.Orientation.HORIZONTAL);
		var bbox = new Gtk.ButtonBox(Gtk.Orientation.HORIZONTAL);
		vbox_main.add(bbox);
		
		#if GTK3_18
		bbox.set_layout (Gtk.ButtonBoxStyle.CENTER);
		#endif
		
		var btn_ok = new Button.with_label(_("OK"));
		btn_ok.margin = 12;
		btn_ok.set_size_request(100, -1);
        bbox.add(btn_ok);
        
        btn_ok.clicked.connect(()=>{
			this.destroy();
		});

		show_all();

		tmr_init = Timeout.add(100, init_delayed);

		log_debug("SettingsWindow: SettingsWindow(): exit");
    }

    private bool init_delayed(){

		if (tmr_init > 0){
			Source.remove(tmr_init);
			tmr_init = 0;
		}

		backend_box.refresh();
		stack.set_visible_child_name("type");
		
		this.resize(def_width, def_height);
		
		//backup_dev_box.refresh(); //will be triggerred indirectly
		
		return false;
	}
	
	private bool on_delete_event(Gdk.EventAny event){
		
		save_changes();

		return false; // close window
	}
	
	private void save_changes(){
		
		exclude_box.save_changes();
		
		App.cron_job_update();

		//App.check_encrypted_home(this);

		//App.check_encrypted_private_dirs(this);
	}

	public enum Tabs{
		BACKUP_TYPE = 0,
		BACKUP_DEVICE = 1,
		SCHEDULE = 2,
		EXCLUDE = 3//,
		//NOTES = 4
	}
}



