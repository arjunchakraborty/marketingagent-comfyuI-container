# ComfyUI Google Cloud Container

This container runs ComfyUI and can be deployed to Google Cloud Platform.

## Downloading Models (Recommended)

To avoid downloading models every time you build the Docker image, download them locally first:

```bash
# Install huggingface-cli if not already installed
pip install huggingface_hub

# Set your HuggingFace token if models require authentication
export HF_TOKEN=your_token
# Or login: huggingface-cli login

# Download models to local ./models directory
./download_models_local.sh
```

This will download all required Flux.1-dev models to a local `models/` directory, which will be copied into the Docker image during build.

## Building the Image

```bash
# Build with local models (faster, no re-downloads)
docker build -t comfyui:latest .

# Or build without local models (models will need to be downloaded separately)
docker build -t comfyui:latest .
```

## Running Locally

```bash
docker run -p 8188:8188 comfyui:latest
```

Access ComfyUI at http://localhost:8188

## Deploying to Google Cloud

### Using Cloud Build

```bash
gcloud builds submit --config cloudbuild.yaml
```

### Using Cloud Run

```bash
# Deploy the service
gcloud run deploy comfyui \
  --image gcr.io/PROJECT_ID/comfyui:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --port 8188 \
  --memory 8Gi \
  --cpu 4
```

### Network Access

The container is configured to be accessible from other containers in the same Google Cloud project. Use the Cloud Run service URL or internal service name for inter-container communication.

## Customizing Models

### Downloading Models Locally

Edit `download_models_local.sh` to add your required models. The script downloads models to a local `models/` directory structure:
- Checkpoints: `./models/checkpoints/`
- VAE: `./models/vae/`
- CLIP: `./models/clip/`
- LoRAs: `./models/loras/`
- ControlNet: `./models/controlnet/`
- etc.

These models are then copied into the Docker image during build, avoiding re-downloads on every build.

### Model Requirements

The current setup includes Flux.1-dev models:
- `flux1-dev.safetensors` (checkpoint)
- `ae.safetensors` (VAE)
- `t5xxl_fp16.safetensors` (CLIP)
- `clip_l.safetensors` (CLIP)

If models require authentication, set the `HF_TOKEN` environment variable before running `download_models_local.sh`.

## Base Container

This container is based on the ComfyUI CI container from: https://github.com/Comfy-Org/comfyui-ci-container.git

