# EKSKubernetesPatches

## Summary

This package is used to track patches that EKS applies on top of upstream [kubernetes](https://github.com/kubernetes/kubernetes).
EKSDataPlaneCDK clones this repo and applies the patches on top of upstream based on the GIT_TAG.

## Development

Clone this repo and the gitfarm kubernetes repository.
```
$ cd ~/workplace/
$ brazil ws create -n EKSDataPlaneKubernetes
$ cd EKSDataPlaneKubernetes/
$ brazil ws use -p EKSDataPlaneKubernetes
$ brazil ws use -p EKSKubernetesPatches
$ cd src/EKSKubernetesPatches/
```

Apply the patches. Make sure the EKSDataPlaneKubernetes repository is clean because the script will modify it.
```
$ pushd ~/workplace/EKSKubernetesPatches/src/EKSKubernetesPatches/
$ cat patches/1.22/GIT_TAG
v1.22.4
$ ./hack/apply_patches.sh patches/1.22 ~/workplace/EKSKubernetesPatches/src/EKSDataPlaneKubernetes/
$ popd
```

Add, edit, drop, or reorder patches with `git rebase -i`, `git cherry-pick`, etc.
```
$ pushd ~/workplace/EKSKubernetesPatches/src/EKSDataPlaneKubernetes/
$ git cherry-pick PATCH-1234
$ git checkout -b PATCH-1234
$ popd
```

Prepare the new patches. Make sure the EKSKubernetesPatches repository is clean because the script will modify it.
```
$ pushd ~/workplace/EKSKubernetesPatches/src/EKSKubernetesPatches/
$ ./hack/prepare_patches.sh ~/workplace/EKSKubernetesPatches/src/EKSDataPlaneKubernetes/ patches/1.22/
$ popd
```

Check the diff and commit patches accordingly.
For example:
- if your intention was only to add one patch, it's not necessary to commit the other patches whose commit hash changed but content did not.
- if you dropped or reordered patches, then it's necessary to commit all patches because they need to be renamed.
- if you edited a patch X that modifies a file also modified by a subsequent patch Y then it's necessary to commit both patch X and Y.
Submit a CR with the prepared patches.
```
$ pushd ~/workplace/EKSKubernetesPatches/src/EKSKubernetesPatches/
$ git diff
$ git add patches/1.22/private/0099-PATCH-1234
$ cr
$ popd
```

### Rebasing patches on a new kubernetes version

For a new minor version, copy the preceding directory then edit the GIT_TAG to the new version you wish to rebase the patches on.

For a new patch version, find the existing directory then edit the GIT_TAG.

Then the process is the same as above. When you apply the patches you should expect a patch to fail in which case you must decide to edit or drop it. Submit a cr with the patch edited or dropped. Repeat this process until all patches succeed for the new GIT_TAG.

# ekspatch

Optionally you may use the ekspatch cli to help with some common patch
manipulation operations.

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

Clone the kubernetes codecommit repository which is a mirror of the gitfarm repository.

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
