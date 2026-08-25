#!/usr/bin/env bash
set -euo pipefail

: "${ARCH:?ARCH is required}"
: "${TCVERSION:?TCVERSION is required}"
: "${FFMPEG_VERSION:?FFMPEG_VERSION is required}"
: "${SPK_REV:=104}"

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
  package.tgz INFO PACKAGE_ICON.PNG PACKAGE_ICON_256.PNG
test -s "$validation_dir/PACKAGE_ICON.PNG"
test -s "$validation_dir/PACKAGE_ICON_256.PNG"
package_version="$(
  sed -n 's/^version="\([^"]*\)".*/\1/p' "$validation_dir/INFO"
)"
expected_package_version="$FFMPEG_VERSION-$SPK_REV"
if [ "$package_version" != "$expected_package_version" ]; then
  echo "SPK metadata version mismatch: expected $expected_package_version, got $package_version" >&2
  exit 1
fi
if [[ "$(basename "$package_file")" != *"_$expected_package_version.spk" ]]; then
  echo "SPK filename version mismatch: expected suffix _$expected_package_version.spk" >&2
  exit 1
fi
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
  ffmpeg_version="$(
    "$validation_dir/payload/bin/ffmpeg" -hide_banner -version |
      awk 'NR == 1 { print $3; exit }'
  )"
  ffprobe_version="$(
    "$validation_dir/payload/bin/ffprobe" -hide_banner -version |
      awk 'NR == 1 { print $3; exit }'
  )"
  if [ "$ffmpeg_version" != "$FFMPEG_VERSION" ]; then
    echo "FFmpeg runtime version mismatch: expected $FFMPEG_VERSION, got $ffmpeg_version" >&2
    exit 1
  fi
  if [ "$ffprobe_version" != "$FFMPEG_VERSION" ]; then
    echo "FFprobe runtime version mismatch: expected $FFMPEG_VERSION, got $ffprobe_version" >&2
    exit 1
  fi

  encoders="$("$validation_dir/payload/bin/ffmpeg" -hide_banner -encoders)"
  for encoder in libmp3lame flac aac mjpeg png; do
    if ! awk -v name="$encoder" '$2 == name { found=1 } END { exit !found }' \
      <<< "$encoders"; then
      echo "Required encoder is missing: $encoder" >&2
      exit 1
    fi
  done

  decoders="$("$validation_dir/payload/bin/ffmpeg" -hide_banner -decoders)"
  for decoder in bmp gif jpegls mjpeg png tiff webp; do
    if ! awk -v name="$decoder" \
      '$2 == name { found=1 } END { exit !found }' <<< "$decoders"; then
      echo "Required artwork decoder is missing: $decoder" >&2
      exit 1
    fi
  done

  filters="$("$validation_dir/payload/bin/ffmpeg" -hide_banner -filters)"
  for filter in aresample format scale; do
    if ! awk -v name="$filter" \
      '$2 == name { found=1 } END { exit !found }' <<< "$filters"; then
      echo "Required conversion filter is missing: $filter" >&2
      exit 1
    fi
  done

  demuxers="$("$validation_dir/payload/bin/ffmpeg" -hide_banner -demuxers)"
  for demuxer in aac asf flac image2 mov mp3 ogg wav; do
    if ! awk -v name="$demuxer" \
      '{
        count = split($2, aliases, ",")
        for (i = 1; i <= count; i++) {
          if (aliases[i] == name)
            found = 1
        }
      }
      END { exit !found }' <<< "$demuxers"; then
      echo "Required input demuxer is missing: $demuxer" >&2
      exit 1
    fi
  done

  protocols="$("$validation_dir/payload/bin/ffmpeg" -hide_banner -protocols)"
  for protocol in file pipe; do
    if ! awk -v name="$protocol" \
      '$1 == name { found=1 } END { exit !found }' <<< "$protocols"; then
      echo "Required local protocol is missing: $protocol" >&2
      exit 1
    fi
  done

  muxers="$("$validation_dir/payload/bin/ffmpeg" -hide_banner -muxers)"
  for muxer in flac image2 image2pipe ipod mov mp3 mp4; do
    if ! awk -v name="$muxer" '$2 == name { found=1 } END { exit !found }' \
      <<< "$muxers"; then
      echo "Required output muxer is missing: $muxer" >&2
      exit 1
    fi
  done

  ipod_options="$(
    "$validation_dir/payload/bin/ffmpeg" -hide_banner -h muxer=ipod
  )"
  grep -Fq "movflags" <<< "$ipod_options"
  grep -Fq "faststart" <<< "$ipod_options"

  python3 - "$validation_dir" <<'PY'
