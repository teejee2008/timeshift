/*
 * BootOptionsWindow.vala
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

class BootOptionsWindow : Gtk.Window{
	private Gtk.Box vbox_main;
	private Gtk.ButtonBox bbox_action;
	private BootOptionsBox boot_options_box;

	private uint tmr_init;
	private int def_width = 450;
	private int def_height = 500;

	public BootOptionsWindow() {

		log_debug("BootOptionsWindow: BootOptionsWindow()");
		
		this.title = _("Bootloader Options");
        this.window_position = WindowPosition.CENTER;
        this.modal = true;
        //this.set_default_size (def_width, def_height);
		this.icon = get_app_icon(16);

		this.delete_event.connect(on_delete_event);

	    // vbox_main
        vbox_main = new Box (Orientation.VERTICAL, 6);
        vbox_main.margin = 12;
        add(vbox_main);

		boot_options_box = new BootOptionsBox(this);
		boot_options_box.margin = 0;
		vbox_main.add(boot_options_box);
		
		create_actions();

		show_all();

		tmr_init = Timeout.add(100, init_delayed);

		log_debug("BootOptionsWindow: BootOptionsWindow(): exit");
    }

	private bool init_delayed(){

		if (tmr_init > 0){
			Source.remove(tmr_init);
			tmr_init = 0;
		}

		return false;
	}
	
	private bool on_delete_event(Gdk.EventAny event){

		//save_changes();
		
		return false; // close window
	}
	
	private void save_changes(){
		//App.cron_job_update();
	}
	
	private void create_actions(){
		
		var hbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
		hbox.margin = 0;
		hbox.margin_top = 24;
        vbox_main.add(hbox);

		Gtk.SizeGroup size_group = null;
		
		// close
		var btn_close = add_button(hbox, _("Close"), "", ref size_group, null);
		//hbox.set_child_packing(btn_close, false, true, 6, Gtk.PackType.END);
		
        btn_close.clicked.connect(()=>{
			save_changes();
			this.destroy();
		});
	}

}



