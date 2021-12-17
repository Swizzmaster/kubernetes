#!/usr/bin/env bash

REPO_ROOT="$(git rev-parse --show-toplevel)"
source "$REPO_ROOT/hack/lib/patch.sh"

set -e

read -p "Apply patches and create an EKSDataPlaneKubernetes CR too? It will be easier to review your EKSDataPlanePatches CR with a corresponding EKSDataPlaneKubernetes CR showing the applied patches. y/n? " -n 1 -r
echo
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  KUBERNETES_DIR="$PWD/../EKSDataPlaneKubernetes"
  if [[ ! -d "$KUBERNETES_DIR" ]]; then
    brazil ws use -p EKSDataPlaneKubernetes
  fi

  echo "Which patches to apply?"
  select PARENT_PATCHES_DIR in patches/*; do test -n "$PARENT_PATCHES_DIR" && break; done
  PARENT_PATCHES_DIR="$PWD/$PARENT_PATCHES_DIR"
  if apply_patches_public_private "$PARENT_PATCHES_DIR" "$KUBERNETES_DIR"; then
    read -p "Create a CR to EKSDataPlaneKubernetes? y/n? " -n 1 -r
  else
    read -p "Create a CR to EKSDataPlaneKubernetes with the patches that succeeded anyway? y/n? " -n 1 -r
  fi
  echo
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    pushd "$PWD/../EKSDataPlaneKubernetes"
    cr --new-review --parent "$VERSION"
    echo "Please link to your EKSDataPlaneKubernetes CR from your EKSKubernetesPatches CR!"
  fi
fi
