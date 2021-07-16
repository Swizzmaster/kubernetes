# EKSKubernetesPatches

## Summary

This package is used to track patches that EKS applies on top of upstream [kubernetes](https://github.com/kubernetes/kubernetes).
The EKSDataplaneCDK clones the repo and applies the patches on top of upstream based on the git tag. The tag is created based on the commit id.

## Usage

*Always execute ekspatch from the project root*

Execute ekspatch with brazil-runtime-exec:
```
brazil-runtime-exec ekspatch --help

Usage: ekspatch [OPTIONS] COMMAND [ARGS]...

Options:
  --help  Show this message and exit.

Commands:
  clone
  create
  pr
```

## Clone
```
Usage: ekspatch clone [OPTIONS]

Options:
  --help  Show this message and exit.
```

Clone the kubernetes codecommit repository.

## Create Patches
```
brazil-runtime-exec ekspatch create --help

Usage: ekspatch create [OPTIONS]

Options:
  -e, --eks-tag TEXT  The eks tag, formatted as
                      v<major>.<minor>.<patch>-eks-<short sha>
                      (v1.12.10-eks-a26503).
  --help              Show this message and exit.
```

Create creates patch files from a branch that already exists on the EKS codecommit repo.  When releasing a new Kubernetes version for EKS, you should ensure the following things to be true:

1. A release branch is created from an upstream version tag.  For example, if the upstream version 1.12.10 is chosen, then v1.12.10 is the upstream version tag.  The release branch should be called release-1.12.10-eks (yes, it should have the patch version).
2. If necessary, a number of patches are applied to the release branch.
3. After all the patches are applied, the last commit is tagged with the eks tag.  For example, 1.12.10-eks-abc123, where abc123 is first 6 digits of the commit SHA.

As long as all the following conventions are followed, then you can create the patches by running the command:
```
brazil-runtime-exec ekspatch create --eks-tag v1.12.10-eks-abc123
```

And the formatted patch files will be added to `./patches/v1.12.10-eks-abc123/...`.


## Pull Request
```
brazil-runtime-exec ekspatch pr --help

Usage: ekspatch pr [OPTIONS]

Options:
  --id TEXT  The github PR id to create a patch from.
  --help     Show this message and exit.
```

Create a patch from a github pull request.  This creates `./patches/<pr-id>/<pr-id>.patch` and `./patches/<pr-id>/<pr-id>-metadata.json`, where the metadata file hold some information about the pull request and patch.  After the patch file is created here, it should still be applied to a release branch.
