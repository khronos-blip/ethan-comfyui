# syntax=docker/dockerfile:1
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Layer 1: System deps + Python 3.11 (deadsnakes PPA required on Ubuntu 22.04)
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.11 python3.11-dev python3.11-venv python3-pip \
    git curl wget htop nano \
    build-essential \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

# Layer 2: Python venv with 3.11
RUN python3.11 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHON="/opt/venv/bin/python3"

# Layer 3: Upgrade pip (caches independently)
RUN pip install --upgrade pip

# Layer 4: Clone ComfyUI
WORKDIR /opt
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git ComfyUI

WORKDIR /opt/ComfyUI

# Layer 5: Install torch with CUDA 12.4 FIRST (before requirements.txt to avoid CPU downgrade)
RUN pip install --no-cache-dir \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu124

# Layer 6: Install ComfyUI requirements (skip torch* to preserve CUDA version)
RUN pip install --no-cache-dir $(grep -v '^\s*#' requirements.txt | grep -v '^torch' | grep -v '^$' | xargs)

# Layer 7: Additional Python deps (gguf, etc.)
RUN pip install --no-cache-dir \
    sqlalchemy alembic aiohttp torchsde einops gguf \
    opencv-python-headless pydantic pillow safetensors transformers \
    sentencepiece protobuf

# Layer 8: Custom nodes — ComfyUI-GGUF
RUN git clone --depth 1 https://github.com/city96/ComfyUI-GGUF.git custom_nodes/ComfyUI-GGUF
RUN pip install --no-cache-dir -r custom_nodes/ComfyUI-GGUF/requirements.txt

# Layer 9: Custom nodes — ComfyUI-Manager
RUN git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager
RUN pip install --no-cache-dir -r custom_nodes/ComfyUI-Manager/requirements.txt 2>/dev/null || true

# Layer 10: Startup script
COPY start.sh /opt/start.sh
RUN chmod +x /opt/start.sh

EXPOSE 8188

ENV PASSWORD=runpod
CMD ["/opt/start.sh"]
