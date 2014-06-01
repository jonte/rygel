using Gtk;

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

        if (device.size () == 0 || service.size () == 0) {
            message ("Nothing to decide on, passing true");

            return true;
        }

        var dialog = new MessageDialog (null, 0, MessageType.QUESTION,
                ButtonsType.YES_NO, "%s from %s is trying to access %s. Allow?",
                agent, address, device["FriendlyName"]);

        var area = dialog.get_message_area ();

        var remember = new CheckButton.with_label ("Remember decision");
        (area as Box).pack_end (remember);
        remember.show ();

        bool result = false;
        dialog.response.connect ((id) => {
            if (id == ResponseType.YES) {
                result = true;
            }

            dialog.destroy ();
        });

        dialog.run ();

        return result;
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
