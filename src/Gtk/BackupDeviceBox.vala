/*
 * BackupBox.vala
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

class BackupDeviceBox : Gtk.Box{

	private Gtk.TreeView tv_devices;
	private Gtk.InfoBar infobar_location;
	private Gtk.Label lbl_infobar_location;
	private Gtk.Label lbl_common;
	
	private Gtk.Window parent_window;

	public BackupDeviceBox (Gtk.Window _parent_window) {

		log_debug("BackupDeviceBox: BackupDeviceBox()");
		
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		margin = 12;

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		add(hbox);

		add_label_header(hbox, _("Select Snapshot Location"), true);

		// buffer
		var label = add_label(hbox, "");
        label.hexpand = true;
       
		// refresh device button
		
		var size_group = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		var btn_refresh = add_button(hbox, _("Refresh"), "", size_group, null);
        btn_refresh.clicked.connect(()=>{
			App.update_partitions();
			tv_devices_refresh();
		});

		// TODO: show this message somewhere
		
		//var msg = _("Only Linux partitions are supported.");
		//msg += "\n" + _("Snapshots will be saved in folder /timeshift");

		// treeview
		init_tv_devices();

		// tooltips
		//tv_devices.set_tooltip_text(msg);

		// infobar
		init_infobar_location();

		log_debug("BackupDeviceBox: BackupDeviceBox(): exit");
    }

    public void refresh(){
		
		tv_devices_refresh();
		
		check_backup_location();

		if (App.btrfs_mode){
			
			lbl_common.label = "<i>• %s\n• %s\n• %s</i>".printf(
				_("Devices displayed above have BTRFS file systems."),
				_("BTRFS snapshots are saved on system partition. Other partitions are not supported."),
				_("Snapshots are saved to /timeshift-btrfs on selected partition. Other locations are not supported.")
			);
		}
		else {
			lbl_common.label = "<i>• %s\n• %s\n• %s\n• %s</i>".printf(
				_("Devices displayed above have Linux file systems."),
				_("Devices with Windows file systems are not supported (NTFS, FAT, etc)."),
				_("Remote and network locations are not supported."),
				_("Snapshots are saved to /timeshift on selected partition. Other locations are not supported.")
			);
		}
	}

	private void init_tv_devices(){
		
		tv_devices = add_treeview(this);
		tv_devices.vexpand = true;
		tv_devices.headers_clickable = true;
		//tv_devices.rules_hint = true;
		tv_devices.activate_on_single_click = true;
		//tv_devices.headers_clickable  = true;
		
		// device name
		
		Gtk.CellRendererPixbuf cell_pix;
		Gtk.CellRendererToggle cell_radio;
		Gtk.CellRendererText cell_text;
		//var col = add_column_radio_and_text(tv_devices, _("Disk"), out cell_radio, out cell_text);
		var col = add_column_icon_radio_text(tv_devices, _("Disk"),
			out cell_pix, out cell_radio, out cell_text);

		col.resizable = true;
		
		col.set_cell_data_func(cell_pix, (cell_layout, cell, model, iter)=>{
			Device dev;
			model.get (iter, 0, out dev, -1);

			(cell as Gtk.CellRendererPixbuf).visible = (dev.type == "disk");
			
		});

        col.add_attribute(cell_pix, "icon-name", 2);

		col.set_cell_data_func(cell_radio, (cell_layout, cell, model, iter)=>{
			Device dev;
			bool selected;
			model.get (iter, 0, out dev, 3, out selected, -1);

			(cell as Gtk.CellRendererToggle).active = selected;

			(cell as Gtk.CellRendererToggle).visible =
				(dev.size_bytes > 10 * KB) && (dev.type != "disk") && (dev.children.size == 0);
		});

		//cell_radio.toggled.connect((path)=>{});

		col.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
			Device dev;
			model.get (iter, 0, out dev, -1);

			/*if (dev.type == "disk"){
				var txt = "%s %s".printf(dev.model, dev.vendor).strip();
				if (txt.length == 0){
					txt = "%s Disk".printf(format_file_size(dev.size_bytes));
				}
				else{
					txt += " (%s Disk)".printf(format_file_size(dev.size_bytes));
				}
				(cell as Gtk.CellRendererText).text = txt.strip();
			}
			else {
				(cell as Gtk.CellRendererText).text = dev.description_full_free();
			}*/

			if (dev.type == "disk"){
				var txt = "%s %s".printf(dev.model, dev.vendor).strip();
				if (txt.length == 0){
					txt = "%s Disk".printf(format_file_size(dev.size_bytes));
				}
				(cell as Gtk.CellRendererText).text = txt.strip();
			}
			else {
				(cell as Gtk.CellRendererText).text = dev.kname;
			}

			//(cell as Gtk.CellRendererText).sensitive = (dev.type != "disk");
		});

		
		// type
		
		col = add_column_text(tv_devices, _("Type"), out cell_text);

		col.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
			Device dev;
			model.get (iter, 0, out dev, -1);
			(cell as Gtk.CellRendererText).text = dev.fstype;

			//(cell as Gtk.CellRendererText).sensitive = (dev.type != "disk");
		});

		// size
		
		col = add_column_text(tv_devices, _("Size"), out cell_text);
		cell_text.xalign = (float) 1.0;
		
		col.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
			Device dev;
			model.get (iter, 0, out dev, -1);

			(cell as Gtk.CellRendererText).text =
					(dev.size_bytes > 0) ? format_file_size(dev.size_bytes, false, "", true, 0) : "";
		});

		// free
		
		col = add_column_text(tv_devices, _("Free"), out cell_text);
		cell_text.xalign = (float) 1.0;
		
		col.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
			Device dev;
			model.get (iter, 0, out dev, -1);

			if (dev.type == "disk"){
				(cell as Gtk.CellRendererText).text = "";
			}
			else{
				(cell as Gtk.CellRendererText).text =
					(dev.free_bytes > 0) ? format_file_size(dev.free_bytes, false, "", true, 0) : "";
			}

			(cell as Gtk.CellRendererText).sensitive = (dev.type != "disk");
		});

		// name
		
		col = add_column_text(tv_devices, _("Name"), out cell_text);
		cell_text.xalign = 0.0f;
		
		col.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
			Device dev;
			model.get (iter, 0, out dev, -1);

			if (dev.type == "disk"){
				(cell as Gtk.CellRendererText).text = "";
			}
			else{
				(cell as Gtk.CellRendererText).text = dev.partlabel;
			}

			(cell as Gtk.CellRendererText).sensitive = (dev.type != "disk");
		});

		// label
		
		col = add_column_text(tv_devices, _("Label"), out cell_text);
		cell_text.xalign = 0.0f;
		
		col.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
			Device dev;
			model.get (iter, 0, out dev, -1);

			if (dev.type == "disk"){
				(cell as Gtk.CellRendererText).text = "";
			}
			else{
				(cell as Gtk.CellRendererText).text = dev.label;
			}

			(cell as Gtk.CellRendererText).sensitive = (dev.type != "disk");
		});
		
		// buffer

		col = add_column_text(tv_devices, "", out cell_text);
		col.expand = true;
		
		/*// label
		
		col = add_column_text(tv_devices, _("Label"), out cell_text);

		col.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
			Device dev;
			model.get (iter, 0, out dev, -1);
			(cell as Gtk.CellRendererText).text = dev.label;

			(cell as Gtk.CellRendererText).sensitive = (dev.type != "disk");
		});*/

		
		
		// events

		tv_devices.row_activated.connect((path, column) => {
			var store = (Gtk.TreeStore) tv_devices.model;
			var selection = tv_devices.get_selection();

			selection.selected_foreach((model, path, iter) => {
				Device dev;
				store.get (iter, 0, out dev);

				if ((App.repo.device == null) || (App.repo.device.uuid != dev.uuid)){
					try_change_device(dev);
				}
				else{
					return;
				}
			});

			store.foreach((model, path, iter) => {
				Device dev;
				store.get (iter, 0, out dev);
				
				if ((App.repo.device != null) && (App.repo.device.uuid == dev.uuid)){
					store.set (iter, 3, true);
					//tv_devices.get_selection().select_iter(iter);
				}
				else{
					store.set (iter, 3, false);
				}

				return false; // continue
			});
		});
	}

	private void init_infobar_location(){
		
		var infobar = new Gtk.InfoBar();
		infobar.no_show_all = true;
		add(infobar);
		infobar_location = infobar;
		
		var content = (Gtk.Box) infobar.get_content_area();
		var label = add_label(content, "");
		lbl_infobar_location = label;

		// scrolled
		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
		scrolled.vscrollbar_policy = Gtk.PolicyType.NEVER;
		scrolled.set_size_request(-1, 100);
		this.add(scrolled);
		
		label = new Gtk.Label("");
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		label.wrap = true;
		label.wrap_mode = Pango.WrapMode.WORD;
		label.margin = 6;
		scrolled.add(label);
		lbl_common = label;
	}

	private void try_change_device(Device dev){

		log_debug("try_change_device: %s".printf(dev.device));
		
		if (dev.type == "disk"){

			bool found_child = false;

			if ((App.btrfs_mode && (dev.fstype == "btrfs")) || (!App.btrfs_mode && dev.has_linux_filesystem())){
				
				change_backup_device(dev);
				found_child = true;
			}

			if (!found_child){

				// find first valid partition
				
				foreach (var child in dev.children){
					
					if ((App.btrfs_mode && (child.fstype == "btrfs")) || (!App.btrfs_mode && child.has_linux_filesystem())){
						
						change_backup_device(child);
						found_child = true;
						break;
					}
				}
			}
			
			if (!found_child){
				
				string msg = _("Selected device does not have Linux partition");
				
				if (App.btrfs_mode){
					msg = _("Selected device does not have BTRFS partition");
				}
				
				lbl_infobar_location.label = "<span weight=\"bold\">%s</span>".printf(msg);
				infobar_location.message_type = Gtk.MessageType.ERROR;
				infobar_location.no_show_all = false;
				infobar_location.show_all();
			}
		}
		else if (dev.has_children()){
			
			// select the child instead of parent
			change_backup_device(dev.children[0]);
		}
		else if (!dev.has_children()){
			
			// select the device
			change_backup_device(dev);
		}
		else {
			
			// ask user to select
			lbl_infobar_location.label = "<span weight=\"bold\">%s</span>".printf(_("Select a partition on this disk"));
			infobar_location.message_type = Gtk.MessageType.ERROR;
			infobar_location.no_show_all = false;
			infobar_location.show_all();
		}
	}

	private void change_backup_device(Device pi){
		
		// return if device has not changed
		if ((App.repo.device != null) && (pi.uuid == App.repo.device.uuid)){ return; }

		gtk_set_busy(true, parent_window);

		log_debug("\n");
		log_msg("selected device: %s".printf(pi.device));
		log_debug("fstype: %s".printf(pi.fstype));

		App.repo = new SnapshotRepo.from_device(pi, parent_window, App.btrfs_mode);

		if (pi.fstype == "luks"){
			
			App.update_partitions();

			var dev = Device.find_device_in_list(App.partitions, pi.uuid);
			
			if (dev.has_children()){
				
				log_debug("has children");
				
				if (dev.children[0].has_linux_filesystem()){
					
					log_debug("has linux filesystem: %s".printf(dev.children[0].fstype));
					log_msg("selecting child device: %s".printf(dev.children[0].device));
						
					App.repo = new SnapshotRepo.from_device(dev.children[0], parent_window, App.btrfs_mode);
					tv_devices_refresh();
				}
				else{
					log_debug("does not have linux filesystem");
				}
			}
		}

		check_backup_location();

		gtk_set_busy(false, parent_window);
	}

	private bool check_backup_location(){
		
		bool ok = true;

		App.repo.check_status();
		string message = App.repo.status_message;
		string details = App.repo.status_details;
		int status_code = App.repo.status_code;
		
		// TODO: call check on repo directly
		
		message = escape_html(message);
		details = escape_html(details);
		
		if (App.live_system()){
			
			switch (status_code){
			case SnapshotLocationStatus.NOT_SELECTED:
				lbl_infobar_location.label = "<span weight=\"bold\">%s</span>".printf(details);
				infobar_location.message_type = Gtk.MessageType.ERROR;
				infobar_location.no_show_all = false;
				infobar_location.show_all();
				ok = false;
				break;
				
			case SnapshotLocationStatus.NOT_AVAILABLE:
				lbl_infobar_location.label = "<span weight=\"bold\">%s</span>".printf(message);
				infobar_location.message_type = Gtk.MessageType.ERROR;
				infobar_location.no_show_all = false;
				infobar_location.show_all();
				ok = false;
				break;

			case SnapshotLocationStatus.READ_ONLY_FS:
			case SnapshotLocationStatus.HARDLINKS_NOT_SUPPORTED:
				lbl_infobar_location.label = "<span weight=\"bold\">%s</span>".printf(message);
				infobar_location.message_type = Gtk.MessageType.ERROR;
				infobar_location.no_show_all = false;
				infobar_location.show_all();
				ok = false;
				break;

			case SnapshotLocationStatus.NO_BTRFS_SYSTEM:
				lbl_infobar_location.label = "<span weight=\"bold\">%s</span>".printf(details);
				infobar_location.message_type = Gtk.MessageType.ERROR;
				infobar_location.no_show_all = false;
				infobar_location.show_all();
				ok = false;
				break;

			case SnapshotLocationStatus.NO_SNAPSHOTS_HAS_SPACE:
			case SnapshotLocationStatus.NO_SNAPSHOTS_NO_SPACE:
				lbl_infobar_location.label = "<span weight=\"bold\">%s</span>".printf(
					_("There are no snapshots on this device"));
				infobar_location.message_type = Gtk.MessageType.ERROR;
				infobar_location.no_show_all = false;
				infobar_location.show_all();
				//ok = false;
				break;

			case SnapshotLocationStatus.HAS_SNAPSHOTS_NO_SPACE:
			case SnapshotLocationStatus.HAS_SNAPSHOTS_HAS_SPACE:
				infobar_location.hide();
				break;
			}
		}
		else{
			switch (status_code){
				case SnapshotLocationStatus.NOT_SELECTED:
					lbl_infobar_location.label = "<span weight=\"bold\">%s</span>".printf(details);
					infobar_location.message_type = Gtk.MessageType.ERROR;
					infobar_location.no_show_all = false;
					infobar_location.show_all();
					ok = false;
					break;
					
				case SnapshotLocationStatus.NOT_AVAILABLE:
				case SnapshotLocationStatus.HAS_SNAPSHOTS_NO_SPACE:
				case SnapshotLocationStatus.NO_SNAPSHOTS_NO_SPACE:
					lbl_infobar_location.label = "<span weight=\"bold\">%s</span>".printf(
						message.replace("<","&lt;"));
					infobar_location.message_type = Gtk.MessageType.ERROR;
					infobar_location.no_show_all = false;
					infobar_location.show_all();
					ok = false;
					break;

				case SnapshotLocationStatus.READ_ONLY_FS:
				case SnapshotLocationStatus.HARDLINKS_NOT_SUPPORTED:
					lbl_infobar_location.label = "<span weight=\"bold\">%s</span>".printf(message);
					infobar_location.message_type = Gtk.MessageType.ERROR;
					infobar_location.no_show_all = false;
					infobar_location.show_all();
					ok = false;
					break;

				case SnapshotLocationStatus.NO_BTRFS_SYSTEM:
					lbl_infobar_location.label = "<span weight=\"bold\">%s</span>".printf(details);
					infobar_location.message_type = Gtk.MessageType.ERROR;
					infobar_location.no_show_all = false;
					infobar_location.show_all();
					ok = false;
					break;

				case 3:
				case 0:
					infobar_location.hide();
					// TODO: Show a disk icon with stats when selected device is OK
					break;
			}

		}
		

		return ok;
	}

	private void tv_devices_refresh(){
		
		App.update_partitions();

		var model = new Gtk.TreeStore(4,
			typeof(Device),
			typeof(string),
			typeof(string),
			typeof(bool));
		
		tv_devices.set_model (model);

		TreeIter iter0;

		foreach(var disk in App.partitions) {
			
			if (disk.type != "disk") { continue; }

			model.append(out iter0, null);
			model.set(iter0, 0, disk, -1);
			model.set(iter0, 1, disk.tooltip_text(), -1);
			model.set(iter0, 2, IconManager.ICON_HARDDRIVE, -1);
			model.set(iter0, 3, false, -1);

			tv_append_child_volumes(ref model, ref iter0, disk);
		}

		tv_devices.expand_all();
		tv_devices.columns_autosize();
	}

	private void tv_append_child_volumes(
		ref Gtk.TreeStore model, ref Gtk.TreeIter iter0, Device parent){

		foreach(var part in App.partitions) {

			if (!part.has_linux_filesystem()){ continue; }

			if (App.btrfs_mode){
				if (part.is_encrypted_partition() && (!part.has_children() || (part.children[0].fstype == "btrfs"))){
					//ok
				}
				else if (part.is_lvm_partition() && (!part.has_children() || (part.children[0].fstype == "btrfs"))){
					//ok
				}
				else if (part.fstype == "btrfs"){
					//ok
				}
				else{
					continue;
				}
			}
			
			if (part.pkname == parent.kname) {
				
				TreeIter iter1;
				model.append(out iter1, iter0);
				model.set(iter1, 0, part, -1);
				model.set(iter1, 1, part.tooltip_text(), -1);
				model.set(iter1, 2, (part.fstype == "luks") ? "locked" : IconManager.ICON_HARDDRIVE, -1);
				
				if (parent.fstype == "luks"){
					// change parent's icon to unlocked
					model.set(iter0, 2, "unlocked", -1);
				}

				if ((App.repo.device != null) && (part.uuid == App.repo.device.uuid)){
					model.set(iter1, 3, true, -1);
				}
				else{
					model.set(iter1, 3, false, -1);
				}

				tv_append_child_volumes(ref model, ref iter1, part);
			}
			else if ((part.kname == parent.kname) && (part.type == "disk")
				&& part.has_linux_filesystem() && !part.has_children()){
				
				// partition-less disk with linux filesystem

				// create a dummy partition
				var part2 = new Device();
				part2.copy_fields_from(part);
				part2.type = "part";
				part2.pkname = part.device.replace("/dev/","");
				part2.parent = part;

				TreeIter iter1;
				model.append(out iter1, iter0);
				model.set(iter1, 0, part2, -1);
				model.set(iter1, 1, part2.tooltip_text(), -1);
				model.set(iter1, 2, (part2.fstype == "luks") ? "locked" : IconManager.ICON_HARDDRIVE, -1);
				
				if ((App.repo.device != null) && (part2.uuid == App.repo.device.uuid)){
					model.set(iter1, 3, true, -1);
				}
				else{
					model.set(iter1, 3, false, -1);
				}
			}
		}
	}
}
