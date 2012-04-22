#Makefile for FRC vxworks gcc patches

PATCH_DIR = $(shell pwd)
DESTDIR = /
PREFIX = $(DESTDIR)/usr/local
DLDIR = $(PATCH_DIR)/download
SRCDIR = $(PATCH_DIR)/sources
BUILDDIR = $(PATCH_DIR)/build

all:
	echo Deferring build to install time, run 'make install' to compile and install

install:
	$(PATCH_DIR)/build.bash $(PREFIX) $(DLDIR) $(SRCDIR) $(BUILDDIR)

clean:
	rm -rf $(DLDIR) $(SRCDIR) $(BUILDDIR)

