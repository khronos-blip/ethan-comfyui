#!/bin/bash
set -e

export PASSWORD=${PASSWORD:-runpod}
export PATH="/opt/venv/bin:$PATH"

# Setup extra_model_paths.yaml to point to /workspace/models (RunPod network volume)
cat << 'YAML' > /opt/ComfyUI/extra_model_paths.yaml
runpod_volume:
    base_path: /workspace/models
    checkpoints: checkpoints
    configs: configs
    loras: loras
    vae: vae
    clip: clip
    unet: unet
    controlnet: controlnet
    embeddings: embeddings
    hypernetworks: hypernetworks
    upscale_models: upscale_models
YAML

cd /opt/ComfyUI
python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header
