/*
 * ExcludeMessageWindow.vala
 *
 * Copyright 2012-17 Tony George <teejeetech@gmail.com>
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

public class ExcludeMessageWindow : Gtk.Dialog{
	private Box vbox_main;
	private Box hbox_action;

	//exclude
	private TreeView tv_exclude;
	private ScrolledWindow sw_exclude;
	private TreeViewColumn col_exclude;
	private Label lbl_header_exclude;
	private Label lbl_exclude;
	private Label lbl_header_home;
	private Label lbl_home;

	//actions
	private Button btn_ok;

	public ExcludeMessageWindow () {

		log_debug("ExcludeMessageWindow: ExcludeMessageWindow()");
		
		this.title = _("Excluded Directories");
        this.window_position = WindowPosition.CENTER_ON_PARENT;
        this.set_destroy_with_parent (true);
		this.set_modal (true);
        this.set_default_size (400, 400);

        //set app icon
		try{
			this.icon = new Gdk.Pixbuf.from_file (App.share_folder + "/icons/48x48/apps/timeshift.png");
		}
        catch(Error e){
	        log_error (e.message);
	    }

	    string msg;

	    //vbox_main
        vbox_main = get_content_area ();
		vbox_main.margin = 6;
		vbox_main.spacing = 6;

		//lbl_header_exclude
		lbl_header_exclude = new Gtk.Label("<b>" + _("Exclude List") + ":</b>");
		lbl_header_exclude.xalign = (float) 0.0;
		lbl_header_exclude.set_use_markup(true);
		vbox_main.add(lbl_header_exclude);

		//lbl_exclude
		lbl_exclude = new Gtk.Label(_("Files matching the following patterns will be excluded") + ":");
		lbl_exclude.xalign = (float) 0.0;
		lbl_exclude.set_use_markup(true);
		vbox_main.add(lbl_exclude);

		//tv_exclude-----------------------------------------------

		//tv_exclude
		tv_exclude = new TreeView();
		tv_exclude.get_selection().mode = SelectionMode.MULTIPLE;
		tv_exclude.headers_visible = false;
		tv_exclude.set_rules_hint (true);

		//sw_exclude
		sw_exclude = new ScrolledWindow(null, null);
		sw_exclude.set_shadow_type (ShadowType.ETCHED_IN);
		sw_exclude.add (tv_exclude);
		sw_exclude.expand = true;
		vbox_main.add(sw_exclude);

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
		cell_exclude_text.foreground = "#222222";
		tv_exclude.append_column(col_exclude);

		//lbl_header_home
		lbl_header_home = new Gtk.Label("<b>" + _("Home Directory") + ":</b>");
		lbl_header_home.xalign = (float) 0.0;
		lbl_header_home.set_use_markup(true);
		lbl_header_home.margin_top = 6;
		vbox_main.add(lbl_header_home);

		//lbl_home
		lbl_home = new Gtk.Label("");
		lbl_home.xalign = (float) 0.0;
		lbl_home.set_use_markup(true);
		lbl_home.wrap = true;
		vbox_main.add(lbl_home);

		msg = _("Hidden files and folders are included by default since they contain user-specific configuration files.") + "\n";
		msg += _("All other files and folders are excluded.") + "\n";
		lbl_home.label =msg;

		//Actions ----------------------------------------------

		//hbox_action
        hbox_action = (Box) get_action_area ();

        //btn_ok
        btn_ok = new Button.from_stock("gtk-ok");
        hbox_action.add(btn_ok);
        btn_ok.clicked.connect (btn_ok_clicked);

		//initialize -----------------------------------------

		var model = new Gtk.ListStore(2, typeof(string), typeof(Gdk.Pixbuf));
		tv_exclude.model = model;

		foreach(string path in App.exclude_list_default){
			tv_exclude_add_item(path);
		}

		log_debug("ExcludeMessageWindow: ExcludeMessageWindow(): exit");
	}

	private void cell_exclude_text_render (CellLayout cell_layout, CellRenderer cell, TreeModel model, TreeIter iter){
		string pattern;
		model.get (iter, 0, out pattern, -1);
		(cell as Gtk.CellRendererText).text = pattern.has_prefix("+ ") ? pattern[2:pattern.length] : pattern;
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

		model.set (iter, 0, path, 1, pix_selected);

		Adjustment adj = tv_exclude.get_hadjustment();
		adj.value = adj.upper;
	}

	private void btn_ok_clicked(){
		this.response(Gtk.ResponseType.OK);
		return;
	}
}
