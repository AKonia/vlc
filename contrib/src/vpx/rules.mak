# libvpx

VPX_VERSION := 1.6.0
VPX_URL := http://storage.googleapis.com/downloads.webmproject.org/releases/webm/libvpx-$(VPX_VERSION).tar.bz2

PKGS += vpx
ifeq ($(call need_pkg,"vpx >= 1.4.0"),)
PKGS_FOUND += vpx
endif

$(TARBALLS)/libvpx-$(VPX_VERSION).tar.bz2:
	$(call download,$(VPX_URL))

.sum-vpx: libvpx-$(VPX_VERSION).tar.bz2

libvpx: libvpx-$(VPX_VERSION).tar.bz2 .sum-vpx
	$(UNPACK)
	$(APPLY) $(SRC)/vpx/libvpx-mac.patch
	$(APPLY) $(SRC)/vpx/libvpx-ios.patch
	$(APPLY) $(SRC)/vpx/libvpx-arm.patch
ifdef HAVE_ANDROID
	$(APPLY) $(SRC)/vpx/libvpx-android.patch
endif
	$(MOVE)

DEPS_vpx =

ifdef HAVE_CROSS_COMPILE
VPX_CROSS := $(HOST)-
else
VPX_CROSS :=
endif

VPX_LDFLAGS := $(LDFLAGS)

ifeq ($(ARCH),arm)
VPX_ARCH := armv7
else ifeq ($(ARCH),i386)
VPX_ARCH := x86
else ifeq ($(ARCH),mips)
VPX_ARCH := mips32
else ifeq ($(ARCH),ppc)
VPX_ARCH := ppc32
else ifeq ($(ARCH),ppc64)
VPX_ARCH := ppc64
else ifeq ($(ARCH),sparc)
VPX_ARCH := sparc
else ifeq ($(ARCH),x86_64)
VPX_ARCH := x86_64
endif

ifdef HAVE_ANDROID
VPX_OS := android
else ifdef HAVE_LINUX
VPX_OS := linux
else ifdef HAVE_MACOSX
ifeq ($(OSX_VERSION),10.5)
VPX_OS := darwin9
else
VPX_OS := darwin10
endif
else ifdef HAVE_IOS
VPX_OS := darwin11
else ifdef HAVE_SOLARIS
VPX_OS := solaris
else ifdef HAVE_WIN64 # must be before WIN32
VPX_OS := win64
else ifdef HAVE_WIN32
VPX_OS := win32
else ifdef HAVE_BSD
VPX_OS := linux
endif

VPX_TARGET := generic-gnu
ifdef VPX_ARCH
ifdef VPX_OS
VPX_TARGET := $(VPX_ARCH)-$(VPX_OS)-gcc
endif
endif

VPX_CONF := \
	--enable-runtime-cpu-detect \
	--disable-docs \
	--disable-examples \
	--disable-unit-tests \
	--disable-install-bins \
	--disable-install-docs \
	--disable-dependency-tracking \
	--enable-vp9-highbitdepth

ifndef BUILD_ENCODERS
VPX_CONF += --disable-vp8-encoder --disable-vp9-encoder
endif

ifndef HAVE_WIN32
VPX_CONF += --enable-pic
else
VPX_CONF += --extra-cflags="-mstackrealign"
endif
ifdef HAVE_MACOSX
VPX_CONF += --sdk-path=$(MACOSX_SDK)
endif
ifdef HAVE_IOS
VPX_CONF += --sdk-path=$(IOS_SDK) --enable-vp8-decoder --disable-vp8-encoder --disable-vp9-encoder
ifdef HAVE_TVOS
VPX_LDFLAGS := -L$(IOS_SDK)/usr/lib -isysroot $(IOS_SDK) -mtvos-version-min=9.0
else
VPX_LDFLAGS := -L$(IOS_SDK)/usr/lib -isysroot $(IOS_SDK) -miphoneos-version-min=6.1
endif
ifeq ($(ARCH),aarch64)
VPX_LDFLAGS += -arch arm64
else
VPX_LDFLAGS += -arch $(ARCH)
endif
endif
ifdef HAVE_ANDROID
# vpx configure.sh overrides our sysroot and it looks for it itself, and
# uses that path to look for the compiler (which we already know)
VPX_CONF += --sdk-path=$(shell dirname $(shell which $(HOST)-clang))
# broken text relocations
ifeq ($(ARCH),x86_64)
VPX_CONF += --disable-mmx
endif
endif

ifndef WITH_OPTIMIZATION
VPX_CONF += --enable-debug --disable-optimizations
endif

.vpx: libvpx
	cd $< && LDFLAGS="$(VPX_LDFLAGS)" CROSS=$(VPX_CROSS) ./configure --target=$(VPX_TARGET) \
		$(VPX_CONF) --prefix=$(PREFIX)
	cd $< && $(MAKE)
	cd $< && ../../../contrib/src/pkg-static.sh vpx.pc
	cd $< && $(MAKE) install
	touch $@
