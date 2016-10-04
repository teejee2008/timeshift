
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
	private Gtk.ComboBox cmb_boot_device;
	private Gtk.CheckButton chk_skip_grub_install;
	private bool show_subvolume = false;
	
	private Gtk.SizeGroup sg_mount_point = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
	private Gtk.SizeGroup sg_device = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
	private Gtk.SizeGroup sg_mount_options = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
	private Gtk.Window parent_window;

	public RestoreDeviceBox (Gtk.Window _parent_window) {
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		margin = 12;

		log_debug("RestoreDeviceBox: RestoreDeviceBox()");

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

		show_subvolume = false;
		foreach(var entry in App.mount_list){
			if ((entry.device != null) && (entry.subvolume_name().length > 0)){
				// subvolumes are used - show the mount options column
				show_subvolume = true;
				break;
			}
		}
		
		// headings
		
		hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		hbox.margin_top = 12;
		add(hbox);

		label = add_label(hbox, _("Mount Path") + " ", true, true);
		label.xalign = (float) 0.0;
		sg_mount_point.add_widget(label);
		
		label = add_label(hbox, _("Device"), true, true);
		label.xalign = (float) 0.0;
		sg_device.add_widget(label);

		if (show_subvolume){
			label = add_label(hbox, _("Subvolume"), true, true);
			label.xalign = (float) 0.5;
		}
		
		// options
		
		option_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		add(option_box);

		// bootloader

		add_bootloader_options();

		// infobar
		
		create_infobar_location();

		log_debug("RestoreDeviceBox: RestoreDeviceBox(): exit");
    }

    public void refresh(){
		log_debug("RestoreDeviceBox: refresh()");
		create_device_selection_options();
		refresh_cmb_boot_device();
		log_debug("RestoreDeviceBox: refresh(): exit");
	}

	private void create_device_selection_options(){
		App.init_mount_list();

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

		var cell_text = new Gtk.CellRendererText();
		cell_text.xalign = (float) 0.0;
		combo.pack_start (cell_text, false);

		combo.has_tooltip = true;
		combo.query_tooltip.connect((x, y, keyboard_tooltip, tooltip) => {
			Device dev;
			TreeIter iter;
			bool ok = combo.get_active_iter (out iter);

			if (!ok) { return true; }
			
			combo.model.get (iter, 0, out dev, -1);
			
			//tooltip.set_icon(get_shared_icon_pixbuf("drive-harddisk", "drive-harddisk", 256));
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
				(cell as Gtk.CellRendererText).markup = dev.description_formatted();
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
			if ((dev.type == "disk")||(dev.type == "loop")){
				continue;
			}

			// display only linux filesystem for / and /home
			if ((entry.mount_point == "/") || (entry.mount_point == "/home")){
				if (!dev.has_linux_filesystem()){
					continue;
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

		// TODO: Remove luks device from dropdown after unlock

		// TODO: Show a disabled header for the disk model

		combo.changed.connect((path) => {

			Device current_dev;
			MountEntry current_entry;
			
			TreeIter iter_active;
			bool selected = combo.get_active_iter (out iter_active);
			if (!selected){
				return;
			}

			TreeIter iter_combo;
			var store = (Gtk.ListStore) combo.model;
			store.get(iter_active, 0, out current_dev, 1, out current_entry, -1);

			if (current_dev.is_encrypted_partition()){

				string msg_out, msg_err;
				var luks_unlocked = Device.luks_unlock(
					current_dev, "", "", parent_window, out msg_out, out msg_err);

				if (luks_unlocked == null){
					
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

				index = -1;

				for (bool next = store.get_iter_first (out iter_combo); next;
					next = store.iter_next (ref iter_combo)) {

					Device dev_iter;
					store.get(iter_combo, 0, out dev_iter, -1);

					index++;
					
					if ((dev_iter != null) && (dev_iter.device == luks_unlocked.device)){
						combo.active = index;
						return;
					}
				}
			}

			if (current_entry.mount_point == "/"){
				App.restore_target = current_dev;
				cmb_boot_device_select_default();
			}

			current_entry.device = current_dev;
		});

		return combo;
	}

	private void add_bootloader_options(){

		//lbl_header_bootloader
		var label = add_label_header(this, _("Select Boot Device"), true);
		label.margin_top = 12;
		
		add_label(this, _("Select device for installing GRUB2 bootloader:"));
		
		var hbox_grub = new Box (Orientation.HORIZONTAL, 6);
        add (hbox_grub);

		//cmb_boot_device
		cmb_boot_device = new ComboBox ();
		cmb_boot_device.hexpand = true;
		hbox_grub.add(cmb_boot_device);

		var cell_text = new CellRendererText ();
		cell_text.text = "";
		cmb_boot_device.pack_start(cell_text, false);

		cell_text = new CellRendererText();
        cmb_boot_device.pack_start(cell_text, false);

        cmb_boot_device.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
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

		cmb_boot_device.changed.connect(()=>{
			save_grub_device_selection();
		});

		string tt = "<b>" + _("** Advanced Users **") + "</b>\n\n"+ _("Skips bootloader (re)installation on target device.\nFiles in /boot directory on target partition will remain untouched.\n\nIf you are restoring a system that was bootable previously then it should boot successfully. Otherwise the system may fail to boot.");

		//chk_skip_grub_install
		var chk = new CheckButton.with_label(
			_("Skip bootloader installation (not recommended)"));
		chk.active = false;
		chk.set_tooltip_markup(tt);
		chk.margin_bottom = 12;
		add (chk);
		chk_skip_grub_install = chk;

		// bootloader must be re-installed for cloning device 
		chk.sensitive = !App.mirror_system;
		
		chk.toggled.connect(()=>{
			cmb_boot_device.sensitive = !chk_skip_grub_install.active;
			App.reinstall_grub2 = !chk_skip_grub_install.active;
			cmb_boot_device.changed();
		});
		
		App.reinstall_grub2 = !chk_skip_grub_install.active;
	}

	private void save_grub_device_selection(){
		
		App.grub_device = "";
		
		if (App.reinstall_grub2){
			Device entry;
			TreeIter iter;
			bool ok = cmb_boot_device.get_active_iter (out iter);
			if (!ok) { return; } // not selected
			TreeModel model = (TreeModel) cmb_boot_device.model;
			model.get(iter, 0, out entry);
			App.grub_device = entry.device;
		}
	}

	private void refresh_cmb_boot_device(){
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

		cmb_boot_device.model = store;

		cmb_boot_device_select_default();
	}

	private void cmb_boot_device_select_default(){

		log_debug("RestoreDeviceBox: cmb_boot_device_select_default()");
		
		if (App.restore_target == null){
			cmb_boot_device.active = -1;
			return;
		}

		var grub_dev = App.restore_target;
		while (grub_dev.has_parent()){
			grub_dev = grub_dev.parent;
		}

		if ((grub_dev == null) || (grub_dev.type != "disk")){
			cmb_boot_device.active = -1;
			return;
		}

		TreeIter iter;
		var store = (Gtk.ListStore) cmb_boot_device.model;
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

		cmb_boot_device.active = active;

		log_debug("RestoreDeviceBox: cmb_boot_device_select_default(): exit");
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

		if (!chk_skip_grub_install.active && cmb_boot_device.active < 0){
			string title =_("Boot device not selected");
			string msg = _("Please select the boot device");
			gtk_messagebox(title, msg, parent_window, true);
			return false;
		}

		// get root partition
		
		App.restore_target = null;
		
		foreach(var entry in App.mount_list){
			if (entry.mount_point == "/"){
				App.restore_target = entry.device;
				break;
			}
		}

		// check if we are restoring the current system
		
		if (App.restore_target == App.root_device){
			return true; // all required devices are already mounted
		}

		// check BTRFS subvolume layout --------------

		if (App.restore_target.type == "btrfs"){
			if (App.check_btrfs_volume(App.restore_target) == false){
				var title = _("Unsupported Subvolume Layout")
					+ " (%s)".printf(App.restore_target.device);
				var msg = _("Partition has an unsupported subvolume layout.") + " ";
				msg += _("Only ubuntu-type layouts with @ and @home subvolumes are currently supported.") + "\n\n";
				gtk_messagebox(title, msg, parent_window, true);
				return false;
			}
		}

		// mount target device -------------

		bool status = App.mount_target_device(parent_window);
		if (status == false){
			string title = _("Error");
			string msg = _("Failed to mount device") + ": %s".printf(App.restore_target.device);
			gtk_messagebox(title, msg, parent_window, true);
			return false;
		}

		return true;
	}
}
