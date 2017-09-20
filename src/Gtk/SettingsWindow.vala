/*
 * SettingsWindow.vala
 *
 * Copyright 2016 Tony George <teejee@tony-pc>
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

	private uint tmr_init;
	private int def_width = 550;
	private int def_height = 500;
	
	public SettingsWindow () {

		log_debug("SettingsWindow: SettingsWindow()");

		this.title = _("Settings");
        this.window_position = WindowPosition.CENTER;
        this.modal = true;
        this.set_default_size (def_width, def_height);
		this.icon = get_app_icon(16);

		this.delete_event.connect(on_delete_event);

        vbox_main = new Box (Orientation.VERTICAL, 0);
        //vbox_main.margin = 6;
        add(vbox_main);

		var hbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
		hbox.set_layout (Gtk.ButtonBoxStyle.CENTER);
		hbox.get_style_context().add_class(Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
        vbox_main.add(hbox);
        
		switcher = new Gtk.StackSwitcher();
		switcher.margin = 6;
		hbox.add (switcher);

		stack = new Gtk.Stack();
		stack.set_transition_duration (200);
        stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
		vbox_main.add(stack);

		switcher.set_stack(stack);
		
		backend_box = new SnapshotBackendBox(this);
		stack.add_titled (backend_box, _("Type"), _("Type"));
		
		backup_dev_box = new BackupDeviceBox(this);
		stack.add_titled (backup_dev_box, _("Location"), _("Location"));

		schedule_box = new ScheduleBox(this);
		stack.add_titled (schedule_box, _("Schedule"), _("Schedule"));

		exclude_box = new ExcludeBox(this, false);
		stack.add_titled (exclude_box, _("Filters"), _("Filters"));

		backend_box.type_changed.connect(()=>{
			exclude_box.visible = !App.btrfs_mode;
			backup_dev_box.refresh();
			//notes_box.refresh();
		});

		create_actions();

		//log_debug("ui created");

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

		App.check_encrypted_home(this);

		App.check_encrypted_private_dirs(this);
	}

	private void create_actions(){
		
		var hbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
		hbox.margin = 6;
		hbox.margin_top = 0;
        vbox_main.add(hbox);

		Gtk.SizeGroup size_group = null;
		
		// close
		
		var img = new Image.from_stock("gtk-close", Gtk.IconSize.BUTTON);
		var btn_close = add_button(hbox, _("Close"), "", ref size_group, img);
		//hbox.set_child_packing(btn_close, false, true, 6, Gtk.PackType.END);
		
        btn_close.clicked.connect(()=>{
			save_changes();
			this.destroy();
		});
	}

	public enum Tabs{
		BACKUP_TYPE = 0,
		BACKUP_DEVICE = 1,
		SCHEDULE = 2,
		EXCLUDE = 3//,
		//NOTES = 4
	}
}



