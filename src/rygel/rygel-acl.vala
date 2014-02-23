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

internal class Rygel.Acl : GLib.Object, GUPnP.Acl
{
    public bool can_sync () { return true; }

    public bool is_allowed (GUPnP.Device? device,
                            GUPnP.Service? service,
                            string         path,
                            string         address,
                            string         agent) {
        message ("%s at %s is trying to access %s/%s (%s)",
                 agent,
                 address,
                 device == null ? "(unknown)" : device.get_friendly_name (),
                 service == null ? "(unknown)" : service.get_id (),
                 path);

        return true;
    }

    public async bool is_allowed_async (GUPnP.Device? device,
                                        GUPnP.Service? service,
                                        string path,
                                        string address,
                                        string agent,
                                        GLib.Cancellable? cancellable)
                                        throws GLib.Error {
        assert_not_reached ();
    }
}
