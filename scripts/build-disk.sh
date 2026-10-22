#!/bin/bash
# Build kylin.qcow2 from the ISO: boot live session, log in over serial, run guest/install.sh.
# Requires: qemu-system-loongarch64, socat, python3, ISO (scripts/fetch-iso.sh). Takes ~1 h under TCG.
#   VM_PASSWORD  required; password for kylin/root in the installed system
set -e
cd "$(dirname "$0")/.."
PW=${VM_PASSWORD:?set VM_PASSWORD before running}
[ -e kylin.qcow2 ] && { echo "kylin.qcow2 exists; remove it first"; exit 1; }
qemu-img create -f qcow2 kylin.qcow2 64G
( cd guest && setsid nohup python3 -m http.server 8000 >/dev/null 2>&1 & echo $! > ../.http.pid )
./boot_cmd.sh
echo "waiting for live login prompt..."
for i in $(seq 400); do grep -aq 'kylin login:' serial.log && break; sleep 5; done
sleep 30
./sertype.py kylin 20        # live user kylin has no password
./sertype.py "curl -s http://10.0.2.2:8000/install.sh -o /tmp/i.sh && sudo VM_PASSWORD='$PW' setsid bash /tmp/i.sh > /tmp/inst.log 2>&1 &" 5
echo "install running in guest; polling..."
for i in $(seq 720); do
  ./sertype.py 'tail -1 /tmp/inst.log' 5
  tail -c 300 serial.log | grep -aq 'INSTALL_DONE' && break
  sleep 25
done
./sertype.py 'sudo poweroff' 60
echo quit | socat - UNIX-CONNECT:mon.sock >/dev/null 2>&1 || true
kill $(cat .http.pid) 2>/dev/null; rm -f .http.pid
echo "done: ./run.sh"
