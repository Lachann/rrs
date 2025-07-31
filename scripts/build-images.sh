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
            
            # Try logging in with automatic HTTP fallback for insecure registries
            REGISTRY_URL="$REGISTRY_ADDRESS"
            LOGIN_OUTPUT=$(echo "$REGISTRY_PASSWORD" | docker login "$REGISTRY_URL" -u "$REGISTRY_USERNAME" --password-stdin 2>&1)
            LOGIN_RESULT=$?
            
            if [ $LOGIN_RESULT -eq 0 ]; then
                echo "Successfully logged into registry $REGISTRY_URL"
            elif echo "$LOGIN_OUTPUT" | grep -q "server gave HTTP response to HTTPS client"; then
                echo "HTTPS failed, trying HTTP for insecure registry..."
                # Convert HTTPS to HTTP if not already HTTP
                REGISTRY_URL=$(echo "$REGISTRY_ADDRESS" | sed 's|^https://|http://|' | sed 's|^[^:/]*:|http://&|' | sed 's|^http://http://|http://|')
                echo "Trying registry URL: $REGISTRY_URL"
                
                if echo "$REGISTRY_PASSWORD" | docker --tlsverify=false login "$REGISTRY_URL" -u "$REGISTRY_USERNAME" --password-stdin; then
                    echo "Successfully logged into insecure registry $REGISTRY_URL"
                    REGISTRY_ADDRESS="$REGISTRY_URL"  # Update address for push operations
                else
                    echo "Login failed even with HTTP. Check registry credentials and connectivity."
                    return 1
                fi
            else
                echo "Login failed: $LOGIN_OUTPUT"
                echo "Check registry credentials and connectivity"
                return 1
            fi
            
            echo "Tagging and pushing to registry..."
            if docker tag "$tag" "$REGISTRY_ADDRESS/$tag"; then
                echo "Successfully tagged image"
            else
                echo "Failed to tag image"
                docker logout "$REGISTRY_ADDRESS" 2>/dev/null
                return 1
            fi
            
            if docker push "$REGISTRY_ADDRESS/$tag"; then
                echo "Successfully pushed $tag to $REGISTRY_ADDRESS"
            else
                echo "Failed to push image to registry"
                echo "This may be due to an insecure (HTTP) registry or network issues"
                docker logout "$REGISTRY_ADDRESS" 2>/dev/null
                return 1
            fi
            
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
