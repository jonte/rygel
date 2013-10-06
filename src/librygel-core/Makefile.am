include $(top_srcdir)/common.am
include $(srcdir)/filelist.am

librygelincdir = $(includedir)/rygel-@RYGEL_API_VERSION@

librygelinc_HEADERS = rygel-core.h

lib_LTLIBRARIES = librygel-core-@RYGEL_API_VERSION@.la

librygel_core_@RYGEL_API_VERSION_UNDERSCORE@_la_SOURCES = \
	$(LIBRYGEL_CORE_VAPI_SOURCE_FILES) \
	$(LIBRYGEL_CORE_NONVAPI_SOURCE_FILES)

librygel_core_@RYGEL_API_VERSION_UNDERSCORE@_la_VALAFLAGS = \
	-H rygel-core.h -C --library=rygel-core-@RYGEL_API_VERSION@ \
	--vapidir=$(srcdir) \
	--pkg uuid \
	--pkg posix \
	$(LIBRYGEL_CORE_DEPS_VALAFLAGS) \
	$(RYGEL_COMMON_VALAFLAGS)

librygel_core_@RYGEL_API_VERSION_UNDERSCORE@_la_CFLAGS = \
	$(RYGEL_COMMON_DEFINES_CFLAGS) \
	$(LIBRYGEL_CORE_DEPS_CFLAGS) \
	-DPLUGIN_DIR='"$(plugindir)"' \
	-DSMALL_ICON_DIR='"$(smallicondir)"' \
	-DBIG_ICON_DIR='"$(bigicondir)"' \
	-include config.h \
	-DG_LOG_DOMAIN='"Rygel"'

librygel_core_@RYGEL_API_VERSION_UNDERSCORE@_la_LIBADD = \
	$(LIBRYGEL_CORE_DEPS_LIBS) \
	-lm

RYGEL_CORE_VERSION=2:2:0
librygel_core_@RYGEL_API_VERSION_UNDERSCORE@_la_LDFLAGS = \
	$(RYGEL_DATA_DIR_DEFINES) \
	-version-info $(RYGEL_CORE_VERSION)

BUILT_SOURCES = \
	rygel-core-@RYGEL_API_VERSION@.vapi \
	rygel-core.h

VAPI_FILES = rygel-core-@RYGEL_API_VERSION@.vapi
DEPS_FILES = rygel-core-@RYGEL_API_VERSION@.deps

vapidir = $(VAPIDIR)
vapi_DATA = $(VAPI_FILES) $(DEPS_FILES)
rygel-core-@RYGEL_API_VERSION@.vapi rygel-core.h: librygel_core_@RYGEL_API_VERSION_UNDERSCORE@_la_vala.stamp

MAINTAINERCLEANFILES += $(BUILT_SOURCES)

EXTRA_DIST = \
	rygel-build-config.vapi \
	$(VAPI_FILES) \
	$(DEPS_FILES) \
	uuid.vapi \
	$(BUILT_SOURCES)
