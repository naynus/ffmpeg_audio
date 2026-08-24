#!/usr/bin/env bash
set -euo pipefail

: "${SPKSRC_REF:=master}"

rm -rf spksrc
mkdir -p spksrc
git -C spksrc init
git -C spksrc remote add origin https://github.com/SynoCommunity/spksrc.git
git -C spksrc fetch --depth 1 origin "$SPKSRC_REF"
git -C spksrc checkout --detach FETCH_HEAD

mkdir -p spksrc/spk/ffmpeg8 spksrc/cross/ffmpeg8
cp recipes/spk/ffmpeg8/Makefile spksrc/spk/ffmpeg8/Makefile
cp recipes/cross/ffmpeg8/Makefile spksrc/cross/ffmpeg8/Makefile

printf 'spksrc_ref=%s\n' "$SPKSRC_REF" > spksrc/build-manifest.txt
