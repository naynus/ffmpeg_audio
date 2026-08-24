SPK_NAME = ffmpeg8
SPK_VERS ?= 8.1.2
SPK_MINOR_VERS = $(firstword $(subst ., ,$(SPK_VERS)))
SPK_REV ?= 102
SPK_ICON = src/ffmpeg8.png

DEPENDS = cross/ffmpeg8
PLIST_TRANSFORM = grep -v '^bin:bin/lame$$'

MIN_GCC_VERSION = 4.9

MAINTAINER = ffmpeg8-audio-builder
MAINTAINER_URL = https://github.com/SynoCommunity/spksrc
DISABLE_GITHUB_MAINTAINER = 1
DESCRIPTION = CPU-only FFmpeg $(SPK_VERS) with audio processing and audio extraction support. Video codecs and hardware acceleration are disabled.
DESCRIPTION_FRE = FFmpeg $(SPK_VERS) sans GPU, avec traitement et extraction audio. Les codecs video et l acceleration materielle sont desactives.
DISPLAY_NAME = FFmpeg $(SPK_MINOR_VERS) Audio
STARTABLE = no

HOMEPAGE = https://www.ffmpeg.org/
LICENSE = GPLv3

POST_STRIP_TARGET = $(SPK_NAME)_extra_install

SPK_COMMANDS = bin/ffprobe$(SPK_MINOR_VERS)
SPK_COMMANDS += bin/ffmpeg$(SPK_MINOR_VERS)

include ../../mk/spksrc.common.mk

ifeq ($(call version_ge, $(TCVERSION), 7.0),1)
SERVICE_USER = auto
endif

include ../../mk/spksrc.spk.mk

.PHONY: $(SPK_NAME)_extra_install
$(SPK_NAME)_extra_install:
	cd $(STAGING_DIR)/bin && ln -sf ffprobe ffprobe$(SPK_MINOR_VERS)
	cd $(STAGING_DIR)/bin && ln -sf ffmpeg ffmpeg$(SPK_MINOR_VERS)
