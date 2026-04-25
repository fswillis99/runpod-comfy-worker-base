ARG BASE_IMAGE=nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04
ARG HF_BASE=https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files
ARG HF_BASE_2=https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files
ARG LIGHTNING_BASE=https://huggingface.co/lightx2v
ARG CUSTOM_BASE=https://comfy-kappa-files-001.s3.us-east-1.amazonaws.com/models/loras

# ---------------------------------------------------------------------------
# Stage 1: Base
# Model Base: Changes Infrequently and is large.
# ---------------------------------------------------------------------------
FROM ${BASE_IMAGE} AS base

# ---------------------------------------------------------------------------
# Stage 2: Download models
# - Download one model per layer to keep layers as small as possible
# ---------------------------------------------------------------------------
FROM base AS final

RUN apt-get update && apt-get install -y \
    wget \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN mkdir /comfyui
WORKDIR /comfyui
RUN mkdir -p models/checkpoints models/vae models/unet models/clip \
              models/text_encoders models/diffusion_models models/loras \
              models/controlnet models/upscale_models models/embeddings

# Download: flux1-dev-fp8 (default) — single checkpoint, no token required
RUN wget -q -O models/checkpoints/flux1-dev-fp8.safetensors \
    https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors

# Download: qwen_image_2512_fp8_e4m3fn.safetensors
RUN wget -q -O models/diffusion_models/qwen_image_2512_fp8_e4m3fn.safetensors \
      "${HF_BASE}/diffusion_models/qwen_image_2512_fp8_e4m3fn.safetensors"

# Download: qwen_image_edit_2511_bf16.safetensors
RUN wget -q -O models/diffusion_models/qwen_image_edit_2511_bf16.safetensors \
      "${HF_BASE_2}/diffusion_models/qwen_image_edit_2511_bf16.safetensors"

# Download: Korean_qwen.safetensors
RUN wget -q -O models/loras/Korean_qwen.safetensors \
      "${CUSTOM_BASE}/Korean_qwen.safetensors"

# Download: Qwen-Image-2512-Lightning-4steps-V1.0-fp32.safetensors
RUN wget -q -O models/loras/Qwen-Image-2512-Lightning-4steps-V1.0-fp32.safetensors \
      "${LIGHTNING_BASE}/Qwen-Image-2512-Lightning/resolve/main/Qwen-Image-2512-Lightning-4steps-V1.0-fp32.safetensors"

# Download: Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors
RUN wget -q -O models/loras/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors \
      "${LIGHTNING_BASE}/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"

# Download: Qwen4Play-2512.1_e10.safetensors
RUN wget -q -O models/loras/Qwen4Play-2512.1_e10.safetensors \
      "${CUSTOM_BASE}/Qwen4Play-2512.1_e10.safetensors"

# Download: qwen-image_nsfw_adv_v1.0.safetensors
RUN wget -q -O models/loras/qwen-image_nsfw_adv_v1.0.safetensors \
      "${CUSTOM_BASE}/qwen-image_nsfw_adv_v1.0.safetensors"

# Download: spanking_Qwen-dim64-v1.safetensors
RUN wget -q -O models/loras/spanking_Qwen-dim64-v1.safetensors \
      "${CUSTOM_BASE}/spanking_Qwen-dim64-v1.safetensors"

# Download: qwen_2.5_vl_7b_fp8_scaled.safetensors
RUN wget -q -O models/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors \
      "${HF_BASE}/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"

# Download: qwen_image_vae.safetensors
RUN wget -q -O models/vae/qwen_image_vae.safetensors \
      "${HF_BASE}/vae/qwen_image_vae.safetensors"

