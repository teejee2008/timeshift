/*
 * DeleteBox.vala
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
using Gee;

#if XAPP
using XApp;
#endif

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

class DeleteBox : Gtk.Box{
	private Gtk.Spinner spinner;
	public Gtk.Label lbl_msg;
	public Gtk.Label lbl_status;
	public Gtk.Label lbl_remaining;
	public Gtk.ProgressBar progressbar;

	private Gtk.Window parent_window;

	public DeleteBox (Gtk.Window _parent_window) {

		log_debug("DeleteBox: DeleteBox()");
		
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		GLib.Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		margin = 12;
		
		// header
		add_label_header(this, _("Deleting Snapshots..."), true);

		var hbox_status = new Gtk.Box(Orientation.HORIZONTAL, 6);
		add (hbox_status);
		
		spinner = new Gtk.Spinner();
		spinner.active = true;
		hbox_status.add(spinner);
		
		//lbl_msg
		lbl_msg = add_label(hbox_status, _("Preparing..."));
		lbl_msg.hexpand = true;
		lbl_msg.ellipsize = Pango.EllipsizeMode.END;
		lbl_msg.max_width_chars = 45;

		lbl_remaining = add_label(hbox_status, "");

		//progressbar
		progressbar = new Gtk.ProgressBar();
		//progressbar.set_size_request(-1,25);
		//progressbar.show_text = true;
		//progressbar.pulse_step = 0.1;
		add (progressbar);

		//lbl_status
		lbl_status = add_label(this, "");
		lbl_status.ellipsize = Pango.EllipsizeMode.MIDDLE;
		lbl_status.max_width_chars = 45;
		lbl_status.margin_bottom = 12;

		log_debug("DeleteBox: DeleteBox(): exit");
    }

	public bool delete_snapshots(){

		log_debug("DeleteBox: delete_snapshots()");

		if (!App.thread_delete_running){
			App.delete_begin();
		}

		if (App.btrfs_mode){
			
			while (App.thread_delete_running){
				
				lbl_msg.label = App.progress_text;
				gtk_do_events();
				sleep(200);

				#if XAPP
				XApp.set_window_progress_pulse(parent_window, true);
				#endif
			}

			#if XAPP
			XApp.set_window_progress_pulse(parent_window, false);
			#endif
		}
		else{
			
			int wait_interval_millis = 100;
			int status_line_counter = 0;
			int status_line_counter_default = 1000 / wait_interval_millis;
			string status_line = "";
			string last_status_line = "";
			int remaining_counter = 10;
			
			while (App.thread_delete_running){

				status_line = escape_html(App.delete_file_task.status_line);

				if (status_line != last_status_line){
					lbl_status.label = status_line;
					last_status_line = status_line;
					status_line_counter = status_line_counter_default;
				}
				else{
					status_line_counter--;
					if (status_line_counter < 0){
						status_line_counter = status_line_counter_default;
						lbl_status.label = "";
					}
				}

				double fraction = App.delete_file_task.progress;

				// time remaining
				remaining_counter--;
				
				if (remaining_counter == 0){
					
					lbl_remaining.label = App.delete_file_task.stat_time_remaining + " " + _("remaining");

					remaining_counter = 10;
				}
					
				if (fraction < 0.99){
					progressbar.fraction = fraction;

					#if XAPP
					XApp.set_window_progress(parent_window, (int)(fraction * 100.0));
					#endif
				}

				lbl_msg.label = App.delete_file_task.status_message;

				gtk_do_events();

				sleep(100);
			}

			#if XAPP
			XApp.set_window_progress(parent_window, 0);
			#endif
		}
		
		//parent_window.destroy();

		return App.thread_delete_success;
	}
}
