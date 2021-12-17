#!/usr/bin/env bash

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
