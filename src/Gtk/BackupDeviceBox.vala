
/*
 * BackupBox.vala
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

class BackupDeviceBox : Gtk.Box{

	private Gtk.TreeView tv_devices;
	private Gtk.InfoBar infobar_location;
	private Gtk.Label lbl_infobar_location;
	
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
		
		Gtk.Image img = new Image.from_stock("gtk-refresh", Gtk.IconSize.BUTTON);
		Gtk.SizeGroup size_group = null;
		var btn_refresh = add_button(hbox, _("Refresh"), "", ref size_group, img);
        btn_refresh.clicked.connect(()=>{
			App.update_partitions();
			tv_devices_refresh();
		});

		// TODO: show this message somewhere
		
		//var msg = _("Only Linux partitions are supported.");
		//msg += "\n" + _("Snapshots will be saved in folder /timeshift");

		// treeview
		create_device_list();

		// tooltips
		//tv_devices.set_tooltip_text(msg);

		// infobar
		create_infobar_location();

		log_debug("BackupDeviceBox: BackupDeviceBox(): exit");
    }

    public void refresh(){
		tv_devices_refresh();
		check_backup_location();
	}

    
	private void create_device_list(){
		tv_devices = add_treeview(this);
		tv_devices.vexpand = true;
		tv_devices.headers_clickable = true;
		tv_devices.rules_hint = true;
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
			Gdk.Pixbuf pix = null;
			model.get (iter, 2, out pix, -1);

			Device dev;
			model.get (iter, 0, out dev, -1);

			(cell as Gtk.CellRendererPixbuf).pixbuf = pix;
			(cell as Gtk.CellRendererPixbuf).visible = (dev.type == "disk");
			
		});

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

	private void create_infobar_location(){
		var infobar = new Gtk.InfoBar();
		infobar.no_show_all = true;
		add(infobar);
		infobar_location = infobar;
		
		var content = (Gtk.Box) infobar.get_content_area ();
		var label = add_label(content, "");
		lbl_infobar_location = label;
	}


	private void try_change_device(Device dev){

		log_debug("try_change_device: %s".printf(dev.device));
		
		if (dev.type == "disk"){
			bool found_child = false;
			foreach (var child in dev.children){
				if (child.has_linux_filesystem()){
					change_backup_device(child);
					found_child = true;
					break;
				}
			}
			if (!found_child){
				lbl_infobar_location.label = "<span weight=\"bold\">%s</span>".printf(
				_("Selected disk does not have Linux partitions"));
				infobar_location.message_type = Gtk.MessageType.ERROR;
				infobar_location.no_show_all = false;
				infobar_location.show_all();
			}
		}
		else if (dev.has_children()){
			change_backup_device(dev.children[0]);
		}
		else if (!dev.has_children()){
			change_backup_device(dev);
		}
		else {
			lbl_infobar_location.label = "<span weight=\"bold\">%s</span>".printf(
				_("Select a partition on this disk"));
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
		log_debug("selected device: %s".printf(pi.device));
		log_debug("fstype: %s".printf(pi.fstype));

		App.repo = new SnapshotRepo.from_device(pi, parent_window);

		if (pi.fstype == "luks"){
			App.update_partitions();

			var dev = Device.find_device_in_list_by_uuid(App.partitions, pi.uuid);
			
			if (dev.has_children()){
				
				log_debug("has children");
				
				if (dev.children[0].has_linux_filesystem()){
					
					log_debug("has linux filesystem: %s".printf(dev.children[0].fstype));
					log_debug("selecting child '%s' of parent '%s'".printf(
						dev.children[0].device, dev.device));
						
					App.repo = new SnapshotRepo.from_device(dev.children[0], parent_window);
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
		string message, details;
		int status_code = App.check_backup_location(out message, out details);
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
			typeof(Gdk.Pixbuf),
			typeof(bool));
		
		tv_devices.set_model (model);

		Gdk.Pixbuf pix_device = get_shared_icon("disk","disk.png",16).pixbuf;

		TreeIter iter0;

		foreach(var disk in App.partitions) {
			if (disk.type != "disk") { continue; }

			model.append(out iter0, null);
			model.set(iter0, 0, disk, -1);
			model.set(iter0, 1, disk.tooltip_text(), -1);
			model.set(iter0, 2, pix_device, -1);
			model.set(iter0, 3, false, -1);

			tv_append_child_volumes(ref model, ref iter0, disk);
		}

		tv_devices.expand_all();
		tv_devices.columns_autosize();
	}

	private void tv_append_child_volumes(
		ref Gtk.TreeStore model, ref Gtk.TreeIter iter0, Device parent){
			
		Gdk.Pixbuf pix_device = get_shared_icon("disk","disk.png",16).pixbuf;
		Gdk.Pixbuf pix_locked = get_shared_icon("locked","locked.png",16).pixbuf;
		Gdk.Pixbuf pix_unlocked = get_shared_icon("unlocked","unlocked.png",16).pixbuf;
		
		foreach(var part in App.partitions) {

			if (!part.has_linux_filesystem()){ continue; }
			
			if (part.pkname == parent.kname) {
				TreeIter iter1;
				model.append(out iter1, iter0);
				model.set(iter1, 0, part, -1);
				model.set(iter1, 1, part.tooltip_text(), -1);
				model.set(iter1, 2, (part.fstype == "luks") ? pix_locked : pix_device, -1);
				
				if (parent.fstype == "luks"){
					// change parent's icon to unlocked
					model.set(iter0, 2, pix_unlocked, -1);
				}

				if ((App.repo.device != null) && (part.uuid == App.repo.device.uuid)){
					model.set(iter1, 3, true, -1);
				}
				else{
					model.set(iter1, 3, false, -1);
				}

				tv_append_child_volumes(ref model, ref iter1, part);
			}
		}
	}

}
