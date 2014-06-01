/*
 *
 * Copyright (C) 2014 Jens Georg <mail@jensge.org>
 *
 * Author: Jens Georg <mail@jensge.org>
 *
 * This file is part of Rygel.
 *
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Rygel is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

[DBus (name = "org.gnome.Rygel1.AclProvider1")]
public interface Rygel.IAclProvider : Object {
    public abstract async bool is_allowed (GLib.HashTable<string, string> device,
                                           GLib.HashTable<string, string> service,
                                           string path,
                                           string address,
                                           string? agent)
                                           throws DBusError, IOError;
}

internal class Rygel.Acl : GLib.Object, GUPnP.Acl
{
    private Rygel.IAclProvider provider;

    public Acl () {
        Bus.watch_name (BusType.SESSION,
                        "org.gnome.Rygel1.AclProvider1",
                        BusNameWatcherFlags.AUTO_START,
                        this.on_name_appeared,
                        this.on_name_vanished);
    }

    public bool can_sync () { return false; }

    public bool is_allowed (GUPnP.Device? device,
                            GUPnP.Service? service,
                            string         path,
                            string         address,
                            string?        agent) {
        assert_not_reached ();
    }

    public async bool is_allowed_async (GUPnP.Device? device,
                                        GUPnP.Service? service,
                                        string path,
                                        string address,
                                        string? agent,
                                        GLib.Cancellable? cancellable)
                                        throws GLib.Error {
        if (provider == null) {
            message ("No external provider found, denying access…");

            return false;
        }

        try {
            var allowed = yield provider.is_allowed (new HashTable<string,
                    string> (null, null),
                                                     new HashTable<string,
                                                     string> (null, null),
                                                     path,
                                                     address,
                                                     agent);
            return allowed;
        } catch (Error error) {
            message ("=> Error: %s", error.message);
        }

        return false;
    }

    private void on_name_appeared (DBusConnection connection,
                                   string         name,
                                   string         name_owner) {
        message ("Found ACL provider %s (%s), creating object",
                 name, name_owner);
        try {
            this.provider = Bus.get_proxy_sync (BusType.SESSION,
                                                name,
                                                "/org/gnome/Rygel1/AclProvider1");
        } catch (Error error) {
            message ("Error creating proxy: %s", error.message);
        }
    }

    private void on_name_vanished (DBusConnection connection, string name) {
        this.provider = null;
    }
}
