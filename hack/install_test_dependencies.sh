#!/usr/bin/env bash

set -e
set -u

KUBERNETES_DIR=$(realpath "$1")

install_golang() {
  local GOLANG_VERSION=$1

  wget -q https://golang.org/dl/go"$GOLANG_VERSION".linux-amd64.tar.gz
  tar -C /usr/local -xzf go"$GOLANG_VERSION".linux-amd64.tar.gz
  export PATH=/usr/local/go/bin:$PATH
}

get_kubernetes_go_version() {
  local KUBERNETES_DIR=$1

  pushd "$KUBERNETES_DIR" > /dev/null

  local GOLANG_VERSION=$(grep build/dependencies.yaml -A1 -e 'golang: upstream version' | awk '/version:/ {print $2}')

  popd > /dev/null

  echo "$GOLANG_VERSION"
}

packages=(
  gcc
  git
  make
  rsync
  wget
  curl
  net-tools
)
if ! command -v apt-get &> /dev/null; then
  echo "apt-get not found, assuming [${packages[*]}] packages are already installed"
else
  apt-get update
  apt-get install -q -y "${packages[@]}"
fi

if ! command -v go version &> /dev/null; then
  GOLANG_VERSION=$(get_kubernetes_go_version "$KUBERNETES_DIR")
  install_golang "$GOLANG_VERSION"
fi
go version
