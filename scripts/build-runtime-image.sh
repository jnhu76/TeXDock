#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE_NAME="${IMAGE_NAME:-{USERNAME}/sharelatex}"
IMAGE_VERSION="${IMAGE_VERSION:-0.2.0}"
BASE_IMAGE="${BASE_IMAGE:-sharelatex/sharelatex:5.5.8}"
DOCKERFILE="${DOCKERFILE:-server-ce/Dockerfile-runtime}"

echo "Building TeXDock runtime overlay image"
echo "  base:    $BASE_IMAGE"
echo "  image:   $IMAGE_NAME:$IMAGE_VERSION"
echo "  latest:  $IMAGE_NAME:latest"
echo

DOCKER_BUILDKIT=1 docker build \
  --build-arg BASE_IMAGE="$BASE_IMAGE" \
  -f "$DOCKERFILE" \
  -t "$IMAGE_NAME:$IMAGE_VERSION" \
  -t "$IMAGE_NAME:latest" \
  .
