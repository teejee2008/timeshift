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
				msg += bullet + _("Scheduled snapshots are enabled. Snapshots will be created automatically at selected intervals.") + "\n\n";

				/*msg += bullet + _("BTRFS snapshots are atomic. They are created instantly and does not require files to be copied. Only file system metadata is changed.\n\n");

				msg += bullet + _("BTRFS snapshots do not occupy any space on disk when first created. All data blocks are shared with system files. As files on the system gradually change with time, new files will point to new data blocks and snapshot files will point to older data blocks. Snapshots will gradually take up disk space as more and more files change on the system.\n\n");*/
			}
			else{
				msg += bullet + _("Scheduled snapshots are disabled. It's recommended to enable it.") + "\n\n";
			}
		}

		msg += bullet + _("You can rollback your system to a previous date by restoring a snapshot.") + "\n\n";

		if (App.btrfs_mode){
			msg += bullet + _("Restoring a snapshot will replace system subvolumes. The current system will be preserved as a new snapshot after restore. You can undo the restore by restoring the new snapshot that was created.") + "\n\n";
		}
		else{
			msg += bullet + _("Restoring a snapshot only replaces system files and settings. Documents and other files in your home directory will not be touched. You can change this by adding a filter to include these files. Any files that you include will be backed up when a snapshot is created, and replaced when the snapshot is restored.") + "\n\n";
		}
		
		msg += bullet + _("If the system is unable to boot after restore, you can try restoring another snapshot by installing and running Timeshift on the Ubuntu Live CD/USB.") + "\n\n";

		if (App.btrfs_mode){
			msg += bullet + _("In BTRFS mode, snapshots are saved on the same disk from which it is created. If your system disk fails, then you will not be able to rescue your system. Use RSYNC mode and save snapshots to another disk if you wish to guard against disk failures.") + "\n\n";
		}
		else{
			msg += bullet + _("To guard against hard disk failures, select an external disk for the snapshot location instead of the system disk.") + "\n\n";

			msg += bullet + _("Avoid storing snapshots on your system disk. Using another non-system disk will allow you to format and re-install the OS on your system disk without losing the snapshots stored on it. You can even install another Linux distribution and later roll-back the previous distribution by restoring the snapshot.") + "\n\n";

			msg += bullet + _("The first snapshot creates a copy of all files on your system. Subsequent snapshots only store files which have changed. You can reduce the size of snapshots by adding filters to exclude files which are not required. For example, you can exclude your web browser cache as these files change constantly and are not critical.") + "\n\n";

			msg += bullet + _("Common files are hard-linked between snapshots. Copying the files manually to another location will duplicate the files and break hard-links between them. Snapshots must be moved carefully by running 'rsync' from a terminal. The file system at destination path must support hard-links.") + "\n\n";
		}

		lbl_message.label = msg;
	}

}
