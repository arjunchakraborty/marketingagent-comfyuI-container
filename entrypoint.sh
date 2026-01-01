#!/bin/bash
set -e

echo "Starting ComfyUI..."

# ComfyUI is installed in /app/ComfyUI
COMFYUI_DIR="/app/ComfyUI"
cd "$COMFYUI_DIR"

# Force CPU mode if no GPU is available
export CUDA_VISIBLE_DEVICES=""
export PYTORCH_ENABLE_MPS_FALLBACK=1

# Suppress CUDA warnings for CPU-only mode
export PYTORCH_NO_CUDA_MEMORY_CACHING=1

echo "Running in CPU mode (GPU not available in Cloud Run)"

# Start ComfyUI server
python main.py \
    --listen ${COMFYUI_HOST:-0.0.0.0} \
    --port ${COMFYUI_PORT:-8188} \
    --enable-cors-header "*"

