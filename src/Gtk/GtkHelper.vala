

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.System;
using TeeJee.Misc;

namespace TeeJee.GtkHelper{

	using Gtk;

	// messages -----------
	
	public void show_err_log(Gtk.Window parent, bool disable_log = true){
		if ((err_log != null) && (err_log.length > 0)){
			gtk_messagebox(_("Error"), err_log, parent, true);
		}

		if (disable_log){
			err_log_disable();
		}
	}
	
	public void gtk_do_events (){

		/* Do pending events */

		while(Gtk.events_pending ())
			Gtk.main_iteration ();
	}

	public void gtk_set_busy (bool busy, Gtk.Window win) {

		/* Show or hide busy cursor on window */

		Gdk.Cursor? cursor = null;

		if (busy){
			cursor = new Gdk.Cursor(Gdk.CursorType.WATCH);
		}
		else{
			cursor = new Gdk.Cursor(Gdk.CursorType.ARROW);
		}

		var window = win.get_window ();

		if (window != null) {
			window.set_cursor (cursor);
		}

		gtk_do_events ();
	}

	public void gtk_messagebox(
		string title, string message, Gtk.Window? parent_win, bool is_error = false){

		/* Shows a simple message box */

		var type = Gtk.MessageType.INFO;
		if (is_error){
			type = Gtk.MessageType.ERROR;
		}
		else{
			type = Gtk.MessageType.INFO;
		}

		/*var dlg = new Gtk.MessageDialog.with_markup(null, Gtk.DialogFlags.MODAL, type, Gtk.ButtonsType.OK, message);
		dlg.title = title;
		dlg.set_default_size (200, -1);
		if (parent_win != null){
			dlg.set_transient_for(parent_win);
			dlg.set_modal(true);
		}
		dlg.run();
		dlg.destroy();*/

		var dlg = new CustomMessageDialog(title,message,type,parent_win, Gtk.ButtonsType.OK);
		dlg.run();
		dlg.destroy();
	}

	public string gtk_inputbox(
		string title, string message, Gtk.Window? parent_win, bool mask_password = false){

		/* Shows a simple input prompt */

		//vbox_main
        Gtk.Box vbox_main = new Box (Orientation.VERTICAL, 0);
        vbox_main.margin = 6;

		//lbl_input
		Gtk.Label lbl_input = new Gtk.Label(title);
		lbl_input.xalign = (float) 0.0;
		lbl_input.label = message;

		//txt_input
		Gtk.Entry txt_input = new Gtk.Entry();
		txt_input.margin_top = 3;
		txt_input.set_visibility(false);

		//create dialog
		var dlg = new Gtk.Dialog.with_buttons(title, parent_win, DialogFlags.MODAL);
		dlg.title = title;
		dlg.set_default_size (300, -1);
		if (parent_win != null){
			dlg.set_transient_for(parent_win);
			dlg.set_modal(true);
		}

		//add widgets
		Gtk.Box content = (Box) dlg.get_content_area ();
		vbox_main.pack_start (lbl_input, false, true, 0);
		vbox_main.pack_start (txt_input, false, true, 0);
		content.add(vbox_main);

		//add buttons
		dlg.add_button(_("OK"),Gtk.ResponseType.OK);
		dlg.add_button(_("Cancel"),Gtk.ResponseType.CANCEL);

		//keyboard shortcuts
		txt_input.key_press_event.connect ((w, event) => {
			if (event.keyval == 65293) {
				dlg.response(Gtk.ResponseType.OK);
				return true;
			}
			return false;
		});

		dlg.show_all();
		int response = dlg.run();
		string input_text = txt_input.text;
		dlg.destroy();

		if (response == Gtk.ResponseType.CANCEL){
			return "";
		}
		else{
			return input_text;
		}
	}


	// combo ---------
	
