#!/usr/bin/env bash

REPO_ROOT="$(git rev-parse --show-toplevel)"
source "$REPO_ROOT/hack/lib/util.sh"

function check_dirty {
  local KUBERNETES_DIR=$1

  pushd "$KUBERNETES_DIR"

  if ! git diff-index --quiet HEAD --; then
    echo "Your $KUBERNETES_DIR repository is in a dirty state.  Exiting.  Stash, commit or reset your in progress work."

    popd

    return 1
  fi

  popd
}

function checkout_kubernetes {
  local VERSION=$1
  local KUBERNETES_DIR=$2

  pushd "$KUBERNETES_DIR"

  if ! git config remote.upstream.url > /dev/null; then
    git remote add upstream https://github.com/kubernetes/kubernetes.git
  fi
  git fetch upstream --tags
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

function apply_patches_all {
  local PARENT_PATCHES_DIR=$1
  local KUBERNETES_DIR=$2
  local PUBLIC_PATCHES_DIR="$PARENT_PATCHES_DIR/0-public"
  local PRIVATE_PATCHES_DIR="$PARENT_PATCHES_DIR/1-private"

  local VERSION=$(get_version "$PARENT_PATCHES_DIR")
  echo "Checking out $VERSION in $KUBERNETES_DIR"
  checkout_kubernetes "$VERSION" "$KUBERNETES_DIR"
  echo "$VERSION checked out!"

  echo "Applying patches in $PARENT_PATCHES_DIR to $KUBERNETES_DIR..."
  echo "Applying public patches in $PUBLIC_PATCHES_DIR to $KUBERNETES_DIR..."
  if apply_patches "$PUBLIC_PATCHES_DIR" "$KUBERNETES_DIR"; then
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

function prepare_patches {
  local KUBERNETES_DIR=$1
  local PATCHES_DIR=$2
  local START_NUM=$3
  local RANGE_START=$4
  local RANGE_END=$5

  pushd "$KUBERNETES_DIR"
  git format-patch \
    --no-numbered \
    --no-signature \
    --start-number "$START_NUM" \
    "$RANGE_START"..$RANGE_END \
    --output-directory $PATCHES_DIR
  popd
}

function prepare_patches_public {
  local KUBERNETES_DIR=$1
  local PARENT_PATCHES_DIR=$2
  local PUBLIC_PATCHES_DIR="$PARENT_PATCHES_DIR/0-public"

  local RANGE_START=$(cat "$PARENT_PATCHES_DIR"/GIT_TAG)
  local NUM_PRIVATE=$(num_private $KUBERNETES_DIR $RANGE_START HEAD)
  local START_NUM=1
  local RANGE_END=HEAD~"$NUM_PRIVATE"

  remove_patches "${PUBLIC_PATCHES_DIR}"
  mkdir -p "${PUBLIC_PATCHES_DIR}"
  prepare_patches "$KUBERNETES_DIR" "$PUBLIC_PATCHES_DIR" "$START_NUM" "$RANGE_START" "$RANGE_END"
}

function prepare_patches_private {
  local KUBERNETES_DIR=$1
  local PARENT_PATCHES_DIR=$2
  local PRIVATE_PATCHES_DIR="$PARENT_PATCHES_DIR/1-private"

  local RANGE_START=$(cat "$PARENT_PATCHES_DIR"/GIT_TAG)
  local NUM_PUBLIC=$(num_public $KUBERNETES_DIR $RANGE_START HEAD)
  local NUM_PRIVATE=$(num_private $KUBERNETES_DIR $RANGE_START HEAD)
  local START_NUM="$(($NUM_PUBLIC + 1))"
  local RANGE_START=HEAD~"$NUM_PRIVATE"
  local RANGE_END=HEAD

  remove_patches "${PRIVATE_PATCHES_DIR}"
  mkdir -p "${PRIVATE_PATCHES_DIR}"
  prepare_patches "$KUBERNETES_DIR" "$PRIVATE_PATCHES_DIR" "$START_NUM" "$RANGE_START" "$RANGE_END"
}

function num_private() {
  local KUBERNETES_DIR=$1
  local RANGE_START=$2
  local RANGE_END=$3

  pushd "$KUBERNETES_DIR"
  echo "$(git rev-list --reverse --grep='--EKS-PRIVATE--' ${RANGE_START}..${RANGE_END})" | wc -l
  popd
}

function num_public() {
  local KUBERNETES_DIR=$1
  local RANGE_START=$2
  local RANGE_END=$3

  pushd "$KUBERNETES_DIR"
  echo "$(git rev-list --reverse --invert-grep --grep='--EKS-PRIVATE--' ${RANGE_START}..${RANGE_END})" | wc -l
  popd
}

function prepare_patches_all {
  local KUBERNETES_DIR=$1
  local PARENT_PATCHES_DIR=$2

  prepare_patches_public "$KUBERNETES_DIR" "$PARENT_PATCHES_DIR"
  prepare_patches_private "$KUBERNETES_DIR" "$PARENT_PATCHES_DIR"
}

function remove_patches() {
  local PATCHES_DIR=$1

  files=($(ls $PATCHES_DIR))
  for file in ${files[@]}; do
      rm ${PATCHES_DIR}/$file
  done
}
