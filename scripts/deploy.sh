#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Monk deployment...${NC}"

# Validate required environment variables
if [ -z "$MONKCODE" ]; then
    echo -e "${RED}Error: MONKCODE environment variable is required${NC}"
    exit 1
fi

if [ -z "$MONK_TAG" ]; then
    echo -e "${YELLOW}Warning: MONK_TAG not set, using 'default'${NC}"
    export MONK_TAG="default"
fi

if [ -z "$MONK_WORKLOAD" ]; then
    echo -e "${YELLOW}Warning: MONK_WORKLOAD not set, will use MANIFEST entrypoint${NC}"
    export MONK_WORKLOAD="rrs/stack"
fi

# Validate registry credentials for image pushing
if [ -n "$REGISTRY_ADDRESS" ] && [ -n "$REGISTRY_USERNAME" ] && [ -n "$REGISTRY_PASSWORD" ]; then
    echo -e "${GREEN}Registry credentials found - images will be pushed to $REGISTRY_ADDRESS${NC}"
elif [ -n "$REGISTRY_ADDRESS" ] || [ -n "$REGISTRY_USERNAME" ] || [ -n "$REGISTRY_PASSWORD" ]; then
    echo -e "${YELLOW}Warning: Partial registry credentials provided. All three (REGISTRY_ADDRESS, REGISTRY_USERNAME, REGISTRY_PASSWORD) are needed for image pushing${NC}"
fi

# login to monk
monk --nofancy --no-interactive login -u $MONK_USERNAME -p $MONK_PASSWORD
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to login to monk${NC}"
    exit 1
fi

# Parse MANIFEST for images that need building
echo -e "${GREEN}Analyzing project structure...${NC}"
if [ -f "MANIFEST" ]; then
    echo "Found MANIFEST file"
    
    # Get images from MANIFEST
    images=$(./scripts/parse-manifest.sh get-images)
    if [ -n "$images" ]; then
        echo -e "${GREEN}Building container images...${NC}"
        for image in $images; do
            echo -e "${YELLOW}Building image: $image${NC}"
            ./scripts/build-images.sh "$image"
        done
    else
        echo "No images found in MANIFEST"
    fi
else
    echo -e "${RED}Error: MANIFEST file not found${NC}"
    exit 1
fi

# Load MANIFEST using monk with cluster connection
echo -e "${GREEN}Loading MANIFEST...${NC}"
monk --nofancy --no-interactive -s monkcode://$MONKCODE load MANIFEST

# Deploy workload using monk with cluster connection
echo -e "${GREEN}Deploying workload $MONK_WORKLOAD to tag $MONK_TAG...${NC}"
monk --nofancy --no-interactive -s monkcode://$MONKCODE update -t "$MONK_TAG" "$MONK_WORKLOAD"

echo -e "${GREEN}Deployment completed successfully!${NC}"

# Show status
echo -e "${GREEN}Deployment status:${NC}"
monk --nofancy --no-interactive -s monkcode://$MONKCODE ps
