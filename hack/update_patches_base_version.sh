#!/usr/bin/env bash

REPO_ROOT="$(git rev-parse --show-toplevel)"
source "$REPO_ROOT/hack/lib/patch.sh"

set -e
set -u

PARENT_PATCHES_DIR=$(realpath "$1")
KUBERNETES_DIR=$(realpath "$2")

clone_kubernetes "$KUBERNETES_DIR"
update_patches_base_version "$PARENT_PATCHES_DIR" "$KUBERNETES_DIR"
