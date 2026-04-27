# syntax=docker/dockerfile:1
# ---------------------------------------------------------------------------
# Models - pulled from the stable model-base image (rebuilt rarely).
# Update this digest when model-base changes.
# Includes: nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04
# ---------------------------------------------------------------------------
FROM us-central1-docker.pkg.dev/project-b882ddad-b8b1-4a5c-908/runpod/model-base@sha256:409c80446822f352447914165dd98d684f6d74ee68f77c83b6ac5b18e8b1d3d3

# ---------------------------------------------------------------------------
# Base - ComfyUI + handler runtime (rebuilt on every app change)
# ---------------------------------------------------------------------------
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
COPY comfy-worker/Dockerfile /Dockerfile

CMD ["/start.sh"]
