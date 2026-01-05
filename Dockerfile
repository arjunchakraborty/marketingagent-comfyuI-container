# Minimal CPU-only ComfyUI image suitable for Cloud Run
FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ffmpeg \
    build-essential \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Clone ComfyUI
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /app/ComfyUI

# Install Python requirements
# ComfyUI requirement versions may vary; install base requirements and runtime deps
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r /app/ComfyUI/requirements.txt \
    && pip install --no-cache-dir xformers==0.0.22.post7 --extra-index-url https://download.pytorch.org/whl/cpu || true

# Copy local models if provided (optional)
# If a local ./models directory exists in the build context, copy it into the image.
# This is optional and safe even if the directory is absent.
COPY models/ /app/ComfyUI/models/

# Copy entrypoint
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Default envs for Cloud Run
ENV COMFYUI_HOST=0.0.0.0 \
    COMFYUI_PORT=8188

EXPOSE 8188

# Health check (optional; Cloud Run uses container port by default)
# HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD curl -f http://localhost:8188 || exit 1

CMD ["/bin/bash", "/app/entrypoint.sh"]
