# 🚀 Ethan ComfyUI Docker — Guía de Despliegue Completa

**Última actualización:** 2026-04-21
**Imagen Docker:** `ghcr.io/khronos-blip/ethan-comfyui:latest`
**Repo:** https://github.com/khronos-blip/ethan-comfyui

> Esta guía cubre todo: desde crear el template en RunPod hasta generar la primera imagen.
> Cualquier LLM (Opus, GLM, Khronos) puede seguirla paso a paso.

---

## 📋 Resumen del Flujo Docker

**Antes (sin Docker):**
1. Crear pod con template genérico (~10s boot)
2. Instalar dependencias manualmente (~15-30 min)
3. Clonar ComfyUI + custom nodes + pip install
4. Configurar `extra_model_paths.yaml` a mano
5. Cruzar dedos para que no haya conflictos
6. **Total: 30-45 min antes de primera imagen**

**Ahora (con Docker):**
1. Crear pod con template Docker (~2 min boot)
2. ComfyUI + dependencias + custom nodes YA instalados
3. `extra_model_paths.yaml` auto-generado en `start.sh`
4. Solo montar volumen con modelos
5. **Total: 2-3 min antes de primera imagen**

---

## 🔧 Paso 1 — Verificar GitHub Actions Build

```bash
cd ~/Docker/ethan-comfyui
gh run list --limit 3
```

Esperar a ver:
```
completed  success  ...  Build and Push Docker Image  main  push  <run_id>
```

Si el último run es `success`, la imagen está en:
```
ghcr.io/khronos-blip/ethan-comfyui:latest
```

**Si falló:** revisar logs con `gh run view <run_id> --log-failed`, arreglar, push de nuevo.

---

## 🔧 Paso 2 — Crear/Actualizar Template en RunPod

### Si el template NO existe:

1. Ir a **RunPod → Templates → New Template**
2. Configurar:
   - **Name:** `Ethan-ComfyUI-GGUF`
   - **Type:** Pod (NO Serverless)
   - **Container Image:** `ghcr.io/khronos-blip/ethan-comfyui:latest`
   - **Container Disk:** 10 GB
   - **Expose HTTP Ports:** `8188` (alias: comfyui)
   - **Environment Variables:** `PASSWORD=runpod`
   - **Start SSH:** ✅ habilitado
   - **Visibility:** Private
3. Click **Save**

### Si el template YA existe:

1. Ir a **RunPod → Templates → Ethan-ComfyUI-GGUF**
2. Cambiar **Container Image** a `ghcr.io/khronos-blip/ethan-comfyui:latest`
3. Click **Save**

---

## 🔧 Paso 3 — Crear Pod con Template

1. **RunPod → Pods → Deploy**
2. Seleccionar template: **Ethan-ComfyUI-GGUF**
3. **⚠️ CRÍTICO — Montar volumen:**
   - Buscar "Network Volume" o "Storage"
   - Seleccionar volumen: **`ethan-4090`** (200GB, EU-RO-1)
   - Mount path: `/workspace`
4. **GPU:** RTX 4090
5. **Datacenter:** EU-RO-1 (preferido, mismo datacenter del volumen)
6. Click **Deploy**

### Alternativa via CLI:

```bash
# Si runpodctl está configurado:
runpodctl deploy pod \
  --templateId <TEMPLATE_ID> \
  --networkVolumeId kk2vn1f4ly \
  --gpuType "NVIDIA RTX 4090" \
  --dataCenter EU-RO-1
```

### Alternativa via API:

