#!/bin/bash
# ./shot.sh name  -> name.png via QEMU monitor screendump
cd "$(dirname "$0")"; n=${1:-shot}
echo "screendump $PWD/$n.ppm" | socat - UNIX-CONNECT:mon.sock >/dev/null; sleep 2
convert $n.ppm $n.png && rm -f $n.ppm && echo $PWD/$n.png
