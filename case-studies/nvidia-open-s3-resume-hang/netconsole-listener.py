#!/usr/bin/env python3
# zel-netconsole receiver — runs on the NAS (rootless, high UDP port).
# Captures kernel log lines streamed by netconsole from the PC (<PC_LAN_IP>)
# during suspend/resume, so a resume HANG that never flushes to the PC's own
# disk is still recorded here over the wire.
import socket, time, os, sys

PORT = 6666
LOG = "/volume1/homes/<nas-user>/zel-netconsole.log"  # explicit absolute path (avoids ~ ambiguity over scp/ssh)

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("0.0.0.0", PORT))

f = open(LOG, "a", buffering=1)  # line-buffered: every line hits disk immediately
banner = "=== zel-netconsole listener up on :%d  %s ===" % (PORT, time.strftime("%Y-%m-%d %H:%M:%S"))
print(banner, flush=True)
f.write(banner + "\n")

while True:
    try:
        data, addr = s.recvfrom(65535)
    except KeyboardInterrupt:
        break
    ts = time.strftime("%H:%M:%S")
    msg = data.decode("utf-8", "replace").rstrip("\n")
    line = "%s %-15s | %s" % (ts, addr[0], msg)
    print(line, flush=True)
    f.write(line + "\n")