import base64
import os
import struct
import sys
import wave

root = sys.argv[1]
with wave.open(os.path.join(root, "input.wav"), "wb") as output:
    output.setnchannels(2)
    output.setsampwidth(2)
    output.setframerate(44100)
    output.writeframes(b"\0" * 44100)

width = height = 16
row_size = (width * 3 + 3) & ~3
rows = []
for y in range(height):
    row = bytearray()
    for x in range(width):
        row.extend((x * 16, y * 16, 160))
    row.extend(b"\0" * (row_size - len(row)))
    rows.append(bytes(row))
pixels = b"".join(reversed(rows))
header_size = 14 + 40
bmp = (
    b"BM"
    + struct.pack("<IHHI", header_size + len(pixels), 0, 0, header_size)
    + struct.pack(
        "<IiiHHIIiiII",
        40,
        width,
        height,
        1,
        24,
        0,
        len(pixels),
        2835,
        2835,
        0,
        0,
    )
    + pixels
)
open(os.path.join(root, "cover.bmp"), "wb").write(bmp)

samples = {
    "cover.png": (
        "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAACXBIWXMAAAAB"
        "AAAAAQBPJcTWAAAAFElEQVR4nGNkYPjHgA2wYBUdtBIAz/YBHDUXJl8AAAAA"
        "SUVORK5CYII="
    ),
    "cover.webp": "UklGRhwAAABXRUJQVlA4TA8AAAAvB8ABAAdQwMz+ByKi/wEA",
}
for name, encoded in samples.items():
    open(os.path.join(root, name), "wb").write(base64.b64decode(encoded))
PY

  for extension in png webp; do
    "$validation_dir/payload/bin/ffmpeg" \
      -hide_banner -loglevel error -nostdin -y \
      -i "$validation_dir/cover.$extension" \
      -map 0:v:0 -frames:v 1 \
      -f image2pipe -c:v copy \
      "$validation_dir/copied.$extension"
    cmp "$validation_dir/cover.$extension" \
      "$validation_dir/copied.$extension"
  done

  "$validation_dir/payload/bin/ffmpeg" \
    -hide_banner -loglevel error -nostdin -y \
    -i "$validation_dir/cover.bmp" \
    -vf "scale=8:8,format=yuvj420p" \
    -frames:v 1 -c:v mjpeg \
    "$validation_dir/cover.jpg"

  "$validation_dir/payload/bin/ffmpeg" \
    -hide_banner -loglevel error -nostdin -y \
    -i "$validation_dir/cover.jpg" \
    -map 0:v:0 -frames:v 1 \
    -f image2pipe -c:v copy \
    "$validation_dir/copied.jpg"
  cmp "$validation_dir/cover.jpg" "$validation_dir/copied.jpg"

  "$validation_dir/payload/bin/ffmpeg" \
    -hide_banner -loglevel error -nostdin -y \
    -i "$validation_dir/input.wav" \
    -i "$validation_dir/cover.jpg" \
    -map 0:a:0 -map 1:v:0 \
    -c:a libmp3lame -c:v copy \
    -metadata title="NaviAgent test" \
    -metadata lyrics="Embedded test lyrics" \
    -disposition:v:0 attached_pic \
    -id3v2_version 3 \
    "$validation_dir/output.mp3"

  "$validation_dir/payload/bin/ffprobe" \
    -v error -print_format json -show_format -show_streams \
    "$validation_dir/output.mp3" > "$validation_dir/output.json"

  python3 - "$validation_dir/output.json" <<'PY'
import json
import sys

probe = json.load(open(sys.argv[1], encoding="utf-8"))
streams = probe.get("streams", [])
audio = next((item for item in streams if item.get("codec_type") == "audio"), None)
artwork = next((item for item in streams if item.get("codec_type") == "video"), None)
if not audio or audio.get("codec_name") != "mp3":
    raise SystemExit("MP3 audio stream validation failed")
if not artwork or artwork.get("codec_name") != "mjpeg":
    raise SystemExit("Attached JPEG stream validation failed")
if artwork.get("disposition", {}).get("attached_pic") != 1:
    raise SystemExit("attached_pic disposition is missing")
tags = {key.lower(): value for key, value in probe.get("format", {}).get("tags", {}).items()}
if tags.get("lyrics") != "Embedded test lyrics":
    raise SystemExit("Embedded lyrics validation failed")
