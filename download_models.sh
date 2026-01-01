#!/bin/bash
set -e

echo "Downloading ComfyUI models for Flux.1-dev workflow..."

# ComfyUI models directory
MODELS_DIR="/app/ComfyUI/models"

echo "Using model directory: ${MODELS_DIR}"

# HuggingFace repository for Flux.1-dev models
# Note: These models may require HuggingFace authentication
FLUX_REPO="black-forest-labs/FLUX.1-dev"

# Function to download model with retry
download_model() {
    local repo=$1
    local filename=$2
    local dest_dir=$3
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        echo "Downloading ${filename} (attempt $((retry + 1))/${max_retries})..."
        if huggingface-cli download "${repo}" \
            "${filename}" \
            --local-dir "${dest_dir}" \
            --local-dir-use-symlinks False \
            --resume-download; then
            echo "Successfully downloaded ${filename}"
            return 0
        else
            retry=$((retry + 1))
            if [ $retry -lt $max_retries ]; then
                echo "Retrying in 5 seconds..."
                sleep 5
            fi
        fi
    done
    
    echo "Warning: Failed to download ${filename} after ${max_retries} attempts"
    return 1
}

# Download Flux.1-dev checkpoint model
if [ ! -f "${MODELS_DIR}/checkpoints/flux1-dev.safetensors" ]; then
    download_model "${FLUX_REPO}" "flux1-dev.safetensors" "${MODELS_DIR}/checkpoints" || true
else
    echo "Checkpoint model already exists, skipping..."
fi

# Download Flux.1-dev VAE model
if [ ! -f "${MODELS_DIR}/vae/ae.safetensors" ]; then
    download_model "${FLUX_REPO}" "ae.safetensors" "${MODELS_DIR}/vae" || true
else
    echo "VAE model already exists, skipping..."
fi

# Download T5XXL CLIP model
if [ ! -f "${MODELS_DIR}/clip/t5xxl_fp16.safetensors" ]; then
    download_model "${FLUX_REPO}" "t5xxl_fp16.safetensors" "${MODELS_DIR}/clip" || true
else
    echo "T5XXL CLIP model already exists, skipping..."
fi

# Download CLIP-L model
if [ ! -f "${MODELS_DIR}/clip/clip_l.safetensors" ]; then
    download_model "${FLUX_REPO}" "clip_l.safetensors" "${MODELS_DIR}/clip" || true
else
    echo "CLIP-L model already exists, skipping..."
fi

echo ""
echo "Model download process completed!"
echo "Models location:"
echo "  - Checkpoint: ${MODELS_DIR}/checkpoints/flux1-dev.safetensors"
echo "  - VAE: ${MODELS_DIR}/vae/ae.safetensors"
echo "  - CLIP T5XXL: ${MODELS_DIR}/clip/t5xxl_fp16.safetensors"
echo "  - CLIP-L: ${MODELS_DIR}/clip/clip_l.safetensors"
echo ""
echo "Note: If models require authentication, set HF_TOKEN environment variable"
echo "      or run: huggingface-cli login"

