/*
 * SettingsWindow.vala
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

public class SettingsWindow : Gtk.Dialog{
	private Box vbox_main;
	private Notebook notebook;

	//schedule
	private Label lbl_schedule;
	private Box vbox_schedule;
	private Box hbox_auto_snapshots;
	private Label lbl_header_schedule;
	private Switch switch_schedule;
	private TreeView tv_schedule;
	private ScrolledWindow sw_schedule;
	private TreeViewColumn col_sched_enable;
	private TreeViewColumn col_sched_level;
	private TreeViewColumn col_sched_desc;

	//auto_remove
	private Label lbl_auto_remove;
	private Box vbox_auto_remove;
	private TreeView tv_remove;
	private ScrolledWindow sw_remove;
	private TreeViewColumn col_remove_rule;
	private TreeViewColumn col_remove_limit;
	private TreeViewColumn col_remove_units;

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
        
	//actions
	private Button btn_save;
	private Button btn_cancel;
	
	private Gee.ArrayList<string> temp_exclude_list;
	
	public SettingsWindow () {
		this.deletable = false;
		this.title = _("Settings");
        this.window_position = WindowPosition.CENTER_ON_PARENT;
        this.set_destroy_with_parent (true);
		this.set_modal (true);
        this.set_default_size (450, 500);	

        //set app icon
		try{
			this.icon = new Gdk.Pixbuf.from_file (App.share_folder + """/pixmaps/timeshift.png""");
		}
        catch(Error e){
	        log_error (e.message);
	    }
	    
	    //vboxMain
        vbox_main = get_content_area ();
        
        //notebook
		notebook = new Notebook ();
		notebook.margin = 6;
		vbox_main.pack_start (notebook, true, true, 0);

        //schedule tab ---------------------------------------------
		
		//lbl_schedule
		lbl_schedule = new Label (_("Schedule"));

        //vbox_schedule
        vbox_schedule = new Box (Gtk.Orientation.VERTICAL, 6);
        vbox_schedule.margin = 6;
        notebook.append_page (vbox_schedule, lbl_schedule);
		
		//automatic snapshots ------------------------------
		
        //hbox_auto_snapshots
        hbox_auto_snapshots = new Box (Gtk.Orientation.HORIZONTAL, 6);
        vbox_schedule.add (hbox_auto_snapshots);
        
        //lbl_header_schedule
		lbl_header_schedule = new Gtk.Label("<b>" + _("Scheduled Snapshots") + "</b>");
		lbl_header_schedule.set_use_markup(true);
		lbl_header_schedule.hexpand = true;
		lbl_header_schedule.xalign = (float) 0.0;
		lbl_header_schedule.valign = Align.CENTER;
		hbox_auto_snapshots.add(lbl_header_schedule);
		
		Box hbox_schedule = new Box(Orientation.HORIZONTAL,0);
        hbox_auto_snapshots.add(hbox_schedule);
        
		//switch_schedule
        switch_schedule = new Gtk.Switch();
        switch_schedule.set_size_request(100,20);
        switch_schedule.active = App.is_scheduled;
        hbox_auto_snapshots.pack_end(switch_schedule,false,false,0);
        
        switch_schedule.notify["active"].connect(switch_schedule_changed);
		
		//tv_schedule -----------------------------------------------
		
        //tv_schedule
		tv_schedule = new TreeView();
		tv_schedule.get_selection().mode = SelectionMode.MULTIPLE;
		tv_schedule.set_rules_hint (true);
		
		//sw_schedule
		sw_schedule = new ScrolledWindow(null, null);
		sw_schedule.set_shadow_type (ShadowType.ETCHED_IN);
		sw_schedule.add (tv_schedule);
		sw_schedule.expand = true;
		vbox_schedule.add(sw_schedule);

		//col_sched_enable
		col_sched_enable = new TreeViewColumn();
		col_sched_enable.title = " " + _("Enable") + " ";
		CellRendererToggle cell_sched_enable = new CellRendererToggle ();
		cell_sched_enable.activatable = true;
		cell_sched_enable.toggled.connect (cell_sched_enable_toggled);
		col_sched_enable.pack_start (cell_sched_enable, false);
		col_sched_enable.set_cell_data_func (cell_sched_enable, cell_sched_enable_render);
		tv_schedule.append_column(col_sched_enable);

		//col_sched_level
		col_sched_level = new TreeViewColumn();
		col_sched_level.title = " " + _("Backup Level") + " ";
		CellRendererText cell_sched_level = new CellRendererText ();
		col_sched_level.pack_start (cell_sched_level, false);
		col_sched_level.set_cell_data_func (cell_sched_level, cell_sched_level_render);
		tv_schedule.append_column(col_sched_level);
		
		//col_sched_desc
		col_sched_desc = new TreeViewColumn();
		col_sched_desc.title = " " + _("Description") + " ";
		col_sched_desc.expand = true;
		CellRendererText cell_sched_desc = new CellRendererText ();
		col_sched_desc.pack_start (cell_sched_desc, false);
		col_sched_desc.set_cell_data_func (cell_sched_desc, cell_sched_desc_render);
		tv_schedule.append_column(col_sched_desc);
		
		//auto-remove tab ------------------------------------------------------
		
		//lbl_auto_remove
		lbl_auto_remove = new Label (_("Auto-Remove"));

        //grid_auto_remove
        vbox_auto_remove = new Box(Gtk.Orientation.VERTICAL, 6);
        vbox_auto_remove.margin = 6;
        notebook.append_page (vbox_auto_remove, lbl_auto_remove);

		//tv_remove
		tv_remove = new TreeView();
		tv_remove.get_selection().mode = SelectionMode.MULTIPLE;
		tv_remove.set_rules_hint (true);
		
		//sw_remove
		sw_remove = new ScrolledWindow(null, null);
		sw_remove.set_shadow_type (ShadowType.ETCHED_IN);
		sw_remove.add (tv_remove);
		sw_remove.expand = true;
		vbox_auto_remove.add(sw_remove);

		//col_remove_rule
		col_remove_rule = new TreeViewColumn();
		col_remove_rule.title = " " + _("Rule") + " ";
		CellRendererText cell_remove_rule = new CellRendererText ();
		col_remove_rule.pack_start (cell_remove_rule, false);
		col_remove_rule.set_cell_data_func (cell_remove_rule, cell_remove_rule_render);
		tv_remove.append_column(col_remove_rule);
		
		//col_sched_desc
		col_remove_limit = new TreeViewColumn();
		col_remove_limit.title = " " + _("Limit") + " ";
		CellRendererText cell_remove_limit = new CellRendererText ();
		cell_remove_limit.xalign = (float) 0.5;
		cell_remove_limit.editable = true;
		cell_remove_limit.edited.connect (cell_remove_limit_edited);
		col_remove_limit.pack_start (cell_remove_limit, false);
		col_remove_limit.set_cell_data_func (cell_remove_limit, cell_remove_limit_render);
		tv_remove.append_column(col_remove_limit);
		
		//col_remove_rule
		col_remove_units = new TreeViewColumn();
		col_remove_units.title = "";
		CellRendererText cell_remove_units = new CellRendererText ();
		col_remove_units.pack_start (cell_remove_units, false);
		col_remove_units.set_cell_data_func (cell_remove_units, cell_remove_units_render);
		tv_remove.append_column(col_remove_units);

		tv_schedule.sensitive = switch_schedule.active;

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
		//toolbar_exclude.get_style_context().add_class(Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
		//toolbar.set_size_request(-1,48);
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

		//initialize ------------------
		
		temp_exclude_list = new Gee.ArrayList<string>();
		
		foreach(string path in App.exclude_list_user){
			if (!temp_exclude_list.contains(path)){
				temp_exclude_list.add(path);
			}
		}
		
		refresh_tv_exclude();
		refresh_tv_schedule();
		refresh_tv_remove();

		// Actions ----------------------------------------------
		
        //btn_save
        btn_save = (Button) add_button (Stock.SAVE, Gtk.ResponseType.ACCEPT);
        btn_save.clicked.connect (btn_save_clicked);
        
        //btn_cancel
        btn_cancel = (Button) add_button (Stock.CANCEL, Gtk.ResponseType.CANCEL);
        btn_cancel.clicked.connect (btn_cancel_clicked);
	}


	private void cell_sched_enable_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		bool val;
		model.get (iter, 0, out val, -1);
		(cell as Gtk.CellRendererToggle).active = val;
	}
	
	private void cell_sched_level_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		string val;
		model.get (iter, 1, out val, -1);
		(cell as Gtk.CellRendererText).text = val;
	}
	
	private void cell_sched_desc_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		string val;
		model.get (iter, 2, out val, -1);
		(cell as Gtk.CellRendererText).text = val;
	}

	private void cell_remove_rule_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		string val;
		model.get (iter, 0, out val, -1);
		(cell as Gtk.CellRendererText).markup = val;
	}
	
	private void cell_remove_limit_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		int val;
		string units;
		model.get (iter, 1, out val, 2, out units, -1);
		(cell as Gtk.CellRendererText).text = (units == "GB") ? "%.0f".printf(val/1024.0) : val.to_string();
	}
	
	private void cell_remove_units_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		string val;
		model.get (iter, 2, out val, -1);
		(cell as Gtk.CellRendererText).text = val;
	}
	
	private void cell_sched_enable_toggled (string path){
		TreeIter iter;
		ListStore model = (ListStore)tv_schedule.model;
		bool enabled;
		int count;
		
		model.get_iter_from_string (out iter, path);
		model.get (iter, 0, out enabled, 2, out count,-1);
		model.set (iter, 0, !enabled);

		//update switch_auto_backups
		bool atleast_one_enabled = false;
		for(int k = 0; k<5; k++){
			model.get_iter_from_string (out iter, k.to_string());
			model.get (iter, 0, out enabled, -1);
			if (enabled){ 
				atleast_one_enabled = true; 
				break; 
			}
		}
		
		switch_schedule.active = atleast_one_enabled;
	}
	
	private void cell_remove_limit_edited (string path, string new_text) {
		int count = 0;
		string units;
		
		TreeIter iter;
		ListStore model = (ListStore)tv_remove.model;
		model.get_iter_from_string (out iter, path);
		model.get (iter, 2, out units,-1);
		count = int.parse(new_text);
		if (units == "GB"){
			count = count * 1024;
		}
		model.set (iter, 1, count);
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

	private void refresh_tv_schedule(){

		ListStore model = new ListStore(3, typeof(bool), typeof(string), typeof(string));

		TreeIter iter;
		model.append(out iter);
		model.set (iter, 0, App.schedule_monthly);
		model.set (iter, 1, _("Monthly"));
		model.set (iter, 2, _("Keep one snapshot per month"));

		model.append(out iter);
		model.set (iter, 0, App.schedule_weekly);
		model.set (iter, 1, _("Weekly"));
		model.set (iter, 2, _("Keep one snapshot per week"));
		
		model.append(out iter);
		model.set (iter, 0, App.schedule_daily);
		model.set (iter, 1, _("Daily"));
		model.set (iter, 2, _("Keep one snapshot per day"));
		
		model.append(out iter);
		model.set (iter, 0, App.schedule_hourly);
		model.set (iter, 1, _("Hourly"));
		model.set (iter, 2, _("Keep one snapshot per hour"));
		
		model.append(out iter);
		model.set (iter, 0, App.schedule_boot);
		model.set (iter, 1, _("Boot"));
		model.set (iter, 2, _("Keep one snapshot per reboot"));
		
		tv_schedule.set_model (model);
		tv_schedule.columns_autosize ();
	}

	private void refresh_tv_remove(){

		ListStore model = new ListStore(3, typeof(string), typeof(int), typeof(string));
		
		string span = "<span foreground=\"#2E2E2E\">";
		if (switch_schedule.active){
			span = "<span foreground=\"blue\">";
		}
		else{
			span = "<span>";
		}
		
		TreeIter iter;
		model.append(out iter);
		model.set (iter, 0, span + _("Monthly") + "</span> " + _("snapshots older than"));
		model.set (iter, 1, App.count_monthly);
		model.set (iter, 2, "months");

		model.append(out iter);
		model.set (iter, 0, span + _("Weekly") + "</span> " + _("snapshots older than"));
		model.set (iter, 1, App.count_weekly);
		model.set (iter, 2, "weeks");
		
		model.append(out iter);
		model.set (iter, 0, span + _("Daily") + "</span> " + _("snapshots older than"));
		model.set (iter, 1, App.count_daily);
		model.set (iter, 2, "days");
		
		model.append(out iter);
		model.set (iter, 0, span + _("Hourly") + "</span> " + _("snapshots older than"));
		model.set (iter, 1, App.count_hourly);
		model.set (iter, 2, "hours");
		
		model.append(out iter);
		model.set (iter, 0, span + _("Boot") + "</span> " + _("snapshots older than"));
		model.set (iter, 1, App.count_boot);
		model.set (iter, 2, "reboots");
		
		model.append(out iter);
		model.set (iter, 0, _("All snapshots older than"));
		model.set (iter, 1, App.retain_snapshots_max_days);
		model.set (iter, 2, "days");
		
		model.append(out iter);
		model.set (iter, 0, _("When free space less than"));
		model.set (iter, 1, App.minimum_free_disk_space_mb);
		model.set (iter, 2, "GB");
		
		tv_remove.set_model (model);
		//tv_remove.columns_autosize ();
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
	
	
	private void switch_schedule_changed(){
		tv_schedule.sensitive = switch_schedule.active;

		if (switch_schedule.active){

			bool atleast_one_enabled = App.schedule_boot 
			|| App.schedule_hourly
			|| App.schedule_daily
			|| App.schedule_weekly
			|| App.schedule_monthly;
			
			if(!atleast_one_enabled){
				TreeIter iter;
				ListStore store = (ListStore) tv_schedule.model;
				bool enabled; 
				int index = -1;
				
				bool iterExists = store.get_iter_first (out iter);
				while (iterExists) { 
					store.get (iter, 0, out enabled,-1);
					switch(++index){
						case 4:
							store.set (iter, 0, true);
							break;
					}
					iterExists = store.iter_next (ref iter);
				}
			}
		}
		else{
			tv_schedule.get_selection().unselect_all();
			tv_remove.get_selection().unselect_all();
		}
		
		refresh_tv_remove(); //refresh the item colors
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
	
	
	private void btn_save_clicked(){
		tv_schedule_save_changes();
		tv_remove_save_changes();
		tv_exclude_save_changes();

		App.save_app_config();
		
		this.destroy();
	}

	private void tv_schedule_save_changes(){
		TreeIter iter;
		TreeModel store = tv_schedule.model;
		bool enabled;
		int index = -1;
		
		bool iterExists = store.get_iter_first (out iter);
		
		while (iterExists) { 
			
			store.get (iter, 0, out enabled,-1);
			
			switch(++index){
				case 0:
					App.schedule_monthly = enabled;
					break;
				case 1:
					App.schedule_weekly = enabled;
					break;
				case 2:
					App.schedule_daily = enabled;
					break;
				case 3:
					App.schedule_hourly = enabled;
					break;
				case 4:
					App.schedule_boot = enabled;
					break;
			}
			iterExists = store.iter_next (ref iter);
		}
		
		if (!App.live_system()){
			App.is_scheduled = switch_schedule.active;
		}
	}
	
	private void tv_remove_save_changes(){
		TreeIter iter;
		TreeModel store = tv_remove.model;
		int count = -1;
		int index = -1;
		
		bool iterExists = store.get_iter_first (out iter);
		
		while (iterExists) { 
			
			store.get (iter, 1, out count, -1);
			
			switch(++index){
				case 0:
					App.count_monthly = count;
					break;
				case 1:
					App.count_weekly = count;
					break;
				case 2:
					App.count_daily	= count;
					break;
				case 3:
					App.count_hourly = count;
					break;
				case 4:
					App.count_boot = count;
					break;
				case 5:
					App.retain_snapshots_max_days = count;
					break;
				case 6:
					App.minimum_free_disk_space_mb = count;
					break;
			}
			iterExists = store.iter_next (ref iter);
		}
	}

	private void tv_exclude_save_changes(){
		App.exclude_list_user.clear();
		foreach(string path in temp_exclude_list){
			if (!App.exclude_list_user.contains(path) && !App.exclude_list_default.contains(path) && !App.exclude_list_home.contains(path)){
				App.exclude_list_user.add(path);
			}
		}
	}
	
	private void btn_cancel_clicked(){
		this.destroy();
	}

}
