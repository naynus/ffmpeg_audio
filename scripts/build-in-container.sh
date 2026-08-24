#!/usr/bin/env bash
set -euo pipefail

: "${ARCH:?ARCH is required}"
: "${TCVERSION:?TCVERSION is required}"
: "${FFMPEG_VERSION:?FFMPEG_VERSION is required}"
: "${SPK_REV:=100}"

cd /github/workspace/spksrc

spksrc_ffmpeg_version="$(
  sed -n 's/^spksrc_ffmpeg_version=//p' build-manifest.txt
)"
spksrc_ref="$(sed -n 's/^spksrc_ref=//p' build-manifest.txt)"
if [ "$FFMPEG_VERSION" != "$spksrc_ffmpeg_version" ]; then
  echo "Regenerating source digest for FFmpeg $FFMPEG_VERSION"
  env -u ARCH -u TCVERSION make --no-print-directory \
    -C cross/ffmpeg8 \
    PKG_VERS="$FFMPEG_VERSION" \
    digests
fi

make --no-print-directory \
  -C spk/ffmpeg8 \
  ARCH="$ARCH" \
  TCVERSION="$TCVERSION" \
  SPK_VERS="$FFMPEG_VERSION" \
  PKG_VERS="$FFMPEG_VERSION" \
  SPK_REV="$SPK_REV" \
  all

{
  printf 'ffmpeg_version=%s\n' "$FFMPEG_VERSION"
  printf 'spk_revision=%s\n' "$SPK_REV"
  printf 'arch=%s\n' "$ARCH"
  printf 'tcversion=%s\n' "$TCVERSION"
  printf 'spksrc_ref=%s\n' "$spksrc_ref"
  printf 'spksrc_commit=%s\n' "$(git rev-parse HEAD)"
  printf 'spksrc_ffmpeg_version=%s\n' "$spksrc_ffmpeg_version"
  printf 'package_files=\n'
  find packages -maxdepth 1 -type f -name '*.spk' -printf '%f\n' | sort
} > build-manifest.txt
