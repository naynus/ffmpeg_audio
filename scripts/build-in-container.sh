#!/usr/bin/env bash
set -euo pipefail

: "${ARCH:?ARCH is required}"
: "${TCVERSION:?TCVERSION is required}"
: "${FFMPEG_VERSION:?FFMPEG_VERSION is required}"
: "${SPK_REV:=102}"

cd /github/workspace/spksrc

spksrc_ffmpeg_version="$(
  sed -n 's/^spksrc_ffmpeg_version=//p' build-manifest.txt
)"
spksrc_ref="$(sed -n 's/^spksrc_ref=//p' build-manifest.txt)"
spksrc_commit="$(sed -n 's/^spksrc_commit=//p' build-manifest.txt)"

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

package_file="$(
  find packages -maxdepth 1 -type f -name '*.spk' -print -quit
)"
if [ -z "$package_file" ]; then
  echo "Build completed without producing an SPK" >&2
  exit 1
fi

validation_dir="$(mktemp -d)"
trap 'rm -rf "$validation_dir"' EXIT
tar -xf "$package_file" -C "$validation_dir" \
  package.tgz PACKAGE_ICON.PNG PACKAGE_ICON_256.PNG
test -s "$validation_dir/PACKAGE_ICON.PNG"
test -s "$validation_dir/PACKAGE_ICON_256.PNG"
mkdir "$validation_dir/payload"
tar -xzf "$validation_dir/package.tgz" -C "$validation_dir/payload"

test -x "$validation_dir/payload/bin/ffmpeg"
test -x "$validation_dir/payload/bin/ffprobe"
test ! -e "$validation_dir/payload/bin/lame"
if find "$validation_dir/payload/lib" -maxdepth 1 -name 'libavdevice*' |
  grep -q .; then
  echo "Unexpected libavdevice files found in the SPK" >&2
  exit 1
fi

# x64 packages can be smoke-tested directly in the amd64 build container.
if [ "$ARCH" = "x64" ]; then
  export LD_LIBRARY_PATH="$validation_dir/payload/lib"
  "$validation_dir/payload/bin/ffmpeg" -hide_banner -version
  "$validation_dir/payload/bin/ffprobe" -hide_banner -version

  encoders="$("$validation_dir/payload/bin/ffmpeg" -hide_banner -encoders)"
  for encoder in libmp3lame flac aac png; do
    if ! awk -v name="$encoder" '$2 == name { found=1 } END { exit !found }' \
      <<< "$encoders"; then
      echo "Required encoder is missing: $encoder" >&2
      exit 1
    fi
  done

  decoders="$("$validation_dir/payload/bin/ffmpeg" -hide_banner -decoders)"
  if ! awk '$2 == "jpegls" { found=1 } END { exit !found }' \
    <<< "$decoders"; then
    echo "Required decoder is missing: jpegls" >&2
    exit 1
  fi

  muxers="$("$validation_dir/payload/bin/ffmpeg" -hide_banner -muxers)"
  for muxer in ipod mov mp4; do
    if ! awk -v name="$muxer" '$2 == name { found=1 } END { exit !found }' \
      <<< "$muxers"; then
      echo "Required MOV-family muxer is missing: $muxer" >&2
      exit 1
    fi
  done

  ipod_options="$(
    "$validation_dir/payload/bin/ffmpeg" -hide_banner -h muxer=ipod
  )"
  grep -Fq "movflags" <<< "$ipod_options"
  grep -Fq "faststart" <<< "$ipod_options"

  python3 - "$validation_dir/input.wav" <<'PY'
import sys
import wave

with wave.open(sys.argv[1], "wb") as output:
    output.setnchannels(2)
    output.setsampwidth(2)
    output.setframerate(44100)
    output.writeframes(b"\0" * 44100)
PY

  "$validation_dir/payload/bin/ffmpeg" \
    -hide_banner -loglevel error -nostdin -y \
    -i "$validation_dir/input.wav" \
    -map 0:a:0 -c:a aac -b:a 256k \
    -movflags +faststart \
    "$validation_dir/output.m4a"

  probe_output="$(
    "$validation_dir/payload/bin/ffprobe" \
      -v error \
      -select_streams a:0 \
      -show_entries format=format_name:stream=codec_name \
      -of default=noprint_wrappers=1 \
      "$validation_dir/output.m4a"
  )"
  grep -Fqx "codec_name=aac" <<< "$probe_output"
  grep -Eq '^format_name=.*(mov|mp4|m4a)' <<< "$probe_output"

  python3 - "$validation_dir/output.m4a" <<'PY'
import sys

data = open(sys.argv[1], "rb").read()
moov = data.find(b"moov")
mdat = data.find(b"mdat")
if moov < 0 or mdat < 0 or moov > mdat:
    raise SystemExit("M4A faststart validation failed")
PY
fi

{
  printf 'ffmpeg_version=%s\n' "$FFMPEG_VERSION"
  printf 'spk_revision=%s\n' "$SPK_REV"
  printf 'arch=%s\n' "$ARCH"
  printf 'tcversion=%s\n' "$TCVERSION"
  printf 'spksrc_ref=%s\n' "$spksrc_ref"
  printf 'spksrc_commit=%s\n' "$spksrc_commit"
  printf 'spksrc_ffmpeg_version=%s\n' "$spksrc_ffmpeg_version"
  printf 'package_files=\n'
  find packages -maxdepth 1 -type f -name '*.spk' -printf '%f\n' | sort
} > build-manifest.txt
