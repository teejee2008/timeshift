namespace TeeJee.Battery{
	using GLib;
	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.Misc;

    [DBus (name = "org.freedesktop.UPower")]
    interface UPowerManager : GLib.Object {
        public abstract GLib.ObjectPath[] enumerate_devices () 
			throws GLib.DBusError,GLib.IOError;
        public abstract GLib.ObjectPath get_display_device () 
			throws GLib.DBusError,GLib.IOError;
        public abstract string get_critical_action () 
			throws GLib.DBusError,GLib.IOError;
        public abstract bool on_battery {owned get;}

    }

    bool running_on_battery()
    {
        UPowerManager upower_manager;
	    bool on_battery=false;
	    try {
	        upower_manager = Bus.get_proxy_sync(BusType.SYSTEM,
	              "org.freedesktop.UPower","/org/freedesktop/UPower");
	        on_battery = upower_manager.on_battery;
	        } catch (GLib.DBusError e) {
	            on_battery = false;
	            log_error (e.message);
	        } catch (GLib.IOError e){
	            on_battery = false;
	            log_error (e.message);
	        }

        return on_battery;
    }

}
