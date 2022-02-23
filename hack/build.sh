#!/usr/bin/env bash

set -e
set -u

KUBERNETES_DIR=$(realpath "$1")
BASEPATH=$(dirname "$0")

pushd $KUBERNETES_DIR
make all WHAT="cmd/$WHAT" KUBE_BUILD_PLATFORMS="linux/amd64"
popd
docker build -t registry/$WHAT:latest -f $BASEPATH/Dockerfile "$KUBERNETES_DIR" --build-arg WHAT=$WHAT
echo "binary placed at _output/dockerized/bin/linux/amd64/$WHAT"
echo "image created with tag registry/$WHAT:latest . Retag and publish to your favorite account."