PY

  "$validation_dir/payload/bin/ffmpeg" \
    -hide_banner -loglevel error -nostdin -y \
    -i "$validation_dir/output.mp3" \
    -map 0 -map_metadata 0 -c copy \
    -metadata artist="NaviAgent artist" \
    -id3v2_version 3 \
    "$validation_dir/tagged.mp3"

  "$validation_dir/payload/bin/ffprobe" \
    -v error -print_format json -show_format -show_streams \
    "$validation_dir/tagged.mp3" > "$validation_dir/tagged.json"

  python3 - "$validation_dir/tagged.json" <<'PY'
import json
import sys

probe = json.load(open(sys.argv[1], encoding="utf-8"))
artwork = next(
    (item for item in probe.get("streams", []) if item.get("codec_type") == "video"),
    None,
)
if not artwork or artwork.get("disposition", {}).get("attached_pic") != 1:
    raise SystemExit("Stream-copy tag update lost attached artwork")
tags = {key.lower(): value for key, value in probe.get("format", {}).get("tags", {}).items()}
if tags.get("artist") != "NaviAgent artist":
    raise SystemExit("Stream-copy tag update failed")
if tags.get("lyrics") != "Embedded test lyrics":
    raise SystemExit("Stream-copy tag update lost lyrics")
PY

  "$validation_dir/payload/bin/ffmpeg" \
    -hide_banner -loglevel error -nostdin -y \
    -i "$validation_dir/tagged.mp3" \
    -map 0:v:0 -frames:v 1 \
    -f image2pipe -c:v copy \
    "$validation_dir/extracted.jpg"
  cmp "$validation_dir/cover.jpg" "$validation_dir/extracted.jpg"

  "$validation_dir/payload/bin/ffmpeg" \
    -hide_banner -loglevel error -nostdin -y \
    -i "$validation_dir/tagged.mp3" \
    -map 0:v:0 -frames:v 1 \
    -f image2pipe -c:v png \
    "$validation_dir/extracted.png"

  python3 - "$validation_dir/extracted.png" <<'PY'
import struct
import sys

data = open(sys.argv[1], "rb").read()
if data[:8] != b"\x89PNG\r\n\x1a\n":
    raise SystemExit("Artwork PNG signature is invalid")
width, height = struct.unpack(">II", data[16:24])
if (width, height) != (8, 8):
    raise SystemExit(f"Artwork PNG dimensions are {width}x{height}, expected 8x8")
PY

  "$validation_dir/payload/bin/ffmpeg" \
    -hide_banner -loglevel error -nostdin -y \
    -i "$validation_dir/tagged.mp3" \
    -map 0:a:0 -map 0:v:0 \
    -map_metadata 0 -map_chapters 0 \
    -c:a flac -compression_level 8 \
    -c:v copy -disposition:v:0 attached_pic \
    "$validation_dir/output.flac"

  "$validation_dir/payload/bin/ffmpeg" \
    -hide_banner -loglevel error -nostdin -y \
    -i "$validation_dir/tagged.mp3" \
    -map 0:a:0 -map 0:v:0 \
    -map_metadata 0 -map_chapters 0 \
    -c:a aac -b:a 256k \
    -c:v copy -disposition:v:0 attached_pic \
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

  for format in flac m4a; do
    "$validation_dir/payload/bin/ffprobe" \
      -v error -print_format json -show_format -show_streams \
      "$validation_dir/output.$format" > "$validation_dir/output-$format.json"
  done

  python3 \
    "$validation_dir/output-flac.json" \
    "$validation_dir/output-m4a.json" <<'PY'
import json
import sys

for path, expected_audio in zip(sys.argv[1:], ("flac", "aac")):
    probe = json.load(open(path, encoding="utf-8"))
    streams = probe.get("streams", [])
    audio = next((item for item in streams if item.get("codec_type") == "audio"), None)
    artwork = next((item for item in streams if item.get("codec_type") == "video"), None)
    if not audio or audio.get("codec_name") != expected_audio:
        raise SystemExit(f"{expected_audio} conversion validation failed")
    if not artwork or artwork.get("codec_name") != "mjpeg":
        raise SystemExit(f"{expected_audio} conversion lost JPEG artwork")
    if artwork.get("disposition", {}).get("attached_pic") != 1:
        raise SystemExit(f"{expected_audio} conversion lost attached_pic")
    tags = {
        key.lower(): value
        for key, value in probe.get("format", {}).get("tags", {}).items()
    }
    if tags.get("artist") != "NaviAgent artist":
        raise SystemExit(f"{expected_audio} conversion lost metadata")
    if tags.get("lyrics") != "Embedded test lyrics":
        raise SystemExit(f"{expected_audio} conversion lost lyrics")
PY

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
