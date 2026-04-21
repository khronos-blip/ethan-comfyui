#!/bin/bash
cd /workspace/ComfyUI_v0123_clean
export PASSWORD=${PASSWORD:-runpod}
export PATH="/opt/venv/bin:$PATH"
python3 main.py --listen 0.0.0.0 --port 8188