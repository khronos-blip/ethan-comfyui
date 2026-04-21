# RunPod Setup: Ethan-ComfyUI-GGUF

## Overview
Pre-built Docker image for Ethan Kalloway AI influencer generation pipeline. ComfyUI + GGUF + custom nodes pre-installed.

## Docker Image
```
ghcr.io/khronos-blip/ethan-comfyui:latest
```
- ComfyUI installed to `/opt/ComfyUI` (NOT /workspace to avoid RunPod volume shadowing)
- PyTorch with **CUDA 12.4** (NOT CPU-only — verified)
- Custom nodes: ComfyUI-GGUF (+ sentencepiece, protobuf), ComfyUI-Manager
- Auto-creates `extra_model_paths.yaml` pointing to `/workspace/models`
- CORS header enabled for API access
- Boot time: ~2-3 min (image cached in EU datacenters)

## Template
**Name:** Ethan-ComfyUI-GGUF (Private, Pod type, NVIDIA GPU)

**Settings:**
- Container Image: `ghcr.io/khronos-blip/ethan-comfyui:latest`
- Container Disk: 10GB (5GB is too tight for logs/temp files)
- Volume Mount Path: `/workspace`
- HTTP Port: 8188 (comfyui)
- Environment Variables: `PASSWORD=runpod`

## Creating a New Pod

1. **RunPod Dashboard → Pods → New Pod**
2. Select template: **Ethan-ComfyUI-GGUF**
3. **⚠️ CRITICAL: Attach Network Volume** — en la configuración del pod, buscar "Network Volume" o "Volumes" y seleccionar `ethan-4090`
4. Elegir GPU: RTX 4090 (EU datacenter preferred)
5. Create

Sin el volumen montado, /workspace estará vacío y ComfyUI no tendrá acceso a los modelos.

## Verifying Pod Health

### Via RunPod App
- HTTP Port 8188 → "Ready" = ComfyUI corriendo
- SSH disponible en Connect tab

### Via SSH
```bash
# Get SSH credentials from RunPod Connect tab
ssh USERNAME@ssh.runpod.io
```

### Via ComfyUI API
```bash
curl http://IP:8188
```
Si devuelve HTML, ComfyUI está listo. Acceder en navegador con:
- URL: `http://IP:8188`
- User: `root`
- Pass: `runpod`

## Verifying Volume Mount

```bash
ls /workspace/
# Debe mostrar: models/ (y otros archivos del volumen)
ls /workspace/models/
# Debe mostrar: checkpoints/ loras/ vae/ clip/ unet/
```

Si `/workspace/models` no existe → el volumen NO se montó. Recrear el pod y asegurarte de seleccionar el volumen al crear.

## Generating Images

Una vez el pod está corriendo y verificado:

1. SSH al pod
2. Subir imágenes de referencia a `/workspace/input/`
3. Ejecutar script de generación (ver recipes.md para prompts)
4. Descargar outputs desde `/workspace/output/`
5. **Parar el pod cuando termine** (RunPod app → Terminate)

## Modelos en ethan-4090

Carpeta `/workspace/models/` contiene:
- `checkpoints/` — Z-Image Turbo, Klein 9B GGUF
- `loras/` — Ethan LoRA v1/v6, anatomy LoRAs, etc.
- `vae/` — ae.safetensors
- `unet/` — (GGUF format)
- `upscale_models/` — 4x-UltraSharp

## Troubleshooting

### ComfyUI no carga aunque HTTP port dice "Ready"
1. Verificar volumen montado: `ls /workspace/models/`
2. Si vacío → volumen no se attachó. Recrear pod.
3. Esperar 2-3 min después de "Ready" — a veces tarda en inicializar

### SSH no conecta
- RunPod SSH requiere autenticación por clave pública/privada
- Usar Web Terminal si está habilitado (más fácil)
- Verificar que el pod esté en estado "Running"

### Docker image tarda mucho en descargar
- Primera vez: ~15-20 min (2.5GB)
- Siguientes veces: ~2 min (cacheado en datacenter)

## Costos
- RTX 4090 en EU-RO-1: ~$0.44/hr
- ethano-4090 volume (200GB): ~$14/mo
- Recommendation: crear pod solo cuando se necesite generar, parar cuando termine

> Note: Pods are ephemeral. Create, generate, terminate. Don't leave running idle.
