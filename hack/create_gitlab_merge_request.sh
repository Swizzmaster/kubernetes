#!/usr/bin/env bash

REPO_ROOT="$(git rev-parse --show-toplevel)"
source "$REPO_ROOT/hack/lib/patch.sh"

set -eux

PARENT_PATCHES_DIR=$(realpath "$1")
MINOR_VERSION="$2"

if git diff --exit-code "$PARENT_PATCHES_DIR"/GIT_TAG; then
  echo "No diff to merge"
  exit 0
fi

LATEST_VERSION=$(get_patches_base_version "$PARENT_PATCHES_DIR")
MESSAGE="Update $MINOR_VERSION patches base version to $LATEST_VERSION"
BRANCH=update_patches_base_version_"$MINOR_VERSION"

set +e
git branch -D "$BRANCH"
set -e
git checkout -b "$BRANCH"
git add "$PARENT_PATCHES_DIR"/GIT_TAG
git commit -m "$MESSAGE"

# Only force push if pipeline was last committer or if branch DNE yet
git fetch origin
set +e
if git rev-parse --verify origin/"$BRANCH"; then
  AUTHOR=$(git show -s --format='%ae' origin/"$BRANCH")
  BRANCH_DNE=""
  echo "$AUTHOR was last committer, it's safe to force push"
else
  AUTHOR=""
  BRANCH_DNE="1"
  echo "origin/$BRANCH doesn't exist yet, it's safe to force push"
fi
set -e

if [[ $AUTHOR == *"eks-dataplane-team"* ]] || [[ $BRANCH_DNE == "1" ]]; then
  echo "Pushing origin/$BRANCH"
  git remote add origin_push https://gitlab-ci-token:"$PROJECT_ACCESS_TOKEN"@gitlab.aws.dev/"$CI_PROJECT_PATH".git
  git push -o merge_request.create -o merge_request.merge_when_pipeline_succeeds -o merge_request.remove_source_branch origin_push "$BRANCH" --force
fi

git checkout @{-1}
git branch -D "$BRANCH"
