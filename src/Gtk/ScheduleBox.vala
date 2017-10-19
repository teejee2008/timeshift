/*
 * ScheduleBox.vala
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

class ScheduleBox : Gtk.Box{
	private Gtk.Image img_shield;
	private Gtk.Label lbl_shield;
	private Gtk.Label lbl_shield_subnote;
	private Gtk.SizeGroup sg_title;
	private Gtk.SizeGroup sg_subtitle;
	private Gtk.SizeGroup sg_count;
	
	private Gtk.Window parent_window;
	
	public ScheduleBox (Gtk.Window _parent_window) {

		log_debug("ScheduleBox: ScheduleBox()");
		
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.VERTICAL, spacing: 6); // work-around
		parent_window = _parent_window;
		margin = 12;
		
		add_label_header(this, _("Select Snapshot Levels"), true);

		Gtk.CheckButton chk_m, chk_w, chk_d, chk_h, chk_b, chk_cron = null;
		Gtk.SpinButton spin_m, spin_w, spin_d, spin_h, spin_b;

		// monthly
		
		add_schedule_option(this, _("Monthly") + " *", _("Create one per month"), out chk_m, out spin_m);

		chk_m.active = App.schedule_monthly;
		chk_m.toggled.connect(()=>{
			App.schedule_monthly = chk_m.active;
			spin_m.sensitive = chk_m.active;
			chk_cron.sensitive = App.scheduled;
			update_statusbar();
		});

		spin_m.set_value(App.count_monthly);
		spin_m.sensitive = chk_m.active;
		spin_m.value_changed.connect(()=>{
			App.count_monthly = (int) spin_m.get_value();
		});
		
		// weekly
		
		add_schedule_option(this, _("Weekly") + " *", _("Create one per week"), out chk_w, out spin_w);

		chk_w.active = App.schedule_weekly;
		chk_w.toggled.connect(()=>{
			App.schedule_weekly = chk_w.active;
			spin_w.sensitive = chk_w.active;
			chk_cron.sensitive = App.scheduled;
			update_statusbar();
		});

		spin_w.set_value(App.count_weekly);
		spin_w.sensitive = chk_w.active;
		spin_w.value_changed.connect(()=>{
			App.count_weekly = (int) spin_w.get_value();
		});

		// daily
		
		add_schedule_option(this, _("Daily") + " *", _("Create one per day"), out chk_d, out spin_d);

		chk_d.active = App.schedule_daily;
		chk_d.toggled.connect(()=>{
			App.schedule_daily = chk_d.active;
			spin_d.sensitive = chk_d.active;
			chk_cron.sensitive = App.scheduled;
			update_statusbar();
		});

		spin_d.set_value(App.count_daily);
		spin_d.sensitive = chk_d.active;
		spin_d.value_changed.connect(()=>{
			App.count_daily = (int) spin_d.get_value();
		});

		// hourly
		
		add_schedule_option(this, _("Hourly") + " *", _("Create one per hour"), out chk_h, out spin_h);

		chk_h.active = App.schedule_hourly;
		chk_h.toggled.connect(()=>{
			App.schedule_hourly = chk_h.active;
			spin_h.sensitive = chk_h.active;
			chk_cron.sensitive = App.scheduled;
			update_statusbar();
		});

		spin_h.set_value(App.count_hourly);
		spin_h.sensitive = chk_h.active;
		spin_h.value_changed.connect(()=>{
			App.count_hourly = (int) spin_h.get_value();
		});

		// boot
		
		add_schedule_option(this, _("Boot"), _("Create one per boot"), out chk_b, out spin_b);

		chk_b.active = App.schedule_boot;
		chk_b.toggled.connect(()=>{
			App.schedule_boot = chk_b.active;
			spin_b.sensitive = chk_b.active;
			chk_cron.sensitive = App.scheduled;
			update_statusbar();
		});

		spin_b.set_value(App.count_boot);
		spin_b.sensitive = chk_b.active;
		spin_b.value_changed.connect(()=>{
			App.count_boot = (int) spin_b.get_value();
		});

		var label = new Gtk.Label("<i>* " + _("Scheduled task runs once every hour") + "</i>");
		label.xalign = (float) 0.0;
		label.margin_top = 6;
		label.margin_left = 12;
		label.set_use_markup(true);
		add(label);
		
		// buffer
		label = new Gtk.Label("");
		label.vexpand = true;
		add(label);
		
		// cron emails
		chk_cron = add_checkbox(this, _("Stop cron emails for scheduled tasks"));
		//chk_cron.hexpand = true;
		chk_cron.set_tooltip_text(_("The cron service sends the output of scheduled tasks as an email to the current user. Select this option to suppress the emails for cron tasks created by Timeshift."));
		//chk_cron.margin_bottom = 12;	
		
		chk_cron.active = App.stop_cron_emails;
		chk_cron.toggled.connect(()=>{
			App.stop_cron_emails = chk_cron.active;
		});

		// scrolled
		var scrolled = new ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		//scrolled.margin = 6;
		//scrolled.margin_top = 0;
		scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
		scrolled.vscrollbar_policy = Gtk.PolicyType.NEVER;
		add(scrolled);
		
		// hbox
		var hbox = new Gtk.Box (Orientation.HORIZONTAL, 6);
		hbox.margin = 6;
		hbox.margin_bottom = 12;
		scrolled.add (hbox);

        // img_shield
		img_shield = new Gtk.Image();
		img_shield.surface = IconManager.lookup_surface(IconManager.SHIELD_HIGH, IconManager.SHIELD_ICON_SIZE, img_shield.scale_factor);
		img_shield.margin_bottom = 6;
        hbox.add(img_shield);

		var vbox = new Box (Orientation.VERTICAL, 6);
        hbox.add (vbox);
        
		// lbl_shield
		lbl_shield = add_label(vbox, "");
        //lbl_shield.margin_bottom = 0;
        lbl_shield.yalign = (float) 0.5;
        lbl_shield.hexpand = true;

        // lbl_shield_subnote
		lbl_shield_subnote = add_label(vbox, "");
		lbl_shield_subnote.yalign = (float) 0.5;
		lbl_shield_subnote.hexpand = true;
		//lbl_shield_subnote.margin_bottom = 6;
		
		lbl_shield_subnote.wrap = true;
		lbl_shield_subnote.wrap_mode = Pango.WrapMode.WORD;

		update_statusbar();

		log_debug("ScheduleBox: ScheduleBox(): exit");
    }

    private void set_shield_label(
		string text, bool is_bold = true, bool is_italic = false, bool is_large = true){
			
		string msg = "<span%s%s%s>%s</span>".printf(
			(is_bold ? " weight=\"bold\"" : ""),
			(is_italic ? " style=\"italic\"" : ""),
			(is_large ? " size=\"x-large\"" : ""),
			escape_html(text));
			
		lbl_shield.label = msg;
	}

	private void set_shield_subnote(
		string text, bool is_bold = false, bool is_italic = true, bool is_large = false){
			
		string msg = "<span%s%s%s>%s</span>".printf(
			(is_bold ? " weight=\"bold\"" : ""),
			(is_italic ? " style=\"italic\"" : ""),
			(is_large ? " size=\"x-large\"" : ""),
			escape_html(text));
			
		lbl_shield_subnote.label = msg;
	}

	private void add_schedule_option(
		Gtk.Box box, string period, string period_desc,
		out Gtk.CheckButton chk, out Gtk.SpinButton spin){

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		hbox.margin_left = 6;
		box.add(hbox);

		if (sg_title == null){
			sg_title = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
			sg_subtitle = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
			sg_count = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		}
		
        var txt = "<b>%s</b>".printf(period);
		chk = add_checkbox(hbox, txt);
		sg_title.add_widget(chk);
		
		//var label = add_label(hbox, " - %s".printf(period_desc));
		//label.hexpand = true;
		//sg_subtitle.add_widget(label);

		var tt = _("Number of snapshots to keep.\nOlder snapshots will be removed once this limit is exceeded.");
		var label = add_label(hbox, _("Keep"));
		label.margin_left = 24;
		label.set_tooltip_text(tt);

		var spin2 = add_spin(hbox, 1, 999, 10);
		spin2.set_tooltip_text(tt);
		sg_count.add_widget(spin2);
		
		spin2.notify["sensitive"].connect(()=>{
			label.sensitive = spin2.sensitive;
		});

		spin = spin2;
	}

	public void update_statusbar(){
		if (App.schedule_monthly || App.schedule_weekly || App.schedule_daily
			|| App.schedule_hourly || App.schedule_boot){

			img_shield.surface = IconManager.lookup_surface(IconManager.SHIELD_HIGH, IconManager.SHIELD_ICON_SIZE, img_shield.scale_factor);
			set_shield_label(_("Scheduled snapshots are enabled"));
			set_shield_subnote(_("Snapshots will be created at selected intervals if snapshot disk has enough space (> 1 GB)"));
		}
		else{
			img_shield.surface = IconManager.lookup_surface(IconManager.SHIELD_LOW, IconManager.SHIELD_ICON_SIZE, img_shield.scale_factor);
			set_shield_label(_("Scheduled snapshots are disabled"));
			set_shield_subnote(_("Select the intervals for creating snapshots"));
		}
	}
}
