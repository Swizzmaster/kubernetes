#!/usr/bin/env bash
#set -x
set -o errexit
set -o nounset
set -o pipefail

REPO=$1
PATCH=$2

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [[ -z ${REPO} ]]; then
    echo "Provide the full path of the kubernetes repo on the local box"
    exit 1
fi

if [[ ! -d ${REPO} ]]; then
    echo "Invalid directory ${REPO}"
    exit 1
fi

if [[ ! -f ${PATCH} ]]; then
	echo "path ${PATCH} does not exist"
	exit 1
fi

if ! git -C ${REPO} diff --quiet --exit-code; then
    echo "found unmerged changes in ${REPO}. The git branch should be clean for the script to safely apply a patch"
fi

if ! git -C ${REPO} diff --quiet --cached --exit-code; then
    echo "found staged changes in ${REPO}. The git branch should be clean for the script to safely apply a patch"
    exit 1
fi

if (( $(git -C ${REPO} status --porcelain | wc -l | awk '{print $1}') > 0 )); then
    echo "found untracked changes in ${REPO}. The git branch should be clean for the script to safely apply a patch"
    exit 1
fi

if git -C ${REPO} status | grep session -q; then
   echo "found an active session in ${REPO}. The git branch should be clean for the script to safely apply a patch. Complete the session and try again."
   exit 1
fi

git -C ${REPO} am ${PATCH} &> /dev/null || true
if git -C ${REPO} status | grep session -q; then
   echo -e "Applying patch ${PATCH} failed. Manually resolve the conflict using \e[3mgit format-patch --3way ${PATCH}\e[0m or \e[3mgit format-patch --reject ${PATCH}\e[0m"
   exit 1
else
   echo "Applied ${PATCH}"
fi

trap "popd" EXIT
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
export KUBE_BUILD_PLATFORMS="linux/amd64 linux/arm64"
	hack/make-rules/build.sh -trimpath cmd/kubelet \
        cmd/kube-proxy \
        cmd/kubectl \
        cmd/kube-apiserver \
        cmd/kube-controller-manager \
        cmd/kube-scheduler
