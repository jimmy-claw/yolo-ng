#!/bin/bash
# Manual persistence test - run on a machine with LogosApp installed
# 1. Install the lgx: make install-lgx LGPM=... 
# 2. Launch LogosApp
# 3. Open yolo-ng, create a board (name + secret)
# 4. Quit LogosApp
# 5. Relaunch LogosApp
# 6. Open yolo-ng - board should be restored automatically
#
# KV data stored at: ~/.local/share/Logos/LogosApp/kv-data/yolo_ng/store.json
echo 'KV data:'
cat ~/.local/share/Logos/LogosApp/kv-data/yolo_ng/store.json 2>/dev/null | python3 -m json.tool || echo 'not found'
