# k3s-wsl

This project is a small experiment for building a simple, reproducible k3s environment on WSL with CUDA/GPU support.

The setup bootstraps a BuildKit builder and uses it to produce:

* a base image with k3s, nerdctl, BuildKit and Helm
* a separate NVIDIA/CUDA image layer for GPU support

During the OOBE phase, the environment installs the NVIDIA Device Plugin (NVDP) so GPU resources are available to Kubernetes
workloads, and Telepresence for local development and debugging against the cluster.

The main goal is to keep the base k3s environment minimal while making GPU support modular and easy to layer on when needed.

## Main workflow

```ps
build [-BuilderName (optional)]
```

produces `k3s-rootfs.tar` and `k3s-nvidia-rootfs.tar` into directory `dist`.

## Install

```ps
wsl --install --name k3s --from-file .\dist\k3s-nvidia-rootfs.tar
```