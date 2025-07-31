#!/bin/sh
# Image building utility script - builds all images from MANIFEST

# Validate MANIFEST exists
if [ ! -f "MANIFEST" ]; then
    echo "Error: MANIFEST file not found"
    exit 1
fi

echo "Building all images from MANIFEST..."

# Get all images from MANIFEST
images=$(./scripts/parse-manifest.sh get-images)
if [ -z "$images" ]; then
    echo "No images found in MANIFEST, skipping build"
    exit 0
fi

# Validate registry credentials for pushing
if [ -z "$REGISTRY_ADDRESS" ] || [ -z "$REGISTRY_USERNAME" ] || [ -z "$REGISTRY_PASSWORD" ]; then
    echo "Warning: Missing registry credentials - images will be built but not pushed"
    echo "Required: REGISTRY_ADDRESS, REGISTRY_USERNAME, REGISTRY_PASSWORD"
fi

# Function to build a single image
build_image() {
    local IMAGE_TAG="$1"
    echo "=== Building image: $IMAGE_TAG ==="
    
    # Get image details from MANIFEST
    IMAGE_DETAILS=$(./scripts/parse-manifest.sh get-image-details "$IMAGE_TAG")
    if [ -z "$IMAGE_DETAILS" ]; then
        echo "Error: Could not find image details for $IMAGE_TAG in MANIFEST"
        return 1
    fi
    
    # Parse the details
    eval "$IMAGE_DETAILS"
    
    if [ -z "$source" ] || [ -z "$dockerfile" ]; then
        echo "Error: Missing source or dockerfile for image $IMAGE_TAG"
        echo "Source: $source"
        echo "Dockerfile: $dockerfile"
        return 1
    fi
    
    echo "Building image $tag from source: $source, dockerfile: $dockerfile"
    
    # Construct full paths
    DOCKERFILE_PATH="$source/$dockerfile"
    BUILD_CONTEXT="$source"
    
    # Verify files exist
    if [ ! -f "$DOCKERFILE_PATH" ]; then
        echo "Error: Dockerfile not found at $DOCKERFILE_PATH"
        return 1
    fi
    
    if [ ! -d "$BUILD_CONTEXT" ]; then
        echo "Error: Build context directory not found at $BUILD_CONTEXT"
        return 1
    fi
    
    echo "Building with:"
    echo "  Tag: $tag"
    echo "  Dockerfile: $DOCKERFILE_PATH"
    echo "  Context: $BUILD_CONTEXT"

    # Build using docker (GitHub Actions/CircleCI standard)
    if command -v docker >/dev/null 2>&1; then
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
        echo "Error: Docker not found. This script requires Docker to be available."
        return 1
    fi
    
    echo "Successfully built image: $tag"
}

# Build all images
for image in $images; do
    if ! build_image "$image"; then
        echo "Failed to build image: $image"
        exit 1
    fi
    echo ""
done

echo "All images built successfully!"
