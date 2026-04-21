# syntax=docker/dockerfile:1
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install system deps
RUN apt-get update && apt-get install -y \
    python3.11 python3-pip python3.11-venv git curl wget htop nano \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender-dev sudo \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3

# Install Python 3.11 venv
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Upgrade pip
RUN pip install --upgrade pip

# Install ComfyUI
WORKDIR /workspace
RUN git clone https://github.com/comfyanonymous/ComfyUI.git ComfyUI_v0123_clean
WORKDIR /workspace/ComfyUI_v0123_clean
RUN git checkout v0.0.12.3

# Install all required packages
RUN pip install -r requirements.txt && \
    pip install sqlalchemy alembic aiohttp torchsde einops gguf \
    opencv-python-headless pydantic pillow safetensors transformers

# Copy custom nodes
RUN mkdir -p custom_nodes/ComfyUI-GGUF && \
    git clone https://github.com/city96/ComfyUI-GGUF.git custom_nodes/ComfyUI-GGUF

# Copy startup script
COPY start.sh /workspace/start.sh
RUN chmod +x /workspace/start.sh

EXPOSE 8188

ENV PASSWORD=runpod
CMD ["/workspace/start.sh"]