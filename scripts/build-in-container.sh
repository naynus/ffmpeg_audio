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

# Set versions in the two FFmpeg recipes instead of passing PKG_VERS on the
# make command line. Command-line variables propagate into dependency builds
# and would otherwise make packages such as LAME use the FFmpeg version.
sed -i -E \
  "s/^PKG_VERS[[:space:]]*\\?=[[:space:]]*.*/PKG_VERS = $FFMPEG_VERSION/" \
  cross/ffmpeg8/Makefile
sed -i -E \
  "s/^SPK_VERS[[:space:]]*\\?=[[:space:]]*.*/SPK_VERS = $FFMPEG_VERSION/" \
  spk/ffmpeg8/Makefile

grep -Fqx "PKG_VERS = $FFMPEG_VERSION" cross/ffmpeg8/Makefile
grep -Fqx "SPK_VERS = $FFMPEG_VERSION" spk/ffmpeg8/Makefile

if [ "$FFMPEG_VERSION" != "$spksrc_ffmpeg_version" ]; then
  echo "Regenerating source digest for FFmpeg $FFMPEG_VERSION"
  env -u ARCH -u TCVERSION make --no-print-directory \
    -C cross/ffmpeg8 \
    digests
fi

make --no-print-directory \
  -C spk/ffmpeg8 \
  ARCH="$ARCH" \
  TCVERSION="$TCVERSION" \
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