	public bool gtk_combobox_set_value (ComboBox combo, int index, string val){

		/* Conveniance function to set combobox value */

		TreeIter iter;
		string comboVal;
		TreeModel model = (TreeModel) combo.model;

		bool iterExists = model.get_iter_first (out iter);
		while (iterExists){
			model.get(iter, 1, out comboVal);
			if (comboVal == val){
				combo.set_active_iter(iter);
				return true;
			}
			iterExists = model.iter_next (ref iter);
		}

		return false;
	}

	public string gtk_combobox_get_value (ComboBox combo, int index, string default_value){

		/* Conveniance function to get combobox value */

		if ((combo.model == null) || (combo.active < 0)) { return default_value; }

		TreeIter iter;
		string val = "";
		combo.get_active_iter (out iter);
		TreeModel model = (TreeModel) combo.model;
		model.get(iter, index, out val);

		return val;
	}

	public GLib.Object gtk_combobox_get_selected_object (
		ComboBox combo,
		int index,
		GLib.Object default_value){

		/* Conveniance function to get combobox value */

		if ((combo.model == null) || (combo.active < 0)) { return default_value; }

		TreeIter iter;
		GLib.Object val = null;
		combo.get_active_iter (out iter);
		TreeModel model = (TreeModel) combo.model;
		model.get(iter, index, out val);

		return val;
	}
	
	public int gtk_combobox_get_value_enum (ComboBox combo, int index, int default_value){

		/* Conveniance function to get combobox value */

		if ((combo.model == null) || (combo.active < 0)) { return default_value; }

		TreeIter iter;
		int val;
		combo.get_active_iter (out iter);
		TreeModel model = (TreeModel) combo.model;
		model.get(iter, index, out val);

		return val;
	}

	// icon -------
	
	public Gdk.Pixbuf? get_app_icon(int icon_size, string format = ".png"){
		var img_icon = get_shared_icon(AppShortName, AppShortName + format,icon_size,"pixmaps");
		if (img_icon != null){
			return img_icon.pixbuf;
		}
		else{
			return null;
		}
	}

	public Gtk.Image? get_shared_icon(
		string icon_name,
		string fallback_icon_file_name,
		int icon_size,
		string icon_directory = AppShortName + "/images"){
			
		Gdk.Pixbuf pix_icon = null;
		Gtk.Image img_icon = null;

		try {
			Gtk.IconTheme icon_theme = Gtk.IconTheme.get_default();
			pix_icon = icon_theme.load_icon (icon_name, icon_size, 0);
		} catch (Error e) {
			//log_error (e.message);
		}

		string fallback_icon_file_path = "/usr/share/%s/%s".printf(icon_directory, fallback_icon_file_name);

		if (pix_icon == null){
			try {
				pix_icon = new Gdk.Pixbuf.from_file_at_size (fallback_icon_file_path, icon_size, icon_size);
			} catch (Error e) {
				log_error (e.message);
			}
		}

		if (pix_icon == null){
			log_error (_("Missing Icon") + ": '%s', '%s'".printf(icon_name, fallback_icon_file_path));
		}
		else{
			img_icon = new Gtk.Image.from_pixbuf(pix_icon);
		}

		return img_icon;
	}

	public Gdk.Pixbuf? get_shared_icon_pixbuf(string icon_name,
		string fallback_file_name,
		int icon_size,
		string icon_directory = AppShortName + "/images"){
			
		var img = get_shared_icon(icon_name, fallback_file_name, icon_size, icon_directory);
		var pixbuf = (img == null) ? null : img.pixbuf;
		return pixbuf;
	}

	// styles ----------------

