#!/usr/bin/env python3
"""Read Hyprland's local cursor IPC; no input-device permissions required.

Polls quickly and prints only when the pointer moves, so the overlay can
follow at the display rate instead of stepping at 60 Hz.
"""
import json, os, socket, time
path = f"{os.environ['XDG_RUNTIME_DIR']}/hypr/{os.environ['HYPRLAND_INSTANCE_SIGNATURE']}/.socket.sock"
last = None
while True:
    try:
        with socket.socket(socket.AF_UNIX) as s:
            s.settimeout(0.05)
            s.connect(path)
            s.sendall(b'j/cursorpos')
            data = b''
            while chunk := s.recv(4096):
                data += chunk
        pos = json.loads(data)
        point = (pos['x'], pos['y'])
        if point != last:
            print(json.dumps({'x': point[0], 'y': point[1]}), flush=True)
            last = point
        time.sleep(0.001)
    except (OSError, ValueError, KeyError):
        time.sleep(0.05)
