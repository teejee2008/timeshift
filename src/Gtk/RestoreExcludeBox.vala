
/*
 * RestoreExcludeBox.vala
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
using TeeJee.Devices;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

class RestoreExcludeBox : Gtk.Box{

	private Gtk.Window parent_window;

	public RestoreExcludeBox (Gtk.Window _parent_window) {
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		margin = 12;

		log_debug("RestoreExcludeBox: RestoreExcludeBox()");

		// header ---------------
		
		//var label = add_label_header(this, _("Items to Restore"), true);

		// personal files --------------------------------
		
		/*var chk = add_checkbox(this, _("Restore System Files &amp; Settings"));
		//chk.margin_top = 12;
		chk.active = true;
		chk.sensitive = false;

		chk = add_checkbox(this, _("Restore Local Application Settings"));
		//chk.margin_top = 12;
		chk.active = true;
		chk.sensitive = false;*/
		
		/*label = add_label(this, _("If un-checked, personal files and folders in home directory will be reset to the previous state."), false, true);
		label.margin_left = 24;
		label.wrap = true;
		label.wrap_mode = Pango.WrapMode.WORD_CHAR;
			
		var tt = _("Keep existing personal files and folders in home directory. If unchecked, personal files and folders in home directory will be reset to the state it was in when snapshot was taken.");
		chk.set_tooltip_text(tt);
		label.set_tooltip_text(tt);*/
		
		// app settings header --------------------------------
		
		var label = add_label_header(this, _("Exclude App Settings"), true);
		label.margin_top = 24;

		add_label(this, _("Select applications to exclude from restore"));

		// all apps ----------------------------
		
		var chk = add_checkbox(this, _("All Applications"));
		chk.margin_top = 12;

		var tt = _("Keep configuration files for all applications. If un-checked, previous configuration files in home directory will be restored from snapshot.");
		chk.set_tooltip_text(tt);
		label.set_tooltip_text(tt);
		
		// web browsers --------------------------------

		chk = add_checkbox(this, _("Web Browsers") + " (%s)".printf(_("Recommended")));
		//chk.margin_top = 12;
		
		label = add_label(this, _("Firefox, Chrome, Chromium"), false, true);
		label.margin_left = 24;
		label.margin_top = 0;
		label.wrap = true;
		label.wrap_mode = Pango.WrapMode.WORD_CHAR;

		tt = _("Keep configuration files for web browsers like Firefox and Chrome. If un-checked, previous configuration files will be restored from snapshot");
		chk.set_tooltip_text(tt);
		label.set_tooltip_text(tt);

		// torrent clients ----------------------------
		
		chk = add_checkbox(this, _("Bittorrent Clients") + " (%s)".printf(_("Recommended")));
		//chk.margin_top = 12;
		
		label = add_label(this, _("Deluge, Transmission"), false, true);
		label.margin_left = 24;
		label.margin_top = 0;
		label.wrap = true;
		label.wrap_mode = Pango.WrapMode.WORD_CHAR;

		tt = _("Keep configuration files for bittorrent clients like Deluge, Transmission, etc. If un-checked, previous configuration files will be restored from snapshot.");
		chk.set_tooltip_text(tt);
		label.set_tooltip_text(tt);

		
		
		//label.set_tooltip_text(_("Keep existing configuration files for all applications."));

		//chk.set_tooltip_text(tt);
		//label.set_tooltip_text(tt);
		
		// all apps ----------------------------
		
		chk = add_checkbox(this, _("Other applications (next page)"));
		//chk.margin_top = 12;
		
		//chk.set_tooltip_text(tt);
		//label.set_tooltip_text(tt);

		log_debug("RestoreExcludeBox: RestoreExcludeBox(): exit");
    }

    public void refresh(){

	}
}
