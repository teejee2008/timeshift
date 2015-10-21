/*
 * DonationWindow.vala
 *
 * Copyright 2012 Tony George <teejee2008@gmail.com>
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
using TeeJee.JSON;
using TeeJee.ProcessManagement;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class DonationWindow : Dialog {
	public DonationWindow() {
		set_title(_("Donate"));
		window_position = WindowPosition.CENTER_ON_PARENT;
		set_destroy_with_parent (true);
		set_modal (true);
		set_deletable(true);
		set_skip_taskbar_hint(false);
		set_default_size (400, 20);
		icon = get_app_icon(16);

		//vbox_main
		Box vbox_main = get_content_area();
		vbox_main.margin = 6;
		vbox_main.homogeneous = false;

		get_action_area().visible = false;

		//lbl_message
		Label lbl_message = new Gtk.Label("");
		string msg = _("Did you find this software useful?\n\nYou can buy me a coffee or make a donation via PayPal to show your support. Or just drop me an email and say Hi. This application is completely free and will continue to remain that way. Your contributions will help in keeping this project alive and improving it further.\n\nFeel free to send me an email if you find any issues in this application or if you need any changes. Suggestions and feedback are always welcome.\n\nThanks,\nTony George\n(teejeetech@gmail.com)");
		lbl_message.label = msg;
		lbl_message.wrap = true;
		vbox_main.pack_start(lbl_message,true,true,0);

		//vbox_actions
		Box vbox_actions = new Box (Orientation.VERTICAL, 6);
		vbox_actions.margin_left = 50;
		vbox_actions.margin_right = 50;
		vbox_actions.margin_top = 20;
		vbox_main.pack_start(vbox_actions,false,false,0);

		//btn_donate_paypal
		Button btn_donate_paypal = new Button.with_label("   " + _("Donate with PayPal") + "   ");
		vbox_actions.add(btn_donate_paypal);
		btn_donate_paypal.clicked.connect(()=>{
			xdg_open("https://www.paypal.com/cgi-bin/webscr?business=teejeetech@gmail.com&cmd=_xclick&currency_code=USD&amount=10&item_name=Timeshift%20Donation");
		});

		//btn_donate_wallet
		Button btn_donate_wallet = new Button.with_label("   " + _("Donate with Google Wallet") + "   ");
		vbox_actions.add(btn_donate_wallet);
		btn_donate_wallet.clicked.connect(()=>{
			xdg_open("https://support.google.com/mail/answer/3141103?hl=en");
		});
		
		//btn_send_email
		Button btn_send_email = new Button.with_label("   " + _("Send Email") + "   ");
		vbox_actions.add(btn_send_email);
		btn_send_email.clicked.connect(()=>{
			xdg_open("mailto:teejeetech@gmail.com");
		});

		//btn_visit
		Button btn_visit = new Button.with_label("   " + _("Visit Website") + "   ");
		vbox_actions.add(btn_visit);
		btn_visit.clicked.connect(()=>{
			xdg_open("http://www.teejeetech.in");
		});

		//btn_exit
		Button btn_exit = new Button.with_label("   " + _("OK") + "   ");
		vbox_actions.add(btn_exit);
		btn_exit.clicked.connect(() => {
			this.destroy();
		});
	}
}
