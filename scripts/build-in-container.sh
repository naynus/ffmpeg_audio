#!/usr/bin/env bash
set -euo pipefail

: "${ARCH:?ARCH is required}"
: "${TCVERSION:?TCVERSION is required}"
: "${FFMPEG_VERSION:?FFMPEG_VERSION is required}"
: "${SPK_REV:=100}"

cd /github/workspace/spksrc

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
  printf 'spksrc_commit=%s\n' "$(git rev-parse HEAD)"
  printf 'package_files=\n'
  find packages -maxdepth 1 -type f -name '*.spk' -printf '%f\n' | sort
} > build-manifest.txt
