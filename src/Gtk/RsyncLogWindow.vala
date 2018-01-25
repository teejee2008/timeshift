/*
 * RsyncLogWindow.vala
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

public class RsyncLogWindow : Window {

	private Gtk.Box vbox_main;
	
	//window
	private int def_width = 800;
	private int def_height = 600;

	private RsyncLogBox logbox;
	private string rsync_log_file;

	public RsyncLogWindow(string _rsync_log_file) {

		log_debug("RsyncLogWindow: RsyncLogWindow()");
		
		this.title = _("Rsync Log Viewer");
		this.window_position = Gtk.WindowPosition.CENTER_ON_PARENT;
		this.set_default_size(def_width, def_height);
		this.icon = IconManager.lookup("timeshift",16);
		this.resizable = true;
		this.modal = true;

		this.delete_event.connect(on_delete_event);

		rsync_log_file = _rsync_log_file;
		
		logbox = new RsyncLogBox(this);
		this.add(logbox);
		
		show_all();

		logbox.open_log(rsync_log_file);

		log_debug("RsyncLogWindow: RsyncLogWindow(): exit");
	}

	private bool on_delete_event(Gdk.EventAny event){
		
		if (logbox.is_running){
			return true; // keep window open
		}
		else{
			this.delete_event.disconnect(on_delete_event); //disconnect this handler
			return false; // close window
		}
	}

}
