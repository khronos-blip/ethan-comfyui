#!/bin/bash
set -e

export PASSWORD=${PASSWORD:-runpod}
export PATH="/opt/venv/bin:$PATH"

# Only write default yaml if missing or still the legacy runpod_volume default
# This allows runtime edits to persist across container restarts
if [ ! -s /opt/ComfyUI/extra_model_paths.yaml ] || grep -q '^runpod_volume:' /opt/ComfyUI/extra_model_paths.yaml; then
cat << 'YAML' > /opt/ComfyUI/extra_model_paths.yaml
# Ethan pipeline volume — points to existing ComfyUI_v0123_clean structure on ethan-4090 volume
ethan_volume:
    base_path: /workspace/ComfyUI_v0123_clean/models
    checkpoints: checkpoints
    configs: configs
    loras: loras
    vae: vae
    clip: text_encoders
    text_encoders: text_encoders
    unet: unet
    diffusion_models: unet
    controlnet: controlnet
    embeddings: embeddings
    hypernetworks: hypernetworks
    upscale_models: upscale_models

# Fallback: plain /workspace/models layout (used if ethan-4090 volume not mounted)
runpod_volume:
    base_path: /workspace/models
    checkpoints: checkpoints
    configs: configs
    loras: loras
    vae: vae
    clip: clip
    text_encoders: text_encoders
    unet: unet
    diffusion_models: unet
    controlnet: controlnet
    embeddings: embeddings
    hypernetworks: hypernetworks
    upscale_models: upscale_models
YAML
fi

cd /opt/ComfyUI
exec python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header
