/*
 * RestoreDeviceBox.vala
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

class BootOptionsBox : Gtk.Box{
	
	private Gtk.Box option_box;
	private Gtk.ComboBox cmb_grub_dev;

	private Gtk.CheckButton chk_reinstall_grub;
	private Gtk.CheckButton chk_update_initramfs;
	private Gtk.CheckButton chk_update_grub;
	private Gtk.Window parent_window;

	public BootOptionsBox (Gtk.Window _parent_window) {

		log_debug("BootOptionsBox: BootOptionsBox()");
		
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		margin = 12;

		// options
		option_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		add(option_box);

		add_bootloader_options();

		refresh_options();

		log_debug("BootOptionsBox: BootOptionsBox(): exit");
    }

	private void add_bootloader_options(){

		// header
		//var label = add_label_header(this, _("Select Bootloader Options"), true);

		add_chk_reinstall_grub();
		
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		hbox.margin_left = 12;
        add (hbox);

		//cmb_grub_dev
		cmb_grub_dev = new ComboBox ();
		cmb_grub_dev.hexpand = true;
		hbox.add(cmb_grub_dev);
		
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

		/*string tt = "<b>" + _("** Advanced Users **") + "</b>\n\n"+ _("Skips bootloader (re)installation on target device.\nFiles in /boot directory on target partition will remain untouched.\n\nIf you are restoring a system that was bootable previously then it should boot successfully. Otherwise the system may fail to boot.");*/

		hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
        add (hbox);
        
		add_chk_update_initramfs(hbox);

		add_chk_update_grub(hbox);
	}

	private void add_chk_reinstall_grub(){
		
		var chk = new CheckButton.with_label(_("(Re)install GRUB2 on:"));
		chk.active = false;
		chk.set_tooltip_markup(_("Re-installs the GRUB2 bootloader on the selected device."));
		//chk.margin_bottom = 12;
		add (chk);
		chk_reinstall_grub = chk;

		chk.toggled.connect(()=>{
			cmb_grub_dev.sensitive = chk_reinstall_grub.active;
			App.reinstall_grub2 = chk_reinstall_grub.active;
			cmb_grub_dev.changed();
		});
	}

	private void add_chk_update_initramfs(Gtk.Box hbox){
		
		//chk_update_initramfs
		var chk = new CheckButton.with_label(_("Update initramfs"));
		chk.active = false;
		chk.set_tooltip_markup(_("Re-generates initramfs for all installed kernels. This is generally not needed. Select this only if the restored system fails to boot."));
		//chk.margin_bottom = 12;
		add (chk);
		chk_update_initramfs = chk;

		chk.toggled.connect(()=>{
			App.update_initramfs = chk_update_initramfs.active;
		});
	}

	private void add_chk_update_grub(Gtk.Box hbox){
		
		//chk_update_grub
		var chk = new CheckButton.with_label(_("Update GRUB menu"));
		chk.active = false;
		chk.set_tooltip_markup(_("Updates the GRUB menu entries (recommended). This is safe to run and should be left selected."));
		//chk.margin_bottom = 12;
		add (chk);
		chk_update_grub = chk;

		chk.toggled.connect(()=>{
			App.update_grub = chk_update_grub.active;
		});
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

	private void refresh_options(){

		refresh_cmb_grub_dev();
		
		chk_reinstall_grub.active = App.reinstall_grub2;
		cmb_grub_dev.sensitive = chk_reinstall_grub.active;
		chk_update_initramfs.active = App.update_initramfs;
		chk_update_grub.active = App.update_grub;
		
		chk_reinstall_grub.sensitive = true;
		chk_update_initramfs.sensitive = true;
		chk_update_grub.sensitive = true;
				
		if (App.mirror_system){
			// bootloader must be re-installed
			chk_reinstall_grub.sensitive = false;
			chk_update_initramfs.sensitive = false;
			chk_update_grub.sensitive = false;
		}
		else{
			if (App.snapshot_to_restore.distro.dist_id == "fedora"){
				// grub2-install should never be run on EFI fedora systems
				chk_reinstall_grub.sensitive = false;
			}
		}
	}
	
	private void refresh_cmb_grub_dev(){
		
		var store = new Gtk.ListStore(2, typeof(Device), typeof(string));

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
			store.set (iter, 1, IconManager.ICON_HARDDRIVE);
		}

		cmb_grub_dev.model = store;

		cmb_grub_dev_select_default();
	}

	private void cmb_grub_dev_select_default(){

		if ((cmb_grub_dev == null) || (cmb_grub_dev.model == null)){
			return;
		}
		
		log_debug("BootOptionsBox: cmb_grub_dev_select_default()");
		
		if (App.grub_device.length == 0){
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
			
			if (dev_iter.device == App.grub_device){
				active = index;
				break;
			}
		}

		cmb_grub_dev.active = active;

		log_debug("BootOptionsBox: cmb_grub_dev_select_default(): exit");
	}
}
