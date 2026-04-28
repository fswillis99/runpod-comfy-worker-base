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
handler.py              # RunPod job handler (WebSocket-based ComfyUI execution)
src/
  start.sh              # Container entrypoint — starts ComfyUI then the handler
  extra_model_paths.yaml
scripts/
  setup-cloudbuild.sh   # One-time GCP setup (run as project owner)
model-base/
  Dockerfile            # Downloads all models into /models-cache (rebuilt rarely)
  cloudbuild.yaml       # Cloud Build config — pushes to Artifact Registry
  models.txt            # Inventory of baked-in model files with verified sizes
comfy-worker/
  Dockerfile            # FROM model-base; installs ComfyUI + handler runtime on top
  cloudbuild.yaml       # Cloud Build config — pushes to Artifact Registry
docker-publish/
  cloudbuild.yaml       # Copies image from Artifact Registry to Docker Hub via crane
```

## Local Development

### Artifact Registry credentials for crane

`crane` uses the Docker credential helper chain. To authenticate against Artifact Registry, run once after activating a GCP service account:

```bash
gcloud auth configure-docker us-central1-docker.pkg.dev
```

This writes the credential helper entry to `~/.docker/config.json`. Subsequent `crane` commands against `us-central1-docker.pkg.dev` will use whatever `gcloud` account is active.

## Building

### Worker image (RunPod)

Builds are handled by Google Cloud Build. After running the one-time setup:

```bash
# One-time setup (run as GCP project owner)
bash scripts/setup-cloudbuild.sh

# Build and push to Artifact Registry
gcloud builds submit \
  --project=project-b882ddad-b8b1-4a5c-908 \
  --config=comfy-worker/cloudbuild.yaml \
  .
```

The build uses a 500 GB disk, pulls models from the pre-built `model-base` image (no re-download), and pushes to Artifact Registry as `runpod/comfy-worker:latest`.

### Publishing to Docker Hub

After the worker build completes, copy it to Docker Hub using `crane` (no layer re-download):

```bash
gcloud builds submit \
  --project=project-b882ddad-b8b1-4a5c-908 \
  --config=docker-publish/cloudbuild.yaml \
  --no-source
```

This pushes `fswillis99/runpod-comfy-worker:latest`.

### Model-base image

The model-base image contains only the baked-in model files. It is built separately and infrequently — only when models are added or updated. The build caches from the previous model-base image in Artifact Registry so unchanged model layers are not re-downloaded or re-pushed.

```bash
gcloud builds submit \
  --project=project-b882ddad-b8b1-4a5c-908 \
  --config=model-base/cloudbuild.yaml \
  model-base/
```

The build uses a 500 GB disk and pushes to Artifact Registry as:
- `us-central1-docker.pkg.dev/project-b882ddad-b8b1-4a5c-908/runpod/model-base:latest`
- `us-central1-docker.pkg.dev/project-b882ddad-b8b1-4a5c-908/runpod/model-base:YYYYMMDD-HHMM`

## RunPod Deployment

1. Create a **Serverless Endpoint** in the RunPod console
2. Set the Docker image to `fswillis99/runpod-comfy-worker:latest`
3. Set container disk to at least 40 GB
4. No environment variables required

## Environment

- Base: `nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04`
- Python: 3.12 via comfy-cli
- ComfyUI: latest
