#!/usr/bin/env bash

REPO_ROOT="$(git rev-parse --show-toplevel)"
source "$REPO_ROOT/hack/lib/patch.sh"

set -e
set -u

KUBERNETES_DIR=$(realpath "$1")
PARENT_PATCHES_DIR=$(realpath "$2")

check_dirty "$REPO_ROOT"
PARENT_PATCHES_DIR_PATTERN=".*/patches/1.[0-9][0-9]"
if [[ "$PARENT_PATCHES_DIR" =~ $PARENT_PATCHES_DIR_PATTERN/public ]]; then
  PARENT_PATCHES_DIR=$(realpath "$PARENT_PATCHES_DIR"/..)
  prepare_patches_public "$KUBERNETES_DIR" "$PARENT_PATCHES_DIR"
elif [[ "$PARENT_PATCHES_DIR" =~ $PARENT_PATCHES_DIR_PATTERN/private ]]; then
  PARENT_PATCHES_DIR=$(realpath "$PARENT_PATCHES_DIR"/..)
  prepare_patches_private "$KUBERNETES_DIR" "$PARENT_PATCHES_DIR"
elif [[ "$PARENT_PATCHES_DIR" =~ $PARENT_PATCHES_DIR_PATTERN ]]; then
  prepare_patches_all "$KUBERNETES_DIR" "$PARENT_PATCHES_DIR"
else
  echo "PARENT_PATCHES_DIR must match pattern $PARENT_PATCHES_DIR_PATTERN"
  exit 1
fi
