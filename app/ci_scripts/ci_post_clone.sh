#!/bin/bash
#
# This script is automatically executed after code cloning in Xcode Cloud
# Used to download pretrained MLX models
#
set -e

echo "==================== Starting Post-Clone Script ===================="

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Script directory: $SCRIPT_DIR"

# Set up model directory - fix the path to point to the correct FastVLM/model location
# Go up one level from ci_scripts to app directory, then to FastVLM/model
MODEL_DIR="$(dirname "$SCRIPT_DIR")/FastVLM/model"
echo "Models will be downloaded to: $MODEL_DIR"

# Ensure model directory exists
mkdir -p "$MODEL_DIR"

# Check if wget is installed, if not install it using brew
if ! command -v wget &>/dev/null; then
    echo "wget not found, installing using brew..."
    brew update
    brew install wget
else
    echo "wget is already installed"
fi

# Call the download script to get the 0.5b model
echo "Starting download of 0.5b pretrained model..."
# Fix path to point to the correct location of the get_pretrained_mlx_model.sh script
bash "$SCRIPT_DIR/../get_pretrained_mlx_model.sh" --model 0.5b --dest "$MODEL_DIR"

echo "Model download complete, checking model files..."
ls -la "$MODEL_DIR"

echo "==================== Post-Clone Script Completed ===================="
