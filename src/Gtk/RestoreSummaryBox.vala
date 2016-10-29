
/*
 * RestoreSummaryBox.vala
 *
 * Copyright 2016 Tony George <tony.george.kol@gmail.com>
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

class RestoreSummaryBox : Gtk.Box{
	public Gtk.Label lbl_devices;
	public Gtk.Label lbl_reboot;
	public Gtk.Label lbl_disclaimer;
	private Gtk.Window parent_window;

	public RestoreSummaryBox (Gtk.Window _parent_window) {
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		margin = 12;

		log_debug("RestoreSummaryBox: RestoreSummaryBox()");

		// devices
		
		add_label_header(this, _("Warning"), true);

		lbl_devices = add_label(this, "", false, false, false);

		// reboot warning

		lbl_reboot = add_label(this, "", true, false, false);
		lbl_reboot.margin_bottom = 6;
		
		// disclaimer
		
		add_label_header(this, _("Disclaimer"), true);
		
		lbl_disclaimer = add_label(this, "", false, false, false);

		// click next
		
		//var label = add_label(this, _("Click Next to continue"), false, false, true);
		//label.margin_top = 6;
		//label.margin_bottom = 6;
		
		// refresh
		
		refresh();

		log_debug("RestoreSummaryBox: RestoreSummaryBox(): exit");
    }

    public void refresh(){
		string msg_devices = "";
		string msg_reboot = "";
		string msg_disclaimer = "";

		App.get_restore_messages(
			true, out msg_devices, out msg_reboot,
			out msg_disclaimer);

		lbl_devices.label = msg_devices;
		lbl_reboot.label = msg_reboot;
		lbl_disclaimer.label = msg_disclaimer;
	}
}
