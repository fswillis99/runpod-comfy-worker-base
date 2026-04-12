# runpod-comfy-worker-base

Custom ComfyUI Docker worker for RunPod serverless, based on [worker-comfyui](https://github.com/runpod-workers/worker-comfyui). Models are baked into the image at build time.

## Supported Workflows

| Workflow | Type | Model |
|---|---|---|
| Flux Dev | Text-to-image | `flux1-dev-fp8.safetensors` |
| Qwen-Image 2512 | Text-to-image | `qwen_image_2512_fp8_e4m3fn.safetensors` |
| Qwen-Image 2511 | Image edit | `qwen_image_edit_2511_bf16.safetensors` |

Qwen workflows run in turbo mode (Lightning LoRA, 6 steps).

## Repository Structure

```
Dockerfile              # Minimal — pulls pre-built image from Docker Hub (used by RunPod)
Dockerfile.dockerhub    # Full multi-stage build with all model downloads (built by Cloud Build)
cloudbuild.yaml         # Google Cloud Build — builds and pushes to Docker Hub
cloudbuild.ar.yaml      # Google Cloud Build — builds and pushes to Artifact Registry (reference)
handler.py              # RunPod job handler (WebSocket-based ComfyUI execution)
src/
  start.sh              # Container entrypoint — starts ComfyUI then the handler
  extra_model_paths.yaml
scripts/
  setup-cloudbuild.sh   # One-time GCP setup (run as project owner)
```

## Building

Builds are handled by Google Cloud Build. After running the one-time setup:

```bash
# One-time setup (run as GCP project owner)
bash scripts/setup-cloudbuild.sh

# Submit a build
gcloud builds submit \
  --project=project-b882ddad-b8b1-4a5c-908 \
  --config=cloudbuild.yaml \
  .
```

The build uses a 300 GB disk and pushes the final image to Docker Hub as `fswillis99/runpod-comfy-worker:latest`.

## RunPod Deployment

1. Create a **Serverless Endpoint** in the RunPod console
2. Set the Docker image to `fswillis99/runpod-comfy-worker:latest`
3. Set container disk to at least 40 GB
4. No environment variables required

## Environment

- Base: `nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04`
- Python: 3.12 via comfy-cli
- ComfyUI: latest
