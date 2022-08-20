# EKSKubernetesPatches

## Summary

This package is used to track patches that EKS applies on top of upstream
[kubernetes](https://github.com/kubernetes/kubernetes).  EKSDataPlaneCDK clones
this repo and applies the patches on top of upstream based on the GIT_TAG.

## Patch Development

### Note About EKS Patches

Patches are cherry-picks or custom commits that are applied to the upstream
Kubernetes codebase before we build binaries used in EKS.  Every patch should
have the marker `--EKS-PATCH--` at the beginning of the first line of the commit
message.  If the commit is only present in our internal fork and not in
[eks-distro](https://github.com/aws/eks-distro), it should have the
`--EKS-PRIVATE--` marker at the beginning of the first line of the commit message.

The public patches (those present in eks-distro) are applied first to upstream
code, followed by our private patches.  This allows the public patch files to
be used by eks-distro without modification.

NOTE: Previously, the `--EKS-PRIVATE--` marker was used in addition to the `--EKS-PATCH--` marker, now it is used in place of it.  There may still be patches with both, they can safely be rebased to only have `--EKS-PRIVATE--` in the message.

### Setup

Clone this repo and the gitfarm kubernetes repository.

```
$ cd ~/workplace/
$ brazil ws create -n EKSKubernetesPatches
$ cd EKSKubernetesPatches/
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

1. Make sure the EKSKubernetesPatches and Kubernetes repos are...
   * up-to-date with the upstream repos
   * on their mainline (EKSKubernetesPatches) or master (Kubernetes) branches, less there is a reason why they're not
   * clean
2. OPTIONAL: to make your life easier, set the following variables to the 
   correct ones for your environment and the version of Kubernetes you’re 
   working on. `PATCHES_ROOT` and `K8S_ROOT` should be absolute paths to the 
   root directories for those packages.
```shell
# For fish
set PATCHES_ROOT ""
set K8S_ROOT ""
set K8S_GIT_TAG "v1.XX.YY"
set K8S_MINOR_VERSION="1.XX"

# For bash, zsh, and other such garbage
PATCHES_ROOT=""
K8S_ROOT=""
K8S_GIT_TAG="v1.XX.YY"
K8S_MINOR_VERSION="1.XX"
```
3. Apply the current patches
```shell
cd $K8S_ROOT
pushd $PATCHES_ROOT
cat patches/$K8S_MINOR_VERSION/GIT_TAG # optional sanity check
./hack/apply_patches.sh patches/$K8S_MINOR_VERSION/ $K8S_ROOT
popd
```
4. Now that they are applied to the appropriate tag, you can add, edit, drop, or
   reorder patches with `git rebase -i`, `git cherry-pick`, etc.
```shell
pushd $K8S_ROOT
git log --pretty=oneline HEAD...$K8S_GIT_TAG # optional sanity check
# git rebase -i $K8S_GIT_TAG or whatever else you want to do
git checkout -b some-branch # when you're done making changes
popd
```
5. Next, you must create new patch files from the commits you modified. Make sure
   the EKSKubernetesPatches repo is clean because the script will modify it.
```shell
pushd $PATCHES_ROOT
./hack/prepare_patches.sh $K8S_ROOT patches/$K8S_MINOR_VERSION/
popd
```

Check the diff and commit patches accordingly.  For example:
- if your intention was only to add one private patch, it might not necessary
  to commit the other patches whose commit hash changed but content did not.
  (Just make sure all patches apply cleanly, and ensure that the patch is
  correctly categorized as public or private.  Note that public patches are
  always applied first, so if it is a public patch you should regenerate all
  patches because private patches will be renumbered.)
- if you dropped or reordered patches, then it's necessary to commit all
  patches because they need to be renamed.
- if you edited a patch X that modifies a file also modified by a subsequent
  patch Y then it's necessary to commit both patch X and Y.  Submit a CR with
  the prepared patches.


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

#### New patch version

A GitLab pipeline automatically finds new Kubernetes patch versions from GitHub
  and create MRs like
  https://gitlab.aws.dev/eks-dataplane/eks-kubernetes-patches/-/merge_requests/34.
  which automatically merge if tests pass

If tests fail, for example because one of our patches encountered conflicts and
failed to apply, then somebody needs to checkout the branch and resolve
conflicts.

#### New minor version

**Note: only create a MR for one version at a time.**

Say the last EKS version was based on kubernetes minor version "A" like 1.23
and you have a new kubernetes minor version "B" like 1.24 (`set
K8S_MINOR_VERSION_A 1.23; set K8S_MINOR_VERSION_B 1.24`).

1. Apply patches from A. (This is necessary for git to do 3 way merges later.)
```shell
./hack/apply_patches.sh patches/$K8S_MINOR_VERSION_A/ $K8S_ROOT
```
2. Copy patches from A to B.
```shell
cp -r patches/$K8S_MINOR_VERSION_A patches/$K8S_MINOR_VERSION_B
```
3. Update B's GIT_TAG (`set GIT_TAG v1.24.3`).
```shell
echo $GIT_TAG > patches/$K8S_MINOR_VERSION_B
```
4. Commit patches.
```shell
git add patches/$K8S_MINOR_VERSION_B
git commit -m "Bootstrap $K8S_MINOR_VERSION_B patches"
```
5. Add B to CI.
```shell
vim .gitlab-ci.yaml
git add .gitlab-ci.yaml
git commit -m "Add $K8S_MINOR_VERSION_B to CI
```
6. Apply patches from B.
```shell
./hack/apply_patches.sh patches/$K8S_MINOR_VERSION_B/ $K8S_ROOT
```
7. If a patch fails (`set BAD_PATCH $PWD/patches/$K8S_MINOR_VERSION_B/0-public/0005`):
    1. Decide if it can be dropped, for example because it is already applied in
       the new minor version.
    2. If so, delete the patch from the patches folder, commit the delete,
       then move on to the next patch.
       ```shell
       rm $BAD_PATCH
       git add $BAD_PATCH
       git commit -m "Drop patch 0005"`
       ```
    3. If not, apply the patch with 3-way merge and resolve conflicts manually.
       ```shell
       pushd $K8S_ROOT
       git am --3way $BAD_PATCH
       ```
    4. Once conflicts are resolved and the new version of the patch is committed
       at the HEAD of your $K8S_ROOT repository, replace the old version of the
       patch with the new, commit the change, then move on to the next patch.
       ```shell
       git format-patch --zero-commit --no-numbered --no-signature HEAD^
       mv ./000*.patch $BAD_PATCH
       git add $BAD_PATCH
       git commit -m "Resolve patch 0005"`
       ```
8. Apply patches from B starting from the patch after the patch that failed
   (`set NEXT_PATCH_NUM 6`).
```shell
./hack/apply_patches.sh patches/$K8S_MINOR_VERSION_B/ $K8S_ROOT $NEXT_PATCH_NUM
```
9. Repeat 7-8 until all patches apply successfully.
10. Regenerate all patches.
```shell
./hack/apply_patches.sh patches/$K8S_MINOR_VERSION_B/ $K8S_ROOT
./hack/prepare_patches.sh $K8S_ROOT patches/$K8S_MINOR_VERSION_B/
```
11. Create an MR.

## Build

### Desktop build

The possible components EKS builds are the following. Developers can build and test components from their own developer boxes and not depend on the EKSDataplaneCDK pipeline.
```
kube-apiserver
kube-controller-manager
kube-scheduler
kubelet
kube-proxy
```

Use the command `WHAT=kube-apiserver ./hack/build.sh ~/workplace/EKSKubernetesPatches/src/EKSDataPlaneKubernetes/` to build on local MAC/Linux dev boxes.
Change the component name to build the one you need to test. 
The build will create image with tag `registry/kube-apiserver:latest`. 
If the docker build fails due to 403, run the following
```
aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com
```

Use the following commands to push from local box and pull the image on CPI:
 - `docker tag registry/kube-apiserver:latest $AWS_ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/kube-apiserver:latest`
 - `docker push $AWS_ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/kube-apiserver:latest`
 - On the CPI instance, edit `/etc/kubernetes/manifests/kube-apiserver.yaml` and replace the image with the newly pushed image.
 - CPI kubelet will fail to download the docker image. You could manually pull the image on CPI using isengard credentials. Change the image in the manigest. ALso, change `imagePullPolicy: Never` , otherwise kubelet will fail to assume the role.

### Code Pipeline build

In order to simulate the code-pipeline build process use the following. This build uses docker and is not advisable to perform on mac. To test the command, use dev desktop.
Docker is needed on dev-desktop https://builderhub.corp.amazon.com/docs/rde/cli-guide/setup-clouddesk.html#install-and-configure-docker
```
export REGISTRY=$AWS_ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com
export VERSION_TAG=v1.22.6
export IMAGE_TAG=v1.22.6-eks-test
export KUBE_BUILD_PLATFORMS="linux/amd64"
./hack/build-pipeline.sh ~/workplace/EKSKubernetesPatches/src/EKSDataPlaneKubernetes/
```
