#!/bin/bash
# Image building utility script

if [ -z "$1" ]; then
    echo "Usage: $0 <image-tag>"
    exit 1
fi

IMAGE_TAG="$1"
echo "Building image: $IMAGE_TAG"

# Get image details from MANIFEST
IMAGE_DETAILS=$(./scripts/parse-manifest.sh get-image-details "$IMAGE_TAG")
if [ -z "$IMAGE_DETAILS" ]; then
    echo "Error: Could not find image details for $IMAGE_TAG in MANIFEST"
    exit 1
fi

# Parse the details
eval "$IMAGE_DETAILS"

if [ -z "$source" ] || [ -z "$dockerfile" ]; then
    echo "Error: Missing source or dockerfile for image $IMAGE_TAG"
    echo "Source: $source"
    echo "Dockerfile: $dockerfile"
    exit 1
fi

echo "Building image $tag from source: $source, dockerfile: $dockerfile"

# Construct full paths
DOCKERFILE_PATH="$source/$dockerfile"
BUILD_CONTEXT="$source"

# Verify files exist
if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "Error: Dockerfile not found at $DOCKERFILE_PATH"
    exit 1
fi

if [ ! -d "$BUILD_CONTEXT" ]; then
    echo "Error: Build context directory not found at $BUILD_CONTEXT"
    exit 1
fi

echo "Building with:"
echo "  Tag: $tag"
echo "  Dockerfile: $DOCKERFILE_PATH"
echo "  Context: $BUILD_CONTEXT"

# Build using podman (compatible with most CI/CD systems)
if command -v podman >/dev/null 2>&1; then
    echo "Using podman for build..."
    podman build -t "$tag" -f "$DOCKERFILE_PATH" "$BUILD_CONTEXT"
    
    # Push to registry if credentials are provided
    if [ -n "$REGISTRY_ADDRESS" ] && [ -n "$REGISTRY_USERNAME" ] && [ -n "$REGISTRY_PASSWORD" ]; then
        echo "Tagging and pushing to registry $REGISTRY_ADDRESS..."
        podman tag "$tag" "$REGISTRY_ADDRESS/$tag"
        podman push --tls-verify=false --creds="$REGISTRY_USERNAME:$REGISTRY_PASSWORD" "$REGISTRY_ADDRESS/$tag"
        echo "Successfully pushed $tag to $REGISTRY_ADDRESS"
    else
        echo "Skipping registry push - missing registry credentials"
    fi
elif command -v docker >/dev/null 2>&1; then
    echo "Using docker for build..."
    docker build -t "$tag" -f "$DOCKERFILE_PATH" "$BUILD_CONTEXT"
    
    # Push to registry if credentials are provided
    if [ -n "$REGISTRY_ADDRESS" ] && [ -n "$REGISTRY_USERNAME" ] && [ -n "$REGISTRY_PASSWORD" ]; then
        echo "Logging into registry $REGISTRY_ADDRESS..."
        echo "$REGISTRY_PASSWORD" | docker login "$REGISTRY_ADDRESS" -u "$REGISTRY_USERNAME" --password-stdin
        
        echo "Tagging and pushing to registry..."
        docker tag "$tag" "$REGISTRY_ADDRESS/$tag"
        docker push "$REGISTRY_ADDRESS/$tag"
        echo "Successfully pushed $tag to $REGISTRY_ADDRESS"
        
        docker logout "$REGISTRY_ADDRESS"
    else
        echo "Skipping registry push - missing registry credentials"
    fi
else
    echo "Error: Neither podman nor docker found. Please install one of them."
    exit 1
fi

echo "Successfully built image: $tag"
