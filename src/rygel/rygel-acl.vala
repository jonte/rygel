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

        message ("Querying ACL for %s on %s by %s@%s",
                 path,
                 device != null ? device.udn : "none",
                 agent ?? "Unknown",
                 address);

        try {
            var device_hash = new HashTable<string, string> (str_hash, str_equal);
            if (device != null) {
                device_hash["FriendlyName"] = device.get_friendly_name ();
                device_hash["UDN"] = device.udn;
                device_hash["Type"] = device.device_type;
            }

            var service_hash = new HashTable<string, string> (str_hash, str_equal);
            if (service != null) {
                service_hash["Type"] = service.service_type;
            }

            var allowed = yield provider.is_allowed (device_hash,
                                                     service_hash,
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
