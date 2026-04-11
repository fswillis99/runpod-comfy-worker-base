ARG BASE_IMAGE=nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04
# MODEL_TYPE options: flux1-dev-fp8 | qwen-image

# ---------------------------------------------------------------------------
# Stage 1: Base — ComfyUI + handler runtime
# ---------------------------------------------------------------------------
FROM ${BASE_IMAGE} AS base

ARG COMFYUI_VERSION=latest
ARG CUDA_VERSION_FOR_COMFY
ARG ENABLE_PYTORCH_UPGRADE=false
ARG PYTORCH_INDEX_URL

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8

RUN apt-get update && apt-get install -y \
    python3.12 \
    python3.12-venv \
    git \
    wget \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    ffmpeg \
    openssh-server \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install uv and create a virtual environment
RUN wget -qO- https://astral.sh/uv/install.sh | sh \
    && ln -s /root/.local/bin/uv /usr/local/bin/uv \
    && ln -s /root/.local/bin/uvx /usr/local/bin/uvx \
    && uv venv /opt/venv

ENV PATH="/opt/venv/bin:${PATH}"

# Install ComfyUI via comfy-cli
RUN uv pip install comfy-cli pip setuptools wheel

RUN if [ -n "${CUDA_VERSION_FOR_COMFY}" ]; then \
      /usr/bin/yes | comfy --workspace /comfyui install --version "${COMFYUI_VERSION}" --cuda-version "${CUDA_VERSION_FOR_COMFY}" --nvidia; \
    else \
      /usr/bin/yes | comfy --workspace /comfyui install --version "${COMFYUI_VERSION}" --nvidia; \
    fi

RUN if [ "$ENABLE_PYTORCH_UPGRADE" = "true" ]; then \
      uv pip install --force-reinstall torch torchvision torchaudio --index-url ${PYTORCH_INDEX_URL}; \
    fi

WORKDIR /comfyui
ADD src/extra_model_paths.yaml ./

# Discover which Python comfy-cli used and install ComfyUI deps there.
# comfy-cli may create its own venv (/comfyui/venv) rather than using /opt/venv.
RUN COMFY_PYTHON=$(find /comfyui -name python -o -name python3 2>/dev/null | grep bin | head -1) && \
    COMFY_PYTHON=${COMFY_PYTHON:-python} && \
    echo "ComfyUI Python: $COMFY_PYTHON" && \
    $COMFY_PYTHON -m pip install Pillow -q && \
    $COMFY_PYTHON -c "from PIL import Image; print('Pillow OK')" && \
    echo $COMFY_PYTHON > /comfy_python.txt

WORKDIR /
RUN uv pip install runpod requests websocket-client

ADD src/start.sh src/network_volume.py handler.py test_input.json ./
RUN chmod +x /start.sh

COPY scripts/comfy-node-install.sh /usr/local/bin/comfy-node-install
COPY scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN chmod +x /usr/local/bin/comfy-node-install /usr/local/bin/comfy-manager-set-mode

ENV PIP_NO_INPUT=1

CMD ["/start.sh"]

# ---------------------------------------------------------------------------
# Stage 2: Download models
# ---------------------------------------------------------------------------
FROM base AS downloader

ARG HUGGINGFACE_ACCESS_TOKEN
ARG MODEL_TYPE=flux1-dev-fp8

WORKDIR /comfyui
RUN mkdir -p models/checkpoints models/vae models/unet models/clip \
              models/text_encoders models/diffusion_models models/loras \
              models/controlnet models/upscale_models models/embeddings

# flux1-dev-fp8 (default) — single checkpoint, no token required
RUN wget -q -O models/checkpoints/flux1-dev-fp8.safetensors \
    https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors

# qwen-image — Qwen-Image 2511 (edit) + 2512 (text-to-image) models
# Sources: HuggingFace (Comfy-Org/Qwen-Image_ComfyUI + lightx2v/Qwen-Image-2512-Lightning)
RUN HF_BASE="https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files"; \
    LIGHTNING_BASE="https://huggingface.co/lightx2v"; \
    \
    echo "Downloading Qwen shared models..."; \
    wget -q -O models/vae/qwen_image_vae.safetensors \
      "${HF_BASE}/vae/qwen_image_vae.safetensors"; \
    wget -q -O models/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors \
      "${HF_BASE}/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"; \
    \
    echo "Downloading Qwen-Image 2512 (text-to-image) models..."; \
    wget -q -O models/diffusion_models/qwen_image_2512_fp8_e4m3fn.safetensors \
      "${HF_BASE}/diffusion_models/qwen_image_2512_fp8_e4m3fn.safetensors"; \
    wget -q -O models/loras/Qwen-Image-2512-Lightning-4steps-V1.0-fp32.safetensors \
      "${LIGHTNING_BASE}/Qwen-Image-2512-Lightning/resolve/main/Qwen-Image-2512-Lightning-4steps-V1.0-fp32.safetensors"; \
    \
    echo "Downloading Qwen-Image 2511 (image-edit) models..."; \
    wget -q -O models/diffusion_models/qwen_image_edit_2511_bf16.safetensors \
      "${HF_BASE}/diffusion_models/qwen_image_edit_2511_bf16.safetensors"; \
    wget -q -O models/loras/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors \
      "${LIGHTNING_BASE}/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"

# Civitai LoRAs (shared by both Qwen workflows)
# These 4 LoRAs are downloaded from Civitai using the API key.
# Replace CIVITAI_VERSION_ID_* with the actual version IDs once known.
# Download URL format: https://civitai.com/api/download/models/{versionId}?token={key}
ARG CIVITAI_API_KEY
# RUN if [ "$MODEL_TYPE" = "qwen-image" ] && [ -n "$CIVITAI_API_KEY" ]; then \
#       CIVITAI_DL="https://civitai.com/api/download/models"; \
#       : "TODO: set correct version IDs after lookup"; \
#       echo "Civitai LoRA download requires version IDs — skipping until configured"; \
#     fi
RUN CUSTOM_BASE="https://comfy-kappa-files-001.s3.us-east-1.amazonaws.com/models/loras"; \
    echo "Fetching custom loras"; \
    wget -q -O models/loras/Qwen4Play-2512.1_e10.safetensors \
      "${CUSTOM_BASE}/Qwen4Play-2512.1_e10.safetensors"; \
    wget -q -O models/loras/qwen-image_nsfw_adv_v1.0.safetensors \
      "${CUSTOM_BASE}/qwen-image_nsfw_adv_v1.0.safetensors"; \
    wget -q -O models/loras/spanking_Qwen-dim64-v1.safetensors \
      "${CUSTOM_BASE}/spanking_Qwen-dim64-v1.safetensors"; \
    wget -q -O models/loras/Korean_qwen.safetensors \
      "${CUSTOM_BASE}/Korean_qwen.safetensors"; \

# ---------------------------------------------------------------------------
# Stage 3: Final image
# ---------------------------------------------------------------------------
FROM base AS final

COPY --from=downloader /comfyui/models /comfyui/models
