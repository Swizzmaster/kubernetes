#!/usr/bin/env bash

REPO_ROOT="$(git rev-parse --show-toplevel)"
source "$REPO_ROOT/hack/lib/patch.sh"

set -e
set -u

PARENT_PATCHES_DIR=$(realpath "$1")
KUBERNETES_DIR=$(realpath "$2")
STARTING_PATCH_NUM="${3:-0}"
if echo "${STARTING_PATCH_NUM}" | grep -E "^0{1,4}$" > /dev/null; then
  STARTING_PATCH_NUM="0"
else
  # Remove leading zeros if they were supplied
  if ! validate_patch_number $STARTING_PATCH_NUM; then
    exit 1
  fi
  STARTING_PATCH_NUM=$(echo "${STARTING_PATCH_NUM}" | sed -E 's/^[0]+//g')
fi
clone_kubernetes "$KUBERNETES_DIR"
check_dirty "$KUBERNETES_DIR"
apply_patches_all "$PARENT_PATCHES_DIR" "$KUBERNETES_DIR" "$STARTING_PATCH_NUM"
