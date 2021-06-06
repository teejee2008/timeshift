/*
 * BackupFinishBox.vala
 *
 * Copyright 2016 Tony George <tony.george.kol@gmail.com>
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

class BackupFinishBox : Gtk.Box{
	private Gtk.Label lbl_header;
	private Gtk.Label lbl_message;
	private Gtk.Window parent_window;

	public BackupFinishBox (Gtk.Window _parent_window) {
		
		log_debug("BackupFinishBox: BackupFinishBox()");
		
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		GLib.Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		margin = 12;


		lbl_header = add_label_header(this, _("Completed"), true);
		lbl_message = add_label_scrolled(this, "", false, true, 0);

		log_debug("BackupFinishBox: BackupFinishBox(): exit");
    }

	public void update_message(bool success){

		var txt = "";
		 
		txt = _("Snapshot Created");

		if (!success){
			txt += " " + _("With Errors");
		}

		lbl_header.label = format_text(txt, true, false, true);
		
		var msg = "";

		msg += _("Close window to exit") + "\n\n";
		
		lbl_message.label = msg;
	}

}
