/*
 * ExcludeListSummaryWindow.vala
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

class ExcludeListSummaryWindow : Gtk.Window{
	private Gtk.Box vbox_main;
	private Gtk.Label lbl_list;
	private Gtk.Button btn_close;
	private bool for_restore = false;
	
	private int def_width = 500;
	private int def_height = 450;

	public ExcludeListSummaryWindow(bool _for_restore) {

		log_debug("ExcludeListSummaryWindow: ExcludeListSummaryWindow()");
		
		this.title = _("Exclude List Summary");
        this.window_position = WindowPosition.CENTER;
        this.modal = true;
        this.set_default_size (def_width, def_height);
		this.icon = get_app_icon(16);

		for_restore = _for_restore;
		
	    // vbox_main
        vbox_main = new Box (Orientation.VERTICAL, 6);
        vbox_main.margin = 12;
        add(vbox_main);

		add_label(vbox_main, _("Files &amp; directories matching the patterns below will be excluded. Patterns starting with a + will include the item instead of excluding."));
		
		//add_label(vbox_main, _("Items"));
		
		lbl_list = add_label_scrolled(vbox_main, "", true, true);

		create_actions();

		refresh();
		
		show_all();

		log_debug("ExcludeListSummaryWindow: ExcludeListSummaryWindow(): exit");
    }
    
	private void create_actions(){
		
		var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        vbox_main.add(hbox);
		Gtk.SizeGroup size_group = null;
		
		// close
		
		var img = new Image.from_stock("gtk-ok", Gtk.IconSize.BUTTON);
		btn_close = add_button(hbox, _("OK"), "", ref size_group, img);

        btn_close.clicked.connect(()=>{
			this.destroy();
		});
	}

	public void refresh(){

		Gee.ArrayList<string> list;
		
		if (for_restore){
			list = App.create_exclude_list_for_restore();
		}
		else{
			list = App.create_exclude_list_for_backup();
		}
		
		var txt = "";
		foreach(var pattern in list){
			if (pattern.strip().length > 0){
				txt += "%s\n".printf(pattern);
			}
		}
		
		lbl_list.label = txt;
	}
}





