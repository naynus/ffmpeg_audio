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

- `ffmpeg_version`: choose `spksrc`, `latest`, or a published FFmpeg 8 release
- `spksrc_ref`: a branch, tag, or commit from SynoCommunity's `spksrc`
- `arch`: the Synology toolchain architecture, such as `x64`
- `tcversion`: the DSM toolchain version, such as `7.2`

`spksrc` is the recommended FFmpeg setting. It builds the FFmpeg version
integrated by the selected `spksrc` revision, so its source digest and patches
are expected to match. `latest` follows the newest official FFmpeg 8 release
and regenerates its source digest, but the build can fail if the current
`spksrc` patches have not yet been updated for that release.

The manual workflow form lists all FFmpeg 8 releases published when the
workflow file was last updated. GitHub Actions requires `choice` options to be
declared statically in the workflow YAML, so newly published versions do not
appear as exact choices automatically. The `latest` choice still resolves the
newest available FFmpeg 8 release dynamically at build time.

The workflow uploads the resulting SPK and a build manifest as artifacts.
Use the architecture and DSM version matching the NAS that will install the
package. A generic package is not produced because the cross-compiled binary
and its shared libraries are architecture-specific.

The workflow clones `spksrc` at build time and overlays the two Makefiles from
this repository. This keeps the toolchain and packaging framework upstream
while keeping the FFmpeg feature selection under version control here.

### Scheduled updates

The workflow runs automatically every Monday at 03:17 UTC. Scheduled builds
default to:

```text
FFMPEG_VERSION=spksrc
SPKSRC_REF=master
SYNOLOGY_ARCH=x64
SYNOLOGY_TCVERSION=7.2
```

These defaults can be overridden without editing the workflow. In the GitHub
repository, open **Settings -> Secrets and variables -> Actions -> Variables**
and create any of:

- `FFMPEG_VERSION`: `spksrc`, `latest`, or a specific FFmpeg 8 version
- `SPKSRC_REF`: normally `master`, or a tag/commit for reproducibility
- `SYNOLOGY_ARCH`: for example `x64` or `aarch64`
- `SYNOLOGY_TCVERSION`: for example `7.2` or `7.3`

The DSM toolchain target remains pinned intentionally. Updating a NAS from DSM
7.2 to 7.3 should be followed by changing `SYNOLOGY_TCVERSION`; automatically
changing it could create an SPK that cannot be installed on the current DSM.

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

Scheduled builds follow the selected `spksrc` revision and its integrated
FFmpeg version automatically. To test a newer official FFmpeg release before
`spksrc` adopts it, manually run the workflow with `ffmpeg_version=latest`.
If patches or configure behavior are incompatible, the workflow intentionally
fails instead of silently falling back to the video-enabled upstream recipe.

## Scope

This is an audio-processing distribution, not a general media transcoder. It
does not support general video conversion. It does retain limited image/video
codec support because NaviAgent represents embedded album artwork as an
`attached_pic` video stream.
