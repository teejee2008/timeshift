
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
	private Gtk.ComboBox cmb_grub_dev;
	private Gtk.CheckButton chk_skip_grub_install;
	private bool show_subvolume = false;
	
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
		
		Gtk.Image img = new Image.from_stock("gtk-refresh", Gtk.IconSize.BUTTON);
		Gtk.SizeGroup size_group = null;
		var btn_refresh = add_button(hbox, _("Refresh"), "", ref size_group, img);
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

		label = add_label(hbox, _("Mount Path") + "  ", true, true);
		label.xalign = (float) 0.0;
		sg_mount_point.add_widget(label);
		
		label = add_label(hbox, _("Device") + "  ", true, true);
		label.xalign = (float) 0.0;
		sg_device.add_widget(label);

		label = add_label(hbox, _("Subvolume"), true, true);
		label.xalign = (float) 0.5;
		label.set_no_show_all(true);
		lbl_header_subvol = label;

		// options
		
		option_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		add(option_box);

		// bootloader

		add_bootloader_options();

		// infobar
		
		create_infobar_location();

		log_debug("RestoreDeviceBox: RestoreDeviceBox(): exit");
    }

    public void refresh(bool reset_device_selections = true){
		log_debug("RestoreDeviceBox: refresh()");
		create_device_selection_options(reset_device_selections);
		refresh_cmb_grub_dev();
		log_debug("RestoreDeviceBox: refresh(): exit");
	}

	private void create_device_selection_options(bool reset_device_selections){

		if (reset_device_selections){
			App.init_mount_list();
		}

		show_subvolume = false;
		foreach(var entry in App.mount_list){
			if ((entry.device != null) && (entry.subvolume_name().length > 0)){
				// subvolumes are used - show the mount options column
				show_subvolume = true;
				break;
			}
		}

		if (show_subvolume){
			lbl_header_subvol.set_no_show_all(false);
		}
		lbl_header_subvol.visible = show_subvolume;

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

		if (show_subvolume){
			string txt = "";
			if (entry.subvolume_name().length > 0){
				txt = "%s".printf(entry.subvolume_name());
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

			if (dev.type == "loop"){
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

			if ((entry.device != null) && (dev.uuid == entry.device.uuid)){
				active = index;
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
						cmb_grub_dev_select_default();
					}

					current_entry.device = luks_unlocked;

					// refresh devices
					
					App.update_partitions();
					refresh(false); // do not reset selections
					return; // no need to continue
				}

				/*index = -1;

				for (bool next = store.get_iter_first (out iter_combo); next;
					next = store.iter_next (ref iter_combo)) {

					Device dev_iter;
					store.get(iter_combo, 0, out dev_iter, -1);

					index++;
					
					if ((dev_iter != null) && (dev_iter.device == luks_unlocked.device)){
						combo.active = index;
						return;
					}
				}*/
			}

			if (current_entry.mount_point == "/"){
				App.dst_root = current_dev;
				cmb_grub_dev_select_default();
			}

			current_entry.device = current_dev;
		});

		return combo;
	}

	private void add_bootloader_options(){

		//lbl_header_bootloader
		var label = add_label_header(this, _("Select GRUB Device"), true);
		label.margin_top = 24;
		
		add_label(this, _("Select device for installing GRUB2 bootloader:"));
		
		var hbox_grub = new Box (Orientation.HORIZONTAL, 6);
        add (hbox_grub);

		//cmb_grub_dev
		cmb_grub_dev = new ComboBox ();
		cmb_grub_dev.hexpand = true;
		hbox_grub.add(cmb_grub_dev);

		var cell_text = new CellRendererText ();
		cell_text.text = "";
		cmb_grub_dev.pack_start(cell_text, false);

		cell_text = new CellRendererText();
        cmb_grub_dev.pack_start(cell_text, false);

        cmb_grub_dev.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
			Device dev;
			model.get (iter, 0, out dev, -1);

			if (dev.type == "disk"){
				//log_msg("desc:" + dev.description());
				(cell as Gtk.CellRendererText).markup =
					"<b>%s (MBR)</b>".printf(dev.description_formatted());
			}
			else{
				(cell as Gtk.CellRendererText).text = dev.description();
			}
		});

		cmb_grub_dev.changed.connect(()=>{
			save_grub_device_selection();
		});

		string tt = "<b>" + _("** Advanced Users **") + "</b>\n\n"+ _("Skips bootloader (re)installation on target device.\nFiles in /boot directory on target partition will remain untouched.\n\nIf you are restoring a system that was bootable previously then it should boot successfully. Otherwise the system may fail to boot.");

		//chk_skip_grub_install
		var chk = new CheckButton.with_label(
			_("Skip bootloader installation"));
		chk.active = false;
		chk.set_tooltip_markup(tt);
		chk.margin_bottom = 12;
		add (chk);
		chk_skip_grub_install = chk;

		if (App.mirror_system){
			// bootloader must be re-installed
			chk_skip_grub_install.active = false;
			chk.sensitive = false;
		}
		else{
			if (App.snapshot_to_restore.distro.dist_id == "fedora"){
				chk_skip_grub_install.active = true;
				chk.sensitive = false;
			}
			else{
				chk_skip_grub_install.active = false;
			}
		}
		
		chk.toggled.connect(()=>{
			cmb_grub_dev.sensitive = !chk_skip_grub_install.active;
			App.reinstall_grub2 = !chk_skip_grub_install.active;
			cmb_grub_dev.changed();
		});
		
		App.reinstall_grub2 = !chk_skip_grub_install.active;
	}

	private void save_grub_device_selection(){
		
		App.grub_device = "";
		
		if (App.reinstall_grub2){
			Device entry;
			TreeIter iter;
			bool ok = cmb_grub_dev.get_active_iter (out iter);
			if (!ok) { return; } // not selected
			TreeModel model = (TreeModel) cmb_grub_dev.model;
			model.get(iter, 0, out entry);
			App.grub_device = entry.device;
		}
	}

	private void refresh_cmb_grub_dev(){
		var store = new Gtk.ListStore(2, typeof(Device), typeof(Gdk.Pixbuf));

		Gdk.Pixbuf pix_device = get_shared_icon("drive-harddisk","disk.png",16).pixbuf;

		TreeIter iter;
		foreach(Device dev in Device.get_block_devices_using_lsblk()) {
			
			// select disk and normal partitions, skip others (loop crypt rom lvm)
			if ((dev.type != "disk") && (dev.type != "part")){
				continue;
			}

			// skip luks and lvm2 partitions
			if ((dev.fstype == "luks")||(dev.fstype == "lvm2")){
				continue;
			}

			// skip extended partitions
			if (dev.size_bytes < 10 * KB){
				continue;
			}

			store.append(out iter);
			store.set (iter, 0, dev);
			store.set (iter, 1, pix_device);
		}

		cmb_grub_dev.model = store;

		cmb_grub_dev_select_default();
	}

	private void cmb_grub_dev_select_default(){

		log_debug("RestoreDeviceBox: cmb_grub_dev_select_default()");
		
		if (App.dst_root == null){
			cmb_grub_dev.active = -1;
			return;
		}

		var grub_dev = App.dst_root;
		while (grub_dev.has_parent()){
			grub_dev = grub_dev.parent;
		}

		if ((grub_dev == null) || (grub_dev.type != "disk")){
			cmb_grub_dev.active = -1;
			return;
		}

		TreeIter iter;
		var store = (Gtk.ListStore) cmb_grub_dev.model;
		int index = -1;
		int active = -1;
		
		for (bool next = store.get_iter_first (out iter); next; next = store.iter_next (ref iter)) {
			
			Device dev_iter;
			store.get(iter, 0, out dev_iter);
			
			index++;
			
			if (dev_iter.device == grub_dev.device){
				active = index;
				break;
			}
		}

		cmb_grub_dev.active = active;

		log_debug("RestoreDeviceBox: cmb_grub_dev_select_default(): exit");
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

		// check if all partitions are selected
		
		foreach(var entry in App.mount_list){
			if (entry.device == null){
				string title = _("Partition Not Selected");
				string msg = _("Select the partition for mount path")
					+ " '%s'".printf(entry.mount_point);
				gtk_messagebox(title, msg, parent_window, true);
				return false;
			}
		}

		// TODO: check on next

		//check if grub device selected ---------------

		if (!chk_skip_grub_install.active && cmb_grub_dev.active < 0){
			string title =_("GRUB device not selected");
			string msg = _("Please select the GRUB device");
			gtk_messagebox(title, msg, parent_window, true);
			return false;
		}

		// check if we are restoring the current system
		
		if (App.dst_root == App.sys_root){
			return true; // all required devices are already mounted
		}

		// check BTRFS subvolume layout --------------

		bool supported = App.check_btrfs_layout(App.dst_root, App.dst_home);
		
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
