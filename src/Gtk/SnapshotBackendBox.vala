
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
	private Gtk.Window parent_window;

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
		
		add_opt_rsync();

		add_opt_btrfs();
	}

	private void add_opt_rsync(){

		var opt = new RadioButton.with_label_from_widget(null, _("Rsync + Hard-links"));
		opt.set_tooltip_markup(_("Create snapshots using RSYNC tool and hard-links"));
		add (opt);
		opt_rsync = opt;

		opt_rsync.toggled.connect(()=>{
			if (opt_rsync.active){
				App.btrfs_mode = false;
			}
			
			// TODO: init
		});


		// scrolled
		var scrolled = new ScrolledWindow(null, null);
		//scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		//scrolled.margin = 6;
		//scrolled.expand = true;
		scrolled.set_size_request(-1,100);
		scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
		scrolled.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		add(scrolled);
		
		var label = add_label((Gtk.Box)scrolled, "", false, true, false);
		//label.vexpand = true;
		label.margin_bottom = 6;
		
		string txt = "";

		txt += "> " + _("Create snapshots using rsync tool and hard-links.") + "\n";

		txt += "> " + _("Snapshots can be stored on non-system devices such as portable hard disks. This allows system to be restored even if the primary hard disk is damaged or re-formatted.") + "\n";

		label.label = format_text(txt, false, true, false);
	}

	private void add_opt_btrfs(){

		var opt = new RadioButton.with_label_from_widget(opt_rsync, _("BTRFS"));
		opt.set_tooltip_markup(_("Create snapshots using RSYNC"));
		add (opt);
		opt_btrfs = opt;

		opt_btrfs.toggled.connect(()=>{
			if (opt_btrfs.active){
				App.btrfs_mode = true;
			}
			
			// TODO: init
		});

		// scrolled
		var scrolled = new ScrolledWindow(null, null);
		//scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		//scrolled.margin = 6;
		//scrolled.expand = true;
		scrolled.set_size_request(-1,200);
		scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
		scrolled.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		add(scrolled);
		
		var label = add_label((Gtk.Box)scrolled, "", false, true, false);
		//label.vexpand = true;
		label.margin_bottom = 6;
		
		string txt = "";

		txt += "> " + _("Create snapshots using the BTRFS file system tools") + "\n";

		txt += "> " + _("Snapshots will be stored on the same device from which it is created (storage on external disks is not supported).") + "\n";

		txt += "> " + _("Snapshots are atomic (created instantly as a single transaction). Snapshots can be created, deleted and restored instantly (without any delay).") + "\n";

		txt += "> " + _("Snapshots are perfect bit-for-bit copies of your system (nothing is excluded).") + "\n";

		txt += "> " + _("Snapshots are very space efficient and do not take space on disk when first created. As system files are modified over time, the files in snapshot will be duplicated, and the snapshot will gradually take up space on disk.") + "\n";
		
		label.label = format_text(txt, false, true, false);
	}

	public void init_backend(){
		if (App.btrfs_mode){
			if (App.repo.available() && (App.repo.device.fstype != "btrfs")){
				App.repo =  new SnapshotRepo.from_null();
			}
		}
	}

	public void refresh(){
		opt_btrfs.active = App.btrfs_mode;
	}
}
