/*
 * Copyright (C) 2008, 2009 Nokia Corporation.
 * Copyright (C) 2006, 2007, 2008 OpenedHand Ltd.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
 *         Jorn Baayen <jorn.baayen@gmail.com>
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

using Rygel;
using Gst;

internal errordomain Rygel.HTTPRequestError {
    UNACCEPTABLE = Soup.KnownStatusCode.NOT_ACCEPTABLE,
    INVALID_RANGE = Soup.KnownStatusCode.BAD_REQUEST,
    OUT_OF_RANGE = Soup.KnownStatusCode.REQUESTED_RANGE_NOT_SATISFIABLE,
    BAD_REQUEST = Soup.KnownStatusCode.BAD_REQUEST,
    NOT_FOUND = Soup.KnownStatusCode.NOT_FOUND
}

/**
 * Responsible for handling HTTP client requests.
 */
internal class Rygel.HTTPRequest : GLib.Object, Rygel.StateMachine {
    private unowned HTTPServer http_server;
    private MediaContainer root_container;
    private Soup.Server server;
    private Soup.Message msg;
    private HashTable<string,string>? query;

    private HTTPResponse response;

    private string item_id;
    private Transcoder transcoder;
    private MediaItem item;
    private Seek byte_range;
    private Seek time_range;

    private Cancellable cancellable;

    public HTTPRequest (HTTPServer                http_server,
                        Soup.Server               server,
                        Soup.Message              msg,
                        HashTable<string,string>? query) {
        this.http_server = http_server;
        this.root_container = http_server.root_container;
        this.server = server;
        this.msg = msg;
        this.query = query;
    }

    public void run (Cancellable? cancellable) {
        this.cancellable = cancellable;

        this.server.pause_message (this.msg);

        if (this.msg.method != "HEAD" && this.msg.method != "GET") {
            /* We only entertain 'HEAD' and 'GET' requests */
            this.handle_error (
                        new HTTPRequestError.BAD_REQUEST ("Invalid Request"));
            return;
        }

        if (this.query != null) {
            this.item_id = this.query.lookup ("itemid");
            var transcode_target = this.query.lookup ("transcode");
            if (transcode_target != null) {
                this.transcoder = this.http_server.get_transcoder (
                                                    transcode_target);
            }
        }

        if (this.item_id == null) {
            this.handle_error (new HTTPRequestError.NOT_FOUND ("Not Found"));
            return;
        }

        // Fetch the requested item
        this.root_container.find_object (this.item_id,
                                         null,
                                         this.on_item_found);
    }

    private void stream_from_gst_source (owned Element src) throws Error {
        var response = new LiveResponse (this.server,
                                         this.msg,
                                         "RygelLiveResponse",
                                         src,
                                         this.time_range);
        this.response = response;
        response.completed += on_response_completed;

        response.run (this.cancellable);
    }

    private void serve_uri (string uri, size_t size) {
        var response = new SeekableResponse (this.server,
                                             this.msg,
                                             uri,
                                             this.byte_range,
                                             size);
        this.response = response;
        response.completed += on_response_completed;

        response.run (this.cancellable);
    }

    private void on_response_completed (HTTPResponse response) {
        this.end (Soup.KnownStatusCode.NONE);
    }

    private void handle_item_request () {
        try {
            this.byte_range = Seek.from_byte_range(this.msg);
            this.time_range = Seek.from_time_range(this.msg);
        } catch (Error error) {
            this.handle_error (error);
            return;
        }

        // Add headers
        this.add_item_headers ();

        if (this.msg.method == "HEAD") {
            // Only headers requested, no need to send contents
            this.server.unpause_message (this.msg);
            this.end (Soup.KnownStatusCode.OK);
            return;
        }

        if (this.item.size > 0 && this.transcoder == null) {
            this.handle_interactive_item ();
        } else {
            this.handle_streaming_item ();
        }
    }

    private void add_item_headers () {
        if (this.transcoder != null) {
            this.msg.response_headers.append ("Content-Type",
                                              this.transcoder.mime_type);
            this.time_range.add_response_header(this.msg);
            return;
        }

        if (this.item.mime_type != null) {
            this.msg.response_headers.append ("Content-Type",
                                              this.item.mime_type);
        }

        if (this.item.size >= 0) {
            this.msg.response_headers.set_content_length (this.item.size);
        }

        if (this.item.size > 0) {
            Seek seek;

            if (this.byte_range != null) {
                seek = this.byte_range;
            } else {
                seek = new Seek (Format.BYTES, 0, this.item.size - 1);
            }

            seek.add_response_header (this.msg, this.item.size);
        }
    }

    private void handle_streaming_item () {
        Element src = null;

        src = this.item.create_stream_source ();

        if (src == null) {
            this.handle_error (new HTTPRequestError.NOT_FOUND ("Not Found"));
            return;
        }

        try {
            if (this.transcoder != null) {
                src = this.transcoder.create_source (this.item, src);
            }

            // Then start the gst stream
            this.stream_from_gst_source (src);
        } catch (Error error) {
            this.handle_error (error);
            return;
        }
    }

    private void handle_interactive_item () {
        if (this.item.uris.size == 0) {
            var error = new HTTPRequestError.NOT_FOUND (
                                "Requested item '%s' didn't provide a URI\n",
                                this.item.id);
            this.handle_error (error);
            return;
        }

        this.serve_uri (this.item.uris.get (0), this.item.size);
    }

    private void on_item_found (GLib.Object source_object,
                                AsyncResult res) {
        var container = (MediaContainer) source_object;

        MediaObject media_object;
        try {
            media_object = container.find_object_finish (res);
        } catch (Error err) {
            this.handle_error (err);
            return;
        }

        if (media_object == null || !(media_object is MediaItem)) {
            this.handle_error (new HTTPRequestError.NOT_FOUND (
                                        "requested item '%s' not found",
                                        this.item_id));
            return;
        }

        this.item = (MediaItem) media_object;

        this.handle_item_request ();
    }

    private void handle_error (Error error) {
        warning ("%s", error.message);

        uint status;
        if (error is HTTPRequestError) {
            status = error.code;
        } else {
            status = Soup.KnownStatusCode.NOT_FOUND;
        }

        this.server.unpause_message (this.msg);
        this.end (status);
    }

    public void end (uint status) {
        if (status != Soup.KnownStatusCode.NONE) {
            this.msg.set_status (status);
        }

        this.completed ();
    }
}

