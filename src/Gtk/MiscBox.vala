/*
 * MiscBox.vala
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

class MiscBox : Gtk.Box{
	
	private Gtk.Window parent_window;
	private bool restore_mode = false;
	
	//private Gtk.CheckButton chk_include_btrfs_home;
	//private Gtk.CheckButton chk_enable_qgroups;
	
	
	public MiscBox (Gtk.Window _parent_window, bool _restore_mode) {

		log_debug("MiscBox: MiscBox()");
		
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		margin = 12;

		restore_mode = _restore_mode;
		
		var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		this.add(vbox);

		// ------------------------
		
		init_date_format_option(vbox);

		refresh();
		
		log_debug("MiscBox: MiscBox(): exit");
    }

	private void init_date_format_option(Gtk.Box box){

		log_debug("MiscBox: init_date_format_option()");

		add_label_header(box, _("Date Format"), false);

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		box.add(hbox);

		var combo = new Gtk.ComboBox();
		combo.hexpand = true;
		hbox.add(combo);

		var entry = new Gtk.Entry();
		entry.hexpand = true;
		hbox.add(entry);
		
		var cell_pix = new Gtk.CellRendererPixbuf();
		combo.pack_start (cell_pix, false);

		var cell_text = new Gtk.CellRendererText();
		cell_text.xalign = (float) 0.0;
		combo.pack_start (cell_text, false);

		var now = new DateTime.local(2019, 8, 11, 20, 25, 43);

		combo.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
			
			string txt;
			model.get (iter, 0, out txt, -1);

			(cell as Gtk.CellRendererText).text = (txt.length == 0) ? _("Custom") : now.format(txt);
		});
		
		// populate combo
		var model = new Gtk.ListStore(1, typeof(string));
		combo.model = model;

		int active = -1;
		int index = -1;
		TreeIter iter;
		foreach(var fmt in new string[]{
			"", // custom
			"%Y-%m-%d %H:%M:%S", // 2019-08-11 20:00:00
			"%Y-%m-%d %I:%M %p", // 2019-08-11 08:00 PM
			"%d %b %Y %I:%M %p", // 11 Aug 2019 08:00 PM
			"%Y %b %d, %I:%M %p", // 2019 Aug 11, 08:00 PM
			"%c"                 // Sunday, 11 August 2019 08:00:00 PM IST
			}){
			
			index++;
			model.append(out iter);
			model.set(iter, 0, fmt);

			if (App.date_format == fmt){
				active = index;
			}
		}
		
		if (active < 0){
			active = 0; 
		}
		
		combo.active = active;

		combo.changed.connect((path) => {

			TreeIter iter_active;
			bool selected = combo.get_active_iter(out iter_active);
			if (!selected){ return; }
			
			TreeIter iter_combo;
			var store = (Gtk.ListStore) combo.model;

			string txt;
			model.get (iter_active, 0, out txt, -1);

			string fmt = Main.date_format_default;
			if (txt.length > 0){
				fmt = txt;
			}
			
			entry.text = fmt;
			
			entry.sensitive = (txt.length == 0);

			App.date_format = fmt;
		});

		entry.text = App.date_format;

		entry.sensitive = (combo.active == 0);

		entry.focus_out_event.connect((entry1, event1) => {
			App.date_format = entry.text;
			log_debug("saved date_format: %s".printf(App.date_format));
			return false;
		});
		
		show_all();

		log_debug("MiscBox: init_date_format_option(): exit");
	}

	// helpers

	public void refresh(){

		if (App.btrfs_mode){

			//chk_include_btrfs_home.active = App.include_btrfs_home_for_restore;
		}
		else{

			//chk_include_btrfs_home
		}

		show_all();
	}
}
