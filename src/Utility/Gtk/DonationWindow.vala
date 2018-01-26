/*
 * DonationWindow.vala
 *
 * Copyright 2012-2018 Tony George <teejeetech@gmail.com>
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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.System;
using TeeJee.Misc;
using TeeJee.GtkHelper;

public class DonationWindow : Dialog {

	private string username = "";
	private Box hbox_action;
	private Button btn_close;

	public DonationWindow() {

		this.set_title(_("Donate"));
		this.window_position = WindowPosition.CENTER_ON_PARENT;
		this.set_destroy_with_parent (true);
		this.set_modal (true);
		this.set_deletable(true);
		this.set_skip_taskbar_hint(false);
		this.set_default_size (500, 20);
		this.icon = IconManager.lookup("timeshift",16);

		//vbox_main
		var vbox_main = get_content_area();
		vbox_main.margin = 6;
		vbox_main.spacing = 6;
		//vbox_main.homogeneous = false;

		//get_action_area().visible = false;
		
		hbox_action = (Box) get_action_area();

		string msg = _("Did you find this software useful?\n\nYou can buy me a coffee or make a donation via PayPal to show your support. Or just drop me an email and say Hi. This application is completely free and will continue to remain that way. Your contributions will help in keeping this project alive and improving it further.\n\nFeel free to send me an email if you find any issues in this application or if you need any changes. Suggestions and feedback are always welcome.\n\nThanks,\nTony George\n(teejeetech@gmail.com)");
		
		var label = new Gtk.Label(msg);
		label.wrap = true;
		label.wrap_mode = Pango.WrapMode.WORD;
		label.max_width_chars = 50;
		label.xalign = 0.0f;
		label.margin_bottom = 6;

		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.hscrollbar_policy = PolicyType.NEVER;
		scrolled.vscrollbar_policy = PolicyType.NEVER;
		scrolled.add (label);
		vbox_main.add(scrolled);
		
		if (get_user_id_effective() == 0){
			username = get_username();
		}

		// donate paypal
		var button = new Gtk.LinkButton.with_label("", _("Donate with PayPal"));
		button.set_tooltip_text("Donate to: teejeetech@gmail.com");
		vbox_main.add(button);
		button.clicked.connect(() => {
			xdg_open("https://www.paypal.com/cgi-bin/webscr?business=teejeetech@gmail.com&cmd=_xclick&currency_code=USD&amount=10&item_name=Polo%20Donation", username);
		});

		// patreon
		button = new Gtk.LinkButton.with_label("", _("Become a Patron"));
		button.set_tooltip_text("https://www.patreon.com/teejeetech");
		vbox_main.add(button);
		button.clicked.connect(() => {
			xdg_open("https://www.patreon.com/teejeetech", username);
		});

		// issue tracker
		button = new Gtk.LinkButton.with_label("", _("Issue Tracker ~ Report Issues, Request Features, Ask Questions"));
		button.set_tooltip_text("https://github.com/teejee2008/timeshift/issues");
		vbox_main.add(button);
		button.clicked.connect(() => {
			xdg_open("https://github.com/teejee2008/timeshift/issues", username);
		});

		// wiki
		button = new Gtk.LinkButton.with_label("", _("Wiki ~ Documentation & Help"));
		button.set_tooltip_text("https://github.com/teejee2008/timeshift/wiki");
		vbox_main.add(button);
		button.clicked.connect(() => {
			xdg_open("https://github.com/teejee2008/timeshift/wiki", username);
		});

		// website
		button = new Gtk.LinkButton.with_label("", "%s ~ %s".printf(_("Website"), "teejeetech.in"));
		button.set_tooltip_text("http://www.teejeetech.in");
		vbox_main.add(button);
		button.clicked.connect(() => {
			xdg_open("http://www.teejeetech.in", username);
		});

		//btn_close
		btn_close = new Button.with_label("  " + _("Close"));
		hbox_action.add(btn_close);

		btn_close.clicked.connect(()=>{ this.destroy(); });

		this.show_all();
	}
}

