#!/usr/bin/env bash

REPO_ROOT="$(git rev-parse --show-toplevel)"
source "$REPO_ROOT/hack/lib/util.sh"

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

function apply_patches_public_private {
  local PARENT_PATCHES_DIR=$1
  local KUBERNETES_DIR=$2

  VERSION=$(get_version "$PARENT_PATCHES_DIR")
  echo "Checking out $VERSION in $KUBERNETES_DIR"
  checkout_kubernetes "$VERSION" "$KUBERNETES_DIR"
  echo "$VERSION checked out!"

  echo "Applying patches in $PARENT_PATCHES_DIR to $KUBERNETES_DIR..."
  PUBLIC_PATCHES_DIR="$PARENT_PATCHES_DIR/public"
  echo "Applying public patches in $PUBLIC_PATCHES_DIR to $KUBERNETES_DIR..."
  if apply_patches "$PUBLIC_PATCHES_DIR" "$KUBERNETES_DIR"; then
    PRIVATE_PATCHES_DIR="$PARENT_PATCHES_DIR/private"
    echo "Applying private patches in $PRIVATE_PATCHES_DIR to $KUBERNETES_DIR..."
    if apply_patches "$PRIVATE_PATCHES_DIR" "$KUBERNETES_DIR"; then
      echo "All patches succeeded!"
      echo "HEAD is at the last successful patch."
      return 0
    fi
  fi

  echo "A patch failed!"
  echo "HEAD is at the last successful patch."
  return 1
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
