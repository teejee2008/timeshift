/*
 * EstimateBox.vala
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

class FinishBox : Gtk.Box{
	private Gtk.Label lbl_header;
	private Gtk.Label lbl_message;
	
	private Gtk.Window parent_window;
	private bool show_notes = true;

	public FinishBox (Gtk.Window _parent_window, bool _show_notes) {

		log_debug("FinishBox: FinishBox()");
		
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		margin = 12;
		show_notes = _show_notes;
		
		// header
		if (show_notes){
			lbl_header = add_label_header(this, _("Notes"), true);
		}
		else{
			lbl_header = add_label_header(this, _("Setup Complete"), true);
		}

		lbl_message = add_label_scrolled(this, "", false, true, 0);

		refresh();

		log_debug("FinishBox: FinishBox(): exit");
    }

	public void refresh(){

		var msg = "";
		string bullet = "▰ ";
		
		if (!show_notes){
			if (App.scheduled){
				msg += bullet + _("Scheduled snapshots are enabled. Snapshots will be created automatically for selected levels.") + "\n\n";
			}
			else{
				msg += bullet + _("Scheduled snapshots are disabled. It's recommended to enable it.") + "\n\n";
			}
		}

		msg += bullet + _("System can be rolled-back to a previous date by restoring a snapshot.") + "\n\n";

		if (App.btrfs_mode){
			msg += bullet + _("Restoring a snapshot will replace system subvolumes, and system subvolumes currently in use will be preserved as a new snapshot. If required, this snapshot can be restored later to 'undo' the restore.") + "\n\n";
		}
		else{
			msg += bullet + _("Restoring snapshots only replaces system files and settings. Non-hidden files and directories in user home directories will not be touched. This behaviour can be changed by adding a filter to include these files. Included files will be backed up when snapshot is created, and replaced when snapshot is restored.") + "\n\n";
		}
		
		if (App.btrfs_mode){
			msg += bullet + _("BTRFS snapshots are saved on the same disk from which it is created. If the system disk fails, snapshots will be lost along with the system. Save snapshots to an external non-system disk in RSYNC mode to guard against disk failures.") + "\n\n";
		}
		else{
			msg += bullet + _("Save snapshots to an external disk instead of the system disk to guard against drive failures.") + "\n\n";

			msg += bullet + _("Saving snapshots to a non-system disk allows you to format and re-install the OS on the system disk without losing snapshots stored on it. You can even install another Linux distribution and later roll-back the previous distribution by restoring a snapshot.") + "\n\n";
		}

		lbl_message.label = msg;
	}

}
