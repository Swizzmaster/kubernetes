from datetime import datetime
import os
import re

from .run import ProcessRunner, cd

remote_pattern = re.compile('\[remote "upstream"\]')
eks_tag_pattern = re.compile('v([\d]+)\.([\d]+)\.([\d]+)-eks-([a-zA-Z0-9]+)')
eks_release_branch_pattern = re.compile('release-([\d+])\.([\d+])\.([\d+])-eks')

def cloned(clone_dir):
    runner = ProcessRunner()
    if os.path.isdir(clone_dir):
        with cd(clone_dir):
            ret, out = runner.execute_command("git status")
            return ret == 0
    else:
        return False

def parse_eks_tag(eks_tag):
    match = re.match(eks_tag_pattern, eks_tag)
    return match[1], match[2], match[3], match[4]

class ReleaseMetadata:
    def __init__(self, major, minor, patch, short_sha):
        self.major = major
        self.minor = minor
        self.patch = patch
        self.short_sha = short_sha
        self.eks_tag = "v{}.{}.{}-eks-{}".format(major, minor, patch, short_sha)
        self.upstream_tag = "v{}.{}.{}".format(major, minor, patch)
        self.eks_release_branch = "release-{}.{}.{}-eks".format(major, minor, patch)

class PatchMetadata:
    def __init__(self, owner, pr_id, url, patch_url, body, pr_creation_date):
        self.owner = owner
        self.pr_id = pr_id
        self.url = url
        self.patch_url = patch_url
        self.body = body
        self.pr_creation_date = pr_creation_date
        self.creation_date = datetime.now().isoformat()

