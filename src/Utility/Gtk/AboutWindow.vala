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
	private Gtk.Box vbox_logo;
	private Gtk.Box vbox_credits;
	private Gtk.Box vbox_license;
	private Gtk.Box vbox_lines;
	private Gtk.Box hbox_action;
	private Gtk.Button btn_license;
	private Gtk.Button btn_credits;
	private Gtk.Button btn_close;
	private Gtk.Window window;

	private Gtk.Image img_logo;
	private Gtk.Label lbl_program_name;
	private Gtk.Label lbl_version;
	private Gtk.Label lbl_comments;
	private Gtk.Label lbl_license;
	private Gtk.LinkButton lbtn_website;
	private Gtk.Label lbl_copyright;

	private string[] _artists;
	public string[] artists{
		get{
			return _artists;
		}
		set{
			_artists = value;
		}
	}

	private string[] _authors;
	public string[] authors{
		get{
			return _authors;
		}
		set{
			_authors = value;
		}
	}

	private string[] _contributors;
	public string[] contributors{
		get{
			return _contributors;
		}
		set{
			_contributors = value;
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

	private string[] _documenters;
	public string[] documenters{
		get{
			return _documenters;
		}
		set{
			_documenters = value;
		}
	}

	private string[] _donations;
	public string[] donations{
		get{
			return _donations;
		}
		set{
			_donations = value;
		}
	}

	private string _license = "";
	public string license{
		get{
			return _license;
		}
		set{
			_license = value;
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
        set_default_size(450, 450);

		if (get_user_id_effective() == 0){
			username = get_username();
			log_debug("username: %s".printf(username));
		}
		
		vbox_main = new Gtk.Box(Orientation.VERTICAL,0);
		vbox_main.margin = 12;
		vbox_main.spacing = 6;
		this.add(vbox_main);
		
		vbox_logo = new Gtk.Box(Orientation.VERTICAL,0);
		vbox_main.add(vbox_logo);

		// license -------------------------------------
		
		vbox_license = new Gtk.Box(Orientation.VERTICAL,0);
		vbox_license.no_show_all = true;
		vbox_main.add(vbox_license);

		var sw_license = new Gtk.ScrolledWindow(null, null);
		sw_license.set_shadow_type(ShadowType.ETCHED_IN);
		sw_license.expand = true;
		vbox_license.add(sw_license);
		
		var label = new Gtk.Label("");
		label.set_use_markup(true);
		label.margin_top = 5;
		label.xalign = 0.0f;
		label.yalign = 0.0f;
		//label.max_width_chars = 70;
		label.wrap = true;
		label.wrap_mode = Pango.WrapMode.WORD_CHAR;
		label.use_markup = true;
		label.margin = 6;
		sw_license.add(label);
		lbl_license = label;
		
		// credits --------------------------------
		
		vbox_credits = new Gtk.Box(Orientation.VERTICAL,0);
		vbox_credits.no_show_all = true;
		vbox_main.add(vbox_credits);

		var sw_credits = new Gtk.ScrolledWindow(null, null);
		sw_credits.set_shadow_type(ShadowType.ETCHED_IN);
		sw_credits.expand = true;
		vbox_credits.add(sw_credits);
		
		vbox_lines = new Gtk.Box(Orientation.VERTICAL,0);
		vbox_lines.margin_top = 10;
		sw_credits.add(vbox_lines);
		
		//logo
		img_logo = new Gtk.Image();
		img_logo.margin_top = 6;
		img_logo.margin_bottom = 6;
        vbox_logo.add(img_logo);

		//program_name
		lbl_program_name = new Gtk.Label("");
		lbl_program_name.set_use_markup(true);
		vbox_logo.add(lbl_program_name);

		//version
		lbl_version = new Gtk.Label("");
		lbl_version.set_use_markup(true);
		lbl_version.margin_top = 5;
		vbox_logo.add(lbl_version);

		//comments
		lbl_comments = new Gtk.Label("");
		lbl_comments.set_use_markup(true);
		lbl_comments.margin_top = 10;
		vbox_logo.add(lbl_comments);

		//website
		lbtn_website = new LinkButton("");
		lbtn_website.margin_top = 5;
		vbox_logo.add(lbtn_website);

		lbtn_website.activate_link.connect(()=>{
			return xdg_open(lbtn_website.uri, username); 
		});

		//copyright
		lbl_copyright = new Gtk.Label("");
		lbl_copyright.set_use_markup(true);
		lbl_copyright.margin_top = 5;
		vbox_logo.add(lbl_copyright);

		//spacer_bottom
		var spacer_bottom = new Gtk.Label("");
		spacer_bottom.margin_top = 20;
		vbox_logo.add(spacer_bottom);

		add_action_buttons();
	}

	private void add_action_buttons(){

		hbox_action = add_button_box(vbox_main, Gtk.Orientation.HORIZONTAL, Gtk.ButtonBoxStyle.CENTER, 6);

		//btn_license
		btn_license = new Gtk.Button.with_label("  " + _("License"));
		btn_license.image = IconManager.lookup_image("help-about-symbolic", 16);
		hbox_action.add(btn_license);

		//btn_credits
		btn_credits = new Gtk.Button.with_label("  " + _("Credits"));
		btn_credits.image = IconManager.lookup_image("help-about-symbolic", 16);
		hbox_action.add(btn_credits);

		//btn_close
		btn_close = new Gtk.Button.with_label("  " + _("Close"));
		btn_close.image = IconManager.lookup_image("help-about-symbolic", 16);
		hbox_action.add(btn_close);

		// handlers
		
        btn_license.clicked.connect(()=>{
			
			vbox_logo.visible = !vbox_logo.visible;

			vbox_license.visible = !vbox_license.visible;
			
			if (vbox_license.visible){
				vbox_license.set_no_show_all(false);
				vbox_license.show_all();
				vbox_credits.hide();
				vbox_logo.hide();
			}
			else{
				vbox_logo.show_all();
			}

			if (vbox_license.visible){
				btn_license.label = "  " + _("Back");
				btn_license.image = IconManager.lookup_image("go-previous-symbolic", 16);
				btn_license.always_show_image = true;
				btn_credits.hide();
				this.resize(800, 500);
			}
			else{
				btn_license.label = "  " + _("License");
				btn_license.image = IconManager.lookup_image("help-about-symbolic", 16);
				btn_license.always_show_image = true;
				btn_credits.show();
				this.resize(450, 400);
			}
		});

        btn_credits.clicked.connect(()=>{
			
			vbox_logo.visible = !vbox_logo.visible;

			vbox_credits.visible = !vbox_credits.visible;

			if (vbox_credits.visible){
				vbox_credits.set_no_show_all(false);
				vbox_credits.show_all();
				vbox_license.hide();
				vbox_logo.hide();
			}
			else{
				vbox_logo.show_all();
			}

			if (vbox_credits.visible){
				btn_credits.label = "  " + _("Back");
				btn_credits.image = IconManager.lookup_image("go-previous-symbolic", 16);
				btn_credits.always_show_image = true;
				btn_license.hide();
			}
			else{
				btn_credits.label = "  " + _("Credits");
				btn_credits.image = IconManager.lookup_image("help-about-symbolic", 16);
				btn_credits.always_show_image = true;
				btn_license.show();
			}
		});


		btn_close.clicked.connect(()=>{ this.destroy(); });
	}

	public void initialize() {
		
		title = program_name;
		img_logo.pixbuf = logo.scale_simple(128,128,Gdk.InterpType.HYPER);
		lbl_program_name.label = "<span size='larger'>%s</span>".printf(program_name);
		lbl_version.label = "v%s".printf(version);
		lbl_comments.label = "%s".printf(comments);
		lbtn_website.uri = website;
		lbtn_website.label = website_label;
		lbl_copyright.label = "<span>%s</span>".printf(copyright);

		if (license.length > 0){
			lbl_license.label = license;
		}
		else{
			lbl_license.label = escape_html(GPLv2LicenseText);
		}

		if (authors.length > 0){
			add_header(_("Authors"));
			foreach(string name in authors){
				add_line("%s\n".printf(name));
			}
			add_line("\n");
		}

		if (contributors.length > 0){
			add_header(_("Contributors"));
			foreach(string name in contributors){
				add_line("%s\n".printf(name));
			}
			add_line("\n");
		}

		if (artists.length > 0){
			add_header(_("Artists"));
			foreach(string name in artists){
				add_line("%s\n".printf(name));
			}
			add_line("\n");
		}

		if (translators.length > 0){
			add_header(_("Translations"));
			foreach(string name in translators){
				add_line("%s\n".printf(name));
			}
			add_line("\n");
		}

		if (documenters.length > 0){
			add_header(_("Documentation"));
			foreach(string name in documenters){
				add_line("%s\n".printf(name));
			}
			add_line("\n");
		}

		if (third_party.length > 0){
			add_header(_("Tools"));
			foreach(string name in third_party){
				add_line("%s\n".printf(name));
			}
			add_line("\n");
		}

		if (donations.length > 0){
			add_header(_("Donations"));
			foreach(string name in donations){
				add_line("%s\n".printf(name));
			}
			add_line("\n");
		}

		if (vbox_lines.get_children().length() == 0){
			btn_credits.visible = false;
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

	private void add_header(string text){
		add_line("<b>%s</b>\n".printf(escape_html(text)), false);
	}
}
