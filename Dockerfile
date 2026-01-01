# Use Python base image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        curl \
        git \
        gcc \
        g++ \
        make \
        libglib2.0-0 \
        libgomp1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Clone ComfyUI repository
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /app/ComfyUI

# Set working directory to ComfyUI
WORKDIR /app/ComfyUI

# Install CPU-only PyTorch first (for Google Cloud compatibility)
# This prevents CUDA dependencies that won't work in Cloud Run
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Create a filtered requirements file without torch packages
RUN grep -v "^torch" requirements.txt | grep -v "^torchvision" | grep -v "^torchaudio" > requirements_filtered.txt || cp requirements.txt requirements_filtered.txt

# Install Python dependencies (excluding torch packages already installed)
RUN pip install --no-cache-dir -r requirements_filtered.txt

# Install additional packages for model downloads
RUN pip install --no-cache-dir huggingface_hub

# Install ComfyUI Manager (custom node manager)
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git /app/ComfyUI/custom_nodes/ComfyUI-Manager

# Create directories for models (ComfyUI expects models in ComfyUI/models/)
RUN mkdir -p /app/ComfyUI/models/checkpoints \
    /app/ComfyUI/models/vae \
    /app/ComfyUI/models/loras \
    /app/ComfyUI/models/upscale_models \
    /app/ComfyUI/models/controlnet \
    /app/ComfyUI/models/clip \
    /app/ComfyUI/models/embeddings

# Copy models from local directory if they exist (faster than downloading during build)
# Models should be downloaded locally first using: ./download_models_local.sh
# Note: If models/ directory doesn't exist, create an empty one to avoid COPY errors
COPY models/ /tmp/models/
RUN if [ -d "/tmp/models" ] && [ "$(ls -A /tmp/models 2>/dev/null)" ]; then \
        echo "Copying local models into image..."; \
        cp -r /tmp/models/* /app/ComfyUI/models/ 2>/dev/null || true; \
        echo "Models copied successfully"; \
    else \
        echo "No local models found in models/ directory"; \
        echo "Models will need to be downloaded separately or added to the image"; \
    fi

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Expose ComfyUI port (default is 8188)
EXPOSE 8188

# Set environment variables for Google Cloud
ENV PYTHONUNBUFFERED=1
ENV COMFYUI_HOST=0.0.0.0
ENV COMFYUI_PORT=8188
# Force CPU mode for Google Cloud Run (no GPU support)
ENV CUDA_VISIBLE_DEVICES=""
ENV PYTORCH_ENABLE_MPS_FALLBACK=1

# Use entrypoint script
ENTRYPOINT ["/app/entrypoint.sh"]

