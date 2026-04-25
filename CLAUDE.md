# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a RunPod serverless worker that runs ComfyUI for image generation. Models are baked into the Docker image at build time. The worker receives ComfyUI API-format workflow payloads, executes them, and returns generated images as base64 strings or S3 URLs.

## Build

Builds run on Google Cloud Build — there is no local build command for the full image. To trigger a build:

```bash
gcloud builds submit \
  --project=project-b882ddad-b8b1-4a5c-908 \
  --config=cloudbuild.yaml \
  .
```

The build uses a 300 GB disk and pushes to `fswillis99/runpod-comfy-worker:latest` (and a datetime tag). Timeout is 6 hours.

## Local Testing

Use `test_input.json` as a sample job payload. The handler can be invoked directly:

```bash
python handler.py
```

Set `SERVE_API_LOCALLY=true` to expose the RunPod handler REST API on `0.0.0.0` (useful for local HTTP testing without a RunPod account).

## Architecture

### Two Dockerfiles

- **`Dockerfile`** — one line: `FROM fswillis99/runpod-comfy-worker:latest`. This is what RunPod pulls; it just references the pre-built image.
- **`Dockerfile.dockerhub`** — the actual multi-stage build used by Cloud Build:
  - **`base` stage**: installs ComfyUI via `comfy-cli` into `/comfyui`, installs handler runtime deps (`runpod`, `requests`, `websocket-client`), copies `handler.py`, `start.sh`, `network_volume.py`
  - **`downloader` stage**: downloads all models from HuggingFace and a private S3 bucket into `/comfyui/models/`
  - **`final` stage**: `base` + copies models from `downloader`

### Request/Response Flow

1. `src/start.sh` starts ComfyUI (`/comfyui/main.py`) in the background, writes its PID to `/tmp/comfyui.pid`, then launches `handler.py`
2. `handler.py` receives a RunPod job, validates input, waits for ComfyUI HTTP at `127.0.0.1:8188` to be ready
3. Uploads any input images via `POST /upload/image`
4. Queues the workflow via `POST /prompt`, then listens on a WebSocket (`/ws?clientId=...`) for execution events
5. On completion, fetches output images via `GET /view`, returns them as `base64` strings (or uploads to S3 if `BUCKET_ENDPOINT_URL` is set)

### Job Input Format

```json
{
  "input": {
    "workflow": { /* ComfyUI API-format node graph */ },
    "images": [{ "name": "input.png", "image": "data:image/png;base64,..." }],
    "comfy_org_api_key": "optional"
  }
}
```

### Key Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `COMFY_LOG_LEVEL` | `DEBUG` | ComfyUI log verbosity |
| `REFRESH_WORKER` | `false` | Restart worker container after each job |
| `SERVE_API_LOCALLY` | — | Expose RunPod handler API on 0.0.0.0 |
| `BUCKET_ENDPOINT_URL` | — | S3 endpoint; if set, outputs upload to S3 instead of base64 |
| `COMFY_ORG_API_KEY` | — | Comfy.org API key (can also be passed per-request) |
| `NETWORK_VOLUME_DEBUG` | `false` | Print diagnostics about `/runpod-volume` model paths |
| `WEBSOCKET_RECONNECT_ATTEMPTS` | `5` | Reconnect attempts if WS drops mid-job |
| `WEBSOCKET_TRACE` | `false` | Low-level websocket frame logging |

### Supported Models (baked into image)

| Workflow | File | Location |
|---|---|---|
| Flux Dev | `flux1-dev-fp8.safetensors` | `models/checkpoints/` |
| Qwen-Image 2512 | `qwen_image_2512_fp8_e4m3fn.safetensors` | `models/diffusion_models/` |
| Qwen-Image 2511 | `qwen_image_edit_2511_bf16.safetensors` | `models/diffusion_models/` |

Qwen workflows use shared VAE (`qwen_image_vae.safetensors`), text encoder (`qwen_2.5_vl_7b_fp8_scaled.safetensors`), Lightning LoRAs, and four custom LoRAs from `comfy-kappa-files-001.s3.us-east-1.amazonaws.com`.

### ComfyUI Python Path

`comfy-cli` may install ComfyUI into its own venv (`/comfyui/venv`) rather than the system venv. The actual Python path is discovered at build time and written to `/comfy_python.txt`. `start.sh` reads this file to launch ComfyUI with the correct interpreter.
