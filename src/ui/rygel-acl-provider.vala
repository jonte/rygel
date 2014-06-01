[DBus (name = "org.gnome.Rygel1.AclProvider1")]
public interface Rygel.IAclProvider : Object {
    public abstract async bool is_allowed (GLib.HashTable<string, string> device,
                                           GLib.HashTable<string, string> service,
                                           string path,
                                           string address,
                                           string? agent)
                                           throws DBusError, IOError;
}

public class Rygel.AclProvider : IAclProvider, Object {
    public async bool is_allowed (GLib.HashTable<string, string> device,
                                  GLib.HashTable<string, string> service,
                                  string path,
                                  string address,
                                  string? agent)
                                  throws DBusError, IOError {
        Idle.add (() => { is_allowed.callback (); return false; });
        yield;

        message ("=======> Request");

        if (device.size () == 0 || service.size () == 0) {

            return true;
        }

        return true;
    }

    private void on_bus_aquired (DBusConnection connection) {
        try {
            connection.register_object ("/org/gnome/Rygel1/AclProvider1",
                                        this as IAclProvider);
        } catch (IOError error) {
            warning ("Failed to register service");
        }
    }

    public void register () {
        Bus.own_name (BusType.SESSION, "org.gnome.Rygel1.AclProvider1",
                      BusNameOwnerFlags.NONE,
                      on_bus_aquired,
                      () => {},
                      () => { warning ("Could not aquire bus name"); });
    }
}