```python
import requests, json, os

API_KEY = os.environ['RUNPOD_API_KEY']
QUERY = """
mutation CreatePod($input: PodCreateInput!) {
  podFindAndDeployOnDemand(input: $input) {
    id desiredStatus runtime { ports { ip publicPort } }
  }
}
"""

variables = {
  "input": {
    "name": "ethan-gen",
    "imageName": "ghcr.io/khronos-blip/ethan-comfyui:latest",
    "gpuCount": 1,
    "cloudType": "ALL",
    "networkVolumeId": "kk2vn1f4ly",  # ethan-4090
    "containerDiskInGb": 10,
    "minMemoryInGb": 15,
    "gpuTypeId": "NVIDIA RTX 4090",
    "ports": "8188/http",
    "env": ["PASSWORD=runpod"],
    "startSsh": True
  }
}

resp = requests.post(
  "https://api.runpod.io/graphql",
  params={"api_key": API_KEY},
  json={"query": QUERY, "variables": variables}
)
pod = resp.json()['data']['podFindAndDeployOnDemand']
print(f"Pod ID: {pod['id']}")
```

---

## 🔧 Paso 4 — Verificar Pod

Esperar ~2-3 minutos (primera vez: 15-20 min si la imagen no está cacheada en el datacenter).

### 4a — Verificar que ComfyUI arrancó:

```bash
# Desde RunPod dashboard → Pods → tu pod → HTTP Port 8188
# O via SSH:
ssh -p <PORT> root@<IP> 'curl -s -m 5 http://127.0.0.1:8188/system_stats | python3 -c "import json,sys; d=json.load(sys.stdin); print(f\"ComfyUI v{d[\"system\"][\"comfyui_version\"]} — RAM: {d[\"devices\"][0][\"vram_total\"]/1e9:.1f}GB VRAM\")"'
```

Esperado: `ComfyUI v0.x.x — RAM: 24.0GB VRAM`

### 4b — Verificar volumen montado:

```bash
ssh -p <PORT> root@<IP> 'ls /workspace/models/ 2>/dev/null && echo "✅ Volumen OK" || echo "❌ SIN VOLUMEN"'
```

Esperado:
```
checkpoints  clip  configs  controlnet  embeddings  hypernetworks  loras  upscale_models  unet  vae
✅ Volumen OK
```

**Si dice `❌ SIN VOLUMEN`:** El volumen no se montó. Terminar pod y recrearlo asegurando seleccionar `ethan-4090`.

### 4c — Verificar modelos accesibles:

```bash
ssh -p <PORT> root@<IP> 'echo "=== UNET ==="; ls /workspace/models/unet/*.gguf 2>/dev/null; echo "=== LORAS ==="; ls /workspace/models/loras/*.safetensors 2>/dev/null; echo "=== VAE ==="; ls /workspace/models/vae/*.safetensors 2>/dev/null'
```

Esperado:
```
=== UNET ===
/workspace/models/unet/z_image_turbo-Q4_K_M.gguf
/workspace/models/unet/flux-2-klein-9b-Q6_K.gguf
=== LORAS ===
/workspace/models/loras/ethan_kalloway_v1.safetensors
/workspace/models/loras/ethan_kalloway_klein9b_v6.safetensors
=== VAE ===
/workspace/models/vae/ae.safetensors
/workspace/models/vae/flux2-vae.safetensors
```

---

## 🔧 Paso 5 — Primera Generación de Test

### 5a — Subir script de generación al pod:

```bash
scp -P <PORT> /path/to/gen_sfw_gguf.py root@<IP>:/tmp/gen_sfw_gguf.py
```

O crear directamente via SSH:

