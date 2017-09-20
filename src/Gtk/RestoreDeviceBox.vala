
/*
 * RestoreDeviceBox.vala
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

class RestoreDeviceBox : Gtk.Box{

	private Gtk.InfoBar infobar_location;
	private Gtk.Label lbl_infobar_location;
	private Gtk.Box option_box;
	private Gtk.Label lbl_header_subvol;
	private bool show_volume_name = false;
	
	private Gtk.SizeGroup sg_mount_point = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
	private Gtk.SizeGroup sg_device = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
	private Gtk.SizeGroup sg_mount_options = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
	private Gtk.Window parent_window;

	public RestoreDeviceBox (Gtk.Window _parent_window) {

		log_debug("RestoreDeviceBox: RestoreDeviceBox()");
		
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		margin = 12;

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		add(hbox);

		add_label_header(hbox, _("Select Target Device"), true);

		// buffer
		var label = add_label(hbox, "");
        label.hexpand = true;
       
		// refresh device button
		
		Gtk.SizeGroup size_group = null;
		var btn_refresh = add_button(hbox, _("Refresh"), "", ref size_group, null);
        btn_refresh.clicked.connect(()=>{
			App.update_partitions();
			refresh();
		});


		if (App.mirror_system){
			add_label(this,
				_("Select the target devices where system will be cloned."));
		}
		else{
			add_label(this,
				_("Select the devices where files will be restored.") + "\n" +
				_("Devices from which snapshot was created are pre-selected."));
		}

		// headings
		
		hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		hbox.margin_top = 12;
		add(hbox);

		label = add_label(hbox, _("Path") + "  ", true, true);
		label.xalign = (float) 0.0;
		sg_mount_point.add_widget(label);
		
		label = add_label(hbox, _("Device") + "  ", true, true);
		label.xalign = (float) 0.0;
		sg_device.add_widget(label);

		label = add_label(hbox, _("Volume"), true, true);
		label.xalign = (float) 0.5;
		label.set_no_show_all(true);
		lbl_header_subvol = label;

		// options
		
		option_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		add(option_box);

		// bootloader
		
		add_boot_options();

		// infobar
		
		create_infobar_location();

		log_debug("RestoreDeviceBox: RestoreDeviceBox(): exit");
    }

    public void refresh(bool reset_device_selections = true){
		log_debug("RestoreDeviceBox: refresh()");
		App.update_partitions();
		create_device_selection_options(reset_device_selections);
		App.init_boot_options();
		log_debug("RestoreDeviceBox: refresh(): exit");
	}

	private void create_device_selection_options(bool reset_device_selections){
		
		if (reset_device_selections){
			App.init_mount_list();
		}

		show_volume_name = false;
		foreach(var entry in App.mount_list){
			if ((entry.device != null) && ((entry.subvolume_name().length > 0) || (entry.lvm_name().length > 0))){
				// subvolumes are used - show the mount options column
				show_volume_name = true;
				break;
			}
		}

		if (show_volume_name){
			lbl_header_subvol.set_no_show_all(false);
		}
		lbl_header_subvol.visible = show_volume_name;

		foreach(var item in option_box.get_children()){
			option_box.remove(item);
		}

		foreach(MountEntry entry in App.mount_list){
			add_device_selection_option(entry);
		}

		show_all();
	}

	private void add_device_selection_option(MountEntry entry){
		var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		option_box.add(box);

		var label = add_label(box, entry.mount_point, true);
		sg_mount_point.add_widget(label);
		
		var combo = add_device_combo(box, entry);
		sg_device.add_widget(combo);

		if (show_volume_name){
			string txt = "";
			if (entry.subvolume_name().length > 0){
				txt = "%s".printf(entry.subvolume_name());
			}
			else {
				txt = "%s".printf(entry.lvm_name());
			}
			label = add_label(box, txt, false);
			sg_mount_options.add_widget(label);
		}
	}

	private Gtk.ComboBox add_device_combo(Gtk.Box box, MountEntry entry){

		var combo = new Gtk.ComboBox();
		box.add(combo);

		var cell_pix = new Gtk.CellRendererPixbuf();
		combo.pack_start (cell_pix, false);

		combo.set_cell_data_func (cell_pix, (cell_layout, cell, model, iter)=>{
			Device dev;
			//bool selected = combo.get_active_iter (out iter);
			//if (!selected) { return; }
			combo.model.get (iter, 0, out dev, -1);

			if (dev != null){

				if (dev.type == "disk"){
					(cell as Gtk.CellRendererPixbuf).pixbuf =
						get_shared_icon_pixbuf("drive-harddisk", "drive-harddisk", 16);
				}
			
				(cell as Gtk.CellRendererPixbuf).sensitive = (dev.type != "disk");
				(cell as Gtk.CellRendererPixbuf).visible = (dev.type == "disk");
			}
		});

		var cell_text = new Gtk.CellRendererText();
		cell_text.xalign = (float) 0.0;
		combo.pack_start (cell_text, false);

		combo.has_tooltip = true;
		combo.query_tooltip.connect((x, y, keyboard_tooltip, tooltip) => {
			Device dev;
			TreeIter iter;
			bool selected = combo.get_active_iter (out iter);
			if (!selected) { return true; }
			combo.model.get (iter, 0, out dev, -1);
			
			tooltip.set_icon(get_shared_icon_pixbuf("drive-harddisk", "drive-harddisk", 128));
			if (dev != null){
				tooltip.set_markup(dev.tooltip_text());
			}
			else{
				tooltip.set_markup(_("Keep this mount path on the root filesystem"));
			}
			
			return true;
		});

		combo.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
			Device dev;
			model.get (iter, 0, out dev, -1);

			if (dev != null){
				(cell as Gtk.CellRendererText).markup = dev.description_simple_formatted();
				(cell as Gtk.CellRendererText).sensitive = (dev.type != "disk");
			}
			else{
				(cell as Gtk.CellRendererText).markup = _("Keep on Root Device");
			}
		});
		
		// populate combo
		var model = new Gtk.ListStore(2, typeof(Device), typeof(MountEntry));
		combo.model = model;
		
		var active = -1;
		var index = -1;
		TreeIter iter;

		if (entry.mount_point != "/"){
			index++;
			model.append(out iter);
			model.set (iter, 0, null);
			model.set (iter, 1, entry);
		}
		
		foreach(var dev in App.partitions){
			// skip disk and loop devices
			//if ((dev.type == "disk")||(dev.type == "loop")){
			//	continue;
			//}

			if ((dev.type == "loop") || (dev.fstype == "iso9660")){
				continue;
			}

			if (dev.type != "disk"){

				// display only linux filesystem for / and /home
				if ((entry.mount_point == "/") || (entry.mount_point == "/home")){
					if (!dev.has_linux_filesystem()){
						continue;
					}
				}

				if (dev.has_children()){
					continue; // skip parent partitions of unlocked volumes (luks)
				}
			}
			
			index++;
			model.append(out iter);
			model.set (iter, 0, dev);
			model.set (iter, 1, entry);
		
			if (entry.device != null){
				if (dev.uuid == entry.device.uuid){
					active = index;
				}
				else if (dev.has_parent() && (dev.parent.uuid == entry.device.uuid)){
					active = index;
				}
				else if (dev.has_children() && (dev.children[0].uuid == entry.device.uuid)){
					// this will not occur since we are skipping parent devices in this loop
					active = index;
				}
			}
		}

		if ((active == -1) && (entry.mount_point != "/")){
			active = 0; // keep on root device
		}

		combo.active = active;
		
		combo.changed.connect((path) => {

			Device current_dev;
			MountEntry current_entry;
			
			TreeIter iter_active;
			bool selected = combo.get_active_iter (out iter_active);
			if (!selected){
				log_debug("device combo: active is -1");
				return;
			}

			TreeIter iter_combo;
			var store = (Gtk.ListStore) combo.model;
			store.get(iter_active, 0, out current_dev, 1, out current_entry, -1);

			if (current_dev.is_encrypted_partition()){

				log_debug("add_device_combo().changed: unlocking encrypted device..");
				
				string msg_out, msg_err;
				var luks_unlocked = Device.luks_unlock(
					current_dev, "", "", parent_window, out msg_out, out msg_err);

				if (luks_unlocked == null){

					log_debug("add_device_combo().changed: failed to unlock");
					
					// reset the selection
					
					if (current_entry.mount_point == "/"){

						// reset to default device
						
						index = -1;
						for (bool next = store.get_iter_first (out iter_combo); next;
							next = store.iter_next (ref iter_combo)) {

							Device dev_iter;
							store.get(iter_combo, 0, out dev_iter, -1);
							index++;
							
							if ((dev_iter != null) && (dev_iter.device == current_entry.device.device)){
								combo.active = index;
							}
						}
					}
					else{
						combo.active = 0; // keep on root device
					}
					
					return;
				}
				else{

					log_debug("add_device_combo().changed: unlocked");
					
					// update current entry
					
					if (current_entry.mount_point == "/"){
						App.dst_root = luks_unlocked;
						App.init_boot_options();
					}

					current_entry.device = luks_unlocked;

					// refresh devices

					refresh(false); // do not reset selections
					return; // no need to continue
				}
			}

			current_entry.device = current_dev;
			
			if (current_entry.mount_point == "/"){
				App.init_boot_options();
			}
		});

		return combo;
	}

	private void add_boot_options(){

		// buffer
		var label = new Gtk.Label("");
		label.vexpand = true;
		add(label);
		
		var hbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
		hbox.margin_bottom = 24;
        add(hbox);

		Gtk.SizeGroup size_group = null;
		
		// close
		
		//var img = new Image.from_stock("gtk-dialog-warning", Gtk.IconSize.BUTTON);
		var button = add_button(hbox, _("Bootloader Options (Advanced)"), "", ref size_group, null);
		button.set_size_request(300, 40);
		button.set_tooltip_text(_("[Advanced Users Only] Change these settings only if the restored system fails to boot."));
		var btn_boot_options = button;
		//hbox.set_child_packing(btn_boot_options, false, true, 6, Gtk.PackType.END);
		
        btn_boot_options.clicked.connect(()=>{
			var win = new BootOptionsWindow();
			win.set_transient_for(parent_window);
			//win.destroy.connect(()=>{
				
			//});;
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

	public bool check_and_mount_devices(){

		// check if we are restoring the current system
		
		if (App.dst_root == App.sys_root){
			return true; // all required devices are already mounted
		}
		
		// check if target device is selected for /
		
		foreach(var entry in App.mount_list){
			if ((entry.mount_point == "/") && (entry.device == null)){
				
				gtk_messagebox(
					_("Root device not selected"),
					_("Select the device for root file system (/)"),
					parent_window, true);
				
				return false;
			}
		}

		// verify that target device for / is not same as system in clone mode
		
		if (App.mirror_system){

			foreach(var entry in App.mount_list){
				if (entry.mount_point != "/"){ continue; }

				bool same = false;
				if (entry.device.uuid == App.sys_root.uuid){
					same = true;
				}
				else if (entry.device.has_parent() && App.sys_root.has_parent()){
					if (entry.device.uuid == App.sys_root.parent.uuid){
						same = true;
					}
				}
				
				if (same){
					
					gtk_messagebox(
						_("Target device is same as system device"),
						_("Select another device for root file system (/)"),
						parent_window, true);
						
					return false;
				}

				break;
			}
		}

		// check if /boot device is selected for luks partitions
		
		foreach(var entry in App.mount_list){
			if ((entry.mount_point == "/boot") && (entry.device == null)){

				if ((App.dst_root != null) && (App.dst_root.is_on_encrypted_partition())){

					gtk_messagebox(
						_("Boot device not selected"),
						_("An encrypted device is selected for root file system (/). The boot directory (/boot) must be mounted on a non-encrypted device for the system to boot successfully.\n\nEither select a non-encrypted device for boot directory or select a non-encrypted device for root filesystem."),
						parent_window, true);

					return false;
				}
			}
		}

		
		
		//check if grub device selected ---------------

		if (App.reinstall_grub2 && (App.grub_device.length == 0)){
			string title =_("GRUB device not selected");
			string msg = _("Please select the GRUB device");
			gtk_messagebox(title, msg, parent_window, true);
			return false;
		}

		// check BTRFS subvolume layout --------------

		bool supported = App.check_btrfs_layout(App.dst_root, App.dst_home, false);
		
		if (!supported){
			var title = _("Unsupported Subvolume Layout")
				+ " (%s)".printf(App.dst_root.device);
			var msg = _("Partition has an unsupported subvolume layout.") + " ";
			msg += _("Only ubuntu-type layouts with @ and @home subvolumes are currently supported.") + "\n\n";
			gtk_messagebox(title, msg, parent_window, true);
			return false;
		}

		// mount target device -------------

		bool status = App.mount_target_devices(parent_window);
		if (status == false){
			string title = _("Error");
			string msg = _("Failed to mount devices");
			gtk_messagebox(title, msg, parent_window, true);
			return false;
		}

		return true;
	}
}
