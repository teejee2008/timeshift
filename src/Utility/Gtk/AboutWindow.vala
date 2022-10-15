/*
 * AboutWindow.vala
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
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class AboutWindow : Gtk.Window {
	
	private Gtk.Box vbox_main;
	private Gtk.Box vbox_lines;
	private Gtk.Box hbox_action;
	private Gtk.Window window;

	private Gtk.Image img_logo;
	private Gtk.Label lbl_program_name;
	private Gtk.Label lbl_version;
	private Gtk.Label lbl_comments;
	private Gtk.Label lbl_license;
	private Gtk.LinkButton lbtn_website;
	private Gtk.Label lbl_copyright;

	private string[] _authors;
	public string[] authors{
		get{
			return _authors;
		}
		set{
			_authors = value;
		}
	}
	
	private string _comments = "";
	public string comments{
		get{
			return _comments;
		}
		set{
			_comments = value;
		}
	}
	
	private string _copyright = "";
	public string copyright{
		get{
			return _copyright;
		}
		set{
			_copyright = value;
		}
	}

	private Gdk.Pixbuf _logo;
	public Gdk.Pixbuf logo{
		get{
			return _logo;
		}
		set{
			_logo = value;
		}
	}

	private string _program_name = "";
	public string program_name{
		get{
			return _program_name;
		}
		set{
			_program_name = value;
		}
	}

	private string[] _translators;
	public string[] translators{
		get{
			return _translators;
		}
		set{
			_translators = value;
		}
	}
	
	private string[] _third_party;
	public string[] third_party{
		get{
			return _third_party;
		}
		set{
			_third_party = value;
		}
	}

	private string _version = "";
	public string version{
		get{
			return _version;
		}
		set{
			_version = value;
		}
	}

	private string _website = "";
	public string website{
		get{
			return _website;
		}
		set{
			_website = value;
		}
	}

	private string _website_label = "";
	public string website_label{
		get{
			return _website_label;
		}
		set{
			_website_label = value;
		}
	}

	private string username = "";
	
	public AboutWindow(Gtk.Window _window) {

		window = _window;
		
        window_position = WindowPosition.CENTER_ON_PARENT;
		set_destroy_with_parent (true);
		set_modal (true);
        skip_taskbar_hint = false;
        set_default_size(450, 400);

		if (get_user_id_effective() == 0){
			username = get_username();
			log_debug("username: %s".printf(username));
		}
		
		vbox_main = new Gtk.Box(Orientation.VERTICAL, 10);
		vbox_main.margin = 10;
		this.add(vbox_main);
		
		// logo
		
		img_logo = new Gtk.Image();
		img_logo.margin = 10;
        vbox_main.add(img_logo);

		// program_name
		
		lbl_program_name = new Gtk.Label("");
		lbl_program_name.set_use_markup(true);
		vbox_main.add(lbl_program_name);

		// version
		
		lbl_version = new Gtk.Label("");
		lbl_version.set_use_markup(true);
		vbox_main.add(lbl_version);
		
		// comments
		
		lbl_comments = new Gtk.Label("");
		lbl_comments.set_use_markup(true);
		vbox_main.add(lbl_comments);
		
		// website
		
		lbtn_website = new LinkButton("");
		vbox_main.add(lbtn_website);

		lbtn_website.activate_link.connect(()=>{
			return xdg_open(lbtn_website.uri, username); 
		});

		// copyright
		lbl_copyright = new Gtk.Label("");
		lbl_copyright.set_use_markup(true);
		vbox_main.add(lbl_copyright);
		
		// copyright
		lbl_license = new Gtk.Label("");
		lbl_license.set_use_markup(true);
		vbox_main.add(lbl_license);

		// spacer
		var spacer = new Gtk.Label("");
		spacer.vexpand = true;
		//vbox_main.add(spacer);

		add_action_buttons();
	}

	private void add_action_buttons(){

		hbox_action = add_button_box(vbox_main, Gtk.Orientation.HORIZONTAL, Gtk.ButtonBoxStyle.CENTER, 6);
		hbox_action.margin = 10;
		
		string url = "https://www.gnu.org/licenses/old-licenses/gpl-2.0.html";
		
		// btn_license
		var btn_license = new Gtk.Button.with_label("License");
		btn_license.set_tooltip_text(url);
		btn_license.image = IconManager.lookup_image("help-about-symbolic", 16);
		hbox_action.add(btn_license);

		btn_license.clicked.connect(()=>{ 
			xdg_open(url, username); 
		});
		
		// btn_close
		var btn_close = new Gtk.Button.with_label(_("Close"));
		btn_close.image = IconManager.lookup_image("help-about-symbolic", 16);
		hbox_action.add(btn_close);

		btn_close.clicked.connect(()=>{ this.destroy(); });
	}

	public void initialize() {
		
		title = program_name;
		img_logo.pixbuf = logo.scale_simple(128,128,Gdk.InterpType.HYPER);
		lbl_program_name.label = "<span size='larger' weight='bold'>%s</span>".printf(program_name);
		lbl_version.label = "v%s".printf(version);
		lbl_comments.label = "%s".printf(comments);
		lbtn_website.uri = website;
		lbtn_website.label = website_label;
		lbl_copyright.label = "<span>%s</span>".printf(copyright);
		
		lbl_license.label = 
"""<small>This program comes with absolutely no warranty.
See the GNU General Public License v2 or later, for details</small>""";

		if (authors.length > 0){
			foreach(string name in authors){
				add_line("%s\n".printf(name));
			}
			add_line("\n");
		}
	}

	private void add_line(string text, bool escape_html_chars = true){
		
		if (text.split(":").length >= 2){
			
			var link = new LinkButton(escape_html(text.split(":")[0]));
			vbox_lines.add(link);

			string val = text[text.index_of(":") + 1:text.length];
			if (val.contains("@")){
				link.uri = "mailto:" + val;
			}
			else if(val.has_prefix("http://") || val.has_prefix("https://")){
				link.uri = val;
			}
			else{
				link.uri = "http://" + val;
			}

			link.activate_link.connect(()=>{
				return xdg_open(link.uri, username); 
			});
		}
		else{
			var txt = text;
			if (escape_html_chars){
				txt = escape_html(text);
			}

			var lbl = new Gtk.Label(txt);
			lbl.set_use_markup(true);
			lbl.valign = Align.START;
			lbl.wrap = true;
			lbl.wrap_mode = Pango.WrapMode.WORD;
			vbox_lines.add(lbl);
		}
	}
}
