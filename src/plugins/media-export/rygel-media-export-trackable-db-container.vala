/*
 * Copyright (C) 2012 Intel Corporation.
 *
 * Author: Jens Georg <jensg@openismus.com>
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
using Gee;

public class Rygel.MediaExport.TrackableDbContainer : TrackableContainer,
                                                      DBContainer {
    public TrackableDbContainer (MediaCache cache, string id, string title) {
        base (cache, id, title);
    }

    public async void add_child (MediaObject object) {
        try {
            if (object is MediaItem) {
                this.media_db.save_item (object as MediaItem);
            } else if (object is MediaContainer) {
                this.media_db.save_container (object as MediaContainer);
            } else {
                assert_not_reached ();
            }
        } catch (Error error) {
            warning ("Failed to add object: %s", error.message);
        }
    }

    public async void remove_child (MediaObject object) {
        try {
            this.media_db.remove_object (object);
        } catch (Error error) {
            warning ("Failed to remove object: %s", error.message);
        }
    }

    // TrackableContainer overrides
    public virtual string get_service_reset_token () {
        return this.media_db.get_reset_token ();
    }

    public virtual void set_service_reset_token (string token) {
        this.media_db.save_reset_token (token);
    }

    public virtual uint32 get_system_update_id () {
        var id = this.media_db.get_update_id ();
        return id;
    }
}