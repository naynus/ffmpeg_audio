#!/usr/bin/env bash
set -euo pipefail

: "${SPKSRC_REF:=master}"

rm -rf spksrc
mkdir -p spksrc
git -C spksrc init
git -C spksrc remote add origin https://github.com/SynoCommunity/spksrc.git
git -C spksrc fetch --depth 1 origin "$SPKSRC_REF"
git -C spksrc checkout --detach FETCH_HEAD

spksrc_ffmpeg_version="$(
  sed -n 's/^PKG_VERS[[:space:]]*=[[:space:]]*//p' \
    spksrc/cross/ffmpeg8/Makefile |
  head -n 1
)"
if [[ ! "$spksrc_ffmpeg_version" =~ ^8\.[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Unable to determine FFmpeg 8 version from spksrc" >&2
  exit 1
fi

mkdir -p spksrc/spk/ffmpeg8/src spksrc/cross/ffmpeg8
cp recipes/spk/ffmpeg8/Makefile spksrc/spk/ffmpeg8/Makefile
cp recipes/spk/ffmpeg8/src/ffmpeg8.png spksrc/spk/ffmpeg8/src/ffmpeg8.png
cp recipes/cross/ffmpeg8/Makefile spksrc/cross/ffmpeg8/Makefile
cp recipes/cross/ffmpeg8/PLIST spksrc/cross/ffmpeg8/PLIST

{
  printf 'spksrc_ref=%s\n' "$SPKSRC_REF"
  printf 'spksrc_commit=%s\n' "$(git -C spksrc rev-parse HEAD)"
  printf 'spksrc_ffmpeg_version=%s\n' "$spksrc_ffmpeg_version"
} > spksrc/build-manifest.txt
