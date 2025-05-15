#!/bin/bash
#
# This script is automatically executed after code cloning in Xcode Cloud
# Used to download pretrained MLX models
#
set -e

echo "==================== Starting Post-Clone Script ===================="

# Get the absolute path of the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Script directory: $SCRIPT_DIR"

# Set up model directory
MODEL_DIR="$SCRIPT_DIR/app/FastVLM/model"
echo "Models will be downloaded to: $MODEL_DIR"

# Ensure model directory exists
mkdir -p "$MODEL_DIR"

# Call the download script to get the 0.5b model
echo "Starting download of 0.5b pretrained model..."
bash "$SCRIPT_DIR/app/get_pretrained_mlx_model.sh" --model 0.5b --dest "$MODEL_DIR"

echo "Model download complete, checking model files..."
ls -la "$MODEL_DIR"

echo "==================== Post-Clone Script Completed ===================="