# Kubernetes Cluster Setup with Kubeadm and Vagrant

This repository contains scripts and configuration files for setting up a Kubernetes cluster using Kubeadm and Vagrant. This setup provides a local development environment with one control plane node and one worker node.

## Prerequisites

- VirtualBox installed
- Vagrant installed
- The exercise files from "Ex_Files_Kubernetes_Provisioning_With_Kubeadm"

## System Requirements

- 8GB+ RAM recommended
- 20GB+ free disk space
- Virtualization enabled in BIOS

## Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd <repository-name>

# Start VMs
vagrant up

# Follow the setup script
bash create_kubernetes_cluster_kubeadm.bash
```

## Architecture

The setup creates two Ubuntu 22.04 VMs:
- **node-a** (192.168.64.8): Control plane node
- **node-b** (192.168.64.9): Worker node

## Components Installed

- **Container Runtime**: containerd v1.7.16
- **Container Runtime Client**: crictl v1.30.0
- **CNI Plugin**: Antrea v2.0.0
- **Kubernetes Components**:
  - kubeadm
  - kubelet
  - kubectl

## Setup Process

The `create_kubernetes_cluster_kubeadm.bash` script performs the following steps:

1. **VM Setup**:
   - Starts two VMs using Vagrant
   - Sets appropriate hostnames and network configurations

2. **Kubernetes Binary Installation**:
   - Downloads and installs kubeadm, kubelet, and kubectl
   - Sets up appropriate configuration files

3. **Container Runtime Installation**:
   - Downloads and installs containerd
   - Configures containerd to use systemd cgroups
   - Installs CNI plugins

4. **Kernel Module Configuration**:
   - Enables overlay and br_netfilter modules
   - Configures kernel parameters for networking

5. **Cluster Initialization**:
   - Initializes Kubernetes control plane on node-a
   - Installs Antrea CNI for pod networking
   - Joins node-b to the cluster

## File Descriptions

- **10-vm.node-a.network, 10-vm.node-b.network**: Network configurations for VMs
- **10-kubeadm.node-a.conf, 10-kubeadm.node-b.conf**: Kubeadm configurations
- **k8s.conf**: Kubernetes module configuration
- **kubelet.service**: Systemd service file for kubelet

## Verifying Cluster

After setup, you can verify your cluster with:

```bash
# On node-a
sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get nodes
sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get pods -A
```

## Setting up kubectl for regular user

To use kubectl without sudo, run:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## Troubleshooting

### Common Issues:

1. **Kubelet fails to start**:
   - Check logs with `sudo journalctl -u kubelet`
   - Ensure containerd is running properly

2. **Node not joining cluster**:
   - Verify network connectivity between nodes
   - Ensure the join token hasn't expired

3. **Pods stuck in pending state**:
   - Check if CNI is properly installed
   - Verify network CIDR configuration

## Cleanup

To remove the cluster and VMs:

```bash
# Turn off VMs
vagrant halt

# Remove VMs
vagrant destroy -f
```
