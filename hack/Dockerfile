ARG  WHAT=""
FROM public.ecr.aws/eks-distro/kubernetes/go-runner:v0.9.0-eks-1-21-4 as go-runner

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-minimal-base:latest
COPY --from=go-runner /usr/local/bin/go-runner /usr/local/bin/go-runner

COPY _output/local/bin/linux/amd64/kube-apiserver /usr/local/bin