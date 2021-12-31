# EKSKubernetesPatches

## Summary

This package is used to track patches that EKS applies on top of upstream
[kubernetes](https://github.com/kubernetes/kubernetes).  EKSDataPlaneCDK clones
this repo and applies the patches on top of upstream based on the GIT_TAG.

## Patch Development

### Note About EKS Patches

Patches are cherry-picks or custom commits that are applied to the upstream
Kubernetes codebase before we build binaries used in EKS.  Every patch that is
not present in upstream should have the marker --EKS-PATCH-- at the beginning
of the first line of the commit message.

Additionally, any patch that is not going to be published to
[eks-distro](https://github.com/aws/eks-distro), should have the
--EKS-PRIVATE-- marker somewhere in the commit message (for readability, at the
beginning of the second or last line).

The public patches (those present in eks-distro) are applied first to upstream
code, followed by our private patches.  This allows the public patch files to
be used by eks-distro without modification.

### Setup

Clone this repo and the gitfarm kubernetes repository.
```
$ cd ~/workplace/
$ brazil ws create -n EKSDataPlaneKubernetes
$ cd EKSDataPlaneKubernetes/
$ brazil ws use -p EKSDataPlaneKubernetes
$ brazil ws use -p EKSKubernetesPatches
$ cd src/EKSKubernetesPatches/
```

Note: kubernetes is a large repository.  If you are on a slow internet
connection, and already have EKSDataPlaneKubernetes cloned, you can link soft
link it to the desired location:

```
$ ln -s ~/workplace/EKSDataPlaneKubernetes/src/EKSDataPlaneKubernetes ~/workplace/EKSKubernetesPatches/src/EKSDataPlaneKubernetes
```

### Modify Existing Patches in EKSKubernetesPatches

In order to modify existing patches in EKSKubernetesPatches, first they must be
applied to the appropriate git tag in the EKSDataPlaneKubernetes repository.
Make sure the EKSDataPlaneKubernetes repository is clean because the script
will modify it.

```
$ pushd ~/workplace/EKSKubernetesPatches/src/EKSKubernetesPatches/
$ cat patches/1.22/GIT_TAG
v1.22.4
$ ./hack/apply_patches.sh patches/1.22 ~/workplace/EKSKubernetesPatches/src/EKSDataPlaneKubernetes/
$ popd
```

Now that they are applied to the appropriate tag, you can add, edit, drop, or
reorder patches with `git rebase -i`, `git cherry-pick`, etc.

```
$ pushd ~/workplace/EKSKubernetesPatches/src/EKSDataPlaneKubernetes/
$ git cherry-pick PATCH-1234
$ git checkout -b PATCH-1234
$ popd
```

Next, you must create new patch files from the commits you modified. Make sure
the EKSKubernetesPatches repository is clean because the script will modify it.

```
$ pushd ~/workplace/EKSKubernetesPatches/src/EKSKubernetesPatches/
$ ./hack/prepare_patches.sh ~/workplace/EKSKubernetesPatches/src/EKSDataPlaneKubernetes/ patches/1.22/
$ popd
```

Check the diff and commit patches accordingly.  For example:
- if your intention was only to add one patch, it's not necessary to commit the
  other patches whose commit hash changed but content did not.
- if you dropped or reordered patches, then it's necessary to commit all
  patches because they need to be renamed.
- if you edited a patch X that modifies a file also modified by a subsequent
  patch Y then it's necessary to commit both patch X and Y.  Submit a CR with
  the prepared patches.

```
$ pushd ~/workplace/EKSKubernetesPatches/src/EKSKubernetesPatches/
$ git diff
$ git add patches/1.22/private/0099-PATCH-1234
$ cr
The branch you're on doesn't track a GitFarm remote. Inferring your --parent to be '201ccfcfb' on branch 'mainline'.
 Running pre-cr hook /home/ANT.AMAZON.COM/nic/workspace/EKSKubernetesPatches/src/EKSKubernetesPatches/pre-cr
 Apply patches and create an EKSDataPlaneKubernetes CR too? It will be easier to review your EKSDataPlanePatches CR with a corresponding EKSDataPlaneKubernetes CR showing the applied patches. y/n?
```

You should choose yes when working on a change to patches.

```
$ popd
```

### Rebasing Patches on a New Kubernetes Version

For a new minor version, copy the preceding directory then edit the GIT_TAG to
the new version you wish to rebase the patches on.  For a new patch version,
find the existing directory then edit the GIT_TAG.  Commit these changes before
you make any changes to patches.

Then the process is the same as above. When you apply the patches you should
expect a patch to fail in which case you must decide to edit or drop it. Submit
a cr with the patch edited or dropped. Repeat this process until all patches
succeed for the new GIT_TAG.


