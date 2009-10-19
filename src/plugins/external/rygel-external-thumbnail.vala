/*
 * Copyright (C) 2009 Zeeshan Ali (Khattak) <zeeshanak@gnome.org>.
 * Copyright (C) 2009 Nokia Corporation.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
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

using DBus;
using FreeDesktop;

/**
 * Represents External thumbnail.
 */
public class Rygel.ExternalThumbnail : Rygel.Thumbnail {
    private static string OBJECT_IFACE = "org.gnome.UPnP.MediaObject1";
    private static string ITEM_IFACE = "org.gnome.UPnP.MediaItem1";

    public static async ExternalThumbnail create (string service_name,
                                                  string object_path,
                                                  string host_ip)
                                                  throws GLib.Error {
        DBus.Connection connection = DBus.Bus.get (DBus.BusType.SESSION);

        var props = connection.get_object (service_name,
                                           object_path)
                                           as Properties;

        var object_props = yield props.get_all (OBJECT_IFACE);
        var item_props = yield props.get_all (ITEM_IFACE);

        return new ExternalThumbnail (object_props, item_props, host_ip);
    }

    private ExternalThumbnail (HashTable<string,Value?> object_props,
                               HashTable<string,Value?> item_props,
                               string                   host_ip) {
        var value = item_props.lookup ("MIMEType");
        this.mime_type = value.get_string ();

        value = item_props.lookup ("URLs");
        weak string[] uris = (string[]) value.get_boxed ();
        if (uris != null && uris[0] != null) {
            this.uri = uris[0].replace ("@ADDRESS@", host_ip);
        }

        value = item_props.lookup ("DLNAProfile");
        if (value != null) {
            this.dlna_profile = value.get_string ();
        }

        value = item_props.lookup ("Size");
        if (value != null) {
            this.size = value.get_int ();
        }

        value = item_props.lookup ("Width");
        if (value != null) {
            this.width = value.get_int ();
        }

        value = item_props.lookup ("Height");
        if (value != null) {
            this.height = value.get_int ();
        }

        value = item_props.lookup ("ColorDepth");
        if (value != null) {
            this.depth = value.get_int ();
        }
    }
}

