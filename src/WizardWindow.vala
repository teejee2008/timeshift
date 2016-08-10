/*
 * WizardWindow.vala
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
using TeeJee.JSON;
using TeeJee.ProcessManagement;
using TeeJee.GtkHelper;
using TeeJee.Multimedia;
using TeeJee.System;
using TeeJee.Misc;

class WizardWindow : Gtk.Window{

	private Gtk.Box vbox_main;
	private Notebook notebook;
	
	public WizardWindow () {
		this.title = AppName + " v" + AppVersion;
        this.window_position = WindowPosition.CENTER;
        this.modal = true;
        this.set_default_size (700, 500);
		//this.delete_event.connect(on_delete_event);
		this.icon = get_app_icon(16);

	    // vbox_main
        var box = new Box (Orientation.VERTICAL, 0);
        box.margin = 0;
        add(box);
		vbox_main = box;
        
		notebook = add_notebook(box, false);

		box = add_tab(notebook, _("Backup Device"));
		create_tab_backup_device(box);
    }

    private Gtk.Notebook add_notebook(Gtk.Box box, bool show_tabs = true){
        // notebook
		var book = new Gtk.Notebook();
		book.margin = 12;
		book.show_tabs = false;
		
		box.pack_start(book, true, true, 0);
		
		return book;
	}

	private Gtk.Box add_tab(Gtk.Notebook book, string title){
		// label
		var label = new Gtk.Label(title);

        // vbox
        var vbox = new Box (Gtk.Orientation.VERTICAL, 6);
        vbox.margin = 6;
        book.append_page (vbox, label);

        return vbox;
	}

	private void create_tab_backup_device(Gtk.Box box){
		add_label(box, _("Backup Location"), true);

		add_radio(box, _("Save to disk partition (under /timeshift):"));

		add_radio(box, _("Save to path*:"));

		add_label(box, _("* File system at selected path must support hard-links!"));
		
	}

	private Gtk.Label add_label(Gtk.Box box, string text, bool is_header = false){
		var msg = is_header ? "<b>%s</b>".printf(text) : "%s".printf(text);
		var label = new Gtk.Label(msg);
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		
		if (is_header){
			label.margin_bottom = 24;
		}
		
		box.add(label);
		
		return label;
	}

	private Gtk.RadioButton add_radio(Gtk.Box box, string text, Gtk.RadioButton? another_radio = null){

		Gtk.RadioButton radio = null;

		if (another_radio == null){
			radio = new Gtk.RadioButton(null);
		}
		else{
			radio = new Gtk.RadioButton.from_widget(another_radio);
		}

		radio.label = text;
		
		box.add(radio);
		
		return radio;
	}
}
