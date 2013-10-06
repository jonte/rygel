include $(top_srcdir)/common.am
include $(srcdir)/filelist.am

librygel_renderer_includedir=$(includedir)/rygel-@RYGEL_API_VERSION@
librygel_renderer_include_HEADERS = rygel-renderer.h

lib_LTLIBRARIES = librygel-renderer-@RYGEL_API_VERSION@.la

LIBRYGEL_RENDERER_VERSION=2:2:0

librygel_renderer_@RYGEL_API_VERSION_UNDERSCORE@_la_SOURCES = \
	$(LIBRYGEL_RENDERER_VAPI_SOURCE_FILES) \
	$(LIBRYGEL_RENDERER_NONVAPI_SOURCE_FILES)

librygel_renderer_@RYGEL_API_VERSION_UNDERSCORE@_la_VALAFLAGS = \
	-H rygel-renderer.h --library=rygel-renderer-@RYGEL_API_VERSION@ \
	$(LIBRYGEL_RENDERER_DEPS_VALAFLAGS) \
	$(RYGEL_COMMON_LIBRYGEL_CORE_VALAFLAGS) \
	$(RYGEL_COMMON_VALAFLAGS)
librygel_renderer_@RYGEL_API_VERSION_UNDERSCORE@_la_CFLAGS = \
	$(LIBRYGEL_RENDERER_DEPS_CFLAGS) \
	$(RYGEL_COMMON_LIBRYGEL_CORE_CFLAGS) \
	-DG_LOG_DOMAIN=\"Rygel\"
librygel_renderer_@RYGEL_API_VERSION_UNDERSCORE@_la_LIBADD = \
	$(LIBRYGEL_RENDERER_DEPS_LIBS) \
	$(RYGEL_COMMON_LIBRYGEL_CORE_LIBS)
librygel_renderer_@RYGEL_API_VERSION_UNDERSCORE@_la_LDFLAGS = \
	-version-info $(LIBRYGEL_RENDERER_VERSION)

vapidir = $(VAPIDIR)
vapi_DATA = rygel-renderer-@RYGEL_API_VERSION@.vapi rygel-renderer-@RYGEL_API_VERSION@.deps

rygel-renderer.h rygel-renderer-@RYGEL_API_VERSION@.vapi: librygel_renderer_@RYGEL_API_VERSION_UNDERSCORE@_la_vala.stamp

EXTRA_DIST = rygel-renderer.h rygel-renderer-@RYGEL_API_VERSION@.vapi rygel-renderer-@RYGEL_API_VERSION@.deps
