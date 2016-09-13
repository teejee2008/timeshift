/*
 * EstimateBox.vala
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

class EstimateBox : Gtk.Box{
	private Gtk.ProgressBar progressbar;
	private Gtk.Window parent_window;
	
	private bool thread_is_running = false;

	public EstimateBox (Gtk.Window _parent_window) {
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		margin = 12;
		
		// header
		add_label_header(this, _("Estimating System Size..."), true);

		var hbox_status = new Gtk.Box (Orientation.HORIZONTAL, 6);
		add (hbox_status);
		
		var spinner = new Gtk.Spinner();
		spinner.active = true;
		hbox_status.add(spinner);
		
		//lbl_msg
		var lbl_msg = add_label(hbox_status, "Please wait...");
		lbl_msg.halign = Align.START;
		lbl_msg.ellipsize = Pango.EllipsizeMode.END;
		lbl_msg.max_width_chars = 50;

		//progressbar
		progressbar = new Gtk.ProgressBar();
		//progressbar.set_size_request(-1,25);
		//progressbar.pulse_step = 0.1;
		add (progressbar);
    }

	public void estimate_system_size(){

		if (Main.first_snapshot_size > 0){
			log_debug("EstimateBox: size > 0");
			return;
		}
		
		progressbar.fraction = 0.0;

		// start the estimation if not already running
		if (!App.thread_estimate_running){

			log_debug("EstimateBox: thread started");
			
			try {
				thread_is_running = true;
				Thread.create<void> (estimate_system_size_thread, true);
			}
			catch (ThreadError e) {
				thread_is_running = false;
				log_error (e.message);
			}
		}

		// wait for completion and increment progressbar
		while (thread_is_running){
			if (progressbar.fraction < 98.0){
				progressbar.fraction += 0.005;
			}
			
			gtk_do_events();
			sleep(100);
		}
	}

	private void estimate_system_size_thread(){
		App.estimate_system_size();
		log_debug("EstimateBox: thread finished");
		thread_is_running = false;
	}
}
