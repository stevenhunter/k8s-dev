# Kubernetes Dev Cluster

There are many ways to create a Kubernetes cluster for development purposes including Kubeadm, Rancher, KinD, Kops etc.  For a particular use-case I had these requirements:

- Run the cluster on an M1 Pro Macbook
- Configure with multiple control-plane/worker nodes
- Run nodes as VMs, not containers
- Deploy K8s cluster with Kubespray
- Calico CNI
- Use local storage for persistent volumes
- Use VSCode DevContainers to isolate development environment

## Prerequisites

- MacOS (tested on MacOS 15.2 with Apple M1 chip)
- Enough RAM dependent upon needs
- [VS Code](https://code.visualstudio.com/) with DevContainers extension
- [Multipass](https://multipass.run/) (for management of K8s node VMs)
- [Colima](https://github.com/abiosoft/colima) (containerisation runtime for VS Code DevContainers preferred over Docker Desktop)
- [Docker](https://www.docker.com/)

## Quick Start

 1. Install the prerequisites.
```bash
brew install colima docker multipass
brew install --cask visual-studio-code
```

If there are issues with multipass which result in errors such as:
```cannot connect to the multipass socket```
then it may be necessary to reinstall multipass.

First remove using: ```sudo sh "/Library/Application Support/com.canonical.multipass/uninstall.sh"```
and then reinstall using ```brew install multipass```

 2. Clone the repository.
```bash
git clone https://github.com/stevenhunter/k8s-dev.git
cd k8s-dev
```

 3. Adjust config appropriately in file `config/setup.conf` specifying Colima and K8s node resources.
 4. Run the setup script
```bash
./setup.sh
```
 6. Open VSCode in the project directory.
 7. When prompted, click 'Reopen in Container'.  
 8. Wait for scripts to run and for Kubespray to bootstrap the cluster.

## Cleanup
To destroy the cluster and all associated resources, run the script `cleanup.sh`.
```bash
./cleanup.sh
```