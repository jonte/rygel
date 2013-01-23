/*
 * Copyright (C) 2011 Nokia Corporation.
 * Copyright (C) 2012 Jens Georg.
 *
 * Author: Jens Georg <jensg@openismus.com>
 *         Jens Georg <mail@jensge.org>
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

using Soup;
using GUPnP;

/**
 * Various devices that need a downgrade to MediaServer:1 and
 * ContentDirectory:1 because they ignore that higher versions are
 * required to be backwards-compatible.
 */
internal class Rygel.RendererV1Hacks : Rygel.V1Hacks {
    private const string DMR = "urn:schemas-upnp-org:device:MediaRenderer";

    public RendererV1Hacks () {
        Object (device_type : DMR,
                service_type : AVTransport.UPNP_TYPE,
                service_type_v1 : AVTransport.UPNP_TYPE_V1);
    }
}
