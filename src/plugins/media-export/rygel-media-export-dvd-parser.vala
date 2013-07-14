/*
 * Copyright (C) 2013 Jens Georg <mail@jensge.org>.
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

internal class Rygel.MediaExport.DVDParser : GLib.Object {
    /// URI to the image / toplevel directory
    public File file { private get; construct; }

    private File cache_file;

    public DVDParser (File file) {
        Object (file : file);
    }

    public override void constructed () {
        unowned string user_cache = Environment.get_user_cache_dir ();
        var cache_folder = Path.build_filename (user_cache,
                                                "rygel",
                                                "dvd-content");
        DirUtils.create_with_parents (cache_folder, 0700);
        var cache_path = Path.build_filename (cache_folder,
                                              MediaCache.get_id (this.file));

        this.cache_file = File.new_for_path (cache_path);
    }

    public async void run () {
        var doc = yield this.get_information ();
        if (doc != null) {
            doc->children;
        }
    }

    public async Xml.Doc* get_information () {
        if (this.cache_file.query_exists ()) {
            return Xml.Parser.read_file (this.cache_file.get_path (),
                                         null,
                                         Xml.ParserOption.NOERROR |
                                         Xml.ParserOption.NOWARNING);
        }

        Pid pid;
        int stdout_fd;

        try {
            Process.spawn_async_with_pipes (null,
                                            { "/usr/bin/lsdvd",
                                              "-Ox",
                                              "-x",
                                              "-q",
                                              this.file.get_path (),
                                              null },
                                            null,
                                            SpawnFlags.DO_NOT_REAP_CHILD |
                                            SpawnFlags.STDERR_TO_DEV_NULL,
                                            null,
                                            out pid,
                                            null,
                                            out stdout_fd);
            var data = new StringBuilder ();
            var io_channel = new IOChannel.unix_new (stdout_fd);
            var io_watch = io_channel.add_watch (IOCondition.IN |
                                                 IOCondition.PRI,
                                                 () => {
                string line;

                try {
                    io_channel.read_to_end (out line, null);
                    data.append (line);
                } catch (Error error) { }

                return true;
            });

            uint child_watch = 0;
            child_watch = ChildWatch.add (pid, () => {
                Source.remove (child_watch);
                Source.remove (io_watch);
                Process.close_pid (pid);

                get_information.callback ();
            });

            yield;

            try {
                this.cache_file.replace_contents (data.str.data,
                                                  null,
                                                  false,
                                                  FileCreateFlags.NONE,
                                                  null);
            } catch (Error rc_error) {
                debug ("Failed to cache lsdvd output: %s", rc_error.message);
            }

            return Xml.Parser.read_memory (data.str,
                                           (int) data.len,
                                           null,
                                           null,
                                           Xml.ParserOption.NOERROR |
                                           Xml.ParserOption.NOWARNING);
        } catch (SpawnError error) {
            debug ("Failed to run lsdvd: %s", error.message);
        }

        return null;
    }
}
