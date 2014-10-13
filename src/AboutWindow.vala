/*
 * AboutWindow.vala
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

public class AboutWindow : Dialog {
	private Box vbox_main;
	private Box vbox_logo;
	private Box vbox_credits;
	private Box vbox_lines;
	private Box hbox_action;
	private Button btn_credits;
	private Button btn_close;
	
	private Gtk.Image img_logo;
	private Label lbl_program_name;
	private Label lbl_version;
	private Label lbl_comments;
	private LinkButton lbtn_website;
	private Label lbl_copyright;

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
	
	public AboutWindow() {
        window_position = WindowPosition.CENTER_ON_PARENT;
		set_destroy_with_parent (true);
		set_modal (true);
        skip_taskbar_hint = false;
        set_default_size (450, 400);	

	    vbox_main = get_content_area();
		vbox_main.margin = 6;
		vbox_main.spacing = 6;
		
		vbox_logo = new Box(Orientation.VERTICAL,0);
		vbox_main.add(vbox_logo);
		
		vbox_credits = new Box(Orientation.VERTICAL,0);
		vbox_credits.no_show_all = true;
		vbox_main.add(vbox_credits);

		vbox_lines = new Box(Orientation.VERTICAL,0);
		vbox_lines.margin_top = 10;

		//logo
		img_logo = new Gtk.Image();
		img_logo.margin_top = 6;
		img_logo.margin_bottom = 6;
        vbox_logo.add(img_logo);
		
		//program_name
		lbl_program_name = new Label("");
		lbl_program_name.set_use_markup(true);
		vbox_logo.add(lbl_program_name);

		//version
		lbl_version = new Label("");
		lbl_version.set_use_markup(true);
		lbl_version.margin_top = 5;
		vbox_logo.add(lbl_version);

		//comments
		lbl_comments = new Label("");
		lbl_comments.set_use_markup(true);
		lbl_comments.margin_top = 10;
		vbox_logo.add(lbl_comments);
		
		//website
		lbtn_website = new LinkButton("");
		lbtn_website.margin_top = 5;
		vbox_logo.add(lbtn_website);

		lbtn_website.activate_link.connect(()=>{
			try{
				return Gtk.show_uri(null, lbtn_website.uri, Gdk.CURRENT_TIME); 
			}
			catch(Error e){
				return false;
			}
		});
		
		//copyright
		lbl_copyright = new Label("");
		lbl_copyright.set_use_markup(true);
		lbl_copyright.margin_top = 5;
		vbox_logo.add(lbl_copyright);

		//spacer_bottom
		var spacer_bottom = new Label("");
		spacer_bottom.margin_top = 20;
		vbox_logo.add(spacer_bottom);

		//scroller
		var sw_credits = new ScrolledWindow(null, null);
		sw_credits.set_shadow_type(ShadowType.ETCHED_IN);
		sw_credits.expand = true;
		
		vbox_credits.add(sw_credits);
		sw_credits.add(vbox_lines);
		
		//hbox_commands --------------------------------------------------
		
		hbox_action = (Box) get_action_area();
		
		//btn_credits
		btn_credits = new Button.with_label("  " + _("Credits"));
		btn_credits.set_image (new Image.from_stock ("gtk-about", IconSize.MENU));
		hbox_action.add(btn_credits);	
			
        btn_credits.clicked.connect(()=>{
			vbox_logo.visible = !(vbox_logo.visible);
			vbox_credits.visible = !(vbox_credits.visible);
			
			if ((vbox_credits.visible)&&(!sw_credits.visible)){
				sw_credits.show_all();
			}
			
			if (vbox_credits.visible){
				btn_credits.label = "  " + _("Back");
				btn_credits.set_image (new Image.from_stock ("gtk-go-back", IconSize.MENU));
			}
			else{
				btn_credits.label = "  " + _("Credits");
				btn_credits.set_image (new Image.from_stock ("gtk-about", IconSize.MENU));
			}
		});

		//btn_close
		btn_close = new Button.with_label("  " + _("Close"));
		btn_close.set_image (new Image.from_stock ("gtk-close", IconSize.MENU));
		hbox_action.add(btn_close);
		
		btn_close.clicked.connect(()=>{ this.destroy(); });
	}
	
	public void initialize() {
		title = program_name;
		img_logo.pixbuf = logo;
		lbl_program_name.label = "<span size='larger'>%s</span>".printf(program_name);
		lbl_version.label = "v%s".printf(version);
		lbl_comments.label = "%s".printf(comments);
		lbtn_website.uri = website;
		lbtn_website.label = website_label;
		//lbl_copyright.label = "<span size='smaller'>%s</span>".printf(copyright);
		lbl_copyright.label = "<span>%s</span>".printf(copyright);
		
		if (authors.length > 0){
			add_line("<b>%s</b>\n".printf(_("Authors")));
			foreach(string name in authors){
				add_line("%s\n".printf(name));
			}
			add_line("\n");
		}
		
		if (third_party.length > 0){
			add_line("<b>%s</b>\n".printf(_("Third Party Tools")));
			foreach(string name in third_party){
				add_line("%s\n".printf(name));
			}
			add_line("\n");
		}
		
		if (artists.length > 0){
			add_line("<b>%s</b>\n".printf(_("Artists")));
			foreach(string name in artists){
				add_line("%s\n".printf(name));
			}
			add_line("\n");
		}

		if (translators.length > 0){
			add_line("<b>%s</b>\n".printf(_("Translators")));
			foreach(string name in translators){
				add_line("%s\n".printf(name));
			}
			add_line("\n");
		}

		if (documenters.length > 0){
			add_line("<b>%s</b>\n".printf(_("Documenters")));
			foreach(string name in documenters){
				add_line("%s\n".printf(name));
			}
			add_line("\n");
		}

		if (donations.length > 0){
			add_line("<b>%s</b>\n".printf(_("Donations")));
			foreach(string name in donations){
				add_line("%s\n".printf(name));
			}
			add_line("\n");
		}

		if (vbox_lines.get_children().length() == 0){
			btn_credits.visible = false;
		}
	}
	
	public void add_line(string text){
		if (text.split(":").length >= 2){
			var link = new LinkButton(text.split(":")[0]);
			vbox_lines.add(link);
			
			string val = text[text.index_of(":") + 1:text.length];
			if (val.contains("@")){
				link.uri = "mailto:" + val;
			}
			else if(val.has_prefix("http://")){
				link.uri = val;
			}
			else{
				link.uri = "http://" + val;
			}

			link.activate_link.connect(()=>{
				try{
					return Gtk.show_uri(null, link.uri, Gdk.CURRENT_TIME); 
				}
				catch(Error e){
					return false;
				}
			});
		}
		else{
			var lbl = new Label(text);
			lbl.set_use_markup(true);
			lbl.valign = Align.START;
			lbl.wrap = true;
			lbl.wrap_mode = Pango.WrapMode.WORD;
			vbox_lines.add(lbl);
		}
	}
}
