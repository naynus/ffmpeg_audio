PKG_NAME = ffmpeg
PKG_VERS ?= 8.1.2
PKG_EXT = tar.bz2
PKG_DIST_NAME = $(PKG_NAME)-$(PKG_VERS).$(PKG_EXT)
PKG_DIST_SITE = https://www.ffmpeg.org/releases
PKG_DIR = $(PKG_NAME)-$(PKG_VERS)

HOMEPAGE = https://www.ffmpeg.org/
COMMENT = CPU-only FFmpeg with audio processing and audio extraction support
LICENSE = GPLv3

MIN_GCC_VERSION = 4.9

include ../../mk/spksrc.common.mk

CONFIGURE_ARGS  = --target-os=linux
CONFIGURE_ARGS += --cross-prefix=$(TC_PATH)$(TC_PREFIX)
CONFIGURE_ARGS += --prefix=$(INSTALL_PREFIX)
CONFIGURE_ARGS += --pkg-config=/usr/bin/pkg-config
CONFIGURE_ARGS += --ranlib=$(RANLIB)
CONFIGURE_ARGS += --enable-cross-compile
CONFIGURE_ARGS += --enable-rpath
CONFIGURE_ARGS += --enable-pic
CONFIGURE_ARGS += --enable-shared
CONFIGURE_ARGS += --disable-static
CONFIGURE_ARGS += --disable-doc
CONFIGURE_ARGS += --disable-debug
CONFIGURE_ARGS += --disable-autodetect
CONFIGURE_ARGS += --enable-gpl
CONFIGURE_ARGS += --disable-everything
CONFIGURE_ARGS += --disable-avdevice
CONFIGURE_ARGS += --enable-swscale
CONFIGURE_ARGS += --enable-zlib

# Programs and libraries required by the shared audio backend.
CONFIGURE_ARGS += --enable-ffmpeg
CONFIGURE_ARGS += --enable-ffprobe
CONFIGURE_ARGS += --enable-avcodec
CONFIGURE_ARGS += --enable-avformat
CONFIGURE_ARGS += --enable-avfilter
CONFIGURE_ARGS += --enable-swresample
CONFIGURE_ARGS += --enable-avutil

# Keep local file and pipe I/O. Network protocols are intentionally omitted so
# no TLS or networking library becomes a transitive dependency.
CONFIGURE_ARGS += --enable-protocol=file,pipe

# Container demuxers. These allow audio extraction from common media files
# while retaining image2 input for local album artwork.
CONFIGURE_ARGS += --enable-demuxer=aac,ac3,adts,aiff,ape,asf,avi,caf,flac,flv,image2,image2pipe,matroska,mov,mp3,mpegts,ogg,wav,webm

# Audio-oriented output containers and the image pipe used for artwork
# previews. ipod is the usual muxer selected for .m4a output.
CONFIGURE_ARGS += --enable-muxer=adts,aiff,caf,flac,image2,image2pipe,ipod,matroska,mp3,mov,mp4,ogg,wav,webm

# Native audio decoders and the image decoders needed for embedded artwork.
CONFIGURE_ARGS += --enable-decoder=aac,ac3,alac,ape,bmp,comfortnoise,cook,dca,eac3,flac,g723_1,g729,gif,gsm,ilbc,jpegls,mjpeg,mp1,mp2,mp3,nellymoser,opus,pcm_alaw,pcm_f16le,pcm_f24le,pcm_f32be,pcm_f32le,pcm_f64be,pcm_f64le,pcm_mulaw,pcm_s16be,pcm_s16le,pcm_s24be,pcm_s24le,pcm_s32be,pcm_s32le,pcm_s64be,pcm_u8,png,s302m,speex,tiff,truehd,tta,vorbis,wavpack,webp,wmalossless,wmav1,wmav2

# Native audio encoders. External codec libraries are intentionally omitted
# except for LAME, which NaviAgent explicitly invokes for MP3 conversion.
CONFIGURE_ARGS += --enable-encoder=aac,ac3,eac3,flac,mp2,pcm_alaw,pcm_f16be,pcm_f16le,pcm_f24be,pcm_f24le,pcm_f32be,pcm_f32le,pcm_f64be,pcm_f64le,pcm_mulaw,pcm_s16be,pcm_s16le,pcm_s24be,pcm_s24le,pcm_s32be,pcm_s32le,pcm_s64be,pcm_u8
CONFIGURE_ARGS += --enable-encoder=libmp3lame,png
CONFIGURE_ARGS += --enable-libmp3lame

# Audio parsers and bitstream filters needed by common transport/container
# formats.
CONFIGURE_ARGS += --enable-parser=aac,ac3,dca,flac,mpegaudio,opus,vorbis
CONFIGURE_ARGS += --enable-bsf=aac_adtstoasc,null

# Audio filters commonly used by server applications.
CONFIGURE_ARGS += --enable-filter=acopy,afade,afifo,afir,aformat,amix,anull,apad,apulsator,aresample,aselect,asetnsamples,asetpts,asetrate,atempo,atrim,bandpass,bandreject,bass,biquad,channelmap,channelsplit,compand,acompressor,dcshift,dynaudnorm,ebur128,equalizer,extrastereo,firequalizer,highpass,join,lowpass,loudnorm,pan,replaygain,sidechaincompress,silencedetect,silenceremove,stereotools,stereowiden,tiltshelf,treble,volume
# The ffmpeg CLI selects these core filters even in an audio-focused build.
CONFIGURE_ARGS += --enable-filter=crop,format,hflip,null,rotate,transpose,trim,vflip

DEPENDS += cross/lame
DEPENDS += cross/zlib

CONFIGURE_ARGS += --extra-cflags=-O3

ifeq ($(findstring $(ARCH),$(i686_ARCHS) $(x64_ARCHS)),$(ARCH))
CONFIGURE_ARGS += --x86asmexe=nasm
else ifneq ($(findstring $(ARCH),$(ARMv8_ARCHS)),$(ARCH))
CONFIGURE_ARGS += --disable-asm
endif

ifeq ($(findstring $(ARCH),$(ARMv7_ARCHS)),$(ARCH))
CONFIGURE_ARGS += --arch=arm
CONFIGURE_ARGS += --enable-neon
CONFIGURE_ARGS += --enable-thumb
CONFIGURE_ARGS += --disable-armv5te
CONFIGURE_ARGS += --disable-armv6
CONFIGURE_ARGS += --disable-armv6t2
CONFIGURE_ARGS += --disable-vfp
endif

ifeq ($(findstring $(ARCH),$(ARMv8_ARCHS)),$(ARCH))
CONFIGURE_ARGS += --arch=arm64
CONFIGURE_ARGS += --enable-neon
CONFIGURE_ARGS += --enable-thumb
endif

ifeq ($(findstring $(ARCH),$(x64_ARCHS)),$(ARCH))
CONFIGURE_ARGS += --arch=x86_64
endif

ifeq ($(ARCH),evansport)
CONFIGURE_ARGS += --arch=x86
CONFIGURE_ARGS += --cpu=atom
endif

ifeq ($(ARCH),qoriq)
CONFIGURE_ARGS += --arch=ppc
CONFIGURE_ARGS += --cpu=e500v2
CONFIGURE_ARGS += --extra-libs=-latomic
endif

include ../../mk/spksrc.cross-cc.mk
