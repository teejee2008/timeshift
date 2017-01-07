/*
 * RestoreFinishBox.vala
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

class RestoreFinishBox : Gtk.Box{
	private Gtk.Label lbl_header;
	private Gtk.Label lbl_message;
	private Gtk.Window parent_window;

	public RestoreFinishBox (Gtk.Window _parent_window) {
		
		log_debug("RestoreFinishBox: RestoreFinishBox()");
		
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		margin = 12;


		lbl_header = add_label_header(this, _("Completed"), true);
		lbl_message = add_label_scrolled(this, "", false, true, 0);

		log_debug("RestoreFinishBox: RestoreFinishBox(): exit");
    }

	public void update_message(bool success){

		var txt = "";
		 
		if (App.mirror_system){
			txt = _("Cloning");
		}
		else{
			txt = _("Restore");
		}
		
		if (success){
			txt += " " + _("Completed");
		}
		else{
			txt += " " + _("Completed With Errors");
		}

		lbl_header.label = format_text(txt, true, false, true);
		
		var msg = "";

		if (App.btrfs_mode && App.restore_current_system){
			msg += _("Snapshot was restored successfully and will become active after system is restarted.") + "\n";
			msg += "\n";
			msg += _("You can continue working on the current system. After restart, the running system will be visible as a new snapshot. You can restore the new snapshot to 'undo' the restore.") + "\n";
		}

		msg += "\n";
		msg += _("Close window to exit") + "\n\n";
		
		lbl_message.label = msg;
	}

}
