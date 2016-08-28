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

	// tabs
	private Gtk.Box tab_estimate;
	private Gtk.Box tab_snapshot_location;
	private Gtk.Box tab_take_snapshot;
	private Gtk.Box tab_finish;
	private Gtk.Box tab_schedule;
	private Gtk.Box tab_include;
	private Gtk.Box tab_exclude;
	
	// tab_snapshot_location
	private Gtk.TreeView tv_devices;
	private Gtk.RadioButton radio_device;
	private Gtk.RadioButton radio_path;
	private Gtk.Entry entry_backup_path;
	private Gtk.InfoBar infobar_location;
	private Gtk.Label lbl_infobar_location;

	private Gtk.Image img_shield;
	private Gtk.Label lbl_shield;
	private Gtk.Label lbl_shield_subnote;

	// tab_final
	private Label lbl_final_message;

	// tab_take_snapshot
	private Gtk.Spinner spinner;
	private Gtk.Label lbl_msg;
	private Gtk.Label lbl_status;
	private ProgressBar progressbar;
	private Gtk.Label lbl_unchanged;
	private Gtk.Label lbl_created;
	private Gtk.Label lbl_deleted;
	private Gtk.Label lbl_modified;
	private Gtk.Label lbl_checksum;
	private Gtk.Label lbl_size;
	private Gtk.Label lbl_timestamp;
	private Gtk.Label lbl_permissions;
	private Gtk.Label lbl_owner;
	private Gtk.Label lbl_group;

	// tab_include, tab_exclude
	private Gtk.TreeView tv_exclude;
	private Gtk.TreeView tv_include;
	
	// actions
	private Gtk.ButtonBox box_actions;
	private Gtk.Button btn_prev;
	private Gtk.Button btn_next;
	private Gtk.Button btn_cancel;
	private Gtk.Button btn_close;

	private bool thread_is_running = false;
	
	private uint tmr_init;

	private string mode;

	private Gee.ArrayList<string> temp_exclude_list;

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

		this.delete_event.connect(on_delete_event);
		
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
			tab_include = create_tab_include();
			tab_exclude = create_tab_exclude();
		}

		if (mode != "create"){
			tab_finish = create_tab_final();
		}


		// TODO: Add separate tabs for include and exclude filters

		// TODO: Add a tab for excluding browser cache and other items
		
		// add handler after tabs are created
		notebook.switch_page.connect(page_changed);
		
		create_actions();

		show_all();

		tmr_init = Timeout.add(100, init_delayed);
    }

	private bool on_delete_event(Gdk.EventAny event){

		log_debug("WizardWindow: on_destroy_event()");
		
		//this.delete_event.disconnect(on_delete_event); //disconnect this handler

		if (mode == "settings"){
			tv_filters_save_changes();
		}
		
		return false; // close window
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
		//radio_device.toggled();
		//radio_path.toggled();
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
		//progressbar.set_size_request(-1,25);
		//progressbar.pulse_step = 0.1;
		box.add (progressbar);
		return box;
	}

	private Gtk.Box create_tab_snapshot_device(){
		var margin = (mode == "settings") ? 12 : 6;
		var box = add_tab(notebook, _("Backup"), margin);
		
		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		box.add(hbox);

		add_label_header(hbox, _("Select Snapshot Location"), true);

		// buffer
		var label = add_label(hbox, "");
        label.hexpand = true;
       
		// radio
		//radio_device = add_radio(hbox, "<b>%s</b>".printf(_("Disk Partition:")), null);

		// buffer
		//var label = add_label(hbox, "");
       // label.hexpand = true;
        
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

		/*radio_device.toggled.connect(() =>{
			tv_devices.sensitive = radio_device.active;

			if (radio_device.active){
				if (App.repo.device != null){
					App.repo = new SnapshotRepo.from_device(App.repo.device, this);
					check_backup_location();
				}
				log_debug("radio_device.toggled: active");
			}
		});*/

		// treeview
		create_device_list(box);

		// tooltips
		//radio_device.set_tooltip_text(msg);
		tv_devices.set_tooltip_text(msg);

		// section path -------------------------------------

		/*
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

		*/
		
		// infobar
		create_infobar_location(box);

		// tooltips
		//radio_path.set_tooltip_text(msg);
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
		lbl_status.margin_bottom = 12;

		var label = add_label(box, "");
		label.vexpand = true;
		
		// add count labels ---------------------------------
		
		Gtk.SizeGroup sg_label = null;
		Gtk.SizeGroup sg_value = null;
		
		lbl_unchanged = add_count_label(box, _("No Change"), ref sg_label, ref sg_value, 12);

		lbl_created = add_count_label(box, _("Created"), ref sg_label, ref sg_value);
		lbl_deleted = add_count_label(box, _("Deleted"), ref sg_label, ref sg_value);
		lbl_modified = add_count_label(box, _("Changed"), ref sg_label, ref sg_value, 12);

		lbl_checksum = add_count_label(box, _("Checksum"), ref sg_label, ref sg_value);
		lbl_size = add_count_label(box, _("Size"), ref sg_label, ref sg_value);
		lbl_timestamp = add_count_label(box, _("Timestamp"), ref sg_label, ref sg_value);
		lbl_permissions = add_count_label(box, _("Permissions"), ref sg_label, ref sg_value);
		lbl_owner = add_count_label(box, _("Owner"), ref sg_label, ref sg_value);
		lbl_group = add_count_label(box, _("Group"), ref sg_label, ref sg_value, 24);

		return box;
	}

	private Gtk.Label add_count_label(Gtk.Box box, string text,
		ref Gtk.SizeGroup? sg_label, ref Gtk.SizeGroup? sg_value,
		int add_margin_bottom = 0){
			
		var hbox = new Box (Orientation.HORIZONTAL, 6);
		box.add (hbox);

		var label = add_label(hbox, text + ":");
		label.xalign = (float) 0.0;
		label.margin_left = 12;
		label.margin_right = 6;

		if (add_margin_bottom > 0){
			label.margin_bottom = add_margin_bottom;
		}

		// add to size group
		if (sg_label == null){
			sg_label = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		}
		sg_label.add_widget(label);

		label = add_label(hbox, "");
		label.xalign = (float) 0.0;

		if (add_margin_bottom > 0){
			label.margin_bottom = add_margin_bottom;
		}

		// add to size group
		if (sg_value == null){
			sg_value = new Gtk.SizeGroup(SizeGroupMode.HORIZONTAL);
		}
		sg_value.add_widget(label);

		return label;
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

	private Gtk.Box create_tab_include(){
		var margin = (mode == "settings") ? 12 : 6;
		var box = add_tab(notebook, _("Include"), margin);
		box.spacing = 6;

		add_label_header(box, _("Include Files"), true);

		add_label(box, _("Include these items in snapshots:"));

		// tv_exclude-----------------------------------------------

		// tv_include
		var treeview = new TreeView();
		treeview.get_selection().mode = SelectionMode.MULTIPLE;
		treeview.headers_visible = false;
		treeview.rules_hint = true;
		treeview.reorderable = true;
		//tv_exclude.row_activated.connect(tv_exclude_row_activated);
		tv_include = treeview;
		
		// scrolled
		var scrolled = new ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.add (tv_include);
		scrolled.expand = true;
		box.add(scrolled);

        // column
		var col = new TreeViewColumn();
		col.title = _("File Pattern");
		col.expand = true;
		tv_include.append_column(col);
		
		// margin
		var cell_text = new CellRendererText ();
		cell_text.text = "";
		col.pack_start (cell_text, false);

		// icon
		var cell_icon = new CellRendererPixbuf ();
		col.pack_start (cell_icon, false);
		col.set_attributes(cell_icon, "pixbuf", 1);

		// pattern
		cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);
		col.set_cell_data_func (cell_text, cell_exclude_text_render);
		//cell_text.editable = true;
		
		//cell_text.edited.connect (cell_exclude_text_edited);

		/* // link
		var link = new LinkButton.with_label("",_("Some locations are excluded by default"));
		link.xalign = (float) 0.0;
		link.activate_link.connect(lnk_default_list_activate);
		box.add(link);
		*
		* */

		// actions

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		box.add(hbox);
		
		Gtk.SizeGroup size_group = null;
		var button = add_button(hbox, _("Add Files"),
			_("Add files to this list"), ref size_group, null);
        button.clicked.connect(()=>{
			menu_include_add_files_clicked();
		});

		size_group = null;
		button = add_button(hbox, _("Add Folders"),
			_("Add folders to this list"), ref size_group, null);
        button.clicked.connect(()=>{
			menu_include_add_folder_clicked();
		});

		size_group = null;
		button = add_button(hbox, _("Add Contents"),
			_("Add the contents of a folder to this list"), ref size_group, null);
        button.clicked.connect(()=>{
			menu_include_add_folder_contents_clicked();
		});

		size_group = null;
		button = add_button(hbox, _("Remove"), "", ref size_group, null);
        button.clicked.connect(()=>{
			btn_include_remove_clicked();
		});


		//initialize ------------------

		temp_exclude_list = new Gee.ArrayList<string>();

		foreach(string path in App.exclude_list_user){
			if (!temp_exclude_list.contains(path)){
				temp_exclude_list.add(path);
			}
		}

		refresh_tv_include();
		
		return box;
	}

	private Gtk.Box create_tab_exclude(){
		var margin = (mode == "settings") ? 12 : 6;
		var box = add_tab(notebook, _("Exclude"), margin);
		box.spacing = 6;

		add_label_header(box, _("Exclude Files"), true);

		add_label(box, _("Exclude these items in snapshots:"));

		// tv_exclude-----------------------------------------------

		// tv_exclude
		var treeview = new TreeView();
		treeview.get_selection().mode = SelectionMode.MULTIPLE;
		treeview.headers_visible = false;
		treeview.rules_hint = true;
		treeview.reorderable = true;
		//tv_exclude.row_activated.connect(tv_exclude_row_activated);
		tv_exclude = treeview;
		
		// scrolled
		var scrolled = new ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		scrolled.add (tv_exclude);
		scrolled.expand = true;
		box.add(scrolled);

        // column
		var col = new TreeViewColumn();
		col.title = _("File Pattern");
		col.expand = true;
		tv_exclude.append_column(col);
		
		// margin
		var cell_text = new CellRendererText ();
		cell_text.text = "";
		col.pack_start (cell_text, false);

		// icon
		var cell_icon = new CellRendererPixbuf ();
		col.pack_start (cell_icon, false);
		col.set_attributes(cell_icon, "pixbuf", 1);

		// pattern
		cell_text = new CellRendererText ();
		col.pack_start (cell_text, false);
		col.set_cell_data_func (cell_text, cell_exclude_text_render);
		//cell_text.editable = true;
		
		//cell_text.edited.connect (cell_exclude_text_edited);

		/* // link
		var link = new LinkButton.with_label("",_("Some locations are excluded by default"));
		link.xalign = (float) 0.0;
		link.activate_link.connect(lnk_default_list_activate);
		box.add(link);
		*
		* */

		// actions
		
		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		box.add(hbox);

		Gtk.SizeGroup size_group = null;
		var button = add_button(hbox, _("Add Files"),
			_("Add files to this list"), ref size_group, null);
        button.clicked.connect(()=>{
			menu_exclude_add_files_clicked();
		});

		size_group = null;
		button = add_button(hbox, _("Add Folders"),
			_("Add folders to this list"), ref size_group, null);
        button.clicked.connect(()=>{
			menu_exclude_add_folder_clicked();
		});

		size_group = null;
		button = add_button(hbox, _("Add Contents"),
			_("Add the contents of a folder to this list"), ref size_group, null);
        button.clicked.connect(()=>{
			menu_exclude_add_folder_contents_clicked();
		});

		size_group = null;
		button = add_button(hbox, _("Remove"), "", ref size_group, null);
        button.clicked.connect(()=>{
			btn_exclude_remove_clicked();
		});


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
			tv_filters_save_changes();
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
		tv_devices.headers_clickable = true;
		tv_devices.rules_hint = true;
		tv_devices.activate_on_single_click = true;
		
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

		// size
		
		col = add_column_text(tv_devices, _("Size"), out cell_text);
		cell_text.xalign = (float) 1.0;
		
		col.set_cell_data_func(cell_text, (cell_layout, cell, model, iter)=>{
			Device dev;
			model.get (iter, 0, out dev, -1);

			(cell as Gtk.CellRendererText).text =
					(dev.size_bytes > 0) ? format_file_size(dev.size_bytes) : "";
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

		gtk_set_busy(true, this);

		log_debug("\n");
		log_debug("selected device: %s".printf(pi.device));
		log_debug("fstype: %s".printf(pi.fstype));

		App.repo = new SnapshotRepo.from_device(pi, this);

		if (pi.fstype == "luks"){
			App.update_partitions();

			var dev = Device.find_device_in_list(App.partitions, pi.device, pi.uuid);
			
			if (dev.has_children()){
				
				log_debug("has children");
				
				if (dev.children[0].has_linux_filesystem()){
					
					log_debug("has linux filesystem: %s".printf(dev.children[0].fstype));
					log_debug("selecting child '%s' of parent '%s'".printf(
						dev.children[0].device, dev.device));
						
					App.repo = new SnapshotRepo.from_device(dev.children[0], this);
					tv_devices_refresh();
				}
				else{
					log_debug("does not have linux filesystem");
				}
			}
		}

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
				msg += _("◈ Scheduled snapshots are disabled. It's recommended to enable it.") + "\n\n";
			}
		}

		msg += _("◈ You can rollback your system to a previous date by restoring a snapshot.") + "\n\n";

		msg += _("◈ Restoring a snapshot only replaces system files and settings. Documents and other files in your home directory will not be touched. You can change this by adding a filter to include these files. Any files that you include will be backed up when a snapshot is created, and replaced when the snapshot is restored.") + "\n\n";

		msg += _("◈ If the system is unable to boot, you can rescue your system by installing and running Timeshift on the Ubuntu Live CD / USB.") + "\n\n";

		msg += _("◈ To guard against hard disk failures, select an external disk for the snapshot location instead of the primary hard disk.") + "\n\n";

		msg += _("◈ Avoid storing snapshots on your system partition. Using another partition will allow you to format and re-install the OS on your system partition without losing the snapshots stored on it. You can even install another Linux distribution and later roll-back the previous distribution by restoring the snapshot.") + "\n\n";

		msg += _("◈ The first snapshot creates a copy of all files on your system. Subsequent snapshots only store files which have changed. You can reduce the size of snapshots by adding filters to exclude files which are not required. For example, you can exclude your web browser cache as these files change constantly and are not very important.") + "\n\n";

		msg += _("◈ Common files are hard-linked between snapshots. Copying the files manually to another location will duplicate the files and break hard-links between them. Snapshots must be moved carefully by running 'rsync' from a terminal and the file system at destination path must support hard-links.") + "\n\n";
		
		lbl_final_message.label = msg;
	}
	
	// filters ----------------

	private void refresh_tv_include(){
		var model = new Gtk.ListStore(2, typeof(string), typeof(Gdk.Pixbuf));
		tv_include.model = model;

		foreach(string path in temp_exclude_list){
			if (path.has_prefix("+ ")){
				treeview_filters_add_item(tv_include, path);
			}
		}
	}

	private void refresh_tv_exclude(){
		var model = new Gtk.ListStore(2, typeof(string), typeof(Gdk.Pixbuf));
		tv_exclude.model = model;

		foreach(string path in temp_exclude_list){
			if (!path.has_prefix("+ ")){
				treeview_filters_add_item(tv_exclude, path);
			}
		}
	}

	private void treeview_filters_add_item(Gtk.TreeView treeview, string path){
		Gdk.Pixbuf pix_exclude = null;
		Gdk.Pixbuf pix_include = null;
		Gdk.Pixbuf pix_selected = null;

		try{
			pix_exclude = new Gdk.Pixbuf.from_file (
				App.share_folder + "/timeshift/images/item-gray.png");
			pix_include = new Gdk.Pixbuf.from_file (
				App.share_folder + "/timeshift/images/item-blue.png");
		}
        catch(Error e){
	        log_error (e.message);
	    }

		TreeIter iter;
		var model = (Gtk.ListStore) treeview.model;
		model.append(out iter);

		if (path.has_prefix("+ ")){
			pix_selected = pix_include;
		}
		else{
			pix_selected = pix_exclude;
		}

		model.set (iter, 0, path, 1, pix_selected, -1);

		var adj = treeview.get_hadjustment();
		adj.value = adj.upper;
	}

	private void cell_exclude_text_render (
		CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		string pattern;
		model.get (iter, 0, out pattern, -1);
		(cell as Gtk.CellRendererText).text = pattern.has_prefix("+ ") ? pattern[2:pattern.length] : pattern;
	}

	private void cell_exclude_text_edited (
		string path, string new_text) {
			
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

	private void tv_filters_save_changes(){
		App.exclude_list_user.clear();
		
		// add include list
		TreeIter iter;
		var store = (Gtk.ListStore) tv_include.model;
		bool iterExists = store.get_iter_first (out iter);
		while (iterExists) {
			string path;
			store.get (iter, 0, out path);

			if (!App.exclude_list_user.contains(path)
				&& !App.exclude_list_default.contains(path)
				&& !App.exclude_list_home.contains(path)){
				
				App.exclude_list_user.add(path);
			}
			
			iterExists = store.iter_next (ref iter);
		}

		// add exclude list
		store = (Gtk.ListStore) tv_exclude.model;
		iterExists = store.get_iter_first (out iter);
		while (iterExists) {
			string path;
			store.get (iter, 0, out path);

			if (!App.exclude_list_user.contains(path)
				&& !App.exclude_list_default.contains(path)
				&& !App.exclude_list_home.contains(path)){
				
				App.exclude_list_user.add(path);
			}
			
			iterExists = store.iter_next (ref iter);
		}

		log_debug("tv_filters_save_changes()");
		foreach(var item in App.exclude_list_user){
			log_debug(item);
		}
		log_debug("");
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

	// TODO: Add link for default exclude items
	
	private void btn_exclude_remove_clicked(){
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

		tv_filters_save_changes();

		refresh_tv_exclude();
	}

	private void menu_exclude_add_files_clicked(){

		var list = browse_files();

		if (list.length() > 0){
			foreach(string path in list){
				if (!temp_exclude_list.contains(path)){
					temp_exclude_list.add(path);
					treeview_filters_add_item(tv_exclude, path);
					log_debug("exclude file: %s".printf(path));
					Main.first_snapshot_size = 0; //re-calculate
				}
				else{
					log_debug("temp_exclude_list contains: %s".printf(path));
				}
			}
		}

		tv_filters_save_changes();
	}

	private void menu_exclude_add_folder_clicked(){

		var list = browse_folder();

		if (list.length() > 0){
			foreach(string path in list){

				path = path + "/";

				if (!temp_exclude_list.contains(path)){
					temp_exclude_list.add(path);
					treeview_filters_add_item(tv_exclude, path);
					log_debug("exclude folder: %s".printf(path));
					Main.first_snapshot_size = 0; //re-calculate
				}
				else{
					log_debug("temp_exclude_list contains: %s".printf(path));
				}
			}
		}

		tv_filters_save_changes();
	}

	private void menu_exclude_add_folder_contents_clicked(){

		var list = browse_folder();

		if (list.length() > 0){
			foreach(string path in list){

				path = path + "/*";

				if (!temp_exclude_list.contains(path)){
					temp_exclude_list.add(path);
					treeview_filters_add_item(tv_exclude, path);
					log_debug("exclude contents: %s".printf(path));
					Main.first_snapshot_size = 0; //re-calculate
				}
				else{
					log_debug("temp_exclude_list contains: %s".printf(path));
				}
			}
		}

		tv_filters_save_changes();
	}


	private void btn_include_remove_clicked(){
		TreeSelection sel = tv_include.get_selection ();
		TreeIter iter;
		bool iterExists = tv_include.model.get_iter_first (out iter);
		while (iterExists) {
			if (sel.iter_is_selected (iter)){
				string path;
				tv_include.model.get (iter, 0, out path);
				temp_exclude_list.remove(path);
				Main.first_snapshot_size = 0; //re-calculate
			}
			iterExists = tv_include.model.iter_next (ref iter);
		}

		tv_filters_save_changes();
		
		refresh_tv_include();
	}
	
	private void menu_include_add_files_clicked(){

		var list = browse_files();

		if (list.length() > 0){
			foreach(string path in list){

				path = path.has_prefix("+ ") ? path : "+ " + path;

				if (!temp_exclude_list.contains(path)){
					temp_exclude_list.add(path);
					treeview_filters_add_item(tv_include,path);
					log_debug("include file: %s".printf(path));
					Main.first_snapshot_size = 0; //re-calculate
				}
				else{
					log_debug("temp_exclude_list contains: %s".printf(path));
				}
			}
		}

		tv_filters_save_changes();
	}

	private void menu_include_add_folder_clicked(){

		var list = browse_folder();

		if (list.length() > 0){
			foreach(string path in list){

				path = path.has_prefix("+ ") ? path : "+ " + path;
				path = path + "/***";

				if (!temp_exclude_list.contains(path)){
					temp_exclude_list.add(path);
					treeview_filters_add_item(tv_include,path);
					log_debug("include folder: %s".printf(path));
					Main.first_snapshot_size = 0; //re-calculate
				}
				else{
					log_debug("temp_exclude_list contains: %s".printf(path));
				}
			}
		}

		tv_filters_save_changes();
	}

	private void menu_include_add_folder_contents_clicked(){

		var list = browse_folder();

		if (list.length() > 0){
			foreach(string path in list){
				path = path.has_prefix("+ ") ? path : "+ " + path;
				path = path + "/*";

				if (!temp_exclude_list.contains(path)){
					temp_exclude_list.add(path);
					treeview_filters_add_item(tv_include, path);
					log_debug("include contents: %s".printf(path));
					Main.first_snapshot_size = 0; //re-calculate
				}
				else{
					log_debug("temp_exclude_list contains: %s".printf(path));
				}
			}
		}

		tv_filters_save_changes();
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

		try {
			thread_is_running = true;
			Thread.create<void> (take_snapshot_thread, true);
		}
		catch (Error e) {
			log_error (e.message);
		}

		//string last_message = "";
		int wait_interval_millis = 100;
		int status_line_counter = 0;
		int status_line_counter_default = 1000 / wait_interval_millis;
		string status_line = "";
		string last_status_line = "";
		
		while (thread_is_running){

			status_line = escape_html(App.task.status_line);
			if (status_line != last_status_line){
				lbl_status.label = status_line;
				last_status_line = status_line;
				status_line_counter = status_line_counter_default;
			}
			else{
				status_line_counter--;
				if (status_line_counter < 0){
					status_line_counter = status_line_counter_default;
					lbl_status.label = "";
				}
			}

			// TODO: show estimated time remaining and file counts

			double fraction = (App.task.status_line_count * 1.0)
				/ Main.first_snapshot_count;

			progressbar.fraction = fraction;

			lbl_msg.label = App.progress_text;

			lbl_unchanged.label = "%'d".printf(App.task.count_unchanged);
			lbl_created.label = "%'d".printf(App.task.count_created);
			lbl_deleted.label = "%'d".printf(App.task.count_deleted);
			lbl_modified.label = "%'d".printf(App.task.count_modified);
			lbl_checksum.label = "%'d".printf(App.task.count_checksum);
			lbl_size.label = "%'d".printf(App.task.count_size);
			lbl_timestamp.label = "%'d".printf(App.task.count_timestamp);
			lbl_permissions.label = "%'d".printf(App.task.count_permissions);
			lbl_owner.label = "%'d".printf(App.task.count_owner);
			lbl_group.label = "%'d".printf(App.task.count_group);

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
		else if (notebook.page == page_num_include){
			// do nothing, page will not be visible when mode != "settings"
		}
		else if (notebook.page == page_num_exclude){
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
		else if (notebook.page == page_num_include){
		//	notebook.page = page_num_exclude;
		}
		else if (notebook.page == page_num_exclude){
		//	notebook.page = page_num_finish;
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
		else if (page_num == page_num_include){
			// do nothing
		}
		else if (page_num == page_num_exclude){
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
		else if (page_num == page_num_include){
			// do nothing
		}
		else if (page_num == page_num_exclude){
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

	private int page_num_include{
		get {
			return notebook.page_num(tab_include);
		}
	}

	private int page_num_exclude{
		get {
			return notebook.page_num(tab_exclude);
		}
	}

	// ui helpers ------------------------

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
