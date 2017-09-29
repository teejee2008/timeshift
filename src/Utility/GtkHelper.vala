

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
			cursor = new Gdk.Cursor.from_name(Gdk.Display.get_default(), "wait");
		}
		else{
			cursor = new Gdk.Cursor.from_name(Gdk.Display.get_default(), "default");
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

	public string? gtk_inputbox(
		string title, string message, Gtk.Window? parent_win, bool mask_password = false){

		/* Shows a simple input prompt */

		//vbox_main
        Gtk.Box vbox_main = new Box (Orientation.VERTICAL, 0);
        vbox_main.margin = 0;

		//lbl_input
		Gtk.Label lbl_input = new Gtk.Label(title);
		lbl_input.xalign = (float) 0.0;
		lbl_input.label = message;

		//txt_input
		Gtk.Entry txt_input = new Gtk.Entry();
		txt_input.margin_top = 3;
		txt_input.set_visibility(!mask_password);

		//create dialog
		var dlg = new Gtk.Dialog.with_buttons(title, parent_win, DialogFlags.MODAL);
		dlg.title = title;
		dlg.set_default_size (300, -1);
		if (parent_win != null){
			dlg.set_transient_for(parent_win);
			dlg.set_modal(true);
		}

		//add widgets
		var content = (Box) dlg.get_content_area ();
		vbox_main.pack_start (lbl_input, false, true, 0);
		vbox_main.pack_start (txt_input, false, true, 0);
		content.add(vbox_main);
		content.margin = 6;
		
		//add buttons
		var actions = (Box) dlg.get_action_area ();
		dlg.add_button(_("OK"),Gtk.ResponseType.OK);
		dlg.add_button(_("Cancel"),Gtk.ResponseType.CANCEL);
		//actions.margin = 6;
		actions.margin_top = 12;
		
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
			return null;
		}
		else{
			return input_text;
		}
	}

	public void wait_and_close_window(int milliseconds, Gtk.Window window){
		gtk_do_events();
		int millis = 0;
		while(millis < milliseconds){
			sleep(200);
			millis += 200;
			gtk_do_events();
		}
		window.destroy();
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

	// utility ------------------

	// add_notebook
	private Gtk.Notebook add_notebook(
		Gtk.Box box, bool show_tabs = true, bool show_border = true){
			
        // notebook
		var book = new Gtk.Notebook();
		book.margin = 0;
		book.show_tabs = show_tabs;
		book.show_border = show_border;
		
		box.pack_start(book, true, true, 0);
		
		return book;
	}

	// add_tab
	private Gtk.Box add_tab(
		Gtk.Notebook book, string title, int margin = 12, int spacing = 6){
			
		// label
		var label = new Gtk.Label(title);

        // vbox
        var vbox = new Box (Gtk.Orientation.VERTICAL, spacing);
        vbox.margin = margin;
        book.append_page (vbox, label);

        return vbox;
	}

	// add_treeview
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

	// add_column_text
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


	// add_column_icon
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

	// add_column_icon_and_text
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

	// add_column_radio_and_text
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

	// add_column_icon_radio_text
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

	// add_label_scrolled
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
		label.set_use_markup(true);
		scroll.add(label);

		if (wrap){
			label.wrap = true;
			label.wrap_mode = Pango.WrapMode.WORD;
		}
		else {
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

	// add_text_view
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
		
	// add_label
	private Gtk.Label add_label(
		Gtk.Box box, string text, bool bold = false,
		bool italic = false, bool large = false){
			
		string msg = "<span%s%s%s>%s</span>".printf(
			(bold ? " weight=\"bold\"" : ""),
			(italic ? " style=\"italic\"" : ""),
			(large ? " size=\"x-large\"" : ""),
			text);
			
		var label = new Gtk.Label(msg);
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		label.wrap = true;
		label.wrap_mode = Pango.WrapMode.WORD;
		box.add(label);
		return label;
	}

	private string format_text(
		string text,
		bool bold = false, bool italic = false, bool large = false){
			
		string msg = "<span%s%s%s>%s</span>".printf(
			(bold ? " weight=\"bold\"" : ""),
			(italic ? " style=\"italic\"" : ""),
			(large ? " size=\"x-large\"" : ""),
			escape_html(text));
			
		return msg;
	}

	// add_label_header
	private Gtk.Label add_label_header(
		Gtk.Box box, string text, bool large_heading = false){
		
		var label = add_label(box, escape_html(text), true, false, large_heading);
		label.margin_bottom = 12;
		return label;
	}

	// add_label_subnote
	private Gtk.Label add_label_subnote(
		Gtk.Box box, string text){
		
		var label = add_label(box, text, false, true);
		label.margin_left = 6;
		return label;
	}

	// add_radio
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

	// add_checkbox
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

	// add_spin
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

	// add_button
	private Gtk.Button add_button(
		Gtk.Box box, string text, string tooltip,
		Gtk.SizeGroup? size_group,
		Gtk.Image? icon = null){
			
		var button = new Gtk.Button();
        box.add(button);

        button.set_label(text);
        button.set_tooltip_text(tooltip);

        if (icon != null){
			button.set_image(icon);
			button.set_always_show_image(true);
		}

		if (size_group != null){
			size_group.add_widget(button);
		}

        return button;
	}

	// add_toggle_button
	private Gtk.ToggleButton add_toggle_button(
		Gtk.Box box, string text, string tooltip,
		Gtk.SizeGroup? size_group,
		Gtk.Image? icon = null){
			
		var button = new Gtk.ToggleButton();
        box.add(button);

        button.set_label(text);
        button.set_tooltip_text(tooltip);

        if (icon != null){
			button.set_image(icon);
			button.set_always_show_image(true);
		}

		if (size_group != null){
			size_group.add_widget(button);
		}
		
        return button;
	}
	
	// add_directory_chooser
	private Gtk.Entry add_directory_chooser(
		Gtk.Box box, string selected_directory, Gtk.Window parent_window){
			
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
			    parent_window,
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

				//App.repo = new SnapshotRepo.from_path(entry.text, this);
				//check_backup_location();
			}

			chooser.destroy();
		});

		return entry;
	}


}

