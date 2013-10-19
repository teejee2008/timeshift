/*
 * MainWindow.vala
 * 
 * Copyright 2013 Tony George <teejee2008@gmail.com>
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
using TeeJee.DiskPartition;
using TeeJee.JSON;
using TeeJee.ProcessManagement;
using TeeJee.GtkHelper;
using TeeJee.Multimedia;
using TeeJee.System;
using TeeJee.Misc;

public class RestoreWindow : Gtk.Dialog{
	private Box vbox_main;
	private Box hbox_action;
	private Notebook notebook;

    //target device
    private Label lbl_header_partitions;
    private TreeView tv_partitions;
	private ScrolledWindow sw_partitions;
	private TreeViewColumn col_device_target;
	private TreeViewColumn col_fs;
	private TreeViewColumn col_size;
	private TreeViewColumn col_used;
	private TreeViewColumn col_label;
	private TreeViewColumn col_dist;
	
	//bootloader
	private Label lbl_header_bootloader;
	private ComboBox cmb_boot_device;
	
	//exclude
	private Label lbl_exclude;
	private Box vbox_exclude;
	private LinkButton lnk_default_list;
	private TreeView tv_exclude;
	private ScrolledWindow sw_exclude;
	private TreeViewColumn col_exclude;
	private Toolbar toolbar_exclude;
	private ToolButton btn_remove;
	private ToolButton btn_warning;
	private ToolButton btn_reset_exclude_list;
	
	private MenuToolButton btn_exclude;
	private Gtk.Menu menu_exclude;
	private ImageMenuItem menu_exclude_add_file;
	private ImageMenuItem menu_exclude_add_folder;
	private ImageMenuItem menu_exclude_add_folder_contents;
	
	private MenuToolButton btn_include;
	private Gtk.Menu menu_include;
	private ImageMenuItem menu_include_add_file;
	private ImageMenuItem menu_include_add_folder;
	
	private Gee.ArrayList<string> temp_exclude_list;
	
	//actions
	private Button btn_cancel;
	private Button btn_restore;

	public RestoreWindow () {
		this.title = _("Restore");
        this.window_position = WindowPosition.CENTER_ON_PARENT;
        this.set_destroy_with_parent (true);
		this.set_modal (true);
        this.set_default_size (550, 500);

        //set app icon
		try{
			this.icon = new Gdk.Pixbuf.from_file (App.share_folder + """/pixmaps/timeshift.png""");
		}
        catch(Error e){
	        log_error (e.message);
	    }
	    
	    //vbox_main
        vbox_main = get_content_area ();

		//notebook
		notebook = new Notebook ();
		notebook.margin = 6;
		vbox_main.pack_start (notebook, true, true, 0);

		//target device tab -------------------------------------------------
		
		//lbl_exclude
		lbl_exclude = new Label (_("Target"));

        //vbox_target
        Box vbox_target = new Box (Orientation.VERTICAL, 6);
        vbox_target.margin = 6;
        notebook.append_page (vbox_target, lbl_exclude);
        
		//lbl_header_partitions
		lbl_header_partitions = new Gtk.Label(_("Device for Restoring Snapshot") + ":");
		lbl_header_partitions.xalign = (float) 0.0;
		lbl_header_partitions.set_use_markup(true);
		vbox_target.add(lbl_header_partitions);
		
		//tv_partitions
		tv_partitions = new TreeView();
		tv_partitions.get_selection().mode = SelectionMode.SINGLE;
		tv_partitions.set_rules_hint (true);
		tv_partitions.button_release_event.connect(tv_partitions_button_press_event);
		
		//sw_partitions
		sw_partitions = new ScrolledWindow(null, null);
		sw_partitions.set_shadow_type (ShadowType.ETCHED_IN);
		sw_partitions.add (tv_partitions);
		sw_partitions.expand = true;
		vbox_target.add(sw_partitions);
		
		//col_device
		col_device_target = new TreeViewColumn();
		col_device_target.title = _("Device");
		col_device_target.spacing = 1;

		CellRendererPixbuf cell_device_icon = new CellRendererPixbuf ();
		cell_device_icon.stock_id = Stock.HARDDISK;
		cell_device_icon.xpad = 1;
		col_device_target.pack_start (cell_device_icon, false);

		CellRendererText cell_device_target = new CellRendererText ();
		col_device_target.pack_start (cell_device_target, false);
		col_device_target.set_cell_data_func (cell_device_target, cell_device_target_render);
		
		tv_partitions.append_column(col_device_target);
		
		//col_fs
		col_fs = new TreeViewColumn();
		col_fs.title = _("Type");
		CellRendererText cell_fs = new CellRendererText ();
		cell_fs.xalign = (float) 0.5;
		col_fs.pack_start (cell_fs, false);
		col_fs.set_cell_data_func (cell_fs, cell_fs_render);
		tv_partitions.append_column(col_fs);

		//col_size
		col_size = new TreeViewColumn();
		col_size.title = _("Size");
		CellRendererText cell_size = new CellRendererText ();
		cell_size.xalign = (float) 1.0;
		col_size.pack_start (cell_size, false);
		col_size.set_cell_data_func (cell_size, cell_size_render);
		tv_partitions.append_column(col_size);
		
		//col_used
		col_used = new TreeViewColumn();
		col_used.title = _("Used");
		CellRendererText cell_used = new CellRendererText ();
		cell_used.xalign = (float) 1.0;
		col_used.pack_start (cell_used, false);
		col_used.set_cell_data_func (cell_used, cell_used_render);
		tv_partitions.append_column(col_used);
		
		//col_label
		col_label = new TreeViewColumn();
		col_label.title = _("Label");
		CellRendererText cell_label = new CellRendererText ();
		col_label.pack_start (cell_label, false);
		col_label.set_cell_data_func (cell_label, cell_label_render);
		tv_partitions.append_column(col_label);
		
		//col_dist
		col_dist = new TreeViewColumn();
		col_dist.title = _("System");
		CellRendererText cell_dist = new CellRendererText ();
		col_dist.pack_start (cell_dist, false);
		col_dist.set_cell_data_func (cell_dist, cell_dist_render);
		tv_partitions.append_column(col_dist);
		
		//bootloader options -------------------------------------------
		
		//lbl_header_bootloader
		lbl_header_bootloader = new Gtk.Label(_("Device for Bootloader Installation") + ":");
		lbl_header_bootloader.set_use_markup(true);
		lbl_header_bootloader.xalign = (float) 0.0;
		vbox_target.add(lbl_header_bootloader);
		
		//hbox_grub
		Box hbox_grub = new Box (Orientation.HORIZONTAL, 6);
		hbox_grub.margin_right = 6;
        hbox_grub.margin_bottom = 6;
        vbox_target.add (hbox_grub);

		//cmb_boot_device
		cmb_boot_device = new ComboBox ();
		cmb_boot_device.hexpand = true;
		hbox_grub.add(cmb_boot_device);
		
		CellRendererText cell_dev_margin = new CellRendererText ();
		cell_dev_margin.text = "";
		cmb_boot_device.pack_start (cell_dev_margin, false);
		
		CellRendererPixbuf cell_dev_icon = new CellRendererPixbuf ();
		cell_dev_icon.stock_id = Stock.HARDDISK;
		cmb_boot_device.pack_start (cell_dev_icon, false);
		
		CellRendererText cell_device_grub = new CellRendererText();
        cmb_boot_device.pack_start(cell_device_grub, false );
        cmb_boot_device.set_cell_data_func (cell_device_grub, cell_device_grub_render);
        
        //Exclude tab ---------------------------------------------
		
		//lbl_exclude
		lbl_exclude = new Label (_("Advanced"));

        //vbox_exclude
        vbox_exclude = new Box(Gtk.Orientation.VERTICAL, 6);
        vbox_exclude.margin = 6;
        notebook.append_page (vbox_exclude, lbl_exclude);

		//toolbar_exclude ---------------------------------------------------
        
        //toolbar_exclude
		toolbar_exclude = new Gtk.Toolbar ();
		toolbar_exclude.toolbar_style = ToolbarStyle.BOTH_HORIZ;
		vbox_exclude.add(toolbar_exclude);
		
		string png_exclude = App.share_folder + "/timeshift/images/item-gray.png";
		string png_include = App.share_folder + "/timeshift/images/item-blue.png";
		
		//btn_exclude
		btn_exclude = new Gtk.MenuToolButton(null,"");
		toolbar_exclude.add(btn_exclude);
		
		btn_exclude.is_important = true;
		btn_exclude.label = _("Exclude");
		btn_exclude.set_tooltip_text (_("Exclude"));
		btn_exclude.set_icon_widget(new Gtk.Image.from_file (png_exclude));
		
		//btn_include
		btn_include = new Gtk.MenuToolButton(null,"");
		toolbar_exclude.add(btn_include);
		
		btn_include.is_important = true;
		btn_include.label = _("Include");
		btn_include.set_tooltip_text (_("Include"));
		btn_include.set_icon_widget(new Gtk.Image.from_file (png_include));
		
		//btn_remove
		btn_remove = new Gtk.ToolButton.from_stock(Gtk.Stock.REMOVE);
		toolbar_exclude.add(btn_remove);
		
		btn_remove.is_important = true;
		btn_remove.label = _("Remove");
		btn_remove.set_tooltip_text (_("Remove selected items"));

		btn_remove.clicked.connect (btn_remove_clicked);

		//btn_warning
		btn_warning = new Gtk.ToolButton.from_stock(Gtk.Stock.DIALOG_WARNING);
		toolbar_exclude.add(btn_warning);
		
		btn_warning.is_important = true;
		btn_warning.label = _("Warning");
		btn_warning.set_tooltip_text (_("Warning"));

		btn_warning.clicked.connect (btn_warning_clicked);

		//separator
		var separator = new Gtk.SeparatorToolItem();
		separator.set_draw (false);
		separator.set_expand (true);
		toolbar_exclude.add(separator);
		
		//btn_reset_exclude_list
		btn_reset_exclude_list = new Gtk.ToolButton.from_stock(Gtk.Stock.REFRESH);
		toolbar_exclude.add(btn_reset_exclude_list);
		
		btn_reset_exclude_list.is_important = false;
		btn_reset_exclude_list.label = _("Reset");
		btn_reset_exclude_list.set_tooltip_text (_("Reset this list to default state"));

		btn_reset_exclude_list.clicked.connect (btn_reset_exclude_list_clicked);
		
		//menu --------------------------------------------------
		
        //menu_exclude
		menu_exclude = new Gtk.Menu();
		btn_exclude.set_menu(menu_exclude);
		
		//menu_exclude_add_file
		menu_exclude_add_file = new ImageMenuItem.with_label ("");
		menu_exclude_add_file.label = _("Exclude File(s)");
		menu_exclude_add_file.set_image(new Gtk.Image.from_file (png_exclude));
		menu_exclude.append(menu_exclude_add_file);
		
		menu_exclude_add_file.activate.connect (menu_exclude_add_files_clicked);

		//menu_exclude_add_folder
		menu_exclude_add_folder = new ImageMenuItem.with_label ("");
		menu_exclude_add_folder.label = _("Exclude Directory");
		menu_exclude_add_folder.set_image(new Gtk.Image.from_file (png_exclude));
		menu_exclude.append(menu_exclude_add_folder);
		
		menu_exclude_add_folder.activate.connect (menu_exclude_add_folder_clicked);

		//menu_exclude_add_folder_contents
		menu_exclude_add_folder_contents = new ImageMenuItem.with_label ("");
		menu_exclude_add_folder_contents.label = _("Exclude Directory Contents");
		menu_exclude_add_folder_contents.set_image(new Gtk.Image.from_file (png_exclude));
		menu_exclude.append(menu_exclude_add_folder_contents);
		
		menu_exclude_add_folder_contents.activate.connect (menu_exclude_add_folder_contents_clicked);
		
		//menu_include
		menu_include = new Gtk.Menu();
		btn_include.set_menu(menu_include);
		
		//menu_include_add_file
		menu_include_add_file = new ImageMenuItem.with_label ("");
		menu_include_add_file.label = _("Include File(s)");
		menu_include_add_file.set_image(new Gtk.Image.from_file (png_include));
		menu_include.append(menu_include_add_file);
		
		menu_include_add_file.activate.connect (menu_include_add_files_clicked);

		//menu_include_add_folder
		menu_include_add_folder = new ImageMenuItem.with_label ("");
		menu_include_add_folder.label = _("Include Directory");
		menu_include_add_folder.set_image(new Gtk.Image.from_file (png_include));
		menu_include.append(menu_include_add_folder);
		
		menu_include_add_folder.activate.connect (menu_include_add_folder_clicked);
		
		menu_exclude.show_all();
		menu_include.show_all();
		
		//tv_exclude-----------------------------------------------
		
		//tv_exclude
		tv_exclude = new TreeView();
		tv_exclude.get_selection().mode = SelectionMode.MULTIPLE;
		tv_exclude.headers_visible = true;
		tv_exclude.set_rules_hint (true);
		//tv_exclude.row_activated.connect(tv_exclude_row_activated);
		
		//sw_exclude
		sw_exclude = new ScrolledWindow(null, null);
		sw_exclude.set_shadow_type (ShadowType.ETCHED_IN);
		sw_exclude.add (tv_exclude);
		sw_exclude.expand = true;
		vbox_exclude.add(sw_exclude);

        //col_exclude
		col_exclude = new TreeViewColumn();
		col_exclude.title = _("File Pattern");
		col_exclude.expand = true;
		
		CellRendererText cell_exclude_margin = new CellRendererText ();
		cell_exclude_margin.text = "";
		col_exclude.pack_start (cell_exclude_margin, false);
		
		CellRendererPixbuf cell_exclude_icon = new CellRendererPixbuf ();
		col_exclude.pack_start (cell_exclude_icon, false);
		col_exclude.set_attributes(cell_exclude_icon, "pixbuf", 1);
		
		CellRendererText cell_exclude_text = new CellRendererText ();
		col_exclude.pack_start (cell_exclude_text, false);
		col_exclude.set_cell_data_func (cell_exclude_text, cell_exclude_text_render);
		cell_exclude_text.editable = true;
		tv_exclude.append_column(col_exclude);
	
		cell_exclude_text.edited.connect (cell_exclude_text_edited);
		
		//lnk_default_list
		lnk_default_list = new LinkButton.with_label("",_("Some locations are excluded by default"));
		lnk_default_list.xalign = (float) 0.0;
		lnk_default_list.activate_link.connect(lnk_default_list_activate);
		vbox_exclude.add(lnk_default_list);
		
		//Actions ----------------------------------------------
		
		//hbox_action
        hbox_action = (Box) get_action_area ();

        //btn_restore
        btn_restore = new Button();
        hbox_action.add(btn_restore);
        
        btn_restore.set_label (" " + _("Restore"));
        btn_restore.set_tooltip_text (_("Restore"));
        Gtk.Image img_restore = new Image.from_stock(Gtk.Stock.GO_FORWARD, Gtk.IconSize.BUTTON);
		btn_restore.set_image(img_restore);
        btn_restore.clicked.connect (btn_restore_clicked);

        //btn_cancel
        btn_cancel = new Button();
        hbox_action.add(btn_cancel);
        
        btn_cancel.set_label (" " + _("Cancel"));
        btn_cancel.set_tooltip_text (_("Cancel"));
        Gtk.Image img_cancel = new Image.from_stock(Gtk.Stock.CANCEL, Gtk.IconSize.BUTTON);
		btn_cancel.set_image(img_cancel);
        btn_cancel.clicked.connect (btn_cancel_clicked);

		//initialize -----------------------------------------
		
		refresh_tv_partitions();
		refresh_cmb_boot_device();
		
		btn_reset_exclude_list_clicked();
	}


	private void cell_device_target_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		PartitionInfo pi;
		model.get (iter, 0, out pi, -1);
		if ((App.root_device != null) && (pi.device == App.root_device.device)){
			(cell as Gtk.CellRendererText).text = pi.partition_name + " (" + _("sys") + ")";
		}
		else{
			(cell as Gtk.CellRendererText).text = pi.partition_name;
		}
	}

	private void cell_fs_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		PartitionInfo pi;
		model.get (iter, 0, out pi, -1);
		(cell as Gtk.CellRendererText).text = pi.type;
	}
	
	private void cell_size_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		PartitionInfo pi;
		model.get (iter, 0, out pi, -1);
		(cell as Gtk.CellRendererText).text = pi.size;
	}
	
	private void cell_used_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		PartitionInfo pi;
		model.get (iter, 0, out pi, -1);
		(cell as Gtk.CellRendererText).text = pi.used;
	}
	
	private void cell_label_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		PartitionInfo pi;
		model.get (iter, 0, out pi, -1);
		(cell as Gtk.CellRendererText).text = pi.label;
	}

	private void cell_dist_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		PartitionInfo pi;
		model.get (iter, 0, out pi, -1);
		(cell as Gtk.CellRendererText).text = pi.dist_info;
	}
	
	private void cell_device_grub_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		DeviceInfo info;
		model.get (iter, 0, out info, -1);
		(cell as Gtk.CellRendererText).text = info.description;
	}

	private void cell_exclude_text_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		string pattern;
		model.get (iter, 0, out pattern, -1);
		(cell as Gtk.CellRendererText).text = pattern.has_prefix("+ ") ? pattern[2:pattern.length] : pattern;
	}

	private void cell_exclude_text_edited (string path, string new_text) {
		string old_pattern;
		string new_pattern;
		
		TreeIter iter;
		ListStore model = (ListStore) tv_exclude.model;
		model.get_iter_from_string (out iter, path);
		model.get (iter, 0, out old_pattern, -1);
		
		if (old_pattern.has_prefix("+ ")){
			new_pattern = "+ " + new_text;
		}
		else{
			new_pattern = new_text;
		}
		model.set (iter, 0, new_pattern);
		
		int index = temp_exclude_list.index_of(old_pattern);
		temp_exclude_list.insert(index, new_pattern);
		temp_exclude_list.remove(old_pattern);
	}


	private void refresh_cmb_boot_device(){
		ListStore store = new ListStore(1, typeof(DeviceInfo));

		TreeIter iter;

		int index = -1;
		int selected_index = -1;
		int default_index = -1;
		
		foreach(DeviceInfo di in get_block_devices()) {
			store.append(out iter);
			store.set (iter, 0, di);

			index++;
			if ((App.restore_target != null) && (di.device == App.restore_target.device[0:-1])){
				selected_index = index;
			}
		}
		
		if (selected_index == -1){
			selected_index = default_index;
		}
		
		cmb_boot_device.set_model (store);
		cmb_boot_device.active = selected_index;
	}
	
	private void refresh_tv_partitions(){
		
		App.update_partition_list();
		
		ListStore model = new ListStore(1, typeof(PartitionInfo));
		
		var list = App.partition_list;
		list.sort((a,b) => { 
					PartitionInfo p1 = (PartitionInfo) a;
					PartitionInfo p2 = (PartitionInfo) b;
					
					return strcmp(p1.device,p2.device);
				});

		TreeIter iter;
		TreePath path_selected = null;
		
		foreach(PartitionInfo pi in list) {
			if (!pi.has_linux_filesystem()) { continue; }
			
			model.append(out iter);
			model.set (iter, 0, pi);
			
			if ((App.restore_target != null) && (App.restore_target.device == pi.device)){
				path_selected = model.get_path(iter);
			}
		}
			
		tv_partitions.set_model (model);
		if (path_selected != null){
			tv_partitions.get_selection().select_path(path_selected);
		}
		//tv_partitions.columns_autosize ();
	}
	
	private void refresh_tv_exclude(){
		ListStore model = new ListStore(2, typeof(string), typeof(Gdk.Pixbuf));
		tv_exclude.model = model;
		
		foreach(string path in temp_exclude_list){
			tv_exclude_add_item(path);
		}
	}

	private void tv_exclude_add_item(string path){
		Gdk.Pixbuf pix_exclude = null;
		Gdk.Pixbuf pix_include = null;
		Gdk.Pixbuf pix_selected = null;

		try{
			pix_exclude = new Gdk.Pixbuf.from_file (App.share_folder + "/timeshift/images/item-gray.png");
			pix_include = new Gdk.Pixbuf.from_file (App.share_folder + "/timeshift/images/item-blue.png");
		}
        catch(Error e){
	        log_error (e.message);
	    }

		TreeIter iter;
		ListStore model = (ListStore) tv_exclude.model;
		model.append(out iter);
			
		if (path.has_prefix("+ ")){
			pix_selected = pix_include;
		}
		else{
			pix_selected = pix_exclude;
		}
		
		model.set (iter, 0, path, 1, pix_selected, -1);
		
		Adjustment adj = tv_exclude.get_hadjustment();
		adj.value = adj.upper;
	}
			
	private bool lnk_default_list_activate(){
		//show message window -----------------
		var dialog = new ExcludeMessageWindow();
		dialog.set_transient_for (this);
		dialog.show_all();
		dialog.run();
		dialog.destroy();
		return true;
	}

	private bool tv_partitions_button_press_event(Gdk.EventButton event){
		TreeIter iter;
		ListStore store;
		TreeSelection sel;
		bool iterExists;
		
		//get selected target device
		PartitionInfo restore_target = null;
		sel = tv_partitions.get_selection ();
		store = (ListStore) tv_partitions.model;
		iterExists = store.get_iter_first (out iter);
		while (iterExists) { 
			if (sel.iter_is_selected (iter)){
				store.get (iter, 0, out restore_target);
				break;
			}
			iterExists = store.iter_next (ref iter);
		}
		App.restore_target = restore_target;

		//select grub target device
		refresh_cmb_boot_device(); 

		return false;
	}


	private void menu_exclude_add_files_clicked(){
		
		var list = browse_files();
		
		if (list.length() > 0){
			foreach(string path in list){
				if (!temp_exclude_list.contains(path)){
					temp_exclude_list.add(path);
					tv_exclude_add_item(path);
					App.first_snapshot_size = 0; //re-calculate
				}
			}
		}
	}

	private void menu_exclude_add_folder_clicked(){
		
		var list = browse_folder();
		
		if (list.length() > 0){
			foreach(string path in list){
				
				path = path + "/";
				
				if (!temp_exclude_list.contains(path)){
					temp_exclude_list.add(path);
					tv_exclude_add_item(path);
					App.first_snapshot_size = 0; //re-calculate
				}
			}
		}
	}

	private void menu_exclude_add_folder_contents_clicked(){
		
		var list = browse_folder();
		
		if (list.length() > 0){
			foreach(string path in list){
				
				path = path + "/*";
				
				if (!temp_exclude_list.contains(path)){
					temp_exclude_list.add(path);
					tv_exclude_add_item(path);
					App.first_snapshot_size = 0; //re-calculate
				}
			}
		}
	}

	private void menu_include_add_files_clicked(){
		
		var list = browse_files();
		
		if (list.length() > 0){
			foreach(string path in list){
				
				path = path.has_prefix("+ ") ? path : "+ " + path;
				
				if (!temp_exclude_list.contains(path)){
					temp_exclude_list.add(path);
					tv_exclude_add_item(path);
					App.first_snapshot_size = 0; //re-calculate
				}
			}
		}
	}

	private void menu_include_add_folder_clicked(){
		
		var list = browse_folder();
		
		if (list.length() > 0){
			foreach(string path in list){
				
				path = path.has_prefix("+ ") ? path : "+ " + path;
				path = path + "/***";
				
				if (!temp_exclude_list.contains(path)){
					temp_exclude_list.add(path);
					tv_exclude_add_item(path);
					App.first_snapshot_size = 0; //re-calculate
				}
			}
		}
	}

	private SList<string> browse_files(){
		var dialog = new Gtk.FileChooserDialog(_("Select file(s)"), this, Gtk.FileChooserAction.OPEN,
							Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
							Gtk.Stock.OPEN, Gtk.ResponseType.ACCEPT);
		dialog.action = FileChooserAction.OPEN;
		dialog.set_transient_for(this);
		dialog.local_only = true;
 		dialog.set_modal (true);
 		dialog.set_select_multiple (true);

		dialog.run();
		var list = dialog.get_filenames();
	 	dialog.destroy ();
	 	
	 	return list;
	}

	private SList<string> browse_folder(){
		var dialog = new Gtk.FileChooserDialog(_("Select directory"), this, Gtk.FileChooserAction.OPEN,
							Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
							Gtk.Stock.OPEN, Gtk.ResponseType.ACCEPT);
		dialog.action = FileChooserAction.SELECT_FOLDER;
		dialog.local_only = true;
		dialog.set_transient_for(this);
 		dialog.set_modal (true);
 		dialog.set_select_multiple (false);
 		
		dialog.run();
		var list = dialog.get_filenames();
	 	dialog.destroy ();
	 	
	 	return list;
	}


	private void btn_remove_clicked(){
		TreeSelection sel = tv_exclude.get_selection ();
		TreeIter iter;
		bool iterExists = tv_exclude.model.get_iter_first (out iter);
		while (iterExists) { 
			if (sel.iter_is_selected (iter)){
				string path;
				tv_exclude.model.get (iter, 0, out path);
				temp_exclude_list.remove(path);
				App.first_snapshot_size = 0; //re-calculate
			}
			iterExists = tv_exclude.model.iter_next (ref iter);
		}

		refresh_tv_exclude();
	}

	private void btn_warning_clicked(){
		string msg = "";
		msg += _("Please do NOT modify this list unless you have a very good reason for doing so.") + " ";
		msg += _("By default, any item that was included/excluded at the time of taking the snapshot will be included/excluded.") + " ";
		msg += _("Any exclude patterns in the current exclude list will also be excluded.") + " ";
		msg += _("To see which files are included in the snapshot use the 'Browse' button on the main window.");
		
		var dialog = new Gtk.MessageDialog.with_markup(null, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.OK, msg);
		dialog.set_title("Warning");
		dialog.set_default_size (200, -1);
		dialog.set_transient_for(this);
		dialog.set_modal(true);
		dialog.run();
		dialog.destroy();
	}
	
	private void btn_reset_exclude_list_clicked(){
		//create a temp exclude list ----------------------------
		
		temp_exclude_list = new Gee.ArrayList<string>();
		
		//add all include/exclude items from snapshot list
		foreach(string path in App.snapshot_to_restore.exclude_list){
			if (!temp_exclude_list.contains(path) && !App.exclude_list_default.contains(path) && !App.exclude_list_home.contains(path)){
				temp_exclude_list.add(path);
			}
		}
		
		//add all exclude items from current list
		foreach(string path in App.exclude_list_user){
			if (!temp_exclude_list.contains(path) && !App.exclude_list_default.contains(path) && !App.exclude_list_home.contains(path)){
				
				if (!path.has_prefix("+ ")){ 		//don't add include entries from current exclude list
					temp_exclude_list.add(path);
				}
			}
		}		
		
		//refresh treeview --------------------------
		
		refresh_tv_exclude();
	}
	

	private void btn_restore_clicked(){
		
		//Note: A successful restore will reboot the system if target device is same as system device
		
		TreeIter iter;
		ListStore store;
		TreeSelection sel;
		bool iterExists;
		
		//check single target partition selected ---------------
		
		sel = tv_partitions.get_selection ();
		if (sel.count_selected_rows() != 1){ 
			gtk_messagebox_show(_("Select Target Device"),_("Please select the target device from the list"), true);
			return; 
		}

		//check if grub device selected ---------------

		if (cmb_boot_device.active < 0){ 
			gtk_messagebox_show(_("Select Boot Device"),_("Please select the boot device"), true);
			return; 
		}
		
		//get selected target partition ------------------
		
		PartitionInfo restore_target = null;
		sel = tv_partitions.get_selection ();
		store = (ListStore) tv_partitions.model;
		iterExists = store.get_iter_first (out iter);
		while (iterExists) { 
			if (sel.iter_is_selected (iter)){
				store.get (iter, 0, out restore_target);
				break;
			}
			iterExists = store.iter_next (ref iter);
		}
		App.restore_target = restore_target;
		
		//save modified exclude list ----------------------
		
		App.exclude_list_restore.clear();
		
		//add default entries
		foreach(string path in App.exclude_list_default){
			if (!App.exclude_list_restore.contains(path)){
				App.exclude_list_restore.add(path);
			}
		}
		
		//add modified user entries
		foreach(string path in temp_exclude_list){
			if (!App.exclude_list_restore.contains(path) && !App.exclude_list_home.contains(path)){
				App.exclude_list_restore.add(path);
			}
		}

		//add home entries
		foreach(string path in App.exclude_list_home){
			if (!App.exclude_list_restore.contains(path)){
				App.exclude_list_restore.add(path);
			}
		}
		
		string timeshift_path = "/timeshift/*";
		if (!App.exclude_list_restore.contains(timeshift_path)){
			App.exclude_list_restore.add(timeshift_path);
		}
		
		//save grub install options ----------------------
		
		//App.reinstall_grub2 = chk_restore_grub2.active;
		App.reinstall_grub2 = true;
		
		if (App.reinstall_grub2){
			DeviceInfo dev;
			cmb_boot_device.get_active_iter (out iter);
			TreeModel model = (TreeModel) cmb_boot_device.model;
			model.get(iter, 0, out dev);
			App.grub_device = dev;
		}
		
		//last option to quit - show disclaimer ------------
		
		if (show_disclaimer() == Gtk.ResponseType.YES){
			this.response(Gtk.ResponseType.OK);
		}
		else{
			this.response(Gtk.ResponseType.CANCEL);
		}
	}

	private int show_disclaimer(){
		string msg = "";
		msg += "<b>" + _("WARNING") + ":</b>\n\n";
		msg += _("Files will be overwritten on the target device!") + "\n";
		msg += _("If the restore fails for any reason and you are unable to boot the system, \nplease boot from the Ubuntu Live CD and try again.") + "\n";
		
		if ((App.root_device != null) && (App.restore_target.device == App.root_device.device)){
			msg += "\n<b>" + _("Please save your work and close all applications.") + "\n";
			msg += _("System will reboot to complete the restore process.") + "</b>\n";
		}
		
		msg += "\n";
		msg += "<b>" + _("DISCLAIMER") + ":</b>\n\n";
		msg += _("This software comes without absolutely NO warranty and the author takes no responsibility for any damage arising from the use of this program.");
		msg += " " + _("If these terms are not acceptable to you, please do not proceed beyond this point!") + "\n";
		msg += "\n";
		msg += "<b>" + _("Continue with restore?") + "</b>\n";
		
		var dialog = new Gtk.MessageDialog.with_markup(null, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.YES_NO, msg);
		dialog.set_title(_("DISCLAIMER"));
		dialog.set_default_size (200, -1);
		dialog.set_transient_for(this);
		dialog.set_modal(true);
		int response = dialog.run();
		dialog.destroy();
		return response;
	}

	private void btn_cancel_clicked(){
		this.response(Gtk.ResponseType.CANCEL);
		return;	
	}

}
