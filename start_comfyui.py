#!/usr/bin/env python3
"""
Wrapper script to start ComfyUI with CPU-only mode.
Patches torch to prevent CUDA assertion errors.
"""
import os
import sys
from unittest.mock import patch, MagicMock

# Set environment variables before importing torch
os.environ['CUDA_VISIBLE_DEVICES'] = ''
os.environ['PYTORCH_ENABLE_MPS_FALLBACK'] = '1'
os.environ['PYTORCH_NO_CUDA_MEMORY_CACHING'] = '1'

# Import torch
import torch

# Create a comprehensive mock for torch.cuda functions
# This will be applied as a context manager to prevent CUDA calls
def create_cuda_patches():
    """Create all necessary patches for torch.cuda"""
    patches = {}
    
    # Patch _lazy_init to do nothing
    def patched_lazy_init():
        pass
    
    # Patch current_device - this is the critical one
    def patched_current_device():
        return 0
    
    # Patch is_available
    def patched_is_available():
        return False
    
    # Patch device_count
    def patched_device_count():
        return 0
    
    # Patch get_device_name
    def patched_get_device_name(device=None):
        return 'CPU'
    
    # Patch get_device_properties
    class MockDeviceProperties:
        def __init__(self):
            self.name = 'CPU'
            self.major = 0
            self.minor = 0
            self.total_memory = 0
    
    def patched_get_device_properties(device):
        return MockDeviceProperties()
    
    # Patch memory functions
    def patched_memory_allocated(device=None):
        return 0
    
    def patched_max_memory_allocated(device=None):
        return 0
    
    def patched_memory_reserved(device=None):
        return 0
    
    def patched_empty_cache():
        pass
    
    def patched_synchronize():
        pass
    
    # Apply all patches
    if hasattr(torch.cuda, '_lazy_init'):
        torch.cuda._lazy_init = patched_lazy_init
    torch.cuda.is_available = patched_is_available
    torch.cuda.device_count = patched_device_count
    torch.cuda.current_device = patched_current_device
    if hasattr(torch.cuda, 'get_device_name'):
        torch.cuda.get_device_name = patched_get_device_name
    if hasattr(torch.cuda, 'get_device_properties'):
        torch.cuda.get_device_properties = patched_get_device_properties
    if hasattr(torch.cuda, 'memory_allocated'):
        torch.cuda.memory_allocated = patched_memory_allocated
    if hasattr(torch.cuda, 'max_memory_allocated'):
        torch.cuda.max_memory_allocated = patched_max_memory_allocated
    if hasattr(torch.cuda, 'memory_reserved'):
        torch.cuda.memory_reserved = patched_memory_reserved
    if hasattr(torch.cuda, 'empty_cache'):
        torch.cuda.empty_cache = patched_empty_cache
    if hasattr(torch.cuda, 'synchronize'):
        torch.cuda.synchronize = patched_synchronize

# Apply patches immediately
create_cuda_patches()

# Additional aggressive patching for current_device
# Ensure it's a pure Python function that never calls _lazy_init
def safe_current_device():
    """Patched current_device that returns 0 without calling CUDA functions"""
    return 0

# Try multiple methods to ensure the patch sticks
try:
    torch.cuda.current_device = safe_current_device
except:
    pass

try:
    torch.cuda.__dict__['current_device'] = safe_current_device
except:
    pass

# Verify the patch
try:
    test_result = torch.cuda.current_device()
    print(f"Verified current_device patch: returns {test_result}")
except Exception as e:
    print(f"Warning: current_device patch verification failed: {e}")

# Ensure device is set to CPU (if available in this torch version)
if hasattr(torch, 'set_default_device'):
    torch.set_default_device('cpu')

print("PyTorch patched for CPU-only mode")
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"Device count: {torch.cuda.device_count()}")

# Change to ComfyUI directory
comfyui_dir = os.environ.get('COMFYUI_DIR', '/app/ComfyUI')
os.chdir(comfyui_dir)

# Add ComfyUI directory to path
sys.path.insert(0, comfyui_dir)

# Get command line arguments
host = os.environ.get('COMFYUI_HOST', '0.0.0.0')
port = int(os.environ.get('COMFYUI_PORT', '8188'))

# Set up sys.argv for ComfyUI
sys.argv = ['main.py --cpu', '--listen', host, '--port', str(port), '--enable-cors-header', '*']

# Import and run main.py as a module
# This approach works better than exec() for scripts with if __name__ == '__main__'
import importlib.util
spec = importlib.util.spec_from_file_location("__main__", os.path.join(comfyui_dir, "main.py"))
main_module = importlib.util.module_from_spec(spec)
sys.modules['__main__'] = main_module
spec.loader.exec_module(main_module)

