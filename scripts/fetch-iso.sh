#!/bin/bash
# Download the official Kylin Desktop V10 SP1 2503 LoongArch64 ISO (no registration) and verify MD5.
set -e
cd "$(dirname "$0")/.."
URL=https://iso.kylinos.cn/web_pungi/download/cdn/j1m5tfWsvMY7Gdez0bhrFxcaZRpyDUPi/Kylin-Desktop-V10-SP1-2503-Release-20250430-LoongArch64.iso
OUT=${1:-Kylin-2503-loongarch64.iso}
MD5=e92d0f4256c0734f970cabe7b19f0067
# resume + retry on stalls (the CDN sometimes stalls)
until curl -fL -C - --speed-limit 10000 --speed-time 30 -o "$OUT" "$URL"; do echo "retrying..."; sleep 3; done
echo "$MD5  $OUT" | md5sum -c -
