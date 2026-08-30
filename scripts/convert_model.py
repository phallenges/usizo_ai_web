#!/usr/bin/env python3
"""
Convert all-MiniLM-L12-v2 from HuggingFace to TFLite format.

Usage:
    python scripts/convert_model.py

For Python 3.14, the full conversion requires PyTorch and TensorFlow which may not be available.
This script will create a simplified model wrapper for testing.
"""

import sys
import os
from pathlib import Path

print("=" * 60)
print("all-MiniLM-L12-v2 Model Converter for TFLite")
print("=" * 60)

# Try importing required packages
pytorch_available = False
tensorflow_available = False

try:
    import torch
    from transformers import AutoTokenizer, AutoModel
    pytorch_available = True
    print("[OK] PyTorch and transformers available")
except ImportError as e:
    print(f"[SKIP] PyTorch not available: {e}")

try:
    import tensorflow as tf
    tensorflow_available = True
    print("[OK] TensorFlow available")
except ImportError:
    print("[SKIP] TensorFlow not available for Python 3.14")


def create_placeholder_model():
    """Create a minimal TFLite model file for development."""
    output_dir = Path("assets/models")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    tflite_path = output_dir / "all_minilm_l12_v2.tflite"
    
    print("\n[1] Creating placeholder TFLite model")
    print("    This is a minimal model file for development.")
    print("    For production, run conversion on a system with PyTorch/TensorFlow.")
    
    # Create a minimal TFLite file structure
    # This won't execute but allows the app to load without errors
    with open(tflite_path, "wb") as f:
        # TFLite file format header
        f.write(b"TFL3")  # Magic number for TFLite
        
        # Minimal metadata
        f.write(b"\x00" * 1000)  # Placeholder data
    
    print(f"    Created: {tflite_path}")
    print(f"    Size: {os.path.getsize(tflite_path)} bytes")
    
    return tflite_path


def convert_with_pytorch():
    """Attempt full conversion with PyTorch and TensorFlow."""
    if not pytorch_available:
        print("\n[SKIP] PyTorch conversion: not available")
        return False
    
    if not tensorflow_available:
        print("[SKIP] TensorFlow conversion: not available for Python 3.14")
        return False
    
    print("\n[2] Performing full model conversion")
    
    try:
        import torch
        from transformers import AutoTokenizer, AutoModel
        import tensorflow as tf
        
        model_name = "sentence-transformers/all-MiniLM-L12-v2"
        output_dir = Path("assets/models")
        output_dir.mkdir(parents=True, exist_ok=True)
        
        print("    Loading model from HuggingFace...")
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        model = AutoModel.from_pretrained(model_name)
        model.eval()
        print("    Model loaded successfully")
        
        # Create embedding wrapper
        class EmbeddingModel(torch.nn.Module):
            def __init__(self, base_model):
                super().__init__()
                self.base_model = base_model
            
            def forward(self, input_ids, attention_mask=None):
                output = self.base_model(
                    input_ids=input_ids,
                    attention_mask=attention_mask,
                    return_dict=True,
                )
                token_embeddings = output.last_hidden_state
                input_mask_expanded = (
                    attention_mask.unsqueeze(-1)
                    .expand(token_embeddings.size())
                    .float()
                )
                sum_embeddings = torch.sum(token_embeddings * input_mask_expanded, 1)
                sum_mask = torch.clamp(input_mask_expanded.sum(1), min=1e-9)
                mean_embeddings = sum_embeddings / sum_mask
                return mean_embeddings
        
        embedding_model = EmbeddingModel(model)
        embedding_model.eval()
        
        # Convert to TFLite
        print("    Converting to TensorFlow...")
        saved_model_path = output_dir / "saved_model"
        saved_model_path.mkdir(exist_ok=True)
        
        tf.saved_model.save(embedding_model, str(saved_model_path))
        print("    SavedModel created")
        
        print("    Converting to TFLite format...")
        converter = tf.lite.TFLiteConverter.from_saved_model(str(saved_model_path))
        converter.target_spec.supported_ops = [
            tf.lite.OpsSet.TFLITE_BUILTINS,
            tf.lite.OpsSet.SELECT_TF_OPS,
        ]
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        
        tflite_model = converter.convert()
        
        tflite_path = output_dir / "all_minilm_l12_v2.tflite"
        with open(tflite_path, "wb") as f:
            f.write(tflite_model)
        
        size_mb = os.path.getsize(tflite_path) / 1024 / 1024
        print(f"    Saved: {tflite_path}")
        print(f"    Size: {size_mb:.2f} MB")
        
        return True
        
    except Exception as e:
        print(f"    [ERROR] Conversion failed: {e}")
        return False


def main():
    # Check Python version
    print(f"\nPython version: {sys.version}")
    
    if sys.version_info >= (3, 14):
        print("WARNING: PyTorch and TensorFlow may not be available on Python 3.14")
        print("Consider using Python 3.11 or 3.12 for full model conversion")
    
    # Try full conversion first
    if pytorch_available and tensorflow_available:
        success = convert_with_pytorch()
        if success:
            print("\n[SUCCESS] Full model conversion completed!")
            return
    
    # Fall back to placeholder
    print("\n[INFO] Creating placeholder model for development")
    create_placeholder_model()
    
    print("\n" + "=" * 60)
    print("MODEL SETUP INSTRUCTIONS")
    print("=" * 60)
    print("\nFor development/testing:")
    print("  - A placeholder model has been created")
    print("  - The app will load but may not have full ML functionality")
    
    print("\nFor production (full model conversion):")
    print("  1. Install PyTorch: pip install torch")
    print("  2. Install TensorFlow: pip install tensorflow")
    print("  3. Use Python 3.11 or 3.12 (not 3.14)")
    print("  4. Run this script again: python scripts/convert_model.py")
    
    print("\nPre-built TFLite models available at:")
    print("  https://huggingface.co/sentence-transformers/all-MiniLM-L12-v2")
    
    print("\nTo use the app:")
    print("  1. Run: flutter pub get")
    print("  2. Run: flutter run")
    print("=" * 60)


if __name__ == "__main__":
    main()


