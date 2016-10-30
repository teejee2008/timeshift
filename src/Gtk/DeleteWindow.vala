/*
 * DeleteWindow.vala
 *
 * Copyright 2016 Tony George <teejee@tony-pc>
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

class DeleteWindow : Gtk.Window{
	private Gtk.Box vbox_main;
	private Gtk.Notebook notebook;
	private Gtk.Box bbox_action;

	// tabs
	private SnapshotListBox snapshot_list_box;
	private DeleteBox delete_box;

	// actions
	private Gtk.Button btn_prev;
	private Gtk.Button btn_next;
	private Gtk.Button btn_hide;
	private Gtk.Button btn_cancel;
	private Gtk.Button btn_close;

	private uint tmr_init;
	private int def_width = 450;
	private int def_height = 500;

	public DeleteWindow() {

		log_debug("DeleteWindow: DeleteWindow()");
		
		this.title = _("Delete Snapshots");
        this.window_position = WindowPosition.CENTER;
        this.modal = true;
        this.set_default_size (def_width, def_height);
		this.icon = get_app_icon(16);

		this.delete_event.connect(on_delete_event);
		
	    // vbox_main
        vbox_main = new Box (Orientation.VERTICAL, 6);
        vbox_main.margin = 12;
        add(vbox_main);

		// add notebook
		notebook = add_notebook(vbox_main, false, false);

		// create tab
		
		var vbox_tab = new Box (Orientation.VERTICAL, 6);
        vbox_tab.margin = 0;
 
		add_label_header(vbox_tab, _("Select Snapshots"), true);

		add_label(vbox_tab, _("Select the snapshots to be deleted"));
		
		var label = new Gtk.Label(_("Snapshots"));
		
		snapshot_list_box = new SnapshotListBox(this);
		snapshot_list_box.hide_context_menu();
		snapshot_list_box.margin = 0;
		vbox_tab.add(snapshot_list_box);
		
		notebook.append_page (vbox_tab, label);
		
		label = new Gtk.Label(_("Delete"));
		delete_box = new DeleteBox(this);
		delete_box.margin = 0;
		notebook.append_page (delete_box, label);

		create_actions();

		show_all();

		tmr_init = Timeout.add(100, init_delayed);

		log_debug("DeleteWindow: DeleteWindow(): exit");
    }
    
	private bool init_delayed(){

		if (tmr_init > 0){
			Source.remove(tmr_init);
			tmr_init = 0;
		}

		go_first();

		return false;
	}

	private bool on_delete_event(Gdk.EventAny event){

		return false; // close window
	}
	
	private void create_actions(){
		var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		hbox.margin = 0;
		hbox.margin_left = 24;
		hbox.margin_right = 24;
		hbox.margin_top = 6;
        vbox_main.add(hbox);
        bbox_action = hbox;

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
			this.destroy();
		});

		// hide
		
		btn_hide = add_button(hbox, _("Hide"), "", ref size_group, null);
		btn_hide.set_tooltip_text(_("Hide this window (files will be deleted in background)"));
		
        btn_hide.clicked.connect(()=>{
			this.destroy();
		});
	
		// cancel
		
		img = new Image.from_stock("gtk-cancel", Gtk.IconSize.BUTTON);
		btn_cancel = add_button(hbox, _("Cancel"), "", ref size_group, img);

        btn_cancel.clicked.connect(()=>{
			// clear queue
			App.delete_list.clear();
			// kill current task
			if (App.delete_file_task != null){
				App.delete_file_task.stop(AppStatus.CANCELLED);
			}
			
			this.destroy(); // TODO: Show error page
		});

		btn_prev.hexpand = btn_next.hexpand = btn_cancel.hexpand = btn_close.hexpand = btn_hide.hexpand = true;

		action_buttons_set_no_show_all(true);
	}

	private void action_buttons_set_no_show_all(bool val){
		btn_prev.no_show_all = val;
		btn_next.no_show_all = val;
		btn_hide.no_show_all = val;
		btn_close.no_show_all = val;
		btn_cancel.no_show_all = val;
	}
	
	// navigation

	private void go_first(){
		
		// set initial tab
		
		if ((App.delete_list.size == 0) && !App.thread_delete_running){
			notebook.page = Tabs.SNAPSHOT_LIST;
		}
		else {
			notebook.page = Tabs.DELETE;
		}

		initialize_tab();
	}
	
	private void go_prev(){
		switch(notebook.page){
		case Tabs.SNAPSHOT_LIST:
		case Tabs.DELETE:
			// btn_previous is disabled for this page
			break;
		}
		
		initialize_tab();
	}
	
	private void go_next(){
		
		if (!validate_current_tab()){
			return;
		}
		
		switch(notebook.page){
		case Tabs.SNAPSHOT_LIST:
			App.delete_list = snapshot_list_box.selected_snapshots();
			notebook.page = Tabs.DELETE;
			break;
		case Tabs.DELETE:
			destroy();
			break;
		}
		
		initialize_tab();
	}

	private void initialize_tab(){

		if (notebook.page < 0){
			return;
		}

		log_msg("");
		log_debug("page: %d".printf(notebook.page));

		// show/hide actions -----------------------------------

		action_buttons_set_no_show_all(false);
		
		switch(notebook.page){
		case Tabs.DELETE:
			btn_prev.hide();
			btn_next.hide();
			btn_close.hide();
			btn_hide.show();
			btn_cancel.show();
			break;
		case Tabs.SNAPSHOT_LIST:
			btn_prev.show();
			btn_next.show();
			btn_close.show();
			btn_hide.hide();
			btn_cancel.hide();
			btn_prev.sensitive = false;
			btn_next.sensitive = true;
			btn_close.sensitive = true;
			break;
		}

		// actions

		switch(notebook.page){
		case Tabs.SNAPSHOT_LIST:
			snapshot_list_box.refresh();
			break;
		case Tabs.DELETE:
			delete_box.delete_snapshots();
			//destroy();
			break;
		}
	}

	private bool validate_current_tab(){
		switch(notebook.page){
		case Tabs.SNAPSHOT_LIST:
			var sel = snapshot_list_box.treeview.get_selection ();
			if (sel.count_selected_rows() == 0){
				gtk_messagebox(
					_("No Snapshots Selected"),
					_("Select snapshots to delete"),
					this, false);;
				return false;
			}
			else{
				return true;
			}
			
		default:
			return true;
		}
	}

	public enum Tabs{
		SNAPSHOT_LIST = 0,
		DELETE = 1
	}
}



