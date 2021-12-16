#!/usr/bin/env bash

set -e

pushd() {
  command pushd "$@" > /dev/null
}

popd() {
  command popd > /dev/null
}

function get_version {
  local PATCHES_DIR=$1

  pushd "$PATCHES_DIR"

  VERSION=$(cat GIT_TAG)

  popd

  echo "$VERSION"
}

function checkout_kubernetes {
  local VERSION=$1
  local KUBERNETES_DIR=$2

  pushd "$KUBERNETES_DIR"

  if ! git config remote.upstream.url > /dev/null; then
    git remote add upstream https://github.com/kubernetes/kubernetes.git
  fi
  git fetch upstream
  git checkout "$VERSION"

  popd
}

function apply_patches {
  local PATCHES_DIR=$1
  local KUBERNETES_DIR=$2

  pushd "$KUBERNETES_DIR"

  for FILE in "$PATCHES_DIR"/*.patch; do
    if git am < "$FILE"; then
      echo "Applying succeeded: $FILE"
    else
      echo "Applying failed: $FILE"
      git am --skip

      popd

      return 1
    fi
  done

  popd
}

read -p "Apply patches and create an EKSDataPlaneKubernetes CR too? It will be easier to review your EKSDataPlanePatches CR with a corresponding EKSDataPlaneKubernetes CR showing the applied patches. y/n? " -n 1 -r
echo
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  if [[ ! -d "../EKSDataPlaneKubernetes" ]]; then
    brazil ws use -p EKSDataPlaneKubernetes
  fi

  echo "Which patches to apply?"
  select PATCHES_DIR in patches/*; do test -n "$PATCHES_DIR" && break; done
  PATCHES_DIR="$PWD/$PATCHES_DIR"

  VERSION=$(get_version "$PATCHES_DIR")

  checkout_kubernetes "$VERSION" "$PWD/../EKSDataPlaneKubernetes"

  SUCCESS=n
  PUBLIC_PATCHES_DIR="$PATCHES_DIR/public"
  echo "Applying public patches in $PUBLIC_PATCHES_DIR to kubernetes $VERSION"
  if apply_patches "$PUBLIC_PATCHES_DIR" "$PWD/../EKSDataPlaneKubernetes"; then
    PRIVATE_PATCHES_DIR="$PATCHES_DIR/private"
    echo "Applying private patches in $PRIVATE_PATCHES_DIR to kubernetes $VERSION"
    if apply_patches "$PRIVATE_PATCHES_DIR" "$PWD/../EKSDataPlaneKubernetes"; then
      SUCCESS=y
    fi
  fi

  if [[ "$SUCCESS" = "y" ]]; then
    read -p "All patches succeeded. Create a CR to EKSDataPlaneKubernetes? y/n? " -n 1 -r
  else
    read -p "Some patches failed. Create a CR to EKSDataPlaneKubernetes with the patches that succeeded anyway? y/n? " -n 1 -r
  fi

  echo
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    pushd "$PWD/../EKSDataPlaneKubernetes"
    cr --new-review --parent $VERSION
    echo "Please link to your EKSDataPlaneKubernetes CR from your EKSKubernetesPatches CR!"
  fi
fi
