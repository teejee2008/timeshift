/*
 * IconManager.vala
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
using Cairo;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class IconManager : GLib.Object {

	public static Gtk.IconTheme theme;

	public static Gee.ArrayList<string> search_paths = new Gee.ArrayList<string>();

    public const int SHIELD_ICON_SIZE = 64;

    public const string GENERIC_ICON_IMAGE = "image-x-generic";
    public const string GENERIC_ICON_IMAGE_MISSING = "image-missing";
    public const string GENERIC_ICON_VIDEO = "video-x-generic";
    public const string GENERIC_ICON_FILE = "text-x-preview";
    public const string GENERIC_ICON_ARCHIVE_FILE = "package-x-generic";
    public const string GENERIC_ICON_DIRECTORY = "folder";
    public const string GENERIC_ICON_ISO = "media-cdrom";
    public const string GENERIC_ICON_PDF = "application-pdf";

    public const string ICON_HARDDRIVE = "drive-harddisk";

    public const string SHIELD_LIVE= "media-optical";
    public const string SHIELD_LOW = "timeshift-shield-low";
    public const string SHIELD_MED = "timeshift-shield-med";
    public const string SHIELD_HIGH = "timeshift-shield-high";

	public static void init(string[] args, string app_name){

		log_debug("IconManager: init()");
		
		search_paths = new Gee.ArrayList<string>();

		// check absolute location
		string path = "/usr/share/%s/images".printf(app_name);
		if (dir_exists(path)){
			search_paths.add(path);
			log_debug("found images directory: %s".printf(path));
		}

		refresh_icon_theme();
	}

	public static void refresh_icon_theme(){

		if (!GTK_INITIALIZED) { return; }
		
		theme = Gtk.IconTheme.get_default();
		foreach(string path in search_paths){
			theme.append_search_path(path);
		}
	}

	public static Gdk.Pixbuf? lookup(string icon_name, int icon_size, bool symbolic = false, bool use_hardcoded = false, int scale = 1){
		
		Gdk.Pixbuf? pixbuf = null;

		if (icon_name.length == 0){ return null; }

		if (!use_hardcoded){
			try {
				pixbuf = theme.load_icon_for_scale(icon_name, icon_size, scale, Gtk.IconLookupFlags.FORCE_SIZE);
				if (pixbuf != null){ return pixbuf; }
			}
			catch (Error e) {
				log_debug(e.message);
			}
		}

		foreach(string search_path in search_paths){

			foreach(string ext in new string[] { ".svg", ".png", ".jpg", ".gif"}){

				string img_file = path_combine(search_path, icon_name + ext);

				if (file_exists(img_file)){

					pixbuf = load_pixbuf_from_file(img_file, icon_size);
					if (pixbuf != null){ return pixbuf; }
				}
			}
		}

		return pixbuf;
	}
	
	public static Gtk.Image? lookup_image(string icon_name, int icon_size, bool symbolic = false, bool use_hardcoded = false){

		if (icon_name.length == 0){ return null; }

        Gtk.Image image = new Gtk.Image();

		Gdk.Pixbuf? pix = lookup(icon_name, icon_size, symbolic, use_hardcoded, image.scale_factor);
		
		if (pix == null){
			pix = lookup(GENERIC_ICON_IMAGE_MISSING, icon_size, symbolic, use_hardcoded, image.scale_factor);
		}

        Cairo.Surface surf = Gdk.cairo_surface_create_from_pixbuf(pix, image.scale_factor, null);

        image.set_from_surface(surf);

        return image;
	}

    public static Cairo.Surface? lookup_surface(string icon_name, int icon_size, int scale = 1, bool symbolic = false, bool use_hardcoded = false){
        if (icon_name.length == 0){ return null; }
        
        Gdk.Pixbuf? pix = lookup(icon_name, icon_size, symbolic, use_hardcoded, scale);
        
        if (pix == null){
            pix = lookup(GENERIC_ICON_IMAGE_MISSING, icon_size, symbolic, use_hardcoded, scale);
        }

        return Gdk.cairo_surface_create_from_pixbuf(pix, scale, null);
    }

	public static Gdk.Pixbuf? lookup_gicon(GLib.Icon? gicon, int icon_size){

		Gdk.Pixbuf? pixbuf = null;

		if (gicon == null){ return null; }
		
		try {
			var icon_info = theme.lookup_by_gicon(gicon, icon_size, Gtk.IconLookupFlags.FORCE_SIZE);
			if (icon_info != null){
				pixbuf = icon_info.load_icon();
			}
		}
		catch (Error e) {
			log_debug(e.message);
		}

		return pixbuf;
	}

	public static Gdk.Pixbuf? add_emblem (Gdk.Pixbuf pixbuf, string icon_name, int emblem_size, bool emblem_symbolic, Gtk.CornerType corner_type) {

		if (icon_name.length == 0){ return pixbuf; }

        Gdk.Pixbuf? emblem = null;

		var SMALL_EMBLEM_COLOR = Gdk.RGBA();
		SMALL_EMBLEM_COLOR.parse("#000000");
		SMALL_EMBLEM_COLOR.alpha = 1.0;

		var EMBLEM_PADDING = 1;

        try {
            var icon_info = theme.lookup_icon (icon_name, emblem_size, Gtk.IconLookupFlags.FORCE_SIZE);
            if (emblem_symbolic){
				emblem = icon_info.load_symbolic(SMALL_EMBLEM_COLOR);
			}
			else{
				emblem = icon_info.load_icon();
			}
        } catch (GLib.Error e) {
            log_error("get_icon_emblemed(): %s".printf(e.message));
            return pixbuf;
        }

        if (emblem == null)
            return pixbuf;

        var offset_x = EMBLEM_PADDING;

        if ((corner_type == Gtk.CornerType.BOTTOM_RIGHT) || (corner_type == Gtk.CornerType.TOP_RIGHT)){
			offset_x = pixbuf.width - emblem.width - EMBLEM_PADDING ;
		}

		var offset_y = EMBLEM_PADDING;

		if ((corner_type == Gtk.CornerType.BOTTOM_LEFT) || (corner_type == Gtk.CornerType.BOTTOM_RIGHT)){
			offset_y = pixbuf.height - emblem.height - EMBLEM_PADDING ;
		}

        var emblemed = pixbuf.copy();
        
        emblem.composite(emblemed, 
			offset_x, offset_y, 
			emblem_size, emblem_size,
			offset_x, offset_y, 
			1.0, 1.0, 
			Gdk.InterpType.BILINEAR, 255);

        return emblemed;
    }
    
    public static Gdk.Pixbuf? add_overlay(Gdk.Pixbuf pixbuf_base, Gdk.Pixbuf pixbuf_overlay) {

        int offset_x = (pixbuf_base.width - pixbuf_overlay.width) / 2 ;

		var offset_y = (pixbuf_base.height - pixbuf_overlay.height) / 2 ;

        var emblemed = pixbuf_base.copy();
        
        pixbuf_overlay.composite(emblemed, 
			offset_x, offset_y, 
			pixbuf_overlay.width, pixbuf_overlay.height,
			offset_x, offset_y, 
			1.0, 1.0, 
			Gdk.InterpType.BILINEAR, 255);

        return emblemed;
    }
    
    public static Gdk.Pixbuf? resize_icon(Gdk.Pixbuf pixbuf_image, int icon_size) {
		
		//log_debug("resize_icon()");
		
		var pixbuf_empty = new Gdk.Pixbuf(Gdk.Colorspace.RGB, true, 8, icon_size, icon_size);
		pixbuf_empty.fill(0x00000000);

		//log_debug("pixbuf_empty: %d, %d".printf(pixbuf_empty.width, pixbuf_empty.height));
		
		var pixbuf_resized = add_overlay(pixbuf_empty, pixbuf_image);
		
		//log_debug("pixbuf_resized: %d, %d".printf(pixbuf_resized.width, pixbuf_resized.height));

		//copy_pixbuf_options(pixbuf_image, pixbuf_resized);
		
        return pixbuf_resized;
    }
    
    public static Gdk.Pixbuf? add_transparency (Gdk.Pixbuf pixbuf, int opacity = 130) {

		var trans = pixbuf.copy();
		trans.fill((uint32) 0xFFFFFF00);

		//log_debug("add_transparency");

		int width = pixbuf.get_width();
		int height = pixbuf.get_height();
		pixbuf.composite(trans, 0, 0, width, height, 0, 0, 1.0, 1.0, Gdk.InterpType.BILINEAR, opacity);

        return trans;
    }
    
    public static Gdk.Pixbuf? load_pixbuf_from_file(string file_path, int icon_size){
		
		Gdk.Pixbuf? pixbuf = null;
		
		int width, height;
		Gdk.Pixbuf.get_file_info(file_path, out width, out height);
		
		if ((width <= icon_size) && (height <= icon_size)){
			try{
				// load without scaling
				pixbuf = new Gdk.Pixbuf.from_file(file_path);
				// pad to requested size
				pixbuf = resize_icon(pixbuf, icon_size);
				// return
				if (pixbuf != null){ return pixbuf; }
			}
			catch (Error e){
				// ignore
			}
		}
		else {
			try{
				// load with scaling - scale down to requested box
				pixbuf = new Gdk.Pixbuf.from_file_at_scale(file_path, icon_size, icon_size, true);
				// pad to requested size
				pixbuf = resize_icon(pixbuf, icon_size);
				// return
				if (pixbuf != null){ return pixbuf; }
			}
			catch (Error e){
				// ignore
			}
		}
		
		return null;
	}
}
