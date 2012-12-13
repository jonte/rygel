/*
 * Copyright (C) 2009 Jens Georg <mail@jensge.org>.
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

using GLib;
using Gee;

internal class FileQueueEntry {
    public File file;
    public bool known;

    public FileQueueEntry (File file, bool known) {
        this.file = file;
        this.known = known;
    }
}

public class Rygel.MediaExport.HarvestingTask : Rygel.StateMachine,
                                                GLib.Object {
    public File origin;
    private MetadataExtractor extractor;
    private MediaCache cache;
    private GLib.Queue<MediaContainer> containers;
    private Gee.Queue<FileQueueEntry> files;
    private RecursiveFileMonitor monitor;
    private string flag;
    private MediaContainer parent;
    private const int BATCH_SIZE = 256;

    public Cancellable cancellable { get; set; }

    private const string HARVESTER_ATTRIBUTES =
                                        FileAttribute.STANDARD_NAME + "," +
                                        FileAttribute.STANDARD_TYPE + "," +
                                        FileAttribute.TIME_MODIFIED + "," +
                                        FileAttribute.STANDARD_CONTENT_TYPE + "," +
                                        FileAttribute.STANDARD_SIZE;

    public HarvestingTask (MetadataExtractor    extractor,
                           RecursiveFileMonitor monitor,
                           File                 file,
                           MediaContainer       parent,
                           string?              flag = null) {
        this.extractor = extractor;
        this.origin = file;
        this.parent = parent;

        try {
            this.cache = MediaCache.get_default ();
        } catch (Error error) {
            // This should not happen. As the harvesting tasks are created
            // long after the first call to get_default which - if fails -
            // will make the whole root-container creation fail
            assert_not_reached ();
        }

        this.extractor.extraction_done.connect (on_extracted_cb);
        this.extractor.error.connect (on_extractor_error_cb);

        this.files = new LinkedList<FileQueueEntry> ();
        this.containers = new GLib.Queue<MediaContainer> ();
        this.monitor = monitor;
        this.flag = flag;
    }

    public void cancel () {
        // detach from common cancellable; otherwise everything would be
        // cancelled like file monitoring, other harvesters etc.
        this.cancellable = new Cancellable ();
        this.cancellable.cancel ();
    }

    /**
     * Extract all metainformation from a given file.
     *
     * What action will be taken depends on the arguments
     * * file is a simple file. Then only information of this
     *   file will be extracted
     * * file is a directory and recursive is false. The children
     *   of the directory (if not directories themselves) will be
     *   enqueued for extraction
     * * file is a directory and recursive is true. ++ All ++ children
     *   of the directory will be enqueued for extraction, even directories
     *
     * No matter how many children are contained within file's hierarchy,
     * only one event is sent when all the children are done.
     */
    public async void run () {
        try {
            var info = yield this.origin.query_info_async
                                        (HARVESTER_ATTRIBUTES,
                                         FileQueryInfoFlags.NONE,
                                         Priority.DEFAULT,
                                         this.cancellable);

            if (this.process_file (this.origin, info, this.parent)) {
                if (info.get_file_type () != FileType.DIRECTORY) {
                    this.containers.push_tail (this.parent);
                }
                this.on_idle ();
            } else {
                this.completed ();
            }
        } catch (Error error) {
            if (!(error is IOError.CANCELLED)) {
                warning (_("Failed to harvest file %s: %s"),
                         this.origin.get_uri (),
                         error.message);
            } else {
                debug ("Harvesting of uri %s was cancelled",
                       this.origin.get_uri ());
            }
            this.completed ();
        }
    }

    /**
     * Add a file to the meta-data extraction queue.
     *
     * The file will only be added to the queue if one of the following
     * conditions is met:
     *   - The file is not in the cache
     *   - The current mtime of the file is larger than the cached
     *   - The size has changed
     * @param file to check
     * @param info FileInfo of the file to check
     * @return true, if the file has been queued, false otherwise.
     */
    private bool push_if_changed_or_unknown (File       file,
                                             FileInfo   info) {
        int64 timestamp;
        int64 size;
        try {
            if (this.cache.exists (file, out timestamp, out size)) {
                int64 mtime = (int64) info.get_attribute_uint64
                                        (FileAttribute.TIME_MODIFIED);

                if (mtime > timestamp ||
                    info.get_size () != size) {
                    this.files.offer (new FileQueueEntry (file, true));

                    return true;
                }
            } else {
                this.files.offer (new FileQueueEntry (file, false));

                return true;
            }
        } catch (Error error) {
            warning (_("Failed to query database: %s"), error.message);
        }

        return false;
    }

    private bool process_file (File           file,
                               FileInfo       info,
                               MediaContainer parent) {
        if (info.get_name ()[0] == '.') {
            return false;
        }

        if (info.get_file_type () == FileType.DIRECTORY) {
            // queue directory for processing later
            this.monitor.add.begin (file);

            var container = new DummyContainer (file, parent);
            this.containers.push_tail (container);
            try {
                this.cache.save_container (container);
            } catch (Error err) {
                warning (_("Failed to update database: %s"), err.message);

                return false;
            }

            return true;
        } else {
            // Check if the file needs to be harvested at all either because
            // it is denied by filter or it hasn't updated
            if (Harvester.is_eligible (info)) {
                return this.push_if_changed_or_unknown (file, info);
            }

            return false;
        }
    }

    private bool process_children (GLib.List<FileInfo>? list) {
        if (list == null || this.cancellable.is_cancelled ()) {
            return false;
        }

        var container = this.containers.peek_head () as DummyContainer;

        foreach (var info in list) {
            var file = container.file.get_child (info.get_name ());

            container.seen (file);
            this.process_file (file, info, container);
        }

        return true;
    }

    private async void enumerate_directory () {
        var directory = (this.containers.peek_head () as DummyContainer).file;
        try {
            var enumerator = yield directory.enumerate_children_async
                                        (HARVESTER_ATTRIBUTES,
                                         FileQueryInfoFlags.NONE,
                                         Priority.DEFAULT,
                                         this.cancellable);

            GLib.List<FileInfo> list = null;
            do {
                list = yield enumerator.next_files_async (BATCH_SIZE,
                                                          Priority.DEFAULT,
                                                          this.cancellable);
            } while (this.process_children (list));

            yield enumerator.close_async (Priority.DEFAULT, this.cancellable);
        } catch (Error err) {
            warning (_("failed to enumerate folder: %s"), err.message);
        }

        this.cleanup_database ();
        this.do_update ();
    }

    private void cleanup_database () {
        var container = this.containers.peek_head () as DummyContainer;

        // delete all children which are not in filesystem anymore
        try {
            foreach (var child in container.children) {
                this.cache.remove_by_id (child);
            }
        } catch (DatabaseError error) {
            warning (_("Failed to get children of container %s: %s"),
                     container.id,
                     error.message);
        }
    }

    private bool on_idle () {
        if (this.cancellable.is_cancelled ()) {
            this.completed ();

            return false;
        }

        if (this.files.size > 0) {
            debug ("Scheduling file %s for meta-data extraction…",
                   this.files.peek ().file.get_uri ());
            this.extractor.extract (this.files.peek ().file);
        } else if (this.containers.get_length () > 0) {
            this.enumerate_directory.begin ();
        } else {
            // nothing to do
            if (this.flag != null) {
                try {
                    this.cache.flag_object (this.origin,
                                            this.flag);
                } catch (Error error) {};
            }
            parent.updated (parent);
            try {
                this.cache.save_container (parent);
            } catch (Error error) { }

            this.completed ();
        }

        return false;
    }

    private void on_extracted_cb (File                   file,
                                  GUPnPDLNA.Information? dlna,
                                  FileInfo               file_info) {
        if (this.cancellable.is_cancelled ()) {
            this.completed ();
        }

        var entry = this.files.peek ();
        if (entry == null || file != entry.file) {
            // this event may be triggered by another instance
            // just ignore it
           return;
        }

        MediaItem item;
        if (dlna == null) {
            item = ItemFactory.create_simple (this.containers.peek_head (),
                                              file,
                                              file_info);
        } else {
            item = ItemFactory.create_from_info (this.containers.peek_head (),
                                                 file,
                                                 dlna,
                                                 file_info);
        }

        if (item != null) {
            item.parent_ref = this.containers.peek_head ();
            // This is only necessary to generate the poper <objAdd LastChange
            // entry
            if (entry.known) {
                (item as UpdatableObject).commit.begin ();
            } else {
                var container = item.parent as TrackableContainer;
                container.add_child_tracked.begin (item, () => {
                    // save again to make sure we persist the update count
                    try {
                        cache.save_item (item);
                    } catch (Error error) { }
                }) ;
            }
        }

        this.files.poll ();
        this.do_update ();
    }

    private void on_extractor_error_cb (File file, Error error) {
        var entry = this.files.peek ();
        if (entry == null || file != entry.file) {
            // this event may be triggered by another instance
            // just ignore it
            return;
        }

        // error is only emitted if even the basic information extraction
        // failed; there's not much to do here, just print the information and
        // go to the next file

        debug ("Skipping %s; extraction completely failed: %s",
               file.get_uri (),
               error.message);

        this.files.poll ();
        this.do_update ();
    }

    /**
     * If all files of a container were processed, notify the container
     * about this and set the updating signal.
     * Reschedule the iteration and extraction
     */
    private void do_update () {
        if (this.files.size == 0 &&
            this.containers.get_length () != 0) {
            var container = this.containers.peek_head ();
            try {
                var cache = MediaCache.get_default ();
                if (cache.get_child_count (container.id) > 0) {
                    var head = this.containers.peek_head ();
                    head.updated (head);
                    cache.save_container (head);
                } else {
                    var parent = container.parent as TrackableContainer;
                    parent.remove_child_tracked.begin (container, () => {
                        try {
                            MediaCache.get_default ().save_container (parent);
                        } catch (Error error) { }
                    });
                }
            } catch (Error error) { }
            this.containers.pop_head ();
        }

        this.on_idle ();
    }
}
