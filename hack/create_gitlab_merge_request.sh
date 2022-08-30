#!/usr/bin/env bash

REPO_ROOT="$(git rev-parse --show-toplevel)"
source "$REPO_ROOT/hack/lib/patch.sh"

set -e
set -u

PARENT_PATCHES_DIR=$(realpath "$1")
MINOR_VERSION="$2"

if git diff --exit-code "$PARENT_PATCHES_DIR"/GIT_TAG; then
  echo "No diff to merge"
  exit 0
fi

LATEST_VERSION=$(get_patches_base_version "$PARENT_PATCHES_DIR")
MESSAGE="Update $MINOR_VERSION patches base version to $LATEST_VERSION"
git checkout -b update_patches_base_version_"$MINOR_VERSION"
git add "$PARENT_PATCHES_DIR"/GIT_TAG
git commit -m "$MESSAGE"
git push -o merge_request.create -o merge_request.merge_when_pipeline_succeeds -o merge_request.remove_source_branch https://gitlab-ci-token:"$PROJECT_ACCESS_TOKEN"@gitlab.aws.dev/"$CI_PROJECT_PATH".git update_patches_base_version_"$MINOR_VERSION" --force

git checkout @{-1}
git branch -D update_patches_base_version_"$MINOR_VERSION"
