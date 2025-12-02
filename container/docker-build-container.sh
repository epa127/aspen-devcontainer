#!/bin/bash
# Smart Docker build helper for CS2690 / Aspen dev containers.
# Automatically builds x86_64 (amd64) images on both Intel and Apple Silicon hosts.

set -e
cd "$(dirname "$0")"

# Default image name and tag
IMAGE_NAME="cs2690"
TAG="latest"

# Detect host architecture
HOST_ARCH="$(uname -m)"

# Default platform: always build amd64, even if host is arm64 (M1/M2/M3)
PLATFORM="linux/amd64"

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -x|--x86|--amd64|--x86_64)
            PLATFORM="linux/amd64"
            TAG="latest"
            shift
            ;;
        -a|--arm|--arm64)
            if [[ "$HOST_ARCH" == "arm64" || "$HOST_ARCH" == "aarch64" ]]; then
                PLATFORM="linux/arm64"
                TAG="arm64"
                shift
            else
                echo "Error: --arm64 builds only supported on ARM hosts." >&2
                exit 1
            fi
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--x86|--arm] [--tag <name>]"
            echo
            echo "Examples:"
            echo "  $0                # build linux/amd64 (default, safe on Apple Silicon)"
            echo "  $0 --arm          # build native linux/arm64 if on Apple Silicon"
            echo "  $0 --tag dev      # tag image as cs2690:dev"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Show configuration
echo "Building image:"
echo "  Host architecture : $HOST_ARCH"
echo "  Target platform   : $PLATFORM"
echo "  Dockerfile        : Dockerfile"
echo "  Tag               : ${IMAGE_NAME}:${TAG}"
echo

# Build image
docker build \
    --platform "$PLATFORM" \
    -t "${IMAGE_NAME}:${TAG}" \
    -f Dockerfile \
    .

echo
echo "Successfully built ${IMAGE_NAME}:${TAG} for ${PLATFORM}"