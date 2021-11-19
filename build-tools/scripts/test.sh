#!/usr/bin/env bash
#set -x
set -o errexit
set -o nounset
set -o pipefail

REPO=$1

if [[ -z ${REPO} ]]; then
    echo "Provide the full path of the kubernetes repo on the local box"
    exit 1
fi

if [[ ! -d ${REPO} ]]; then
    echo "Invalid directory ${REPO}"
    exit 1
fi

pushd ${REPO}

export CGO_ENABLED=0
export GOLDFLAGS='-s -w -buildid=""'
export KUBE_STATIC_OVERRIDES="cmd/kubelet \
        cmd/kube-proxy \
        cmd/kubeadm \
        cmd/kubectl \
        cmd/kube-apiserver \
        cmd/kube-controller-manager \
        cmd/kube-scheduler"
make generated_files
export KUBE_BUILD_PLATFORMS="linux/amd64"
	hack/make-rules/build.sh -trimpath cmd/kubelet \
        cmd/kube-proxy \
        cmd/kubeadm \
        cmd/kubectl \
        cmd/kube-apiserver \
        cmd/kube-controller-manager \
        cmd/kube-scheduler

eval $(./hack/install-etcd.sh | grep PATH)

make test

