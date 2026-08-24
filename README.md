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

### One-click release

The workflow can build the SPK and publish it as a GitHub Release in one run:

1. Open **Actions -> Build minimal FFmpeg 8 SPK -> Run workflow**.
2. Select the build settings. `publish_release` is enabled by default for
   manual runs.
3. Leave `release_tag` as `auto`, or enter a custom tag.
4. Click **Run workflow**.

An automatic tag has this format:

```text
v<ffmpeg-version>-r<spk-revision>-<architecture>-dsm<toolchain-version>
```

For example:

```text
v8.1.2-r102-x64-dsm7.2
```

The release contains the generated `.spk` file and `build-manifest.txt`.
Push and scheduled runs continue to upload Actions artifacts only; they do
not publish releases.

Available manual-run release options:

- `publish_release`: enable or disable GitHub Release publication
- `release_tag`: use `auto` or provide a custom release tag
- `release_draft`: create a draft release for review
- `release_prerelease`: mark the release as a pre-release
- `generate_release_notes`: let GitHub generate release notes

The workflow requires the repository's Actions token to have permission to
write repository contents. This is configured in the workflow with
`contents: write`; the account running the workflow must also have permission
to create releases.

### Build options

The build inputs are:

- `ffmpeg_version`: choose the supported `spksrc` recipe or experimental
  `latest` upstream release
- `spksrc_ref`: a branch, tag, or commit from SynoCommunity's `spksrc`
- `arch`: the Synology toolchain architecture, such as `x64`
- `tcversion`: the DSM toolchain version, such as `7.2`
- `spk_rev`: the Synology package revision number

`spksrc` is the recommended FFmpeg setting. It builds the FFmpeg version
integrated by the selected `spksrc` revision, so its source digest and patches
are expected to match. `latest` follows the newest official FFmpeg 8 release
and regenerates its source digest, but the build can fail if the current
`spksrc` patches have not yet been updated for that release.

An `spksrc` revision normally supports the single FFmpeg version pinned by its
`cross/ffmpeg8` recipe. It does not publish a compatibility list containing
every older FFmpeg 8 tag. For this reason, the manual form does not present
upstream release tags as supported choices. Select `spksrc` and pin
`spksrc_ref` to a commit when a reproducible, recipe-matched build is required.

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

- `FFMPEG_VERSION`: `spksrc` (supported), `latest` (experimental), or an
  explicit FFmpeg 8 version override for compatibility testing
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
