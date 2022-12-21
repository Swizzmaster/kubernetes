#!/usr/bin/env bash

REPO_ROOT="$(git rev-parse --show-toplevel)"
source "$REPO_ROOT/hack/lib/util.sh"
PATCH_NUM_FORMAT_LEN=4

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

function clone_kubernetes {
  local KUBERNETES_DIR=$1

  if [ ! "$(ls -A "$KUBERNETES_DIR")" ]; then
    echo "Your $KUBERNETES_DIR repository is empty.  Cloning."
    git clone https://github.com/kubernetes/kubernetes.git "$KUBERNETES_DIR" --origin upstream
  fi
}

function checkout_kubernetes {
  local VERSION=$1
  local KUBERNETES_DIR=$2

  pushd "$KUBERNETES_DIR"

  if ! git config remote.upstream.url > /dev/null; then
    git remote add upstream https://github.com/kubernetes/kubernetes.git
  fi
  git fetch upstream --tags -f
  git checkout "$VERSION"

  popd
}

# gets the kubernetes version that patches in PATCHES_DIR apply to
function get_patches_base_version {
  local PATCHES_DIR=$1

  pushd "$PATCHES_DIR"

  VERSION=$(cat GIT_TAG)

  popd

  echo "$VERSION"
}

# gets the latest kubernetes version which patches in PATCHES_DIR *may* apply to
function get_latest_patch_version_for_minor {
  local PATCHES_DIR=$1
  local KUBERNETES_DIR=$2

  local VERSION=$(get_patches_base_version "$1")
  local MINOR_VERSION=${VERSION%.*}

  pushd "$KUBERNETES_DIR"

  git fetch upstream --tags -f
  local LATEST_VERSION=$(git tag --sort creatordate | grep "$MINOR_VERSION"'.[0-9]*$' | tail -n1)

  popd

  echo "$LATEST_VERSION"
}

function update_patches_base_version {
  local PATCHES_DIR=$1
  local KUBERNETES_DIR=$2

  local LATEST_VERSION=$(get_latest_patch_version_for_minor "$1" "$2")
  local MINOR_VERSION=${LATEST_VERSION%.*}

  echo "$LATEST_VERSION" > "$PATCHES_DIR"/GIT_TAG

  if git diff --exit-code "$PATCHES_DIR"/GIT_TAG; then
    echo "No new $MINOR_VERSION patches base version found"
  else
    echo "New $MINOR_VERSION patches base version $LATEST_VERSION found"
  fi
}

function apply_patches {
  local PATCHES_DIR=$1
  local KUBERNETES_DIR=$2
  local STARTING_PATCH_NUM=$3

  pushd "$KUBERNETES_DIR"

  if [[ -n "$(ls $PATCHES_DIR)" ]]; then
    local patches=$(get_patches ${PATCHES_DIR} ${STARTING_PATCH_NUM})
    echo "Patches to apply: ${patches}"
    for file in ${patches}; do
      if git am < "$file"; then
        echo "Applying succeeded: $file"
      else
        echo "Applying failed: $file"
        git am --skip
        popd
        return 1
      fi
    done
  else
    echo "Nothing to apply in $PATCHES_DIR"
  fi

  popd
}

function get_patches {
  local PATCHES_DIR=$1
  local STARTING_PATCH_NUM=$2
  declare -a patches

  for file in "${PATCHES_DIR}"/*.patch; do
    patch_number=$(get_patch_number $file)
    if ((patch_number >= STARTING_PATCH_NUM)); then
      patches+=($file)
    fi
  done
  echo ${patches[@]}
}

# Extract patch number from filename
function get_patch_number {
  local file=$1
  local patch_number=$(basename $file | head -c $PATCH_NUM_FORMAT_LEN)
  # remove leading 0's from patch number
  echo "${patch_number}" | sed -E 's/^[0]+//g'
}

function validate_patch_number {
  local patch_number=$1
  if ! echo "${patch_number}" | grep -E "[[:digit:]]{1,4}" > /dev/null; then
    echo "Invalid patch number"
    return 1
  fi
}

function apply_patches_all {
  local PARENT_PATCHES_DIR=$1
  local KUBERNETES_DIR=$2
  local STARTING_PATCH=$3
  local PUBLIC_PATCHES_DIR="$PARENT_PATCHES_DIR/0-public"
  local PRIVATE_PATCHES_DIR="$PARENT_PATCHES_DIR/1-private"

  local VERSION=$(get_patches_base_version "$PARENT_PATCHES_DIR")

  if [[ $STARTING_PATCH == "0" ]]; then
    echo "Checking out $VERSION in $KUBERNETES_DIR"
    checkout_kubernetes "$VERSION" "$KUBERNETES_DIR"
    echo "$VERSION checked out!"
  else
    echo "Starting from patch $STARTING_PATCH."
    echo "Assuming previous patches are already applied in $KUBERNETES_DIR"
  fi

  echo "Applying patches in $PARENT_PATCHES_DIR to $KUBERNETES_DIR..."
  echo "Applying public patches in $PUBLIC_PATCHES_DIR to $KUBERNETES_DIR..."
  if apply_patches "$PUBLIC_PATCHES_DIR" "$KUBERNETES_DIR" "$STARTING_PATCH"; then
    echo "Applying private patches in $PRIVATE_PATCHES_DIR to $KUBERNETES_DIR..."
    if apply_patches "$PRIVATE_PATCHES_DIR" "$KUBERNETES_DIR" "$STARTING_PATCH"; then
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
  git -c diff.noprefix=false format-patch \
    --abbrev=11 \
    --zero-commit \
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
  git rev-list --reverse --grep='--EKS-PRIVATE--' ${RANGE_START}..${RANGE_END} | wc -l | sed 's/[[:space:]]*//'
  popd
}

function num_public() {
  local KUBERNETES_DIR=$1
  local RANGE_START=$2
  local RANGE_END=$3

  pushd "$KUBERNETES_DIR"
  git rev-list --reverse --invert-grep --grep='--EKS-PRIVATE--' ${RANGE_START}..${RANGE_END} | wc -l | sed 's/[[:space:]]*//'
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

  if [[ -z "${PATCHES_DIR}" ]]; then
    echo "remove_patches: PATCHES_DIR cannot be empty."
    exit 1
  fi

  if [[ -n "$(ls $PATCHES_DIR)" ]]; then
    rm ${PATCHES_DIR}/*
  fi
}