	public static int CSS_AUTO_CLASS_INDEX = 0;
	public static void gtk_apply_css(Gtk.Widget[] widgets, string css_style){
		var css_provider = new Gtk.CssProvider();
		var css = ".style_%d { %s }".printf(++CSS_AUTO_CLASS_INDEX, css_style);
		try {
			css_provider.load_from_data(css,-1);
		} catch (GLib.Error e) {
            warning(e.message);
        }

        foreach(var widget in widgets){
			
			widget.get_style_context().add_provider(
				css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
				
			widget.get_style_context().add_class("style_%d".printf(CSS_AUTO_CLASS_INDEX));
		}
	}
	
	// treeview -----------------
	
	public int gtk_treeview_model_count(TreeModel model){
		int count = 0;
		TreeIter iter;
		if (model.get_iter_first(out iter)){
			count++;
			while(model.iter_next(ref iter)){
				count++;
			}
		}
		return count;
	}

	public void gtk_stripe_row(
		Gtk.CellRenderer cell,
		bool odd_row,
		string odd_color = "#F4F6F7",
		string even_color = "#FFFFFF"){

		if (cell is Gtk.CellRendererText){
			(cell as Gtk.CellRendererText).background = odd_row ? odd_color : even_color;
		}
		else if (cell is Gtk.CellRendererPixbuf){
			(cell as Gtk.CellRendererPixbuf).cell_background = odd_row ? odd_color : even_color;
		}
	}

	public void gtk_treeview_redraw(Gtk.TreeView treeview){
		var model = treeview.model;
		treeview.model = null;
		treeview.model = model;
	}
	
	// menu
	
	public void gtk_menu_add_separator(Gtk.Menu menu){
		Gdk.RGBA gray = Gdk.RGBA();
		gray.parse ("rgba(200,200,200,1)");
		
		// separator
		var menu_item = new Gtk.SeparatorMenuItem();
		menu_item.override_color (StateFlags.NORMAL, gray);
		menu.append(menu_item);
	}

	public Gtk.MenuItem gtk_menu_add_item(
		Gtk.Menu menu,
		string label,
		string tooltip,
		Gtk.Image? icon_image,
		Gtk.SizeGroup? sg_icon = null,
		Gtk.SizeGroup? sg_label = null){

		var menu_item = new Gtk.MenuItem();
		menu.append(menu_item);
			
		var box = new Gtk.Box(Orientation.HORIZONTAL, 3);
		menu_item.add(box);

		// add icon

		if (icon_image == null){
			var dummy = new Gtk.Label("");
			box.add(dummy);

			if (sg_icon != null){
				sg_icon.add_widget(dummy);
			}
		}
		else{
			box.add(icon_image);

			if (sg_icon != null){
				sg_icon.add_widget(icon_image);
			}
		}
		
		// add label
		
		var lbl = new Gtk.Label(label);
		lbl.xalign = (float) 0.0;
		lbl.margin_right = 6;
		box.add(lbl);

		if (sg_label != null){
			sg_label.add_widget(lbl);
		}

		box.set_tooltip_text(tooltip);

		return menu_item;
	}

	// build ui

	public Gtk.Label gtk_box_add_header(Gtk.Box box, string text){
		var label = new Gtk.Label("<b>" + text + "</b>");
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		label.margin_bottom = 6;
		box.add(label);

		return label;
	}

	// misc
	
	public bool gtk_container_has_child(Gtk.Container container, Gtk.Widget widget){
		foreach(var child in container.get_children()){
			if (child == widget){
				return true;
			}
		}
		return false;
	}


	private void text_view_append(Gtk.TextView view, string text){
		TextIter iter;
		view.buffer.get_end_iter(out iter);
		view.buffer.insert(ref iter, text, text.length);
	}

	private void text_view_prepend(Gtk.TextView view, string text){
		TextIter iter;
		view.buffer.get_start_iter(out iter);
		view.buffer.insert(ref iter, text, text.length);
	}

	private void text_view_scroll_to_end(Gtk.TextView view){
		TextIter iter;
		view.buffer.get_end_iter(out iter);
		view.scroll_to_iter(iter, 0.0, false, 0.0, 0.0);
	}

	private void text_view_scroll_to_start(Gtk.TextView view){
		TextIter iter;
		view.buffer.get_start_iter(out iter);
		view.scroll_to_iter(iter, 0.0, false, 0.0, 0.0);
	}
	
	// file chooser ----------------
	
	public Gtk.FileFilter create_file_filter(string group_name, string[] patterns) {
		var filter = new Gtk.FileFilter ();
		filter.set_filter_name(group_name);
		foreach(string pattern in patterns) {
			filter.add_pattern (pattern);
		}
		return filter;
	}
}

