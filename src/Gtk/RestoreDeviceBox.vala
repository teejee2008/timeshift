
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
using TeeJee.Devices;
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

		add_label(this, _("Select the partitions where files will be restored.") + "\n"
			+ _("Partitions from which snapshot was created are pre-selected."));


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
		label.xalign = (float) 0.5;
		sg_mount_point.add_widget(label);
		
		label = add_label(hbox, _("Device"), true, true);
		label.xalign = (float) 0.5;
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
    }

    public void refresh(){
		create_device_selection_options();
		refresh_cmb_boot_device();
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
			combo.get_active_iter (out iter);
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
		
		var active = 0;
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

		combo.active = active;

		combo.changed.connect((path) => {
			Device current_dev;
			MountEntry current_entry;
			TreeIter iter_active;
			combo.get_active_iter (out iter_active);
			combo.model.get(iter_active, 0, out current_dev, 1, out current_entry, -1);

			current_entry.device = current_dev;
		});

		return combo;
	}

	private void add_bootloader_options(){

		//var label = add_label(this, "");
		//label.vexpand = true;
		
		//lbl_header_bootloader
		var label = add_label_header(this, _("Select Boot Device"), true);
		label.margin_top = 48;
		
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

		//var cell_icon = new CellRendererPixbuf ();
		//cell_icon.xpad = 4;
		//cmb_boot_device.pack_start(cell_icon, false);

		cell_text = new CellRendererText();
        cmb_boot_device.pack_start(cell_text, false);

		/*cmb_boot_device.set_cell_data_func(cell_icon, (cell_layout, cell, model, iter)=>{
			Device dev;
			model.get (iter, 0, out dev, -1);

			Gdk.Pixbuf pix = null;
			model.get (iter, 1, out pix, -1);

			//(cell as Gtk.CellRendererPixbuf).pixbuf = pix;
			(cell as Gtk.CellRendererPixbuf).visible = (dev.type == "disk");
		});*/
		
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

		string tt = "<b>" + _("** Advanced Users **") + "</b>\n\n"+ _("Skips bootloader (re)installation on target device.\nFiles in /boot directory on target partition will remain untouched.\n\nIf you are restoring a system that was bootable previously then it should boot successfully.\nOtherwise the system may fail to boot.");

		//chk_skip_grub_install
		chk_skip_grub_install = new CheckButton.with_label(
			_("Skip bootloader installation (not recommended)"));
		chk_skip_grub_install.active = false;
		chk_skip_grub_install.set_tooltip_markup(tt);
		chk_skip_grub_install.margin_bottom = 12;
		add (chk_skip_grub_install);

		chk_skip_grub_install.toggled.connect(()=>{
			cmb_boot_device.sensitive = !chk_skip_grub_install.active;
		});
	}

	private void refresh_cmb_boot_device(){
		var store = new Gtk.ListStore(2, typeof(Device), typeof(Gdk.Pixbuf));

		Gdk.Pixbuf pix_device = get_shared_icon("drive-harddisk","disk.png",16).pixbuf;
		
		TreeIter iter;
		foreach(Device dev in Device.get_block_devices_using_lsblk()) {
			// select disk and normal partitions, skip others (loop and crypt)
			if ((dev.type != "disk") && (dev.type != "part")){
				continue;
			}

			// skip luks partitions
			if (dev.fstype == "luks"){
				continue;
			}
			
			store.append(out iter);
			store.set (iter, 0, dev);
			store.set (iter, 1, pix_device);
		}

		cmb_boot_device.set_model (store);
		cmb_boot_device_select_default();
	}

	private void cmb_boot_device_select_default(){
		if (App.restore_target == null){
			cmb_boot_device.active = -1;
			return;
		}

		TreeIter iter;
		var store = (Gtk.ListStore) cmb_boot_device.model;
		int index = -1;

		int first_mbr_device_index = -1;
		for (bool next = store.get_iter_first (out iter); next; next = store.iter_next (ref iter)) {
			Device dev;
			store.get(iter, 0, out dev);

			index++;

			if (dev.device == App.restore_target.device[0:8]){
				cmb_boot_device.active = index;
				break;
			}

			if (dev.has_parent() && (dev.parent.device == App.restore_target.device[0:8])){
				cmb_boot_device.active = index;
				break;
			}

			if ((first_mbr_device_index == -1) && (dev.device.length == "/dev/sdX".length)){
				first_mbr_device_index = index;
			}
		}

		//select first MBR device if not found
		if (cmb_boot_device.active == -1){
			cmb_boot_device.active = first_mbr_device_index;
		}
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

		


		/*
		TreeIter iter;
		Gtk.ListStore store;
		TreeSelection sel;
			
		//check if target device selected ---------------
		
		if (radio_sys.active){
			//we are restoring the current system - no need to mount devices
			App.restore_target = App.root_device;
			return true;
		}
		else{
			//we are restoring to another disk - mount selected devices

			App.restore_target = null;
			App.mount_list.clear();
			bool no_mount_points_set_by_user = true;

			//find the root mount point set by user
			store = (Gtk.ListStore) tv_partitions.model;
			for (bool next = store.get_iter_first (out iter); next; next = store.iter_next (ref iter)) {
				Device pi;
				string mount_point;
				store.get(iter, 0, out pi);
				store.get(iter, 1, out mount_point);

				if ((mount_point != null) && (mount_point.length > 0)){
					mount_point = mount_point.strip();
					no_mount_points_set_by_user = false;

					App.mount_list.add(new MountEntry(pi,mount_point,""));

					if (mount_point == "/"){
						App.restore_target = pi;
					}
				}
			}

			if (App.restore_target == null){
				//no root mount point was set by user

				if (no_mount_points_set_by_user){
					//user has not set any mount points

					//check if a device is selected in treeview
					sel = tv_partitions.get_selection ();
					if (sel.count_selected_rows() == 1){
						//use selected device as the root mount point
						for (bool next = store.get_iter_first (out iter); next; next = store.iter_next (ref iter)) {
							if (sel.iter_is_selected (iter)){
								Device pi;
								store.get(iter, 0, out pi);
								App.restore_target = pi;
								App.mount_list.add(new MountEntry(pi,"/",""));
								break;
							}
						}
					}
					else{
						//no device selected and no mount points set by user
						string title = _("Select Target Device");
						string msg = _("Please select the target device from the list");
						gtk_messagebox(title, msg, this, true);
						return false;
					}
				}
				else{
					//user has set some mount points but not set the root mount point
					string title = _("Select Root Device");
					string msg = _("Please select the root device (/)");
					gtk_messagebox(title, msg, this, true);
					return false;
				}
			}

			//check BTRFS subvolume layout --------------

			if (App.restore_target.type == "btrfs"){
				if (App.check_btrfs_volume(App.restore_target) == false){
					string title = _("Unsupported Subvolume Layout");
					string msg = _("The target partition has an unsupported subvolume layout.") + " ";
					msg += _("Only ubuntu-type layouts with @ and @home subvolumes are currently supported.") + "\n\n";
					gtk_messagebox(title, msg, this, true);
					return false;
				}
			}

			//mount target device -------------

			bool status = App.mount_target_device(this);
			if (status == false){
				string title = _("Error");
				string msg = _("Failed to mount device") + ": %s".printf(App.restore_target.device);
				gtk_messagebox(title, msg, this, true);
				return false;
			}
		}

		//check if grub device selected ---------------

		if (!chk_skip_grub_install.active && cmb_boot_device.active < 0){
			string title =_("Boot device not selected");
			string msg = _("Please select the boot device");
			gtk_messagebox(title, msg, this, true);
			return false;
		}
		* */

		return true;
	}
}
