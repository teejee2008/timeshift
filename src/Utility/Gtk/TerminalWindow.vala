/*
 * TerminalWindow.vala
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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class TerminalWindow : Gtk.Window {
	
	private Gtk.Box vbox_main;
	private Vte.Terminal term;
	
	private int def_width = 800;
	private int def_height = 600;

	private Pid child_pid;
	private Gtk.Window parent_win = null;
	public bool is_running = false;
	
	// init
	
	public TerminalWindow.with_parent(Gtk.Window? parent) {
		
		if (parent != null){
			set_transient_for(parent);
			parent_win = parent;
		}
		
		set_modal(true);
		fullscreen();

		this.delete_event.connect(()=>{
			// do not allow window to close 
			return true;
		});
		
		init_window();
	}

	public void init_window () {
		
		this.title = "";
		this.icon = IconManager.lookup("timeshift",16);
		this.resizable = true;
		this.deletable = false;
		
		// vbox_main ---------------
		
		vbox_main = new Gtk.Box(Orientation.VERTICAL, 6);
		vbox_main.set_size_request (def_width, def_height);
		add (vbox_main);

		// terminal ----------------------
		
		term = new Vte.Terminal();
		term.expand = true;
		vbox_main.add(term);

		term.input_enabled = true;
		term.backspace_binding = Vte.EraseBinding.AUTO;
		term.cursor_blink_mode = Vte.CursorBlinkMode.SYSTEM;
		term.cursor_shape = Vte.CursorShape.UNDERLINE;
		//term.rewrap_on_resize = true;
		
		term.scroll_on_keystroke = true;
		term.scroll_on_output = true;

		// colors -----------------------------
		
		var color = Gdk.RGBA();
		color.parse("#FFFFFF");
		term.set_color_foreground(color);

		color.parse("#404040");
		term.set_color_background(color);
		
		// grab focus ----------------
		
		term.grab_focus();
		
		show_all();
	}

	public void start_shell(){
		
		string[] argv = new string[1];
		argv[0] = "/bin/sh";

		string[] env = Environ.get();
		
		try{

			is_running = true;

			term.spawn_sync(
				Vte.PtyFlags.DEFAULT, //pty_flags
				TEMP_DIR, //working_directory
				argv, //argv
				env, //env
				GLib.SpawnFlags.SEARCH_PATH, //spawn_flags
				null, //child_setup
				out child_pid,
				null
			);
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	public void execute_script(string script_path, bool wait = false){
		
		string[] argv = new string[1];
		argv[0] = script_path;
		
		string[] env = Environ.get();

		try{

			is_running = true;
			
			term.spawn_sync(
				Vte.PtyFlags.DEFAULT, //pty_flags
				TEMP_DIR, //working_directory
				argv, //argv
				env, //env
				GLib.SpawnFlags.SEARCH_PATH, //spawn_flags
				null, //child_setup
				out child_pid,
				null
			);

			term.watch_child(child_pid);
	
			term.child_exited.connect(script_exit);

			if (wait){
				while (is_running){
					sleep(200);
					gtk_do_events();
				}
			}
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	public void script_exit(int status){

		is_running = false;
		
		this.hide();

		//no need to check status again
		
		//destroying parent will display main window
		if (parent != null){
			parent_win.destroy();
		}
	}
}


