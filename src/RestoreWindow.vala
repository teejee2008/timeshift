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
using TeeJee.Devices;
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
    private RadioButton radio_sys;
    private RadioButton radio_other;
    private TreeView tv_partitions;
	private ScrolledWindow sw_partitions;
	private TreeViewColumn col_device_target;
	private TreeViewColumn col_mount;
	private TreeViewColumn col_fs;
	private TreeViewColumn col_size;
	private TreeViewColumn col_dist;
	private CellRendererCombo cell_mount;
	
	//bootloader
	private Label lbl_header_bootloader;
	private ComboBox cmb_boot_device;
	private CheckButton chk_skip_grub_install;
	
	//apps
	private Label lbl_app;
	private Box vbox_app;
	private Label lbl_app_message;
	private TreeView tv_app;
	private ScrolledWindow sw_app;
	private TreeViewColumn col_app;

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
	
	private Device selected_target = null;
	
	public RestoreWindow () {
		this.title = _("Restore");
        this.window_position = WindowPosition.CENTER_ON_PARENT;
        this.set_destroy_with_parent (true);
		this.set_modal (true);
        this.set_default_size (550, 500);
		this.skip_taskbar_hint = true;
		this.icon = get_app_icon(16);
		
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
        
        //hbox_device
        Box hbox_device = new Box (Orientation.HORIZONTAL, 6);
        //hbox_device.margin = 6;
		vbox_target.add(hbox_device);

		//lbl_header_partitions
		lbl_header_partitions = new Gtk.Label((App.mirror_system ? _("Device for Cloning System") : _("Device for Restoring Snapshot")) + ":");
		lbl_header_partitions.xalign = (float) 0.0;
		lbl_header_partitions.set_use_markup(true);
		hbox_device.add(lbl_header_partitions);

		radio_sys = new RadioButton(null);
		hbox_device.add(radio_sys);
		radio_sys.label = "Current System";
		
		radio_other = new RadioButton.from_widget(radio_sys);
		hbox_device.add(radio_other);
		radio_other.label = "Other Device";

		if (App.live_system() || App.mirror_system){
			radio_other.active = true;
			radio_sys.sensitive = false;
		}
		else{
			radio_sys.sensitive = true;
			radio_sys.active = true;
		}
		
		radio_sys.toggled.connect(() => {
			sw_partitions.sensitive = radio_other.active;
			
			if (radio_sys.active){
				App.restore_target = App.root_device;
			}
			
			refresh_tv_partitions();
			//tv_partitions_select_target(); 
			cmb_boot_device_select_default();
		});
		
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
		tv_partitions.append_column(col_device_target);
		
		CellRendererPixbuf cell_device_icon = new CellRendererPixbuf ();
		cell_device_icon.stock_id = "gtk-harddisk";
		cell_device_icon.xpad = 1;
		col_device_target.pack_start (cell_device_icon, false);

		CellRendererText cell_device_target = new CellRendererText ();
		col_device_target.pack_start (cell_device_target, false);
		col_device_target.set_cell_data_func (cell_device_target, cell_device_target_render);

		//col_fs
		col_fs = new TreeViewColumn();
		col_fs.title = _("Type");
		CellRendererText cell_fs = new CellRendererText ();
		cell_fs.xalign = (float) 0.5;
		col_fs.pack_start (cell_fs, false);
		col_fs.set_cell_data_func (cell_fs, cell_fs_render);
		tv_partitions.append_column(col_fs);

		//col_mount
		col_mount = new TreeViewColumn();
		col_mount.title = _("Mount");
		cell_mount = new CellRendererCombo();
		cell_mount.xalign = (float) 0.0;
		cell_mount.editable = true;
		cell_mount.width = 70;
		col_mount.pack_start (cell_mount, false);
		col_mount.set_cell_data_func (cell_mount, cell_mount_render);
		tv_partitions.append_column(col_mount);
		
		cell_mount.set_property ("text-column", 0);
		col_mount.add_attribute (cell_mount, "text", 1);

		//populate combo
		ListStore model = new ListStore(1, typeof(string));
		cell_mount.model = model;
		
		TreeIter iter;
		model.append(out iter);
		model.set (iter, 0, "/");
		model.append(out iter);
		model.set (iter, 0, "/home");
		model.append(out iter);
		model.set (iter, 0, "/boot");

		cell_mount.changed.connect((path, iter_new) => {
			string val;
			cell_mount.model.get (iter_new, 0, out val);
			model = (ListStore) tv_partitions.model;
			model.get_iter_from_string (out iter, path);
			model.set (iter, 1, val);
		});
		
		cell_mount.edited.connect((path, new_text) => {
			model = (ListStore) tv_partitions.model;
			model.get_iter_from_string (out iter, path);
			model.set (iter, 1, new_text);
		});

		//col_size
		col_size = new TreeViewColumn();
		col_size.title = _("Size");
		CellRendererText cell_size = new CellRendererText ();
		cell_size.xalign = (float) 1.0;
		col_size.pack_start (cell_size, false);
		col_size.set_cell_data_func (cell_size, cell_size_render);
		tv_partitions.append_column(col_size);
				
		//col_dist
		col_dist = new TreeViewColumn();
		col_dist.title = _("System");
		CellRendererText cell_dist = new CellRendererText ();
		col_dist.pack_start (cell_dist, false);
		col_dist.set_cell_data_func (cell_dist, cell_dist_render);
		tv_partitions.append_column(col_dist);

		tv_partitions.set_tooltip_column(2);
		
		//bootloader options -------------------------------------------
		
		//lbl_header_bootloader
		lbl_header_bootloader = new Gtk.Label(_("Device for Bootloader Installation") + ":");
		lbl_header_bootloader.set_use_markup(true);
		lbl_header_bootloader.xalign = (float) 0.0;
		vbox_target.add(lbl_header_bootloader);
		
		//hbox_grub
		Box hbox_grub = new Box (Orientation.HORIZONTAL, 6);
		hbox_grub.margin_right = 6;
        //hbox_grub.margin_bottom = 6;
        vbox_target.add (hbox_grub);

		//cmb_boot_device
		cmb_boot_device = new ComboBox ();
		cmb_boot_device.hexpand = true;
		hbox_grub.add(cmb_boot_device);
		
		CellRendererText cell_dev_margin = new CellRendererText ();
		cell_dev_margin.text = "";
		cmb_boot_device.pack_start (cell_dev_margin, false);
		
		CellRendererPixbuf cell_dev_icon = new CellRendererPixbuf ();
		cell_dev_icon.stock_id = "gtk-harddisk";
		cmb_boot_device.pack_start (cell_dev_icon, false);
		
		CellRendererText cell_device_grub = new CellRendererText();
        cmb_boot_device.pack_start(cell_device_grub, false );
        cmb_boot_device.set_cell_data_func (cell_device_grub, cell_device_grub_render);
		
		string tt = "<b>" + _("** Advanced Users **") + "</b>\n\n"+ _("Skips bootloader (re)installation on target device.\nFiles in /boot directory on target partition will remain untouched.\n\nIf you are restoring a system that was bootable previously then it should boot successfully.\nOtherwise the system may fail to boot.");
		
		//chk_skip_grub_install
		chk_skip_grub_install = new CheckButton.with_label(_("Skip bootloader installation (not recommended)"));
		chk_skip_grub_install.active = false;
		chk_skip_grub_install.set_tooltip_markup(tt);
		vbox_target.add (chk_skip_grub_install);
		
		chk_skip_grub_install.toggled.connect(()=>{
			cmb_boot_device.sensitive = !chk_skip_grub_install.active;
		});
		
        //Exclude Apps tab ---------------------------------------------
		
		//lbl_apps
		lbl_app = new Label (_("Exclude"));

        //vbox_apps
        vbox_app = new Box(Gtk.Orientation.VERTICAL, 6);
        vbox_app.margin = 6;
        notebook.append_page (vbox_app, lbl_app);
		
		//lbl_app_message
		string msg = _("Select the applications for which current settings should be kept.") + "\n";
		msg += _("For all other applications, settings will be restored from selected snapshot.");
		lbl_app_message = new Label (msg);
		lbl_app_message.xalign = (float) 0.0;
		vbox_app.add(lbl_app_message);
		
		//tv_app-----------------------------------------------

		//tv_app
		tv_app = new TreeView();
		tv_app.get_selection().mode = SelectionMode.MULTIPLE;
		tv_app.headers_visible = false;
		tv_app.set_rules_hint (true);

		//sw_app
		sw_app = new ScrolledWindow(null, null);
		sw_app.set_shadow_type (ShadowType.ETCHED_IN);
		sw_app.add (tv_app);
		sw_app.expand = true;
		vbox_app.add(sw_app);

        //col_app
		col_app = new TreeViewColumn();
		col_app.title = _("Application");
		col_app.expand = true;
		tv_app.append_column(col_app);
		
		CellRendererText cell_app_margin = new CellRendererText ();
		cell_app_margin.text = "";
		col_app.pack_start (cell_app_margin, false);
		
		CellRendererToggle cell_app_enabled = new CellRendererToggle ();
		cell_app_enabled.radio = false;
		cell_app_enabled.activatable = true;
		col_app.pack_start (cell_app_enabled, false);
		col_app.set_cell_data_func (cell_app_enabled, cell_app_enabled_render);
		
		cell_app_enabled.toggled.connect (cell_app_enabled_toggled);
		
		CellRendererText cell_app_text = new CellRendererText ();
		col_app.pack_start (cell_app_text, false);
		col_app.set_cell_data_func (cell_app_text, cell_app_text_render);

        //Advanced tab ---------------------------------------------
		
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
		btn_remove = new Gtk.ToolButton.from_stock("gtk-remove");
		toolbar_exclude.add(btn_remove);
		
		btn_remove.is_important = true;
		btn_remove.label = _("Remove");
		btn_remove.set_tooltip_text (_("Remove selected items"));

		btn_remove.clicked.connect (btn_remove_clicked);

		//btn_warning
		btn_warning = new Gtk.ToolButton.from_stock("gtk-dialog-warning");
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
		btn_reset_exclude_list = new Gtk.ToolButton.from_stock("gtk-refresh");
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
        Gtk.Image img_restore = new Image.from_stock("gtk-go-forward", Gtk.IconSize.BUTTON);
		btn_restore.set_image(img_restore);
        btn_restore.clicked.connect (btn_restore_clicked);

        //btn_cancel
        btn_cancel = new Button();
        hbox_action.add(btn_cancel);
        
        btn_cancel.set_label (" " + _("Cancel"));
        btn_cancel.set_tooltip_text (_("Cancel"));
        Gtk.Image img_cancel = new Image.from_stock("gtk-cancel", Gtk.IconSize.BUTTON);
		btn_cancel.set_image(img_cancel);
        btn_cancel.clicked.connect (btn_cancel_clicked);

		//initialize -----------------------------------------

		btn_reset_exclude_list_clicked();

		refresh_tv_partitions();
		refresh_cmb_boot_device();
		//refresh_tv_exclude(); //called by btn_reset_exclude_list_clicked()
		refresh_tv_apps();

		sw_partitions.sensitive = radio_other.active;
		
		notebook.switch_page.connect_after((page, new_page_index) => {
			if (new_page_index == 1){
				bool ok = check_and_mount_devices();
				if (!ok){
					notebook.set_current_page(0);
					gtk_do_events();
					return;
				}

				//save current app selections
				Gee.ArrayList<string> selected_app_list = new Gee.ArrayList<string>();
				foreach(AppExcludeEntry entry in App.exclude_list_apps){
					if (entry.enabled){
						selected_app_list.add(entry.relpath);
					}
				}
				
				//refresh the list
				App.add_app_exclude_entries();
				
				//restore app selections
				foreach(AppExcludeEntry entry in App.exclude_list_apps){
					if (selected_app_list.contains(entry.relpath)){
						entry.enabled = true;
					}
				}
				
				//refresh treeview
				refresh_tv_apps();
			}
		});
		
		set_app_page_state();
	}
	
	private void set_app_page_state(){
		if (App.restore_target == null){
			lbl_app.sensitive = false;
			vbox_app.sensitive = false;
		}
		else{
			lbl_app.sensitive = true;
			vbox_app.sensitive = true;
		}
	}
	
	private void cell_device_target_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		Device pi;
		model.get (iter, 0, out pi, -1);
		
		string symlink = "";
		foreach(string sym in pi.symlinks){
			if (sym.has_prefix("/dev/mapper/")){
				symlink = sym.replace("/dev/mapper/","");
			}
		}

		if ((App.root_device != null) && (pi.device == App.root_device.device)){
			(cell as Gtk.CellRendererText).text = pi.name + " (" + _("sys") + ")" + ((symlink.length > 0) ? " → " + symlink : "");
		}
		else{
			(cell as Gtk.CellRendererText).text = pi.name + ((symlink.length > 0) ? " → " + symlink : "");
		}
		
		Gtk.CellRendererText ctxt = (cell as Gtk.CellRendererText);
		set_cell_text_color(ref ctxt);
	}
	
	private void set_cell_text_color(ref CellRendererText cell){
		string span = "<span>";
		if (!sw_partitions.sensitive){
			span = "<span foreground=\"#585858\">";
		}
		cell.markup = span + cell.text + "</span>";
	}
	
	private void cell_fs_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		Device pi;
		model.get (iter, 0, out pi, -1);
		(cell as Gtk.CellRendererText).text = pi.type;
		Gtk.CellRendererText ctxt = (cell as Gtk.CellRendererText);
		set_cell_text_color(ref ctxt);
	}
	
	private void cell_size_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		Device pi;
		model.get (iter, 0, out pi, -1);
		(cell as Gtk.CellRendererText).text = (pi.size_mb > 0) ? "%s GB".printf(pi.size) : "";
		Gtk.CellRendererText ctxt = (cell as Gtk.CellRendererText);
		set_cell_text_color(ref ctxt);
	}
	
	private void cell_mount_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		(cell as Gtk.CellRendererCombo).background = "#F2F5A9";
	}
	
	private void cell_dist_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		Device pi;
		model.get (iter, 0, out pi, -1);
		(cell as Gtk.CellRendererText).text = pi.dist_info;
		Gtk.CellRendererText ctxt = (cell as Gtk.CellRendererText);
		set_cell_text_color(ref ctxt);
	}
	
	
	private void cell_device_grub_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		Device dev;
		model.get (iter, 0, out dev, -1);
		if (dev.devtype == "disk"){
			(cell as Gtk.CellRendererText).markup = "<b>" + dev.description() + " (MBR)</b>";
		}
		else{
			(cell as Gtk.CellRendererText).markup = dev.description_formatted();
		}
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

	private void cell_app_enabled_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		AppExcludeEntry entry;
		model.get (iter, 0, out entry, -1);
		(cell as Gtk.CellRendererToggle).active = entry.enabled;
	}
	
	private void cell_app_text_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		AppExcludeEntry entry;
		model.get (iter, 0, out entry, -1);
		(cell as Gtk.CellRendererText).text = entry.relpath;
	}

	private void cell_app_enabled_toggled (string path){
		AppExcludeEntry entry;
		TreeIter iter;
		ListStore model = (ListStore) tv_app.model; //get model
		model.get_iter_from_string (out iter, path); //get selected iter
		model.get (iter, 0, out entry, -1); //get entry
		entry.enabled = !entry.enabled;
	}

	private void refresh_cmb_boot_device(){
		ListStore store = new ListStore(1, typeof(Device));
		
		//add devices
		Gee.ArrayList<Device> device_list = new Gee.ArrayList<Device>();
		foreach(Device di in get_block_devices()) {
			device_list.add(di);
		}
		
		//add partitions
		var list = App.partition_list;
		foreach(Device pi in list) {
			if (!pi.has_linux_filesystem()) { continue; }
			device_list.add(pi);
		}
		
		//sort
		device_list.sort((a,b) => { 
					Device p1 = (Device) a;
					Device p2 = (Device) b;
					
					return strcmp(p1.device,p2.device);
				});
				
		TreeIter iter;
		foreach(Device entry in device_list) {
			store.append(out iter);
			store.set (iter, 0, entry);
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
		ListStore store = (ListStore) cmb_boot_device.model;
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
			
			if ((first_mbr_device_index == -1) && (dev.device.length == "/dev/sdX".length)){
				first_mbr_device_index = index;
			}
		}
		
		//select first MBR device if not found
		if (cmb_boot_device.active == -1){
			cmb_boot_device.active = first_mbr_device_index;
		}
	}
	
	private void refresh_tv_partitions(){
		
		App.update_partition_list();
		
		ListStore model = new ListStore(3, typeof(Device), typeof(string), typeof(string));
		tv_partitions.set_model (model);

		TreeIter iter;
		foreach(Device pi in App.partition_list) {
			if (!pi.has_linux_filesystem()) { continue; }
			if (!radio_sys.sensitive && (App.root_device != null) && ((pi.device == App.root_device.device)||(pi.uuid == App.root_device.uuid))) { continue; }
			
			string symlink = "";
			foreach(string sym in pi.symlinks){
				if (sym.has_prefix("/dev/mapper/")){
					symlink = sym;
				}
			}
			
			string tt = "";
			tt += "%-7s".printf(_("Device")) + "\t: %s\n".printf(pi.device + ((symlink.length > 0) ? " → " + symlink : ""));
			tt += "%-7s".printf(_("UUID")) + "\t: %s\n".printf(pi.uuid);
			tt += "%-7s".printf(_("Type")) + "\t: %s\n".printf(pi.type);
			tt += "%-7s".printf(_("Label")) + "\t: %s\n".printf(pi.label);
			tt += "%-7s".printf(_("Size")) + "\t: %s\n".printf((pi.size_mb > 0) ? "%s GB".printf(pi.size) : "");
			tt += "%-7s".printf(_("Used")) + "\t: %s\n".printf((pi.used_mb > 0) ? "%s GB".printf(pi.used) : "");
			tt += "%-7s".printf(_("System")) + "\t: %s".printf(pi.dist_info);
			
			model.append(out iter);
			model.set (iter,0,pi,1,"",2,tt);
		}
		
		tv_partitions_select_target();
	}
	
	private void tv_partitions_select_target(){
		
		if (App.restore_target == null){ 
			tv_partitions.get_selection().unselect_all();
			return; 
		}
		
		TreeIter iter;
		ListStore store = (ListStore) tv_partitions.model;
		
		for (bool next = store.get_iter_first (out iter); next; next = store.iter_next (ref iter)) {
			Device pi;
			string mount_point;
			store.get(iter, 0, out pi);
			store.get(iter, 1, out mount_point);
			if (pi.device == App.restore_target.device){
				TreePath path = store.get_path(iter);
				tv_partitions.get_selection().select_path(path);
			}
		}
	}
	
	private void refresh_tv_exclude(){
		ListStore model = new ListStore(2, typeof(string), typeof(Gdk.Pixbuf));
		tv_exclude.model = model;
		
		foreach(string path in temp_exclude_list){
			tv_exclude_add_item(path);
		}
	}

	private void refresh_tv_apps(){
		ListStore model = new ListStore(1, typeof(AppExcludeEntry));
		tv_app.model = model;
		
		foreach(AppExcludeEntry entry in App.exclude_list_apps){
			TreeIter iter;
			model.append(out iter);
			model.set (iter, 0, entry, -1);
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
		Device restore_target = null;
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
		
		//select grub device
		if (selected_target == null){
			cmb_boot_device_select_default();
		}
		else if (selected_target.device != restore_target.device){
			cmb_boot_device_select_default(); 
		}
		else{
			//target device has not changed - do not reset to default boot device
		}
		selected_target = restore_target;
		
		set_app_page_state();
		
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
							"gtk-cancel", Gtk.ResponseType.CANCEL,
							"gtk-open", Gtk.ResponseType.ACCEPT);
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
							"gtk-cancel", Gtk.ResponseType.CANCEL,
							"gtk-open", Gtk.ResponseType.ACCEPT);
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
		//create a temp exclude list
		temp_exclude_list = new Gee.ArrayList<string>();
		
		//add all include/exclude items from snapshot list
		if (App.snapshot_to_restore != null){
			foreach(string path in App.snapshot_to_restore.exclude_list){
				if (!temp_exclude_list.contains(path) && !App.exclude_list_default.contains(path) && !App.exclude_list_home.contains(path)){
					temp_exclude_list.add(path);
				}
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
		
		//refresh treeview
		refresh_tv_exclude();
	}
	

	private void btn_restore_clicked(){

		//check if backup device is online
		if (!check_backup_device_online()) { return; }
		
		//Note: A successful restore will reboot the system if target device is same as system device
		
		bool ok = check_and_mount_devices();
		if (!ok){
			return;
		}

		//save grub install options ----------------------
		
		App.reinstall_grub2 = !chk_skip_grub_install.active;

		TreeIter iter;
		if (App.reinstall_grub2){
			Device entry;
			cmb_boot_device.get_active_iter (out iter);
			TreeModel model = (TreeModel) cmb_boot_device.model;
			model.get(iter, 0, out entry);
			App.grub_device = entry.device;
		}
		else{
			App.grub_device = "";
		}
		
		//save modified exclude list ----------------------
		
		App.exclude_list_restore.clear();
		
		//add default entries
		foreach(string path in App.exclude_list_default){
			if (!App.exclude_list_restore.contains(path)){
				App.exclude_list_restore.add(path);
			}
		}
		
		//add app entries
		foreach(AppExcludeEntry entry in App.exclude_list_apps){
			if (entry.enabled){
				string pattern = entry.pattern();
				if (!App.exclude_list_restore.contains(pattern)){
					App.exclude_list_restore.add(pattern);
				}
				
				pattern = entry.pattern(true);
				if (!App.exclude_list_restore.contains(pattern)){
					App.exclude_list_restore.add(pattern);
				}
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
		
		//exclude timeshift backups
		string timeshift_path = "/timeshift/*";
		if (!App.exclude_list_restore.contains(timeshift_path)){
			App.exclude_list_restore.add(timeshift_path);
		}
		
		//exclude boot directory if grub install is skipped
		if (!App.reinstall_grub2){
			App.exclude_list_restore.add("/boot/*");
		}
		
		//last option to quit - show disclaimer ------------
		
		if (show_disclaimer() == Gtk.ResponseType.YES){
			this.response(Gtk.ResponseType.OK);
		}
		else{
			this.response(Gtk.ResponseType.CANCEL);
		}
	}

	private bool check_backup_device_online(){
		if (!App.backup_device_online()){
			gtk_messagebox(_("Device Offline"),_("Backup device is not available"), null, true);
			return false;
		}
		else{
			return true;
		}
	}
	
	private bool check_and_mount_devices(){
		TreeIter iter;
		ListStore store;
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
			store = (ListStore) tv_partitions.model;
			for (bool next = store.get_iter_first (out iter); next; next = store.iter_next (ref iter)) {
				Device pi;
				string mount_point;
				store.get(iter, 0, out pi);
				store.get(iter, 1, out mount_point);

				if ((mount_point != null) && (mount_point.length > 0)){
					mount_point = mount_point.strip();
					no_mount_points_set_by_user = false;
					
					App.mount_list.add(new MountEntry(pi,mount_point));
					
					if (mount_point == "/"){
						App.restore_target = pi;
						break;
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
								App.mount_list.add(new MountEntry(pi,"/"));
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
		
		return true;
	}
	
	private int show_disclaimer(){
		string msg = App.disclaimer_pre_restore();
		msg += "\n\n";
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
		App.unmount_target_device();
		this.response(Gtk.ResponseType.CANCEL);
		return;	
	}

}
