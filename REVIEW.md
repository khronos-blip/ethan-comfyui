# Code Review: ethan-comfyui Docker Image

**Reviewed:** 2026-04-21
**Reviewer:** Khronos (automated)
**Status:** 3 CRITICAL issues found, all fixed

---

## 🔴 CRITICAL Issues

### 1. Python 3.11 not available on Ubuntu 22.04 base image
`apt-get install python3.11` will **FAIL** — Ubuntu 22.04 ships Python 3.10 only. Python 3.11 requires the `deadsnakes` PPA.

**Fix:** Add `software-properties-common` + `deadsnakes/ppa` before installing python3.11.

### 2. PyTorch will install CPU-only (no CUDA)
`pip install -r requirements.txt` installs `torch` from PyPI default, which is **CPU-only**. The base CUDA image doesn't auto-magically make pip pick CUDA wheels.

ComfyUI's `requirements.txt` lists `torch torchvision torchaudio` without any `--index-url`, so it will grab the CPU builds. On a 4090, this means **all generation will use CPU instead of GPU**.

**Fix:** Install torch with `--index-url https://download.pytorch.org/whl/cu124` BEFORE `requirements.txt`, then skip torch in requirements to avoid downgrade.

### 3. Custom node dependencies not installed
ComfyUI-GGUF and ComfyUI-Manager are git cloned but their `requirements.txt` files are never installed. ComfyUI-GGUF needs `sentencepiece` and `protobuf` (gguf itself is manually installed, good). ComfyUI-Manager has its own deps too.

**Fix:** Add `pip install -r custom_nodes/ComfyUI-GGUF/requirements.txt` and same for Manager.

---

## 🟡 HIGH Issues

### 4. `python3` symlink override breaks system tools
`ln -sf /usr/bin/python3.11 /usr/bin/python3` overrides the system Python. Ubuntu system tools (`apt`, `cloud-init`, etc.) depend on Python 3.10. This can cause bizarre failures.

**Fix:** Remove the symlink. Use the venv's python3 directly (venv is already created with python3.11, so `/opt/venv/bin/python3` IS 3.11).

### 5. Missing `build-essential`
Some pip packages compile C extensions. Without `gcc`/`make`, they either fail or pull in pre-built wheels that may not be optimized.

**Fix:** Add `build-essential` to apt install.

---

## 🟢 MEDIUM Issues

### 6. No `.dockerignore`
The `.git/` directory (thousands of objects) gets sent to the Docker daemon as build context. Slows builds unnecessarily.

**Fix:** Added `.dockerignore`.

### 7. Unnecessary packages
`sudo`, `nano`, `htop` add ~30MB to the image. Not harmful but not needed in a headless container.

**Fix:** Removed `sudo` (already root). Kept `nano` and `htop` for SSH debugging convenience — they're small and useful.

### 8. Layer optimization: git clone + pip in single layer
Cloning ComfyUI and installing all pip packages in one `RUN` means any change to the install list re-downloads everything.

**Fix:** Split into logical layers (system deps → clone → torch CUDA → requirements → custom nodes). Each layer caches independently.

### 9. ComfyUI-Manager missing requirements
Similar to #3, Manager's requirements should be explicitly installed.

**Fix:** Added `pip install -r custom_nodes/ComfyUI-Manager/requirements.txt`.

---

## 📋 File-by-File Review

### Dockerfile — Fixed ✅
- Added deadsnakes PPA for Python 3.11
- Install torch with cu124 index URL first, then install requirements with `--no-deps` for torch* to prevent CPU downgrade
- Install custom node requirements
- Split into cache-friendly layers
- Added build-essential
- Removed python3 symlink override
- Set `PYTHON` env to the venv python3 for clarity

### start.sh — Minor fix ✅
- Added `--enable-cors-header` for API access (needed by external API callers)
- extra_model_paths.yaml looks correct: maps `/workspace/models` with proper subdirectories
- `--listen 0.0.0.0 --port 8188` is correct for Docker/RunPod
- PASSWORD env var with fallback is good

### .github/workflows/docker.yml — OK ✅
- Triggers: push to main + manual dispatch ✓
- Permissions: `packages:write` for GHCR ✓
- Auth: `GITHUB_TOKEN` with GHCR ✓
- Tags: latest + SHA ✓
- Cache: GHA cache with mode=max ✓
- Platform: linux/amd64 only ✓ (correct for NVIDIA containers)
- No changes needed

### RUNPOD_SETUP.md — Minor updates ✅
- Updated image description to reflect fixes
- Added note about CORS header for API access
- Noted that torch now correctly targets CUDA 12.4
- Removed stale pod reference

---

## Summary

| Severity | Count | Status |
|----------|-------|--------|
| 🔴 Critical | 3 | All fixed |
| 🟡 High | 2 | All fixed |
| 🟢 Medium | 4 | All fixed |
| Total | 9 | **All resolved** |

The most impactful fix is #2 (torch CPU-only) — without it, the entire pipeline would fall back to CPU on the 4090, making the container completely useless for generation. Fix #1 (Python 3.11) would cause the build to fail entirely.

---

## Testing Recommendations

After pushing the fixed Dockerfile:

1. **Build test:** `docker buildx build --platform linux/amd64 -t test .` — should complete without errors
2. **Torch verification:** Run container, exec `python3 -c "import torch; print(torch.cuda.is_available())"` — must print `True`
3. **ComfyUI startup:** Verify ComfyUI starts without import errors
4. **GGUF node:** Verify ComfyUI-GGUF appears in loaded custom nodes
5. **Model path:** Verify `extra_model_paths.yaml` loads (check ComfyUI logs for "runpod_volume" search path)
6. **End-to-end:** Submit a simple generation via API to `/workspace/output/`
