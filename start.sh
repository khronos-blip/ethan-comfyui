#!/bin/bash
set -e

echo "========================================"
echo "Ethan ComfyUI Docker — Start"
echo "Date: $(date)"
echo "========================================"

export PASSWORD=${PASSWORD:-runpod}
export PATH="/opt/venv/bin:$PATH"

# Print diagnostics
echo "[INFO] Python: $(python3 --version)"
echo "[INFO] Python path: $(which python3)"
echo "[INFO] Working dir: $(pwd)"
echo "[INFO] ComfyUI dir exists: $(test -d /opt/ComfyUI && echo yes || echo no)"
echo "[INFO] Volume mount status:"
ls -la /workspace 2>/dev/null | head -5 || echo "[WARN] /workspace not accessible"

# Only write default yaml if missing or still the legacy runpod_volume default
if [ ! -s /opt/ComfyUI/extra_model_paths.yaml ] || grep -q '^runpod_volume:' /opt/ComfyUI/extra_model_paths.yaml; then
    echo "[INFO] Writing extra_model_paths.yaml"
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
else
    echo "[INFO] Preserving existing extra_model_paths.yaml"
fi

echo "[INFO] Checking GPU availability..."
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo "[WARN] nvidia-smi not available"

echo "========================================"
echo "[INFO] Starting ComfyUI on 0.0.0.0:8188"
echo "========================================"

cd /opt/ComfyUI
exec python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header
