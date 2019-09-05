import argparse
import json
import logging
import os
import re
import requests
import sys

from loguru import logger
import click

from .run import ProcessRunner, cd
from .format_patch import format_patch_command
from .util import cloned, ReleaseMetadata, PatchMetadata, eks_tag_pattern, parse_eks_tag

clone_url = "https://git-codecommit.us-west-2.amazonaws.com/v1/repos/kubernetes"
upstream_url = "https://github.com/kubernetes/kubernetes.git"
clone_dir = "kubernetes"

@click.group()
def main(args=sys.argv):
    logger.debug("args: {}", args)

@main.command()
def clone():
    runner = ProcessRunner()

    if cloned(clone_dir):
        print("Already cloned into {}".format(clone_dir))
        return

    ret, out = runner.execute_command("bash -c 'git clone {}'".format(clone_url))
    if ret != 0:
        print("Clone failed: {}".format(out))
        return

    with cd(clone_dir):
        ret, out = runner.execute_command("git remote add upstream {}".format(upstream_url))
        if ret != 0:
            print("Adding remote {} failed: {}".format(upstream_url, out))
            return

        ret, out = runner.execute_command("git checkout master")
        if ret != 0:
            print("Git checkout master failed: {}".format(out))
            return

        ret, out = runner.execute_command("git pull upstream master")
        if ret != 0:
            print("Git pull upstream master failed: {}".format(out))
            return

@main.command()
@click.option("--eks-tag", "-e", default="", help="The eks tag, formatted as v<major>.<minor>.<patch>-eks-<short sha> (v1.12.10-eks-a26503).")
def create(eks_tag):
    runner = ProcessRunner()
    source = "codecommit"

    if not re.match(eks_tag_pattern, eks_tag):
        logger.error("Incorrectly formatted eks-tag.  It should look like: v1.12.10-eks-a26503")
        return

    major, minor, patch, short_sha = parse_eks_tag(eks_tag)
    patch_metadata = PatchMetadata(major, minor, patch, short_sha)

    if not cloned(clone_dir):
        logger.error("Run 'ekspatch clone' first to clone kubernetes.")
        return

    with cd(clone_dir):
        # Fetch eks tag, i.e. v1.12.10-eks-a26503
        ret, out = runner.execute_command("git fetch origin {}".format(eks_tag))
        if ret != 0:
            logger.error("Failed to fetch eks-tag from {}".format(clone_url))
            return

        # Fetch upstream tag, i.e. v1.12.10
        ret, out = runner.execute_command("git fetch origin {}".format(patch_metadata.upstream_tag))
        if ret != 0:
            logger.warning("Failed to fetch upstream tag {} from {}".format(patch_metadata.upstream_tag, clone_url))
            ret, out = runner.execute_command("git fetch upstream {}".format(patch_metadata.upstream_tag))
            logger.info("Trying to find {} upstream...".format(patch_metadata.upstream_tag))
            if ret != 0:
                logger.error("Failed to fetch upstream tag {} from {}".format(patch_metadata.upstream_tag, upstream_url))
                return

        # Fetch eks release branch
        ret, out = runner.execute_command("git fetch origin {}".format(patch_metadata.eks_release_branch))
        if ret != 0:
            logger.debug("Failed to fetch eks release branch {} from {}".format(patch_metadata.eks_release_branch, clone_url))
            return

        ret, out = runner.execute_command("git rev-parse {}".format(patch_metadata.upstream_tag))
        if ret != 0:
            logger.error("Failed getting revision of upstream tag: {}".format(out))
            return

        # start_sha is the commit where we start creating patches (exclusive)
        start_sha = next(out).strip()

        ret, out = runner.execute_command("git rev-parse {}".format(patch_metadata.eks_tag))
        if ret != 0:
            logger.error("Failed getting revision of eks tag: {}".format(next(out)))
            return

        # end_sha is the commit where we stop creating patches (inclusive)
        end_sha = next(out).strip()

        logger.info("Creating patches from: {} ({}) (Not inclusive)".format(patch_metadata.upstream_tag, start_sha))
        logger.info("Creating patches to: {} ({})".format(patch_metadata.eks_tag, end_sha))

        cmd = format_patch_command(start_sha, end_sha, eks_tag)
        ret, out = runner.execute_command(cmd)
        if ret != 0:
            print("Format patch failed: {}".format(out))
            return


@main.command()
@click.option("--id", "prid", help="The github PR id to create a patch from.")
def pr(prid):
    runner = ProcessRunner()
    if not cloned(clone_dir):
        logger.error("Run 'ekspatch clone' first to clone kubernetes.")
        return

    # TODO: check to see if a patch has already been generated from this PR.

    response = requests.get("https://api.github.com/repos/kubernetes/kubernetes/pulls/{}".format(prid))
    jsn = json.loads(response.text)

    ret, out = runner.execute_command("bash -c 'echo $USER'")
    if ret != 0:
        logger.error("Failed getting $USER: {}".format(next(out)))
        return

    user = next(out).strip()

    patch_metadata = PatchMetadata(
            owner=user,
            pr_id=prid,
            url=jsn['html_url'],
            patch_url = jsn['patch_url'],
            body = jsn['body'],
            pr_creation_date = jsn['created_at']
        )

    patch_dir = "patches/prs/{}".format(prid)
    patch_file = os.path.join(patch_dir, "{}.patch".format(prid))
    patch_metadata_file = os.path.join(patch_dir, "{}-metadata.json".format(prid))

    if not os.path.isdir(patch_dir):
        os.makedirs(patch_dir)

    with open(patch_file, "w") as f:
        response = requests.get(patch_metadata.patch_url)
        f.write(response.text)

    with open(patch_metadata_file, "w") as m:
        m.write(json.dumps(patch_metadata.__dict__, indent=4, sort_keys=True))

    print("Patch has been written to {}".format(patch_file))
    print("Patch metadata has been written to {}".format(patch_metadata_file))
    print("PR link: {}".format(patch_metadata.url))