```bash
ssh -p <PORT> root@<IP> 'cat > /tmp/gen_sfw_gguf.py << "PYEOF"
#!/usr/bin/env python3
import json, urllib.request, time, uuid, sys, random
COMFY = "http://127.0.0.1:8188"
PROMPT = sys.argv[1] if len(sys.argv) > 1 else "test"

wf = {
  "1": {"class_type": "UnetLoaderGGUF", "inputs": {"unet_name": "z_image_turbo-Q4_K_M.gguf"}},
  "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_3_4b.safetensors", "type": "qwen_image"}},
  "3": {"class_type": "VAELoader", "inputs": {"vae_name": "ae.safetensors"}},
  "4": {"class_type": "LoraLoader", "inputs": {
    "model": ["1", 0], "clip": ["2", 0],
    "lora_name": "ethan_kalloway_v1.safetensors",
    "strength_model": 0.95, "strength_clip": 0.95}},
  "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["4", 1], "text": PROMPT}},
  "5n": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["4", 1], "text": ""}},
  "6": {"class_type": "EmptyLatentImage", "inputs": {"width": 1088, "height": 1600, "batch_size": 1}},
  "7": {"class_type": "KSampler", "inputs": {
    "model": ["4", 0], "positive": ["5", 0], "negative": ["5n", 0],
    "latent_image": ["6", 0],
    "seed": random.randint(1, 2**32-1), "steps": 8, "cfg": 1.0,
    "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0}},
  "8": {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["3", 0]}},
  "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "sfw_test"}}
}

data = json.dumps({"prompt": wf, "client_id": str(uuid.uuid4())}).encode()
resp = json.loads(urllib.request.urlopen(
  urllib.request.Request(COMFY+"/prompt", data=data, headers={"Content-Type":"application/json"}),
  timeout=30).read())
pid = resp.get("prompt_id")
print("Queued:", pid)
for i in range(120):
    time.sleep(2)
    h = json.loads(urllib.request.urlopen(COMFY+"/history/"+pid, timeout=10).read())
    if pid in h:
        s = h[pid].get("status", {})
        if s.get("completed"):
            for nid, out in h[pid].get("outputs", {}).items():
                for img in out.get("images", []):
                    print("IMG:", img.get("filename"), "| DONE", i*2, "s")
            sys.exit(0)
        if s.get("status_str") == "error":
            print("ERROR:", json.dumps(s)[:1500]); sys.exit(1)
PYEOF'
```

### 5b — Generar test:

```bash
ssh -p <PORT> root@<IP> 'python3 /tmp/gen_sfw_gguf.py "EthanKal01, photorealistic portrait of a 29 year old athletic man with short wavy copper-red hair, freckles, hazel-green eyes, wearing a black t-shirt, studio lighting, shot on Sony A7R IV"'
```

Esperado:
```
Queued: <uuid>
IMG: sfw_test_00001_.png | DONE 50 s
```

### 5c — Descargar y verificar:

```bash
scp -P <PORT> root@<IP>:/opt/ComfyUI/output/sfw_test_*.png /tmp/ethan_test.png
file /tmp/ethan_test.png
# Debe decir: PNG image data, 1088 x 1600, ...
```

⚠️ Si la imagen es negra (0 bytes o <1KB) → ver Troubleshooting abajo.

---

## 🎬 Paso 6 — Generación de Pack Completo

Una vez verificado que el pod funciona, seguir el **PROTOCOLO DE GENERACIÓN DE PACK DIARIO** en:
```
~/.openclaw/workspace/memory/ethan-pod-bootstrap-guide.md
```

El flujo es idéntico, pero los paths de ComfyUI cambian:
- **Antes:** `/workspace/ComfyUI_clean_v0123/`
- **Ahora (Docker):** `/opt/ComfyUI/`

⚠️ Los outputs ahora van a `/opt/ComfyUI/output/` (no `/workspace/`).

---

## 🛑 Detener el Pod

```bash
# STOP (conserva volumen, solo cobra storage)
runpodctl stop pod <POD_ID>

# TERMINATE (elimina pod, volumen sigue intacto)
runpodctl remove pod <POD_ID>
```

⚠️ **NUNCA dejar un 4090 corriendo sin usar** — $0.44/hr = $10.56/día idle.

---

## 🩹 Troubleshooting

### "Imagen sale 100% negra"
- **Causa:** Estás usando `z-image-turbo-fp32.safetensors` + `ZSamplerTurbo`.
- **Fix:** Usar `z_image_turbo-Q4_K_M.gguf` con `UnetLoaderGGUF` + `KSampler` euler/simple.
- ❌ NO upgradear torch, NO flags especiales.

