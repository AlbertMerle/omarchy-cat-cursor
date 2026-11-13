#!/usr/bin/env python3
"""Remap the click-through overlay after another overlay is opened."""
import socket, os, json
path=f"{os.environ['XDG_RUNTIME_DIR']}/hypr/{os.environ['HYPRLAND_INSTANCE_SIGNATURE']}/.socket2.sock"
with socket.socket(socket.AF_UNIX) as s:
    s.connect(path)
    with s.makefile() as events:
        for event in events:
            if event.startswith('openlayer>>') and 'cat-cursor' not in event:
                print('raise', flush=True)
