#!/bin/bash
set -e

echo "Downloading ComfyUI models locally for Flux.1-dev workflow..."
echo "These models will be copied into the Docker image during build."

# Local models directory (relative to script location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="${SCRIPT_DIR}/models"

# Create model directories
mkdir -p "${MODELS_DIR}/checkpoints" \
         "${MODELS_DIR}/vae" \
         "${MODELS_DIR}/loras" \
         "${MODELS_DIR}/upscale_models" \
         "${MODELS_DIR}/controlnet" \
         "${MODELS_DIR}/clip" \
         "${MODELS_DIR}/embeddings"

echo "Using local model directory: ${MODELS_DIR}"

# Check if huggingface_hub is available
if ! python3 -c "import huggingface_hub" 2>/dev/null; then
    echo "Error: huggingface_hub is not installed."
    echo "Install it with one of these commands:"
    echo "  pip install huggingface_hub"
    echo "  pip3 install huggingface_hub"
    echo "  python3 -m pip install huggingface_hub"
    exit 1
fi

echo "Using Python huggingface_hub API"

# HuggingFace repositories for Flux.1-dev models
# Note: These models may require HuggingFace authentication
FLUX_REPO="black-forest-labs/FLUX.1-dev"
# VAE model is in a separate repository
VAE_REPO="receptektas/black-forest-labs-ae_safetensors"
# CLIP models are in separate repositories
T5XXL_REPO="Comfy-Org/stable-diffusion-3.5-fp8"
CLIPL_REPO="Comfy-Org/HunyuanVideo_repackaged"
CLIP_REPO="black-forest-labs/FLUX.1-dev"

# Function to list files in a repository (for debugging)
list_repo_files() {
    local repo=$1
    echo "Listing files in ${repo}..."
    python3 << EOF
import os
from huggingface_hub import list_repo_files

repo_id = "${repo}"
token = os.environ.get("HF_TOKEN", None)

try:
    files = list_repo_files(repo_id=repo_id, token=token)
    print("Available files:")
    for file in files:
        if "clip" in file.lower() or "t5" in file.lower() or file.endswith(".safetensors"):
            print(f"  - {file}")
except Exception as e:
    print(f"Error listing files: {e}")
EOF
}

# Check if HF_TOKEN is set
if [ -z "$HF_TOKEN" ]; then
    echo "Note: HF_TOKEN not set. If models require authentication, set it:"
    echo "  export HF_TOKEN=your_token"
    echo ""
fi

# Function to download model with retry
download_model() {
    local repo=$1
    local filename=$2
    local dest_dir=$3
    local dest_file="${dest_dir}/${filename}"
    local max_retries=3
    local retry=0
    
    # Check if file already exists and is complete
    # Check both the full path and the final filename (in case it was already moved)
    local final_filename=$(basename "${filename}")
    local final_dest_file="${dest_dir}/${final_filename}"
    
    if [ -f "${dest_file}" ] || [ -f "${final_dest_file}" ]; then
        echo "Model ${final_filename} already exists, skipping..."
        return 0
    fi
    
    # Check for partial downloads (files with .incomplete or .tmp extensions)
    # huggingface_hub may create temporary files during download
    local partial_files=("${dest_file}.incomplete" "${dest_file}.tmp" "${dest_file}.part")
    for partial in "${partial_files[@]}"; do
        if [ -f "${partial}" ]; then
            echo "Found partial download for ${filename}, will resume..."
            break
        fi
    done
    
    while [ $retry -lt $max_retries ]; do
        echo "Downloading ${filename} (attempt $((retry + 1))/${max_retries})..."
        
        # Use Python API directly (more reliable than CLI)
        if python3 << EOF
import os
import sys
from pathlib import Path
from huggingface_hub import hf_hub_download

repo_id = "${repo}"
filename = "${filename}"
local_dir = "${dest_dir}"
token = os.environ.get("HF_TOKEN", None)

try:
    # Download the file
    # Note: huggingface_hub automatically resumes interrupted downloads
    # It checks for partial files and continues from where it left off
    downloaded_path = hf_hub_download(
        repo_id=repo_id,
        filename=filename,
        local_dir=local_dir,
        token=token,
        # Force re-download if needed (set to False to resume automatically)
        force_download=False,
        # Local files are automatically checked and resumed
    )
    
    # If file was downloaded to a subdirectory, move it to the target directory
    downloaded_file = Path(downloaded_path)
    target_file = Path(local_dir) / Path(filename).name
    
    if downloaded_file != target_file and downloaded_file.exists():
        # Create target directory if it doesn't exist
        target_file.parent.mkdir(parents=True, exist_ok=True)
        # Move file to expected location
        downloaded_file.rename(target_file)
        # Remove empty subdirectories if any
        for parent in downloaded_file.parents:
            try:
                if parent != Path(local_dir) and parent.exists() and not any(parent.iterdir()):
                    parent.rmdir()
            except:
                pass
        print(f"Downloaded and moved to: {target_file}")
    else:
        print(f"Downloaded to: {downloaded_path}")
    
    sys.exit(0)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
EOF
        then
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
    
    echo "Error: Failed to download ${filename} after ${max_retries} attempts"
    return 1
}

