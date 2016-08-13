/*
 * WizardWindow.vala
 *
 * Copyright 2013 Tony George <teejee@tony-pc>
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

class WizardWindow : Gtk.Window{

	private Gtk.Box vbox_main;
	private Notebook notebook;
	private Gtk.TreeView tv_devices;
	private string selected_path = "";
	private Gtk.RadioButton radio_device;
	private Gtk.RadioButton radio_path;
	private Gtk.Entry entry_backup_path;
	private Gtk.InfoBar infobar_device;
	private Gtk.Label lbl_infobar_device;
	private Gtk.InfoBar infobar_path;
	private Gtk.Label lbl_infobar_path;

	private uint tmr_init;
	
	public WizardWindow () {
		this.title = AppName + " v" + AppVersion;
        this.window_position = WindowPosition.CENTER;
        this.modal = true;
        this.set_default_size (500, 500);
		//this.delete_event.connect(on_delete_event);
		this.icon = get_app_icon(16);

	    // vbox_main
        var box = new Box (Orientation.VERTICAL, 0);
        box.margin = 0;
        add(box);
		vbox_main = box;
        
		notebook = add_notebook(box, false, false);
		notebook.margin = 6;
		
		box = add_tab(notebook, _("Backup Device"));
		create_tab_backup_device(box);

		create_actions(box);

		show_all();

		tmr_init = Timeout.add(100, init_delayed);
    }

    private bool init_delayed(){

		if (tmr_init > 0){
			Source.remove(tmr_init);
			tmr_init = 0;
		}
		
		tv_devices_refresh();

		if (App.snapshot_path.length > 0){
			entry_backup_path.text = App.snapshot_path;
		}

		if (App.snapshot_device != null){
			select_backup_device(App.snapshot_device);
		}

		if (App.use_snapshot_path){
			radio_path.active = true;
		}
		else{
			radio_device.active = true;
		}

		radio_device.toggled();
		radio_path.toggled();

		return false;
	}
    
	private void create_tab_backup_device(Gtk.Box box){
		
		add_label_header(box, _("Select Snapshot Location"), true);

		// section device
		
		radio_device = add_radio(box, "<b>%s</b>".printf(_("Save to disk partition:")), null);

		var msg = _("Only Linux partitions are supported.");
		msg += "\n" + _("Snapshots will be saved in folder /timeshift");
				
		//var lbl_device_subnote = add_label_subnote(box,msg);

		radio_device.toggled.connect(() =>{
			tv_devices.sensitive = radio_device.active;
			//lbl_device_subnote.sensitive = radio_device.active;
			infobar_device.visible = radio_device.active;

			if (radio_device.active){
				if (App.snapshot_device != null){
					select_backup_device(App.snapshot_device);
				}
				
				check_backup_device(App.snapshot_device);
			}
		});
		
		create_device_list(box);

		create_infobar_device(box);

		radio_device.set_tooltip_text(msg);
		tv_devices.set_tooltip_text(msg);

		// section path
		
		radio_path = add_radio(box, "<b>%s</b>".printf(_("Save to specified path:")), radio_device);
		radio_path.margin_top = 12;

		msg = _("File system at selected path must support hard-links");
		//var lbl_path_subnote = add_label_subnote(box,msg);

		entry_backup_path = add_directory_chooser(box, App.snapshot_path);

		radio_path.toggled.connect(()=>{
			entry_backup_path.sensitive = radio_path.active;
			//lbl_path_subnote.sensitive = radio_path.active;
			infobar_path.visible = radio_path.active;
			if (radio_path.active){
				entry_backup_path.text = App.snapshot_path;
				check_backup_path(App.snapshot_path);
			}
		});

		create_infobar_path(box);

		radio_path.set_tooltip_text(msg);
		entry_backup_path.set_tooltip_text(msg);
	}

	private void create_actions(Gtk.Box box){
		var hbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
		hbox.set_layout (Gtk.ButtonBoxStyle.EXPAND);
		hbox.margin = 0;
		hbox.margin_top = 24;
		hbox.margin_left = 24;
		hbox.margin_right = 24;
        box.add(hbox);

		Gtk.SizeGroup size_group = null;
		
		// previous
		
		Gtk.Image img = new Image.from_stock("gtk-go-back", Gtk.IconSize.BUTTON);
		var button = add_button(hbox, _("Previous"), "", ref size_group, img);

        button.clicked.connect(()=>{
			notebook.prev_page();
		});

		// next
		
		img = new Image.from_stock("gtk-go-forward", Gtk.IconSize.BUTTON);
		button = add_button(hbox, _("Next"), "", ref size_group, img);

        button.clicked.connect(()=>{
			notebook.next_page();
		});

		// cancel
		
		img = new Image.from_stock("gtk-close", Gtk.IconSize.BUTTON);
		button = add_button(hbox, _("Close"), "", ref size_group, img);

        button.clicked.connect(()=>{
			this.destroy();
		});

		
	}
	
	private void create_device_list(Gtk.Box box){
		tv_devices = add_treeview(box);

		Gtk.CellRendererPixbuf cell_pix;
		var col = add_column_icon(tv_devices, "", out cell_pix);

		col.set_cell_data_func(cell_pix, (cell_layout, cell, model, iter)=>{
			Gdk.Pixbuf pix = null;
			model.get (iter, 2, out pix, -1);

			//Gtk.Image img = null;
			/*if ((dev.type == "crypt") && (dev.pkname.length > 0)){
				img = get_shared_icon("unlocked","unlocked.png",16);
			}
			else if (dev.fstype.contains("luks")){
				img = get_shared_icon("locked","locked.png",16);
			}
			else if (dev.fstype.contains("iso9660")){
				img = get_shared_icon("media-cdrom","media-cdrom.png",16);
			}
			else{*/
				//img = get_shared_icon("gtk-harddisk","gtk-harddisk.svg",16);
			//}
			
			(cell as Gtk.CellRendererPixbuf).pixbuf =  pix;
		});

		// device name
		
		Gtk.CellRendererText cell_text;
		col = add_column_text(tv_devices, _("Partition"), out cell_text);

		col.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
			Device dev;
			model.get (iter, 0, out dev, -1);
			(cell as Gtk.CellRendererText).text = dev.device;
		});

		// type
		
		col = add_column_text(tv_devices, _("Type"), out cell_text);

		col.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
			Device dev;
			model.get (iter, 0, out dev, -1);
			(cell as Gtk.CellRendererText).text = dev.fstype;
		});
		
		// size
		
		col = add_column_text(tv_devices, _("Size"), out cell_text);

		col.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
			Device dev;
			model.get (iter, 0, out dev, -1);
			(cell as Gtk.CellRendererText).text = (dev.size_bytes > 0) ? "%s".printf(dev.size) : "";
		});
		
		// label
		
		col = add_column_text(tv_devices, _("Label"), out cell_text);

		col.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
			Device dev;
			model.get (iter, 0, out dev, -1);
			(cell as Gtk.CellRendererText).text = dev.label;
		});

		// events

		tv_devices.cursor_changed.connect(() => {
			
			// get selected iter
			
			Gtk.TreeIter iter;
			var store = (Gtk.ListStore) tv_devices.model;
			var selection = tv_devices.get_selection ();
			
			bool iterExists = store.get_iter_first (out iter);
			while (iterExists) {
				if (selection.iter_is_selected (iter)){
					Device dev;
					store.get (iter, 0, out dev);
					change_backup_device(dev);
					break;
				}
				iterExists = store.iter_next (ref iter);
			}
		});
	}

	private void create_infobar_device(Gtk.Box box){
		var infobar = new Gtk.InfoBar();
		infobar.no_show_all = true;
		box.add(infobar);
		infobar_device = infobar;
		
		var content = (Gtk.Box) infobar.get_content_area ();
		var label = add_label(content, "");
		lbl_infobar_device = label;
	}

	private void create_infobar_path(Gtk.Box box){
		var infobar = new Gtk.InfoBar();
		infobar.no_show_all = true;
		box.add(infobar);
		infobar_path = infobar;
		
		var content = (Gtk.Box) infobar.get_content_area ();
		var label = add_label(content, "");
		lbl_infobar_path = label;
	}
	
	private void change_backup_device(Device pi){
		// return if device has not changed
		if ((App.snapshot_device != null) && (pi.uuid == App.snapshot_device.uuid)){ return; }

		gtk_set_busy(true, this);

		Device previous_device = App.snapshot_device;
		App.snapshot_device = pi;

		// try mounting the device
		
		if (App.mount_backup_device(this)){
			App.update_partitions();
		}
		else{
			App.snapshot_device = previous_device;
			select_backup_device(previous_device);
		}

		check_backup_device(App.snapshot_device);

		gtk_set_busy(false, this);
	}

	private void select_backup_device(Device pi){

		tv_devices.get_selection().unselect_all();

		if (App.snapshot_device == null){
			return;
		}
		
		Gtk.TreeIter iter;
		var store = (Gtk.ListStore) tv_devices.model;

		bool iterExists = store.get_iter_first (out iter);
		while (iterExists) {
			Device dev;
			store.get (iter, 0, out dev);

			if (dev.uuid == App.snapshot_device.uuid){
				tv_devices.get_selection().select_iter(iter);
				break;
			}
			else{
				iterExists = store.iter_next (ref iter);
			}
		}
	}

	private void check_backup_device(Device pi){
		string message;
		int status_code = App.check_backup_device(out message);
		
		/*
		-1 - device un-available
		 0 - first snapshot taken, disk space sufficient
		 1 - first snapshot taken, disk space not sufficient
		 2 - first snapshot not taken, disk space not sufficient
		 3 - first snapshot not taken, disk space sufficient
		*/
		
		switch(status_code){
			case 1:
			case 2:
				var msg = _("Backup device does not have enough space!");
				lbl_infobar_device.label = "<span weight=\"bold\">%s</span>".printf(msg);
				infobar_device.message_type = Gtk.MessageType.ERROR;
				infobar_device.no_show_all = false;
				infobar_device.show_all();
				break;

			case 3:
			case 0:
				infobar_device.hide();
				break;

			case -1:
				var msg = _("Device is not available!");
				lbl_infobar_device.label = "<span weight=\"bold\">%s</span>".printf(msg);
				infobar_device.message_type = Gtk.MessageType.ERROR;
				infobar_device.no_show_all = false;
				infobar_device.show_all();
				break;
		}
	}

	private void check_backup_path(string path){
		var msg = _("File system at selected path must support hard-links");
		
		lbl_infobar_path.label = "<span weight=\"bold\">%s</span>".printf(msg);
		infobar_path.message_type = Gtk.MessageType.INFO;
		infobar_path.no_show_all = false;
		infobar_path.show_all();

		infobar_path.hide();
	}

	//public bool check_hardlink_support(string path){
		//string test_file = path_combine(path, get_ran );
		//file_write(, "");
		//re
	//}

	//public bool check_write_support(){

	//}
	
	private void tv_devices_refresh(){
		App.update_partitions();

		var model = new Gtk.ListStore(3, typeof(Device), typeof(string), typeof(Gdk.Pixbuf));
		tv_devices.set_model (model);

		TreeIter iter;
		foreach(Device pi in App.partitions) {
			if (!pi.has_linux_filesystem()) { continue; }

			string tt = "";
			tt += "%-7s".printf(_("Device")) + "\t: %s\n".printf(pi.full_name_with_alias);
			tt += "%-7s".printf(_("UUID")) + "\t: %s\n".printf(pi.uuid);
			tt += "%-7s".printf(_("Type")) + "\t: %s\n".printf(pi.type);
			tt += "%-7s".printf(_("Label")) + "\t: %s\n".printf(pi.label);
			tt += "%-7s".printf(_("Size")) + "\t: %s\n".printf((pi.size_bytes > 0) ? "%s GB".printf(pi.size) : "");
			tt += "%-7s".printf(_("Used")) + "\t: %s\n".printf((pi.used_bytes > 0) ? "%s GB".printf(pi.used) : "");
			tt += "%-7s".printf(_("System")) + "\t: %s".printf(pi.dist_info);

			model.append(out iter);
			model.set(iter, 0, pi, -1);
			model.set(iter, 1, tt, -1);

			//set icon ----------------

			Gdk.Pixbuf pix_selected = null;
			Gdk.Pixbuf pix_device = get_shared_icon("disk","disk.png",16).pixbuf;
			Gdk.Pixbuf pix_locked = get_shared_icon("locked","locked.svg",16).pixbuf;

			if (pi.type == "luks"){
				pix_selected = pix_locked;
			}
			else{
				pix_selected = pix_device;
			}

			model.set (iter, 2, pix_selected, -1);
		}
	}

	// utility ------------------
	
	private Gtk.Notebook add_notebook(Gtk.Box box, bool show_tabs = true, bool show_border = true){
        // notebook
		var book = new Gtk.Notebook();
		book.margin = 12;
		book.show_tabs = show_tabs;
		book.show_border = show_border;
		
		box.pack_start(book, true, true, 0);
		
		return book;
	}

	private Gtk.Box add_tab(Gtk.Notebook book, string title, int margin = 6, int spacing = 6){
		// label
		var label = new Gtk.Label(title);

        // vbox
        var vbox = new Box (Gtk.Orientation.VERTICAL, spacing);
        vbox.margin = margin;
        book.append_page (vbox, label);

        return vbox;
	}

	private Gtk.TreeView add_treeview(Gtk.Box box,
		Gtk.SelectionMode selection_mode = Gtk.SelectionMode.SINGLE){
			
		// TreeView
		var treeview = new TreeView();
		treeview.get_selection().mode = selection_mode;
		treeview.set_rules_hint (true);

		// ScrolledWindow
		var scrollwin = new ScrolledWindow(null, null);
		scrollwin.set_shadow_type (ShadowType.ETCHED_IN);
		scrollwin.add (treeview);
		scrollwin.expand = true;
		box.add(scrollwin);

		return treeview;
	}

	private Gtk.TreeViewColumn add_column_text(
		Gtk.TreeView treeview, string title, out Gtk.CellRendererText cell){
			
		// TreeViewColumn
		var col = new Gtk.TreeViewColumn();
		col.title = title;
		
		cell = new Gtk.CellRendererText();
		cell.xalign = (float) 0.0;
		col.pack_start (cell, false);
		treeview.append_column(col);
		
		return col;
	}

	private Gtk.TreeViewColumn add_column_icon(
		Gtk.TreeView treeview, string title, out Gtk.CellRendererPixbuf cell){
		
		// TreeViewColumn
		var col = new Gtk.TreeViewColumn();
		col.title = title;
		
		cell = new Gtk.CellRendererPixbuf();
		cell.xpad = 2;
		col.pack_start (cell, false);
		treeview.append_column(col);

		return col;
	}
	
	private Gtk.Label add_label(
		Gtk.Box box, string text, bool is_bold = false, bool is_italic = false, bool is_large = false){
			
		string msg = "<span%s%s%s>%s</span>".printf(
			(is_bold ? " weight=\"bold\"" : ""),
			(is_italic ? " style=\"italic\"" : ""),
			(is_large ? " size=\"x-large\"" : ""),
			text);
			
		var label = new Gtk.Label(msg);
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		box.add(label);
		return label;
	}

	private Gtk.Label add_label_header(
		Gtk.Box box, string text, bool large_heading = false){
		
		var label = add_label(box, text, true, false, large_heading);
		label.margin_bottom = 12;
		return label;
	}

	private Gtk.Label add_label_subnote(
		Gtk.Box box, string text){
		
		var label = add_label(box, text, false, true);
		label.margin_left = 6;
		return label;
	}

	private Gtk.RadioButton add_radio(Gtk.Box box, string text, Gtk.RadioButton? another_radio_in_group){

		Gtk.RadioButton radio = null;

		if (another_radio_in_group == null){
			radio = new Gtk.RadioButton(null);
		}
		else{
			radio = new Gtk.RadioButton.from_widget(another_radio_in_group);
		}

		radio.label = text;
		
		box.add(radio);

		foreach(var child in radio.get_children()){
			if (child is Gtk.Label){
				var label = (Gtk.Label) child;
				label.use_markup = true;
				break;
			}
		}
		
		return radio;
	}

	private Gtk.Button add_button(
		Gtk.Box box, string text, string tooltip,
		ref Gtk.SizeGroup? size_group,
		Gtk.Image? icon = null){
			
		var button = new Gtk.Button();
        box.add(button);

        button.set_label(text);
        button.set_tooltip_text(tooltip);

        if (icon != null){
			button.set_image(icon);
			button.set_always_show_image(true);
		}

		if (size_group == null){
			size_group = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		}
		
		size_group.add_widget(button);
		
        return button;
	}
	
	private Gtk.Entry add_directory_chooser(Gtk.Box box, string selected_directory){
			
		// Entry
		var entry = new Gtk.Entry();
		entry.hexpand = true;
		entry.margin_left = 6;
		entry.secondary_icon_stock = "gtk-open";
		entry.placeholder_text = _("Enter path or browse for directory");
		box.add (entry);

		if ((selected_directory != null) && dir_exists(selected_directory)){
			entry.text = selected_directory;
		}

		entry.icon_release.connect((p0, p1) => {
			//chooser
			var chooser = new Gtk.FileChooserDialog(
			    _("Select Path"),
			    this,
			    FileChooserAction.SELECT_FOLDER,
			    "_Cancel",
			    Gtk.ResponseType.CANCEL,
			    "_Open",
			    Gtk.ResponseType.ACCEPT
			);

			chooser.select_multiple = false;
			chooser.set_filename(selected_directory);

			if (chooser.run() == Gtk.ResponseType.ACCEPT) {
				entry.text = chooser.get_filename();
				check_backup_path(entry.text);
			}

			chooser.destroy();
		});

		return entry;
	}
}
