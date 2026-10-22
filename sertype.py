#!/usr/bin/env python3
# sertype.py "line" [wait] -- types a line on serial slowly, then Enter
import socket,sys,time
s=socket.socket(socket.AF_UNIX); s.connect('serial.sock')
for c in sys.argv[1]: s.send(c.encode()); time.sleep(0.05)
s.send(b'\r'); time.sleep(float(sys.argv[2]) if len(sys.argv)>2 else 3); s.close()
