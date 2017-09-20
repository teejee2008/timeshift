/*
 * CustomMessageDialog.vala
 *
 * Copyright 2016 Tony George <teejeetech@gmail.com>
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

public class CustomMessageDialog : Gtk.Dialog {
	
	private Gtk.Box vbox_main;
	private Gtk.Label lbl_msg;
	private Gtk.ScrolledWindow sw_msg;
	private Gtk.Button btn_ok;
	private Gtk.Button btn_cancel;
	private Gtk.Button btn_yes;
	private Gtk.Button btn_no;

	private string msg_title;
	private string msg_body;
	private Gtk.MessageType msg_type;
	private Gtk.ButtonsType buttons_type;
	
	public CustomMessageDialog(
		string _msg_title, string _msg_body,
		Gtk.MessageType _msg_type, Window? parent, Gtk.ButtonsType _buttons_type) {
			
		set_transient_for(parent);
		set_modal(true);

		msg_title = _msg_title;
		msg_body = _msg_body;
		msg_type = _msg_type;
		buttons_type = _buttons_type;
		
		init_window();

		show_all();

		if (lbl_msg.get_allocated_height() > 400){
			sw_msg.vscrollbar_policy = PolicyType.AUTOMATIC;
			sw_msg.set_size_request(-1,400);
			lbl_msg.margin_right = 25;
		}
		else{
			sw_msg.vscrollbar_policy = PolicyType.NEVER;
		}
	}

	public void init_window () {
		title = "";
		
		window_position = WindowPosition.CENTER_ON_PARENT;
		icon = get_app_icon(16);
		resizable = false;
		deletable = false;
		skip_taskbar_hint = true;
		skip_pager_hint = true;
		
		//vbox_main
		vbox_main = get_content_area () as Gtk.Box;
		vbox_main.margin = 6;

		//hbox_contents
		var hbox_contents = new Box (Orientation.HORIZONTAL, 6);
		hbox_contents.margin = 6;
		vbox_main.add (hbox_contents);

		string icon_name = "gtk-dialog-info";
		
		switch(msg_type){
		case Gtk.MessageType.INFO:
			icon_name = "gtk-dialog-info";
			break;
		case Gtk.MessageType.WARNING:
			icon_name = "gtk-dialog-warning";
			break;
		case Gtk.MessageType.QUESTION:
			icon_name = "gtk-dialog-question";
			break;
		case Gtk.MessageType.ERROR:
			icon_name = "gtk-dialog-error";
			break;
		}

		// image ----------------
		
		var img = new Image.from_icon_name(icon_name, Gtk.IconSize.DIALOG);
		img.margin_right = 12;
		hbox_contents.add(img);
		
		// label -------------------

		var text = "<span weight=\"bold\" size=\"x-large\">%s</span>\n\n%s".printf(
			escape_html(msg_title),
			msg_body);
		lbl_msg = new Gtk.Label(text);
		lbl_msg.xalign = (float) 0.0;
		lbl_msg.max_width_chars = 70;
		lbl_msg.wrap = true;
		lbl_msg.wrap_mode = Pango.WrapMode.WORD_CHAR;
		lbl_msg.use_markup = true;

		//sw_msg
		sw_msg = new ScrolledWindow(null, null);
		//sw_msg.set_shadow_type (ShadowType.ETCHED_IN);
		sw_msg.add (lbl_msg);
		sw_msg.expand = true;
		sw_msg.hscrollbar_policy = PolicyType.NEVER;
		sw_msg.vscrollbar_policy = PolicyType.AUTOMATIC;
		//sw_msg.set_size_request();
		hbox_contents.add(sw_msg);

		// actions -------------------------
		
		var action_area = get_action_area () as Gtk.Box;
		action_area.margin_top = 12;

		switch(buttons_type){
		case Gtk.ButtonsType.OK:
			btn_ok = (Gtk.Button) add_button ("_Ok", Gtk.ResponseType.OK);
			break;
		case Gtk.ButtonsType.OK_CANCEL:
			btn_ok = (Gtk.Button) add_button ("_Ok", Gtk.ResponseType.OK);
			btn_cancel = (Gtk.Button) add_button ("_Cancel", Gtk.ResponseType.CANCEL);
			break;
		case Gtk.ButtonsType.YES_NO:
			btn_yes = (Gtk.Button) add_button ("_Yes", Gtk.ResponseType.YES);
			btn_no = (Gtk.Button) add_button ("_No", Gtk.ResponseType.NO);
			break;
			
		}
	}
}


