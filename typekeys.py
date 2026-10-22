#!/usr/bin/env python3
# typekeys.py "text"  -- types via QEMU monitor sendkey; {ret} {down} {ctrl-x} etc. for special keys
import socket,sys,time,re
m={' ':'spc','-':'minus','=':'equal',',':'comma','.':'dot','/':'slash','_':'shift-minus',':':'shift-semicolon',';':'semicolon','\n':'ret'}
def keys(s):
    for t in re.findall(r'\{[^}]+\}|.',s,re.S):
        if t.startswith('{'): yield t[1:-1]
        elif t.isupper(): yield 'shift-'+t.lower()
        else: yield m.get(t,t)
s=socket.socket(socket.AF_UNIX); s.connect(sys.argv[2] if len(sys.argv)>2 else 'mon.sock')
for k in keys(sys.argv[1]):
    s.send(('sendkey %s\n'%k).encode()); time.sleep(0.08)
time.sleep(0.5); s.close()
