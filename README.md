# ComfyUI Google Cloud Container

This container runs ComfyUI and can be deployed to Google Cloud Platform.

## Downloading Models (Required for Local Development)

Models are mounted from the host filesystem via volume mounts, so you need to download them locally first:

```bash
# Install huggingface-cli if not already installed
pip install huggingface_hub

# Set your HuggingFace token if models require authentication
export HF_TOKEN=your_token
# Or login: huggingface-cli login

# Download models to local ./models directory
./download_models_local.sh
```

This will download all required Flux.1-dev models to a local `models/` directory. These models will be mounted into the container at runtime, **not copied into the Docker image**. This keeps the image size small and allows you to update models without rebuilding.

## Building the Image

```bash
# Build the image (models are not included in the image)
docker build -t comfyui:latest .
```

The image does not contain models - they are mounted from your local filesystem when running with docker-compose.

## Running Locally

### Using Docker Compose (Recommended)

```bash
# Start the service
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the service
docker-compose down
```

The `docker-compose.yml` file automatically mounts the model directories from `./models/` into the container. Access ComfyUI at http://localhost:8188

### Using Docker Run

```bash
docker run -p 8188:8188 \
  -v $(pwd)/models/checkpoints:/app/ComfyUI/models/checkpoints \
  -v $(pwd)/models/clip:/app/ComfyUI/models/clip \
  -v $(pwd)/models/vae:/app/ComfyUI/models/vae \
  comfyui:latest
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

These models are mounted into the container at runtime via volume mounts (configured in `docker-compose.yml`). This means:
- Models are **not** stored in the Docker image (keeping it small)
- You can update models on the host filesystem without rebuilding the image
- Changes to models are immediately available in the container

### Model Requirements

The current setup includes Flux.1-dev models:
- `flux1-dev.safetensors` (checkpoint)
- `ae.safetensors` (VAE)
- `t5xxl_fp16.safetensors` (CLIP)
- `clip_l.safetensors` (CLIP)

If models require authentication, set the `HF_TOKEN` environment variable before running `download_models_local.sh`.

## Base Container

This container is based on the ComfyUI CI container from: https://github.com/Comfy-Org/comfyui-ci-container.git

