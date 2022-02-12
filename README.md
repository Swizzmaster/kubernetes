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
connection, and already have EKSDataPlaneKubernetes cloned, you can soft
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
$ git cherry-pick <patch 1234 sha>
$ git checkout -b patch-1234
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
  other patches whose commit hash changed but content did not. (Just make sure
  all patches apply cleanly).
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
 Apply patches and create an EKSDataPlaneKubernetes CR too? It will be easier to review your EKSDataPlanePatches CR
 with a corresponding EKSDataPlaneKubernetes CR showing the applied patches. y/n?
```

You should choose yes when working on a change to patches.

```
$ popd
```

### Using Interactive Rebase to Reorder Commits

An interactive rebase can be used to reorder, squash or edit commits that have
been applied.  After running `apply_patches.sh`, the EKSDataPlaneKubernetes
repository will have the patches in a detached HEAD state, applied to the tag
specified in GIT_TAG.  In order to begin an interactive rebase, navigate to
EKSDataPlaneKubernetes and run an interactive rebase targeting the tag in
GIT_TAG.

```
git rebase -i "$(cat ~/workspace/EKSKubernetesPatches/src/EKSKubernetesPatches/patches/1.21/GIT_TAG)"
```

### When Patches Fail to Apply

If the patches fail to apply when you run `apply_patches.sh`, determine why.
One possibility is that the is already applied in the new version.  In order to
determine if this is the case, you can try applying the failed patch again:

```
$ pushd ~/workplace/EKSKubernetesPatches/src/EKSDataPlaneKubernetes/
$ git am --3way ~/workplace/EKSKubernetesPatches/src/EKSKubernetesPatches/patches/1.21/0-public/0009-EKS-PATCH
```

and you'll see output like:

```
Applying: --EKS-PATCH-- Ignore 'wait: no child processes' error when calling mount/umount
Using index info to reconstruct a base tree...
M	staging/src/k8s.io/mount-utils/mount_linux.go
Falling back to patching base and 3-way merge...
No changes -- Patch already applied.
```

Drop the patch by deleting the patch file from the correct patches directory,
and then run apply_patches.sh and prepare_patches.sh again.

The other possibility is that there is a conflict, in which case the code must
be modified so that the patch applies and the behavior is preserved.  If there
isn't a test for the patch, one should be added.

### Rebasing Patches on a New Kubernetes Version

**Note: only create a CR for one version at a time.**

For a new minor version, copy the preceding directory then edit the GIT_TAG to
the new version you wish to rebase the patches on.  For a new patch version,
find the existing directory then edit the GIT_TAG.  Commit these changes before
you make any changes to patches.

Then the process is the same as above.  You can run `apply_patches.sh` followed
by `prepare_patches.sh` (which will always result in a diff, even if the
patches apply cleanly), or you can attempt to run `cr`, making sure to run the
pre-cr hook to create a patch review cr against EKSDataPlaneKubernetes.  If the
patches don't apply, this step will fail.

When you apply the patches you should expect a patch to fail in which case you
must decide to edit or drop it. Submit a cr with the patch edited or dropped.
Repeat this process until all patches succeed for the new GIT_TAG.
