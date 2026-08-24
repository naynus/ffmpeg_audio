# Minimal FFmpeg 8 SPK for Synology

This repository builds a CPU-only, audio-focused FFmpeg 8 SPK with
SynoCommunity's `spksrc` Docker toolchain.

The build intentionally does not install or declare:

- `synocli-videodriver`
- `synocli-videodriver-tools`
- VA-API, Vulkan, OpenCL, Intel Media SDK, or V4L2 acceleration
- General-purpose FFmpeg video encoders and video decoders
- Optional external video libraries such as x264, x265, libaom, dav1d,
  libvpx, libwebp, and libzimg

It retains the FFmpeg programs and libraries needed to process audio and to
extract audio streams from common containers such as MP4, MKV, WebM, MPEG-TS,
Ogg, FLAC, MP3, WAV, AIFF, CAF, and ASF. It also retains the small image
codec/container subset required for embedded album artwork: JPEG/MJPEG, PNG,
WebP, GIF, BMP, TIFF, `image2`, and `image2pipe`.

## Important package-name behavior

The generated package is named `ffmpeg8`, so it can act as a replacement for
the SynoCommunity FFmpeg 8 package. It cannot be installed alongside another
package with the same package name. Uninstall the existing package first, then
install the generated SPK.

The package contains:

```text
/var/packages/ffmpeg8/target/bin/ffmpeg
/var/packages/ffmpeg8/target/bin/ffmpeg8
/var/packages/ffmpeg8/target/bin/ffprobe
/var/packages/ffmpeg8/target/bin/ffprobe8
```

## GitHub Actions

Run **Actions -> Build minimal FFmpeg 8 SPK -> Run workflow** and select:

- `ffmpeg_version`: `latest` or a specific FFmpeg 8 release, such as `8.1.2`
- `spksrc_ref`: a branch, tag, or commit from SynoCommunity's `spksrc`
- `arch`: the Synology toolchain architecture, such as `x64`
- `tcversion`: the DSM toolchain version, such as `7.2`

The workflow uploads the resulting SPK and a build manifest as artifacts.
Use the architecture and DSM version matching the NAS that will install the
package. A generic package is not produced because the cross-compiled binary
and its shared libraries are architecture-specific.

The workflow clones `spksrc` at build time and overlays the two Makefiles from
this repository. This keeps the toolchain and packaging framework upstream
while keeping the FFmpeg feature selection under version control here.

## Local build

The same build can be run on Linux or macOS with Docker:

```bash
bash scripts/prepare-spksrc.sh

docker run --rm \
  --platform=linux/amd64 \
  -v "$PWD:/github/workspace" \
  -w /github/workspace \
  -e ARCH=x64 \
  -e TCVERSION=7.2 \
  -e FFMPEG_VERSION=8.1.2 \
  -e SPK_REV=100 \
  ghcr.io/synocommunity/spksrc:latest \
  /bin/bash /github/workspace/scripts/build-in-container.sh
```

SynoCommunity documents the Docker development environment and the
architecture-specific `make` targets in its `spksrc` repository.

## Updating FFmpeg

When moving to a newer FFmpeg release, first run the workflow with the new
version. If upstream `spksrc` has not yet added compatible patches or the
release changes configure behavior, the build may need a small recipe update.
The workflow intentionally fails instead of silently falling back to the
video-enabled upstream recipe.

## Scope

This is an audio-processing distribution, not a general media transcoder. It
does not support general video conversion. It does retain limited image/video
codec support because NaviAgent represents embedded album artwork as an
`attached_pic` video stream.