### "ComfyUI no arranca (connection refused tras 3 min)"
```bash
# Ver log:
ssh -p <PORT> root@<IP> 'cat /opt/ComfyUI/comfyui.log 2>/dev/null || journalctl -u comfyui --no-pager -n 30'
```
- Si falta un paquete: `ssh ... 'pip install <paquete>'`
- Reiniciar: `ssh ... 'pkill python3; cd /opt/ComfyUI && nohup python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header > /tmp/comfyui.log 2>&1 &'`

### "Volumen vacío (/workspace/models no existe)"
- El volumen no se montó. Terminar pod y recrearlo asegurando `ethan-4090` seleccionado.

### "Docker image tarda mucho (~20 min primera vez)"
- Normal. La imagen es ~2.5GB. Siguientes veces: ~2 min (cacheado en datacenter).

### "Custom node not found: UnetLoaderGGUF"
- Verificar: `ssh ... 'ls /opt/ComfyUI/custom_nodes/ComfyUI-GGUF/'`
- Si no existe: `ssh ... 'cd /opt/ComfyUI/custom_nodes && git clone https://github.com/city96/ComfyUI-GGUF && pip install -r ComfyUI-GGUF/requirements.txt'`

---

## 💰 Costos

| Concepto | Costo |
|---|---|
| RTX 4090 EU-RO-1 | $0.44/hr |
| Volumen ethan-4090 (200GB) | ~$14/mes |
| Build GitHub Actions | Gratis (GitHub minutes) |
| Container Registry (GHCR) | Gratis (<1GB público) |
| Pack 25 imgs completo | ~$0.15 |
| Primera imagen (cold start) | ~$0.007 |

---

## 📦 Diferencias Docker vs Template Antiguo

| Aspecto | Template antiguo (`runpod-torch-v240`) | Docker image |
|---|---|---|
| Boot time | ~10s | ~2 min (primera vez: 15-20 min) |
| Setup manual | 15-30 min pip installs | 0 min (todo pre-instalado) |
| ComfyUI location | `/workspace/ComfyUI_clean_v0123/` | `/opt/ComfyUI/` |
| Output path | `/workspace/ComfyUI_clean_v0123/output/` | `/opt/ComfyUI/output/` |
| Modelos | En volumen (`/workspace/models/`) | Mismo (volumen) |
| torch version | 2.4.1+cu124 (pre-instalado) | CUDA 12.4 (pre-instalado con CUDA) |
| Python | 3.11 (del template) | 3.11 (deadsnakes PPA) |
| Custom nodes | Manual | Pre-instalados (GGUF + Manager) |
| Reproducible | ❌ Cada pod puede variar | ✅ Docker garantiza consistencia |

---

## 🔄 Actualizar la Imagen Docker

Si necesitas cambiar algo (añadir custom nodes, paquetes, etc.):

```bash
cd ~/Docker/ethan-comfyui

# 1. Editar Dockerfile
vim Dockerfile

# 2. Commit y push
git add -A
git commit -m "Fix: descripción del cambio"
git push

# 3. GitHub Actions auto-build (~20 min)
gh run list --limit 3  # verificar que completó

# 4. Crear nuevo pod con la nueva imagen (o re-deploy)
```

No necesitas tocar el template — siempre apunta a `:latest`.

---

## ✅ Checklist Pre-Generación

Antes de lanzar un pack, verificar:

- [ ] GitHub Actions build: `completed success`
- [ ] Template RunPod: apunta a `ghcr.io/khronos-blip/ethan-comfyui:latest`
- [ ] Pod creado con volumen `ethan-4090` montado en `/workspace`
- [ ] ComfyUI responde en puerto 8188
- [ ] Modelos accesibles en `/workspace/models/`
- [ ] Primera imagen de test sale bien (no negra, >1MB)
- [ ] `generation-queue.md` actualizado con 25 prompts del día
