/*
 * DonationWindow.vala
 *
 * Copyright 2012-18 Tony George <teejeetech@gmail.com>
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

public class DonationWindow : Gtk.Window {

	private Gtk.Box vbox_main;
	private string username = "";
	private string appname = "Timeshift";
	private bool has_donation_plugins = false;
	private bool has_wiki = false;

	public DonationWindow(Gtk.Window window) {

		set_title("");
		set_transient_for(window);
		window_position = WindowPosition.CENTER_ON_PARENT;
		set_destroy_with_parent (true);
		set_modal (true);
		set_deletable(true);
		set_skip_taskbar_hint(false);
		set_default_size (500, 400);

		//vbox_main
		vbox_main = new Gtk.Box(Orientation.VERTICAL, 0);
		vbox_main.margin = 6;
		vbox_main.spacing = 6;
		this.add(vbox_main);
		
		if (get_user_id_effective() == 0){
			username = get_username();
		}

		// -----------------------------

		string msg = _("If you find this application useful, and wish to support its development, use the button below to make a donation with PayPal.");
		
		add_label(msg);

		var hbox = add_hbox();
		
		add_button(hbox, _("Donate (5$)"),
			"https://www.paypal.com/cgi-bin/webscr?business=teejeetech@gmail.com&cmd=_xclick&currency_code=USD&amount=5.00&item_name=%s+Donation".printf(appname));

		add_button(hbox, _("Become a Patron"),
			"https://www.patreon.com/bePatron?u=3059450");

		
		msg = _("This application was created for my personal use. I work on it during my free time based on my requirements and interest. It is distributed in the hope that it may be useful. Since this is a free application, it is not possible for me to spend additional time providing free support to individual users. If you need changes in this application, consider making a donation to sponsor the work, or get involved with the development and contribute. See sections below for more info.");
		
		var label = add_label(msg);

		// -----------------------------

		msg = format_heading(_("Support")) + "   ";
		
		msg += _("Use the issue tracker for reporting issues, asking questions, and requesting features. If you need an immediate response, use the button below to make a donation for $10 with PayPal. Add your questions to the tracker and send me an email with the issue number (teejeetech@gmail.com). This option is for questions you may have about the application, and for help with issues. This does not cover development work for fixing issues and adding features.");
		
		add_label(msg);

		hbox = add_hbox();

		add_button(hbox, _("Get Support ($10)"),
			"https://www.paypal.com/cgi-bin/webscr?business=teejeetech@gmail.com&cmd=_xclick&currency_code=USD&amount=10.00&item_name=%s+Support".printf(appname));

		add_button(hbox, _("Issue Tracker"),
			"https://github.com/teejee2008/%s/issues".printf(appname.down()));

		if (has_wiki){
			
			add_button(hbox, _("Wiki"),
				"https://github.com/teejee2008/%s/wiki".printf(appname.down()));
		}

		// -----------------------------

		msg = format_heading(_("Feature Requests")) + "   ";
		
		msg += _("If you need changes to this application, add your requirements to the issue tracker. You can sponsor the work for your own request, or sponsor an existing request by making a donation with PayPal. Items available for sponsorship are labelled as <i>\"OpenForSponsorship\"</i>, along with an amount for the work involved. You can make a donation for that amount with PayPal, and send me an email with the issue number. Sponsored changes will be implemented in the next release of the application.");

		add_label(msg);

		hbox = add_hbox();
		
		add_button(hbox, _("Items for Sponsorship"),
			"https://github.com/teejee2008/" + appname.down() + "/issues?q=is%3Aissue+is%3Aopen+label%3AOpenForSponsorship");
			
		add_button(hbox, _("Sponsor a Feature"),
			"https://www.paypal.com/cgi-bin/webscr?business=teejeetech@gmail.com&cmd=_xclick&currency_code=USD&item_name=%s+Sponsor".printf(appname));

		// -----------------------------

		if (has_donation_plugins){
			
			msg = format_heading(_("Donation Plugins")) + "   ";
			
			msg += _("I sometimes create exclusive plugins to encourage people to contribute. You can make a contribution by translating the application to other languages, by submitting code changes, or by making a donation for $10 with PayPal. Contributors are added to an email distribution list, and plugins are sent by email. These plugins are open-source. You can request the source code after receiving the plugins.");

			add_label(msg);

			hbox = add_hbox();
			
			add_button(hbox, _("Donation Plugins"),
				"https://github.com/teejee2008/%s/wiki/Donation-Features".printf(appname.down()));

			add_button(hbox, _("Get Donation Plugins ($10)"),
				"https://www.paypal.com/cgi-bin/webscr?business=teejeetech@gmail.com&cmd=_xclick&currency_code=USD&amount=10.00&item_name=%s+Donation+Plugins".printf(appname));
		}
		
		// close window ---------------------------------------------------------

		hbox = add_hbox();
		
		var button = new Gtk.Button.with_label(_("Close"));
		button.margin_top = 12;
		hbox.add(button);
		
		button.clicked.connect(() => {
			this.destroy();
		});

		this.show_all();
	}

	private void add_heading(string msg){
		
		var label = new Gtk.Label("<span weight=\"bold\" size=\"large\" style=\"italic\">%s</span>".printf(msg));
		label.wrap = true;
		label.wrap_mode = Pango.WrapMode.WORD;
		label.set_use_markup(true);
		label.max_width_chars = 50;
		label.xalign = 0.0f;
		label.margin_top = 12;
		vbox_main.add(label);
	}
	
	private string format_heading(string msg){

		return "<span weight=\"bold\" size=\"large\" style=\"italic\">%s</span>".printf(msg);
	}

	private Gtk.Label add_label(string msg){

		var label = new Gtk.Label(msg);
		label.wrap = true;
		label.wrap_mode = Pango.WrapMode.WORD;
		label.set_use_markup(true);
		label.max_width_chars = 50;
		label.xalign = 0.0f;
		//label.margin_bottom = 6;

		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.hscrollbar_policy = PolicyType.NEVER;
		scrolled.vscrollbar_policy = PolicyType.NEVER;
		scrolled.add(label);
		vbox_main.add(scrolled);

		return label;
	}

	private Gtk.ButtonBox add_hbox(){

		var hbox = new Gtk.ButtonBox(Orientation.HORIZONTAL);
		hbox.set_layout(Gtk.ButtonBoxStyle.CENTER);
		hbox.set_spacing(6);
		vbox_main.add(hbox);
		return hbox;
	}

	private void add_button(Gtk.Box box, string text, string url){

		var button = new Gtk.Button.with_label(text);
		button.set_tooltip_text(url);
		box.add(button);
		
		button.clicked.connect(() => {
			xdg_open(url, username);
		});
	}

	private void add_link_button(Gtk.Box box, string text, string url){

		var button = new Gtk.LinkButton.with_label("", text);
		button.set_tooltip_text(url);
		box.add(button);
		
		button.clicked.connect(() => {
			xdg_open(url, username);
		});
	}
}

