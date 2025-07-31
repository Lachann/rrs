#!/bin/sh
set -e

# Colors for output (using printf instead of echo -e for sh compatibility)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

printf "${GREEN}Starting Monk deployment...${NC}\n"

# Validate required environment variables
if [ -z "$MONKCODE" ]; then
    printf "${RED}Error: MONKCODE environment variable is required${NC}\n"
    exit 1
fi

if [ -z "$MONK_TAG" ]; then
    printf "${YELLOW}Warning: MONK_TAG not set, using 'default'${NC}\n"
    export MONK_TAG="default"
fi

if [ -z "$MONK_WORKLOAD" ]; then
    printf "${YELLOW}Warning: MONK_WORKLOAD not set, will use MANIFEST entrypoint${NC}\n"
    export MONK_WORKLOAD="rrs/stack"
fi

# Validate and login to Monk CLI
if [ -z "$MONK_USERNAME" ] || [ -z "$MONK_PASSWORD" ]; then
    printf "${RED}Error: MONK_USERNAME and MONK_PASSWORD environment variables are required for authentication${NC}\n"
    exit 1
fi

printf "${GREEN}Authenticating with Monk CLI...${NC}\n"
monk --nofancy --no-interactive login -u "$MONK_USERNAME" -p "$MONK_PASSWORD"

# Validate registry credentials for image pushing
if [ -n "$REGISTRY_ADDRESS" ] && [ -n "$REGISTRY_USERNAME" ] && [ -n "$REGISTRY_PASSWORD" ]; then
    printf "${GREEN}Registry credentials found - images will be pushed to $REGISTRY_ADDRESS${NC}\n"
elif [ -n "$REGISTRY_ADDRESS" ] || [ -n "$REGISTRY_USERNAME" ] || [ -n "$REGISTRY_PASSWORD" ]; then
    printf "${YELLOW}Warning: Partial registry credentials provided. All three (REGISTRY_ADDRESS, REGISTRY_USERNAME, REGISTRY_PASSWORD) are needed for image pushing${NC}\n"
fi

# Parse MANIFEST for images that need building
printf "${GREEN}Analyzing project structure...${NC}\n"
if [ -f "MANIFEST" ]; then
    echo "Found MANIFEST file"
    
    # Get images from MANIFEST
    images=$(./scripts/parse-manifest.sh get-images)
    if [ -n "$images" ]; then
        printf "${GREEN}Building container images...${NC}\n"
        for image in $images; do
            printf "${YELLOW}Building image: $image${NC}\n"
            ./scripts/build-images.sh "$image"
        done
    else
        echo "No images found in MANIFEST"
    fi
else
    printf "${RED}Error: MANIFEST file not found${NC}\n"
    exit 1
fi

# Load MANIFEST using monk with cluster connection
printf "${GREEN}Loading MANIFEST...${NC}\n"
monk --nofancy --no-interactive -s monkcode://$MONKCODE load MANIFEST

# Deploy workload using monk with cluster connection
printf "${GREEN}Deploying workload $MONK_WORKLOAD to tag $MONK_TAG...${NC}\n"
monk --nofancy --no-interactive -s monkcode://$MONKCODE update -t "$MONK_TAG" "$MONK_WORKLOAD"

printf "${GREEN}Deployment completed successfully!${NC}\n"

# Show status
printf "${GREEN}Deployment status:${NC}\n"
monk --nofancy --no-interactive -s monkcode://$MONKCODE ps
