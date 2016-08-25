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
	private Gtk.RadioButton radio_device;
	private Gtk.RadioButton radio_path;
	private Gtk.Entry entry_backup_path;
	private Gtk.InfoBar infobar_location;
	private Gtk.Label lbl_infobar_location;

	private Gtk.Image img_shield;
	private Gtk.Label lbl_shield;
	private Gtk.Label lbl_shield_subnote;

	private Label lbl_final_message;

	private Gtk.Box tab_estimate;
	private Gtk.Box tab_snapshot_location;
	private Gtk.Box tab_take_snapshot;
	private Gtk.Box tab_finish;
	private Gtk.Box tab_schedule;
	private Gtk.Box tab_filters;
	
	private Gtk.Spinner spinner;
	private Gtk.Label lbl_msg;
	private Gtk.Label lbl_status;
	private Gtk.TextView txtv_create;
	private ProgressBar progressbar;

	private Gtk.ButtonBox box_actions;
	private Gtk.Button btn_prev;
	private Gtk.Button btn_next;
	private Gtk.Button btn_cancel;
	private Gtk.Button btn_close;

	private bool show_finish_page = false;

	private bool thread_is_running = false;
	
	private uint tmr_init;

	private string mode;


	//exclude
	
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

	private bool show_dummy_progress = false;
	
	public WizardWindow (string _mode) {

		if (_mode.length == 0){
			this.title = "Setup Wizard";
		}
		else{
			this.title = "";
		}

        this.window_position = WindowPosition.CENTER;
        this.modal = true;
        this.set_default_size (500, 500);
		//this.delete_event.connect(on_delete_event);
		this.icon = get_app_icon(16);

	    // vbox_main
        var box = new Box (Orientation.VERTICAL, 6);
        box.margin = 0; // keep 0 as we will hide tabs in Wizard view
        add(box);
		vbox_main = box;

		mode = _mode;
        
		notebook = add_notebook(box, (mode == "settings"), (mode == "settings"));
		notebook.margin = 6;

		if (mode != "settings"){
			tab_estimate = create_tab_estimate_system_size();
		}

		tab_snapshot_location = create_tab_snapshot_device();

		if (mode != "settings"){
			tab_take_snapshot = create_tab_first_snapshot();
		}

		tab_schedule = create_tab_schedule();

		if (mode == "settings"){
			tab_filters = create_tab_filters();
		}

		if (mode != "create"){
			tab_finish = create_tab_final();
		}

		// add handler after tabs are created
		notebook.switch_page.connect(page_changed);
		
		create_actions();

		show_all();

		tmr_init = Timeout.add(100, init_delayed);
    }

    private bool init_delayed(){

		if (tmr_init > 0){
			Source.remove(tmr_init);
			tmr_init = 0;
		}

		if (App.repo.snapshot_path_user.length > 0){
			entry_backup_path.text = App.repo.snapshot_path_user;
		}

		if (App.repo.use_snapshot_path_custom){
			radio_path.active = true;
		}
		else{
			radio_device.active = true;
		}

		tv_devices_refresh();
		radio_device.toggled();
		radio_path.toggled();
		check_backup_location();
		chk_schedule_changed();

		go_first();

		return false;
	}
	
	private Gtk.Box create_tab_estimate_system_size(){

		var margin = (mode == "settings") ? 12 : 6;
		var box = add_tab(notebook, _("Estimate"), margin);
		
		add_label_header(box, _("Estimating System Size..."), true);

		var hbox_status = new Gtk.Box (Orientation.HORIZONTAL, 6);
		box.add (hbox_status);
		
		var spinner = new Gtk.Spinner();
		spinner.active = true;
		hbox_status.add(spinner);
		
		//lbl_msg
		var lbl_msg = add_label(hbox_status, "Please wait...");
		lbl_msg.halign = Align.START;
		lbl_msg.ellipsize = Pango.EllipsizeMode.END;
		lbl_msg.max_width_chars = 50;

		//progressbar
		var progressbar = new Gtk.ProgressBar();
		progressbar.set_size_request(-1,25);
		//progressbar.pulse_step = 0.1;
		box.add (progressbar);
		return box;
	}

	private Gtk.Box create_tab_snapshot_device(){
		var margin = (mode == "settings") ? 12 : 6;
		var box = add_tab(notebook, _("Snapshot Device"), margin);
		
		add_label_header(box, _("Select Snapshot Location"), true);

		// section device -------------------------------------

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		box.add(hbox);
		
		// radio
		radio_device = add_radio(hbox, "<b>%s</b>".printf(_("Disk Partition:")), null);

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
		
		var msg = _("Only Linux partitions are supported.");
		msg += "\n" + _("Snapshots will be saved in folder /timeshift");
				
		//var lbl_device_subnote = add_label_subnote(box,msg);

		radio_device.toggled.connect(() =>{
			tv_devices.sensitive = radio_device.active;

			if (radio_device.active){
				if (App.repo.device != null){
					App.repo = new SnapshotRepo.from_device(App.repo.device, this);
					check_backup_location();
				}
				log_debug("radio_device.toggled: active");
			}
		});

		// treeview
		create_device_list(box);

		// tooltips
		radio_device.set_tooltip_text(msg);
		tv_devices.set_tooltip_text(msg);

		// section path -------------------------------------

		// radio
		radio_path = add_radio(box, "<b>%s</b>".printf(_("Custom Path:")), radio_device);
		radio_path.margin_top = 12;

		msg = _("File system at selected path must support hard-links");
		//var lbl_path_subnote = add_label_subnote(box,msg);

		// chooser
		entry_backup_path = add_directory_chooser(box, App.repo.snapshot_path_user);
		entry_backup_path.margin_bottom = 12;
		
		radio_path.toggled.connect(()=>{
			entry_backup_path.sensitive = radio_path.active;

			if (radio_path.active){
				if (App.repo != null){
					App.repo = new SnapshotRepo.from_path(App.repo.snapshot_path_user, this);
					check_backup_location();
				}
				log_debug("radio_path.toggled: active");
			}
		});

		// infobar
		create_infobar_location(box);

		// tooltips
		radio_path.set_tooltip_text(msg);
		entry_backup_path.set_tooltip_text(msg);

		return box;
	}

	private Gtk.Box create_tab_first_snapshot(){
		var margin = (mode == "settings") ? 12 : 6;
		var box = add_tab(notebook, _("Create Snapshot"), margin);
		
		add_label_header(box, _("Creating Snapshot..."), true);

		var hbox_status = new Box (Orientation.HORIZONTAL, 6);
		box.add (hbox_status);
		
		spinner = new Gtk.Spinner();
		spinner.active = true;
		hbox_status.add(spinner);
		
		//lbl_msg
		lbl_msg = add_label(hbox_status, _("Preparing..."));
		lbl_msg.halign = Align.START;
		lbl_msg.ellipsize = Pango.EllipsizeMode.END;
		lbl_msg.max_width_chars = 50;

		//progressbar
		progressbar = new Gtk.ProgressBar();
		//progressbar.set_size_request(-1,25);
		//progressbar.show_text = true;
		//progressbar.pulse_step = 0.1;
		box.add (progressbar);

		//lbl_status

		lbl_status = add_label(box, "");
		lbl_status.ellipsize = Pango.EllipsizeMode.MIDDLE;
		lbl_status.max_width_chars = 45;
		
		//txtv_create = add_text_view(box, "");
		//txtv_create.margin_top = 12;

		return box;
	}

	private Gtk.Box create_tab_schedule(){
		var margin = (mode == "settings") ? 12 : 6;
		var box = add_tab(notebook, _("Schedule"), margin);
		box.spacing = 6;

		add_label_header(box, _("Select Snapshot Intervals"), true);

		Gtk.CheckButton chk_m, chk_w, chk_d, chk_h, chk_b;
		Gtk.SpinButton spin_m, spin_w, spin_d, spin_h, spin_b;

		// monthly
		
		add_schedule_option(box, _("Monthly"), _("Create one per month"), out chk_m, out spin_m);

		chk_m.active = App.schedule_monthly;
		chk_m.toggled.connect(()=>{
			App.schedule_monthly = chk_m.active;
			spin_m.sensitive = chk_m.active;
			chk_schedule_changed();
		});

		spin_m.set_value(App.count_monthly);
		spin_m.sensitive = chk_m.active;
		spin_m.value_changed.connect(()=>{
			App.count_monthly = (int) spin_m.get_value();
		});
		
		// weekly
		
		add_schedule_option(box, _("Weekly"), _("Create one per week"), out chk_w, out spin_w);

		chk_w.active = App.schedule_weekly;
		chk_w.toggled.connect(()=>{
			App.schedule_weekly = chk_w.active;
			spin_w.sensitive = chk_w.active;
			chk_schedule_changed();
		});

		spin_w.set_value(App.count_weekly);
		spin_w.sensitive = chk_w.active;
		spin_w.value_changed.connect(()=>{
			App.count_weekly = (int) spin_w.get_value();
		});

		// daily
		
		add_schedule_option(box, _("Daily"), _("Create one per day"), out chk_d, out spin_d);

		chk_d.active = App.schedule_daily;
		chk_d.toggled.connect(()=>{
			App.schedule_daily = chk_d.active;
			spin_d.sensitive = chk_d.active;
			chk_schedule_changed();
		});

		spin_d.set_value(App.count_daily);
		spin_d.sensitive = chk_d.active;
		spin_d.value_changed.connect(()=>{
			App.count_daily = (int) spin_d.get_value();
		});

		// hourly
		
		add_schedule_option(box, _("Hourly"), _("Create one per hour"), out chk_h, out spin_h);

		chk_h.active = App.schedule_hourly;
		chk_h.toggled.connect(()=>{
			App.schedule_hourly = chk_h.active;
			spin_h.sensitive = chk_h.active;
			chk_schedule_changed();
		});

		spin_h.set_value(App.count_hourly);
		spin_h.sensitive = chk_h.active;
		spin_h.value_changed.connect(()=>{
			App.count_hourly = (int) spin_h.get_value();
		});

		// boot
		
		add_schedule_option(box, _("Boot"), _("Create one per boot"), out chk_b, out spin_b);

		chk_b.active = App.schedule_boot;
		chk_b.toggled.connect(()=>{
			App.schedule_boot = chk_b.active;
			spin_b.sensitive = chk_b.active;
			chk_schedule_changed();
		});

		spin_b.set_value(App.count_boot);
		spin_b.sensitive = chk_b.active;
		spin_b.value_changed.connect(()=>{
			App.count_boot = (int) spin_b.get_value();
		});
		
		// buffer
		var label = new Gtk.Label("");
		label.vexpand = true;
		box.add(label);

		// shield
		var hbox = new Gtk.Box (Orientation.HORIZONTAL, 6);
        hbox.margin_bottom = 6;
        hbox.margin_left = 6;
        hbox.margin_right = 6;
        box.add (hbox);

        // img_shield
		img_shield = new Gtk.Image();
		img_shield.pixbuf = get_shared_icon("security-high", "security-high.svg", 48).pixbuf;
        hbox.add(img_shield);

		var vbox = new Box (Orientation.VERTICAL, 6);
		vbox.margin_bottom = 0;
        hbox.add (vbox);
        
		// lbl_shield
		lbl_shield = add_label(vbox, "");
        lbl_shield.margin_bottom = 0;
        lbl_shield.yalign = (float) 0.5;
        lbl_shield.hexpand = true;

        // lbl_shield_subnote
		lbl_shield_subnote = add_label(vbox, "");
		lbl_shield_subnote.yalign = (float) 0.5;
		lbl_shield_subnote.hexpand = true;

		lbl_shield_subnote.wrap = true;
		lbl_shield_subnote.wrap_mode = Pango.WrapMode.WORD;
		
		return box;
	}

	private Gtk.Box create_tab_filters(){
		var margin = (mode == "settings") ? 12 : 6;
		var box = add_tab(notebook, _("Filters"), margin);
		box.spacing = 6;

		add_label_header(box, _("Select Files to Include & Exclude"), true);

		//toolbar_exclude ---------------------------------------------------

        //toolbar_exclude
		toolbar_exclude = new Gtk.Toolbar ();
		toolbar_exclude.toolbar_style = ToolbarStyle.BOTH_HORIZ;
		//toolbar_exclude.get_style_context().add_class(Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
		//toolbar.set_size_request(-1,48);
		box.add(toolbar_exclude);

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
		btn_reset_exclude_list.set_tooltip_text (_("Clear the list"));

		btn_reset_exclude_list.clicked.connect (btn_reset_exclude_list_clicked);

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
		box.add(sw_exclude);

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

		// link
		var link = new LinkButton.with_label("",_("Some locations are excluded by default"));
		link.xalign = (float) 0.0;
		link.activate_link.connect(lnk_default_list_activate);
		box.add(link);

		//initialize ------------------

		temp_exclude_list = new Gee.ArrayList<string>();

		foreach(string path in App.exclude_list_user){
			if (!temp_exclude_list.contains(path)){
				temp_exclude_list.add(path);
			}
		}

		refresh_tv_exclude();
		
		return box;
	}

	private Gtk.Box create_tab_final(){
		var margin = (mode == "settings") ? 12 : 6;
		var box = add_tab(notebook, _("Notes"), margin);

		if (mode != "settings"){
			add_label_header(box, _("Setup Complete"), true);
		}
		
		lbl_final_message = add_label_scrolled(box, "", false, true, 0);

		update_final_message();
		
		return box;
	}


	private void create_actions(){
		var hbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
		hbox.set_layout (Gtk.ButtonBoxStyle.EXPAND);
		hbox.margin = 0;
		//hbox.margin_top = 24;
		hbox.margin_left = 24;
		hbox.margin_right = 24;
		hbox.margin_bottom = 12;
        vbox_main.add(hbox);
		box_actions = hbox;
		
		Gtk.SizeGroup size_group = null;
		
		// previous
		
		Gtk.Image img = new Image.from_stock("gtk-go-back", Gtk.IconSize.BUTTON);
		btn_prev = add_button(hbox, _("Previous"), "", ref size_group, img);
		
        btn_prev.clicked.connect(()=>{
			go_prev();
		});

		// next
		
		img = new Image.from_stock("gtk-go-forward", Gtk.IconSize.BUTTON);
		btn_next = add_button(hbox, _("Next"), "", ref size_group, img);

        btn_next.clicked.connect(()=>{
			go_next();
		});

		// close
		
		img = new Image.from_stock("gtk-close", Gtk.IconSize.BUTTON);
		btn_close = add_button(hbox, _("Close"), "", ref size_group, img);

        btn_close.clicked.connect(()=>{
			App.cron_job_update();
			this.destroy();
		});

		// cancel
		
		img = new Image.from_stock("gtk-cancel", Gtk.IconSize.BUTTON);
		btn_cancel = add_button(hbox, _("Cancel"), "", ref size_group, img);

        btn_cancel.clicked.connect(()=>{
			if (App.task != null){
				App.task.stop(AppStatus.CANCELLED);
			}
			
			this.destroy(); // TODO: Show error page
		});
	}
	
	private void create_device_list(Gtk.Box box){
		tv_devices = add_treeview(box);
		tv_devices.vexpand = true;
		tv_devices.rules_hint = true;
		
		// device name
		
		Gtk.CellRendererPixbuf cell_pix;
		Gtk.CellRendererToggle cell_radio;
		Gtk.CellRendererText cell_text;
		//var col = add_column_radio_and_text(tv_devices, _("Disk"), out cell_radio, out cell_text);
		var col = add_column_icon_radio_text(tv_devices, _("Disk"),
			out cell_pix, out cell_radio, out cell_text);
		
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
				(dev.type != "disk") && ((dev.fstype != "luks") || (dev.children.size == 0));
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
					(dev.free_bytes > 0) ? format_file_size(dev.free_bytes) : "";
			}

			(cell as Gtk.CellRendererText).sensitive = (dev.type != "disk");
		});
		
		// size
		
		col = add_column_text(tv_devices, _("Size"), out cell_text);
		cell_text.xalign = (float) 1.0;
		
		col.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
			Device dev;
			model.get (iter, 0, out dev, -1);

			(cell as Gtk.CellRendererText).text =
					(dev.size_bytes > 0) ? format_file_size(dev.size_bytes) : "";
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

		tv_devices.cursor_changed.connect(() => {
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

	private void create_infobar_location(Gtk.Box box){

		// dummy
		//var label = add_label(box, "");
		//label.vexpand = true;
		
		var infobar = new Gtk.InfoBar();
		infobar.no_show_all = true;
		box.add(infobar);
		infobar_location = infobar;
		
		var content = (Gtk.Box) infobar.get_content_area ();
		var label = add_label(content, "");
		lbl_infobar_location = label;
	}


	private void try_change_device(Device dev){

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
		else if (!dev.has_children()){
			change_backup_device(dev);
		}
		else if (dev.has_children()){
			change_backup_device(dev.children[0]);
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

		gtk_set_busy(true, this);
		
		App.repo = new SnapshotRepo.from_device(pi, this);

		App.update_partitions();
		var newpi = Device.find_device_in_list(App.partitions,pi.device,pi.uuid);

		//log_debug("newpi: %s".printf(pi.device));
		//log_debug("pi.fstype: %s".printf(pi.fstype));
		//log_debug("pi.child_device: %s".printf(
		//	(pi.children.size == 0) ? "null" : pi.children[0].device));
		
		if ((pi.fstype == "luks") && !pi.has_children() && newpi.has_children()){
			App.repo = new SnapshotRepo.from_device(newpi.children[0], this);
			tv_devices_refresh();
		}

		//if (App.snapshot_device != null){
		//	log_msg("Snapshot device: %s".printf(App.snapshot_device.description()));
		//}

		check_backup_location();

		gtk_set_busy(false, this);
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

		TreeIter iter0, iter_selected, iter_dummy;

		model.append(out iter_dummy, null);
		iter_selected = iter_dummy;
		model.clear();

		foreach(var disk in App.partitions) {
			if (disk.type != "disk") { continue; }

			model.append(out iter0, null);
			model.set(iter0, 0, disk, -1);
			model.set(iter0, 1, disk.tooltip_text(), -1);
			model.set(iter0, 2, pix_device, -1);
			model.set(iter0, 3, false, -1);

			tv_append_child_volumes(ref model, ref iter0, disk, ref iter_selected);
		}

		//TODO: pre-select the current App.snapshot_device

		//if (iter_selected != iter_dummy){
			//tv_devices.get_selection().select_iter(iter_selected);
		//}

		tv_devices.expand_all();
		tv_devices.columns_autosize();
	}

	private void tv_append_child_volumes(
		ref Gtk.TreeStore model, ref Gtk.TreeIter iter0,
		Device parent, ref Gtk.TreeIter iter_selected){
			
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
					//iter_selected = iter1;
					model.set(iter1, 3, true, -1);
				}
				else{
					model.set(iter1, 3, false, -1);
				}

				tv_append_child_volumes(ref model, ref iter1, part, ref iter_selected);
			}
		}
	}

	private void chk_schedule_changed(){
		if (App.schedule_monthly || App.schedule_weekly || App.schedule_daily
		|| App.schedule_hourly || App.schedule_boot){

			img_shield.pixbuf =
				get_shared_icon("", "security-high.svg", Main.SHIELD_ICON_SIZE).pixbuf;
			set_shield_label(_("Scheduled snapshots are enabled"));
			set_shield_subnote(_("Snapshots will be created at selected intervals if snapshot disk has enough space (> 1 GB)"));
		}
		else{
			img_shield.pixbuf =
				get_shared_icon("", "security-low.svg", Main.SHIELD_ICON_SIZE).pixbuf;
			set_shield_label(_("Scheduled snapshots are disabled"));
			set_shield_subnote(_("Select the intervals for creating snapshots"));
		}
	}

	private void update_final_message(){

		var msg = "";

		if (mode != "settings"){
			if (App.scheduled){
				msg += _("◈ Scheduled snapshots are enabled. Snapshots will be created automatically at selected intervals.") + "\n\n";
			}
			else{
				msg += _("◈ Scheduled snapshots are disabled. It's recommended to enable it so that you have a recent snapshot of your system to restore in case of issues.") + "\n\n";
			}
		}

		msg += _("◈ You can rollback your system to a previous date by restoring a snapshot.") + "\n\n";

		msg += _("◈ Restoring a snapshot only replaces system files and settings. Documents and other files in your home directory will not be affected. You can change this in Settings by adding a filter to include these files.") + "\n\n";

		msg += _("◈ If the system is unable to boot, you can rescue your system by installing and running Timeshift on the Ubuntu Live CD / USB.") + "\n\n";

		msg += _("◈ To guard against hard disk failures, select an external disk for the snapshot location instead of the primary hard disk.") + "\n\n";

		msg += _("◈ Avoid storing snapshots on your system partition. Using another partition will allow you to format and re-install the OS on your system partition without losing the snapshots stored on it. You can even install another Linux distribution and later roll-back the previous distribution by restoring the snapshot.") + "\n\n";

		msg += _("◈ Snapshots only store files which have changed. You can reduce the size by adding filters to exclude files which are not required.") + "\n\n";

		msg += _("◈ Common files are hard-linked between snapshots. Copying the files manually to another location will duplicate files and break hard-links. Snapshots must be moved carefully by running 'rsync' from a terminal and the file system at destination path must support hard-links.") + "\n\n";
		
		lbl_final_message.label = msg;
	}
	
	// filters ----------------

	private void refresh_tv_exclude(){
		var model = new Gtk.ListStore(2, typeof(string), typeof(Gdk.Pixbuf));
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
		var model = (Gtk.ListStore) tv_exclude.model;
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

	private void cell_exclude_text_render (
		CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		string pattern;
		model.get (iter, 0, out pattern, -1);
		(cell as Gtk.CellRendererText).text = pattern.has_prefix("+ ") ? pattern[2:pattern.length] : pattern;
	}

	private void cell_exclude_text_edited (string path, string new_text) {
		string old_pattern;
		string new_pattern;

		TreeIter iter;
		var model = (Gtk.ListStore) tv_exclude.model;
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

	private void tv_exclude_save_changes(){
		App.exclude_list_user.clear();
		foreach(string path in temp_exclude_list){
			if (!App.exclude_list_user.contains(path) && !App.exclude_list_default.contains(path) && !App.exclude_list_home.contains(path)){
				App.exclude_list_user.add(path);
			}
		}
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
				Main.first_snapshot_size = 0; //re-calculate
			}
			iterExists = tv_exclude.model.iter_next (ref iter);
		}

		refresh_tv_exclude();
	}

	private void btn_warning_clicked(){
		string msg = "";
		msg += _("Documents, music and other folders in your home directory are excluded by default.") + " ";
		msg += _("Please do NOT include these folders in your snapshot unless you have a very good reason for doing so.") + " ";
		msg += _("If you include any specific folders then these folders will get overwritten with previous contents when you restore a snapshot.");

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

		//refresh treeview --------------------------

		refresh_tv_exclude();
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


	private void menu_exclude_add_files_clicked(){

		var list = browse_files();

		if (list.length() > 0){
			foreach(string path in list){
				if (!temp_exclude_list.contains(path)){
					temp_exclude_list.add(path);
					tv_exclude_add_item(path);
					Main.first_snapshot_size = 0; //re-calculate
				}
			}
		}

		tv_exclude_save_changes();
	}

	private void menu_exclude_add_folder_clicked(){

		var list = browse_folder();

		if (list.length() > 0){
			foreach(string path in list){

				path = path + "/";

				if (!temp_exclude_list.contains(path)){
					temp_exclude_list.add(path);
					tv_exclude_add_item(path);
					Main.first_snapshot_size = 0; //re-calculate
				}
			}
		}

		tv_exclude_save_changes();
	}

	private void menu_exclude_add_folder_contents_clicked(){

		var list = browse_folder();

		if (list.length() > 0){
			foreach(string path in list){

				path = path + "/*";

				if (!temp_exclude_list.contains(path)){
					temp_exclude_list.add(path);
					tv_exclude_add_item(path);
					Main.first_snapshot_size = 0; //re-calculate
				}
			}
		}

		tv_exclude_save_changes();
	}

	private void menu_include_add_files_clicked(){

		var list = browse_files();

		if (list.length() > 0){
			foreach(string path in list){

				path = path.has_prefix("+ ") ? path : "+ " + path;

				if (!temp_exclude_list.contains(path)){
					temp_exclude_list.add(path);
					tv_exclude_add_item(path);
					Main.first_snapshot_size = 0; //re-calculate
				}
			}
		}

		tv_exclude_save_changes();
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
					Main.first_snapshot_size = 0; //re-calculate
				}
			}
		}

		tv_exclude_save_changes();
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

	// actions
	
	private void estimate_system_size(){
		if (Main.first_snapshot_size == 0){
			App.calculate_size_of_first_snapshot();
			App.save_app_config();
		}
	}

	private void take_snapshot(){

		show_dummy_progress = (App.repo.snapshots.size > 0);

		try {
			thread_is_running = true;
			Thread.create<void> (take_snapshot_thread, true);
		}
		catch (Error e) {
			log_error (e.message);
		}

		string last_message = "";
		
		while (thread_is_running){

			lbl_status.label = escape_html(App.task.status_line);
			//string line = null;
			//while((line = App.task.status_lines.pop_head()) != null){
				//text_view_append(txtv_create, line + "\n");
				//text_view_scroll_to_end(txtv_create);
				//lbl_status.label = line;
				//gtk_do_events();
			//}
			
			if (show_dummy_progress){
				if (progressbar.fraction < 99.0){	
					progressbar.fraction = progressbar.fraction + 0.0005;
				}
			}
			else{
				double fraction = (App.task.status_line_count * 1.0)
					/ Main.first_snapshot_count;

				progressbar.fraction = fraction;
			}

			if (App.progress_text != last_message){
				progressbar.fraction = 0;
				lbl_msg.label = App.progress_text;
				last_message = App.progress_text;
			}
	
			gtk_do_events();

			sleep(100);
			//gtk_do_events();
		}

		//TODO: check errors.

		go_next();
	}
	
	private void take_snapshot_thread(){
		App.take_snapshot(true,"",this);
		thread_is_running = false;
	}

	// navigation

	private void page_changed(Widget page, uint page_num){
		
	}
	
	private void go_first(){
		
		// set initial tab
		
		if (App.live_system()){
			// skip tab_estimate and go to tab_snapshot_location
			notebook.page = page_num_snapshot_location;
		}
		else{
			if (Main.first_snapshot_size == 0){
				if (notebook.page != page_num_estimate){
					notebook.page = page_num_estimate;
				}
			}
			else{
				// skip tab_estimate
				notebook.page = page_num_snapshot_location;
				
				if (mode == "create"){
					// skip tab_snapshot_location if valid
					go_next();
				}
			}
		}

		initialize_tab(notebook.page);
	}
	
	private void go_prev(){
		// btn_previous is visible only when mode != "settings"
		
		if (notebook.page == page_num_estimate){
			// do nothing, btn_previous is disabled for this page
		}
		else if (notebook.page == page_num_snapshot_location){
			// do nothing, btn_previous is disabled for this page
		}
		else if (notebook.page == page_num_take_snapshot){
			// do nothing, btn_previous is disabled for this page
		}
		else if (notebook.page == page_num_schedule){
			notebook.page = page_num_snapshot_location;
		}
		else if (notebook.page == page_num_filters){
			// do nothing, page will not be visible when mode != "settings"
		}
		else if (notebook.page == page_num_finish){
			notebook.page = page_num_schedule;
		}

		initialize_tab(notebook.page);
	}
	
	private void go_next(){
		// btn_next is visible only when mode != "settings"
		
		if (!validate_current_tab()){
			return;
		}

		if (notebook.page == page_num_estimate){
			notebook.page = page_num_snapshot_location;
		}
		else if (notebook.page == page_num_snapshot_location){

			if (!App.repo.has_snapshots() || (mode == "create")){
				notebook.page = page_num_take_snapshot;
			}
			else{
				notebook.page = page_num_schedule;
			}
		}
		else if (notebook.page == page_num_take_snapshot){
			if (mode == "create"){
				destroy();
			}
			else{
				notebook.page = page_num_schedule;
			}
		}
		else if (notebook.page == page_num_schedule){
			notebook.page = page_num_finish;
		}
		else if (notebook.page == page_num_filters){
			notebook.page = page_num_finish;
		}
		else if (notebook.page == page_num_finish){
			// do nothing, btn_next is disabled for this page
		}

		initialize_tab(notebook.page);
	}

	private void initialize_tab(int page_num){

		if (page_num < 0){
			return;
		}

		log_msg("");
		log_debug("page: %d".printf(page_num));

		// show/hide actions -----------------------------------

		if (mode == "wizard"){
			if ((page_num == page_num_estimate)
				|| (page_num == page_num_take_snapshot)){

				btn_prev.hide();
				btn_next.hide();
				btn_close.hide();
				
				btn_cancel.show();
				box_actions.set_layout (Gtk.ButtonBoxStyle.CENTER);
			}
			else{
				btn_prev.show();
				btn_next.show();
				btn_close.show();
				
				btn_cancel.hide();
				box_actions.set_layout (Gtk.ButtonBoxStyle.EXPAND);
			}
		}
		else if (mode == "create"){
			btn_prev.hide();
			btn_next.hide();
			btn_cancel.show();
			btn_close.hide();
			box_actions.set_layout (Gtk.ButtonBoxStyle.CENTER);
		}
		else{
			btn_prev.hide();
			btn_next.hide();
			btn_cancel.hide();
			btn_close.show();
			box_actions.set_layout (Gtk.ButtonBoxStyle.CENTER);
		}
		
		// enable/disable actions ---------------------------------

		btn_prev.sensitive = btn_prev.visible;
		btn_next.sensitive = btn_next.visible;
			
		if (page_num == page_num_estimate){
			// do nothing
		}
		else if (page_num == page_num_snapshot_location){
			btn_prev.sensitive = false;
		}
		else if (page_num == page_num_take_snapshot){
			// do nothing
		}
		else if (page_num == page_num_schedule){
			// do nothing
		}
		else if (page_num == page_num_filters){
			// do nothing
		}
		else if (page_num == page_num_finish){
			btn_next.sensitive = false;
		}
		
		// start actions -------------------
	
		if (page_num == page_num_estimate){
			estimate_system_size();
			go_next();
		}
		else if (page_num == page_num_snapshot_location){
			check_backup_location();
		}
		else if (page_num == page_num_take_snapshot){
			take_snapshot();
			go_next();
		}
		else if (page_num == page_num_schedule){
			// do nothing
		}
		else if (page_num == page_num_filters){
			// do nothing
		}
		else if (page_num == page_num_finish){
			update_final_message();
		}
	}

	private bool validate_current_tab(){
		
		if (notebook.page == page_num_snapshot_location){
			if (!check_backup_location()){
				
				gtk_messagebox(App.repo.status_message,
					App.repo.status_details, this, true);
					
				return false;
			}
		}

		return true;
	}

	// properties ---------------------------------

	private int page_num_estimate{
		get {
			return notebook.page_num(tab_estimate);
		}
	}

	private int page_num_snapshot_location{
		get {
			return notebook.page_num(tab_snapshot_location);
		}
	}

	private int page_num_take_snapshot{
		get {
			return notebook.page_num(tab_take_snapshot);
		}
	}

	private int page_num_finish{
		get {
			return notebook.page_num(tab_finish);
		}
	}

	private int page_num_schedule{
		get {
			return notebook.page_num(tab_schedule);
		}
	}

	private int page_num_filters{
		get {
			return notebook.page_num(tab_filters);
		}
	}

	// utility ------------------
	
	private Gtk.Notebook add_notebook(Gtk.Box box, bool show_tabs = true, bool show_border = true){
        // notebook
		var book = new Gtk.Notebook();
		book.margin = 6;
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
		treeview.show_expanders = true;
		treeview.enable_tree_lines = true;

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

	private Gtk.TreeViewColumn add_column_icon_and_text(
		Gtk.TreeView treeview, string title,
		out Gtk.CellRendererPixbuf cell_pix, out Gtk.CellRendererText cell_text){
			
		// TreeViewColumn
		var col = new Gtk.TreeViewColumn();
		col.title = title;

		cell_pix = new Gtk.CellRendererPixbuf();
		cell_pix.xpad = 2;
		col.pack_start (cell_pix, false);
		
		cell_text = new Gtk.CellRendererText();
		cell_text.xalign = (float) 0.0;
		col.pack_start (cell_text, false);
		treeview.append_column(col);

		return col;
	}

	private Gtk.TreeViewColumn add_column_radio_and_text(
		Gtk.TreeView treeview, string title,
		out Gtk.CellRendererToggle cell_radio, out Gtk.CellRendererText cell_text){
			
		// TreeViewColumn
		var col = new Gtk.TreeViewColumn();
		col.title = title;

		cell_radio = new Gtk.CellRendererToggle();
		cell_radio.xpad = 2;
		cell_radio.radio = true;
		cell_radio.activatable = true;
		col.pack_start (cell_radio, false);
		
		cell_text = new Gtk.CellRendererText();
		cell_text.xalign = (float) 0.0;
		col.pack_start (cell_text, false);
		treeview.append_column(col);

		return col;
	}

	private Gtk.TreeViewColumn add_column_icon_radio_text(
		Gtk.TreeView treeview, string title,
		out Gtk.CellRendererPixbuf cell_pix,
		out Gtk.CellRendererToggle cell_radio,
		out Gtk.CellRendererText cell_text){
			
		// TreeViewColumn
		var col = new Gtk.TreeViewColumn();
		col.title = title;

		cell_pix = new Gtk.CellRendererPixbuf();
		cell_pix.xpad = 2;
		col.pack_start (cell_pix, false);

		cell_radio = new Gtk.CellRendererToggle();
		cell_radio.xpad = 2;
		cell_radio.radio = true;
		cell_radio.activatable = true;
		col.pack_start (cell_radio, false);
		
		cell_text = new Gtk.CellRendererText();
		cell_text.xalign = (float) 0.0;
		col.pack_start (cell_text, false);
		treeview.append_column(col);

		return col;
	}

	private Gtk.Label add_label_scrolled(
		Gtk.Box box, string text,
		bool show_border = false, bool wrap = false, int ellipsize_chars = 40){

		// ScrolledWindow
		var scroll = new Gtk.ScrolledWindow(null, null);
		scroll.hscrollbar_policy = PolicyType.NEVER;
		scroll.vscrollbar_policy = PolicyType.ALWAYS;
		scroll.expand = true;
		box.add(scroll);
		
		var label = new Gtk.Label(text);
		label.xalign = (float) 0.0;
		label.yalign = (float) 0.0;
		label.margin = 6;
		scroll.add(label);

		if (wrap){
			label.wrap = true;
			label.wrap_mode = Pango.WrapMode.WORD;
		}

		if (ellipsize_chars > 0){
			label.wrap = false;
			label.ellipsize = Pango.EllipsizeMode.MIDDLE;
			label.max_width_chars = ellipsize_chars;
		}

		if (show_border){
			scroll.set_shadow_type (ShadowType.ETCHED_IN);
		}
		else{
			label.margin_left = 0;
		}
		
		return label;
	}

	private Gtk.TextView add_text_view(
		Gtk.Box box, string text){

		// ScrolledWindow
		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.hscrollbar_policy = PolicyType.NEVER;
		scrolled.vscrollbar_policy = PolicyType.ALWAYS;
		scrolled.expand = true;
		box.add(scrolled);
		
		var view = new Gtk.TextView();
		view.wrap_mode = Gtk.WrapMode.WORD_CHAR;
		view.accepts_tab = false;
		view.editable = false;
		view.cursor_visible = false;
		view.buffer.text = text;
		view.sensitive = false;
		scrolled.add (view);

		return view;
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
		
		var label = add_label(box, escape_html(text), true, false, large_heading);
		label.margin_bottom = 12;
		return label;
	}

	private Gtk.Label add_label_subnote(
		Gtk.Box box, string text){
		
		var label = add_label(box, text, false, true);
		label.margin_left = 6;
		return label;
	}

	private Gtk.RadioButton add_radio(
		Gtk.Box box, string text, Gtk.RadioButton? another_radio_in_group){

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

	private Gtk.CheckButton add_checkbox(
		Gtk.Box box, string text){

		var chk = new Gtk.CheckButton.with_label(text);
		chk.label = text;
		box.add(chk);

		foreach(var child in chk.get_children()){
			if (child is Gtk.Label){
				var label = (Gtk.Label) child;
				label.use_markup = true;
				break;
			}
		}
		
		/*
		chk.toggled.connect(()=>{
			chk.active;
		});
		*/

		return chk;
	}

	private Gtk.SpinButton add_spin(
		Gtk.Box box, double min, double max, double val,
		int digits = 0, double step = 1, double step_page = 1){

		var adj = new Gtk.Adjustment(val, min, max, step, step_page, 0);
		var spin  = new Gtk.SpinButton(adj, step, digits);
		spin.xalign = (float) 0.5;
		box.add(spin);

		/*
		spin.value_changed.connect(()=>{
			label.sensitive = spin.sensitive;
		});
		*/

		return spin;
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
		//entry.margin_left = 6;
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

				App.repo = new SnapshotRepo.from_path(entry.text, this);
				check_backup_location();
			}

			chooser.destroy();
		});

		return entry;
	}

	private void set_shield_label(
		string text, bool is_bold = true, bool is_italic = false, bool is_large = true){
			
		string msg = "<span%s%s%s>%s</span>".printf(
			(is_bold ? " weight=\"bold\"" : ""),
			(is_italic ? " style=\"italic\"" : ""),
			(is_large ? " size=\"x-large\"" : ""),
			escape_html(text));
			
		lbl_shield.label = msg;
	}

	private void set_shield_subnote(
		string text, bool is_bold = false, bool is_italic = true, bool is_large = false){
			
		string msg = "<span%s%s%s>%s</span>".printf(
			(is_bold ? " weight=\"bold\"" : ""),
			(is_italic ? " style=\"italic\"" : ""),
			(is_large ? " size=\"x-large\"" : ""),
			escape_html(text));
			
		lbl_shield_subnote.label = msg;
	}

	private void add_schedule_option(
		Gtk.Box box, string period, string period_desc,
		out Gtk.CheckButton chk, out Gtk.SpinButton spin){

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		box.add(hbox);
		
        var txt = "<b>%s</b> - %s".printf(period, period_desc);
		chk = add_checkbox(hbox, txt);

		var label = add_label(hbox, "");
		label.hexpand = true;

		var tt = _("Number of snapshots to keep.\nOlder snapshots will be removed once this limit is exceeded.");
		label = add_label(hbox, _("Keep"));
		label.set_tooltip_text(tt);
		
		var spin2 = add_spin(hbox, 1, 999, 10);
		spin2.set_tooltip_text(tt);
		
		spin2.notify["sensitive"].connect(()=>{
			label.sensitive = spin2.sensitive;
		});

		spin = spin2;
	}
}
