#!/usr/bin/env bash

set -e
set -u

KUBERNETES_DIR=$(realpath "$1")
BASEPATH=$(dirname "$0")

export CGO_ENABLED=0 GOLDFLAGS='-s -w -buildid=""' KUBE_BUILD_PLATFORMS="linux/amd64"
pushd $KUBERNETES_DIR
make generated_files
hack/make-rules/build.sh -trimpath cmd/$WHAT
popd
docker build -t registry/kube-apiserver:latest -f $BASEPATH/Dockerfile "$KUBERNETES_DIR" --build-arg WHAT=$WHAT