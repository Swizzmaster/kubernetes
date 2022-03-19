#!/bin/bash

set -e
set -u

KUBERNETES_DIR=$(realpath "$1")
BASEPATH=$(dirname "$0")

pushd $KUBERNETES_DIR
echo "Registry $REGISTRY"
if [[ -z "$REGISTRY" ]]; then
	echo "export REGISTRY. eg. export REGISTRY=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"
fi
if [[ -z "$VERSION_TAG" ]]; then
	echo "export VERSION_TAG. eg. export VERSION_TAG=v1.22.6"
fi
# IMAGE_TAG is very sensitive to many tools.
# Don't change the pattern, else we will run into regression like https://github.com/aws/containers-roadmap/issues/1404#issuecomment-884751824
if [[ -z "$IMAGE_TAG" ]]; then
	echo "export IMAGE_TAG. eg. export VERSION_TAG=v1.22.6-eks-test"
fi

KUBE_MINOR_VERSION=$(echo "${VERSION_TAG}" | awk -F. '{print $2}')
export KUBE_BUILD_CONFORMANCE=n
export KUBE_FASTBUILD=false
export KUBE_DOCKER_REGISTRY=$REGISTRY
export KUBE_DOCKER_IMAGE_TAG=$VERSION_TAG
export KUBE_GIT_VERSION=$IMAGE_TAG

echo "REGISTRY: $REGISTRY"
echo "VERSION_TAG: $VERSION_TAG"
echo "IMAGE_TAG: $IMAGE_TAG"

docker system prune -f
docker volume prune -f
make quick-release
# kube-apiserver
docker load -i _output/release-images/amd64/kube-apiserver.tar
docker tag $REGISTRY/kube-apiserver-amd64:$VERSION_TAG $REGISTRY/eks/kube-apiserver:$IMAGE_TAG-linux_amd64

# kube-controller-manager
docker load -i _output/release-images/amd64/kube-controller-manager.tar
docker tag $REGISTRY/kube-controller-manager-amd64:$VERSION_TAG $REGISTRY/eks/kube-controller-manager:$IMAGE_TAG-linux_amd64

# kube-scheduler
docker load -i _output/release-images/amd64/kube-scheduler.tar
docker tag $REGISTRY/kube-scheduler-amd64:$VERSION_TAG $REGISTRY/eks/kube-scheduler:$IMAGE_TAG-linux_amd64

# build pause
pushd $KUBERNETES_DIR/build/pause
PAUSE_TAG="$(grep "^TAG = " Makefile | awk '{print $NF}')"
# Notice the nuance in - and _ for the tags. The docker manifest upload code expects the _arch
# https://code.amazon.com/packages/EKSDataPlaneCDK/blobs/mainline/--/eks_code_pipeline/build_deploy_scripts/upload.sh
PAUSE_IMAGE_AMD64="pause:${PAUSE_TAG}-linux-amd64"
PAUSE_IMAGE_ARM64="pause:${PAUSE_TAG}-linux-arm64"
PAUSE_IMAGE_MULTIARCH_AMD64="pause:${PAUSE_TAG}-linux_amd64"
PAUSE_IMAGE_MULTIARCH_ARM64="pause:${PAUSE_TAG}-linux_arm64"
if (( KUBE_MINOR_VERSION < 21 )); then
  PAUSE_IMAGE_AMD64="pause-linux-amd64:${PAUSE_TAG}"
  PAUSE_IMAGE_ARM64="pause-linux-arm64:${PAUSE_TAG}"
  PAUSE_IMAGE_MULTIARCH_AMD64="pause:${PAUSE_TAG}-linux_amd64"
  PAUSE_IMAGE_MULTIARCH_ARM64="pause:${PAUSE_TAG}-linux_arm64"
fi

REGISTRY=$REGISTRY/eks ARCH=amd64 make container
docker image tag $REGISTRY/eks/${PAUSE_IMAGE_AMD64} $REGISTRY/eks/${PAUSE_IMAGE_MULTIARCH_AMD64}

REGISTRY=$REGISTRY/eks ARCH=arm64 make container
docker image tag $REGISTRY/eks/${PAUSE_IMAGE_ARM64} $REGISTRY/eks/${PAUSE_IMAGE_MULTIARCH_ARM64}

popd
popd
