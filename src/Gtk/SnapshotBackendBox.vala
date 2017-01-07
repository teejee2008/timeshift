
/*
 * SnapshotBackendBox.vala
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

class SnapshotBackendBox : Gtk.Box{
	
	private Gtk.RadioButton opt_rsync;
	private Gtk.RadioButton opt_btrfs;
	private Gtk.Label lbl_description;
	private Gtk.Window parent_window;
	
	public signal void type_changed();

	public SnapshotBackendBox (Gtk.Window _parent_window) {

		log_debug("SnapshotBackendBox: SnapshotBackendBox()");
		
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		margin = 12;

		build_ui();

		refresh();

		log_debug("SnapshotBackendBox: SnapshotBackendBox(): exit");
    }

	private void build_ui(){

		add_label_header(this, _("Select Snapshot Type"), true);

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
		//hbox.homogeneous = true;
		add(hbox);
		
		add_opt_rsync(hbox);

		add_opt_btrfs(hbox);

		add_description();
	}

	private void add_opt_rsync(Gtk.Box hbox){

		var opt = new RadioButton.with_label_from_widget(null, _("RSYNC"));
		opt.set_tooltip_markup(_("Create snapshots using RSYNC tool and hard-links"));
		hbox.add (opt);
		opt_rsync = opt;

		opt_rsync.toggled.connect(()=>{
			if (opt_rsync.active){
				App.btrfs_mode = false;
				init_backend();
				type_changed();
				update_description();
			}
		});
	}

	private void add_opt_btrfs(Gtk.Box hbox){

		var opt = new RadioButton.with_label_from_widget(opt_rsync, _("BTRFS"));
		opt.set_tooltip_markup(_("Create snapshots using RSYNC"));
		hbox.add (opt);
		opt_btrfs = opt;

		opt_btrfs.toggled.connect(()=>{
			if (opt_btrfs.active){
				if (check_for_btrfs_tools()){
					App.btrfs_mode = true;
					init_backend();
					type_changed();
					update_description();
				}
				else{
					opt_rsync.active = true;
				}
			}
		});
	}

	private bool check_for_btrfs_tools(){
		if (!cmd_exists("btrfs")){
			string msg = _("The 'btrfs' command is not available on your system. Install the 'btrfs-tools' package and try again.");
			string title = _("BTRFS Tools Not Found");
			gtk_set_busy(false, parent_window);
			gtk_messagebox(title, msg, parent_window, true);
			
			return false;
		}
		else{
			return true;
		}
	}
	

	private void add_description(){
		// scrolled
		var scrolled = new ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		//scrolled.margin = 6;
		//scrolled.expand = true;
		scrolled.set_size_request(-1,200);
		scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
		scrolled.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		add(scrolled);

		var lbl = new Gtk.Label("");
		lbl.set_use_markup(true);
		lbl.xalign = (float) 0.0;
		lbl.yalign = (float) 0.0;
		lbl.wrap = true;
		lbl.wrap_mode = Pango.WrapMode.WORD;
		lbl.margin = 12;
		lbl.vexpand = true;
		scrolled.add(lbl);

		lbl_description = lbl;
	}

	private void update_description(){

		string bullet = "▰ ";
		
		if (opt_btrfs.active){
			string txt = "<b>BTRFS Snapshots</b>\n\n";

			txt += bullet + _("Snapshots are created using the built-in features of the BTRFS file system.") + "\n\n";
			
			txt += bullet + _("Snapshots are created and restored instantly. Snapshot creation is an atomic transaction at the file system level.") + "\n\n";

			txt += bullet + _("Snapshots are restored by replacing system subvolumes. Since files are never copied, deleted or overwritten, there is no risk of data loss. The existing system is preserved as a new snapshot after restore.") + "\n\n";
			
			txt += bullet + _("Snapshots are perfect, byte-for-byte copies of the system. Excluding files is not supported.") + "\n\n";

			txt += bullet + _("Snapshots are saved on the same disk from which they are created (system disk). Storage on other disks is not supported. If your system disk fails then the snapshots stored on it will be lost along with the system.") + "\n\n";

			txt += bullet + _("Size of BTRFS snapshots are initially zero. As system files gradually change with time, data gets written to new blocks which take up disk space (copy-on-write). The files in the snapshot continue to point to the original data blocks.") + "\n\n";

			txt += bullet + _("OS must be installed on a BTRFS partition with Ubuntu-type subvolume layout (@ and @home subvolumes). Other file systems and subvolume layouts are not supported.") + "\n\n";
			
			lbl_description.label = txt;
		}
		else{
			string txt = "<b>RSYNC Snapshots</b>\n\n";

			txt += bullet + _("Snapshots are created by creating copies of system files using rsync, and hard-linking unchanged files from the previous snapshot.") + "\n\n";
			
			txt += bullet + _("Files are copied when the first snapshot is created. Subsequent snapshots are incremental. Unchanged files are hard-linked from the previous snapshot.") + "\n\n";

			txt += bullet + _("Snapshots can be saved to any disk formatted with a Linux file system. Saving snapshots to a non-system/portable disk allows the system to be restored even if the system disk is damaged or re-formatted.") + "\n\n";

			txt += bullet + _("Files and directories can be excluded to save disk space.") + "\n\n";

			lbl_description.label = txt;
		}
	}
	
	public void init_backend(){
		App.try_select_default_device_for_backup(parent_window);
	}

	public void refresh(){
		opt_btrfs.active = App.btrfs_mode;
		type_changed();
		update_description();
	}
}