# Download Flux.1-dev checkpoint model
echo ""
echo "=== Downloading Checkpoint Model ==="
download_model "${FLUX_REPO}" "flux1-dev.safetensors" "${MODELS_DIR}/checkpoints"

# Download Flux.1-dev VAE model
echo ""
echo "=== Downloading VAE Model ==="
echo "Downloading VAE model from ${VAE_REPO}..."
download_model "${VAE_REPO}" "ae.safetensors" "${MODELS_DIR}/vae" || {
    echo "Warning: Failed to download VAE from ${VAE_REPO}"
    echo "Trying alternative repository..."
    download_model "${FLUX_REPO}" "ae.safetensors" "${MODELS_DIR}/vae" || {
        echo "Error: Could not download VAE model"
        echo "You may need to download it manually from: https://huggingface.co/${VAE_REPO}"
    }
}

# Download T5XXL CLIP model
# Note: T5XXL is in a different repository (Comfy-Org/stable-diffusion-3.5-fp8)
echo ""
echo "=== Downloading CLIP Models ==="
echo "Downloading T5XXL CLIP model from ${T5XXL_REPO}..."
download_model "${T5XXL_REPO}" "text_encoders/t5xxl_fp16.safetensors" "${MODELS_DIR}/clip" || {
    echo "Warning: Failed to download T5XXL from ${T5XXL_REPO}"
    echo "Trying alternative path..."
    download_model "${T5XXL_REPO}" "t5xxl_fp16.safetensors" "${MODELS_DIR}/clip" || {
        echo "Error: Could not download T5XXL CLIP model"
        echo "You may need to download it manually from: https://huggingface.co/${T5XXL_REPO}"
    }
}

# Rename if downloaded with subdirectory path
if [ -f "${MODELS_DIR}/clip/text_encoders/t5xxl_fp16.safetensors" ]; then
    mv "${MODELS_DIR}/clip/text_encoders/t5xxl_fp16.safetensors" "${MODELS_DIR}/clip/t5xxl_fp16.safetensors"
    rmdir "${MODELS_DIR}/clip/text_encoders" 2>/dev/null || true
fi

# Download CLIP-L model
# Note: CLIP-L is in a different repository (Comfy-Org/HunyuanVideo_repackaged)
echo ""
echo "=== Downloading CLIP-L Model ==="
echo "Downloading CLIP-L model from ${CLIPL_REPO}..."
download_model "${CLIPL_REPO}" "split_files/text_encoders/clip_l.safetensors" "${MODELS_DIR}/clip" || {
    echo "Warning: Failed to download CLIP-L from ${CLIPL_REPO}"
    echo "Trying alternative path..."
    download_model "${CLIPL_REPO}" "clip_l.safetensors" "${MODELS_DIR}/clip" || {
        echo "Error: Could not download CLIP-L model"
        echo "You may need to download it manually from: https://huggingface.co/${CLIPL_REPO}"
    }
}

# Rename if downloaded with subdirectory path
if [ -f "${MODELS_DIR}/clip/split_files/text_encoders/clip_l.safetensors" ]; then
    mv "${MODELS_DIR}/clip/split_files/text_encoders/clip_l.safetensors" "${MODELS_DIR}/clip/clip_l.safetensors"
    # Remove empty subdirectories
    rmdir "${MODELS_DIR}/clip/split_files/text_encoders" 2>/dev/null || true
    rmdir "${MODELS_DIR}/clip/split_files" 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo "Model download process completed!"
echo "=========================================="
echo "Models location:"
echo "  - Checkpoint: ${MODELS_DIR}/checkpoints/flux1-dev.safetensors"
echo "  - VAE: ${MODELS_DIR}/vae/ae.safetensors"
echo "  - CLIP T5XXL: ${MODELS_DIR}/clip/t5xxl_fp16.safetensors"
echo "  - CLIP-L: ${MODELS_DIR}/clip/clip_l.safetensors"
echo ""
echo "You can now build the Docker image and models will be copied from this directory:"
echo "  docker build -t comfyui:latest ."
echo ""

