# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository provides automated scripts for installing Kubernetes clusters on Red Hat-based Linux distributions using containerd as the container runtime. It supports RHEL 8/9, CentOS Stream 8/9, Rocky Linux 8/9, and Fedora 37+.

## Common Commands

### System Check and Prerequisites
```bash
# Check system compatibility before installation
sudo ./scripts/utils/system-check.sh

# Set up system prerequisites
sudo ./scripts/prerequisites.sh
```

### Installation Process
```bash
# Install containerd container runtime
sudo ./scripts/install-containerd.sh

# Install Kubernetes components (kubeadm, kubelet, kubectl)
sudo ./scripts/install-kubernetes.sh

# Initialize master node with Flannel CNI
sudo ./scripts/setup-master-node.sh

# Initialize master node with Calico CNI
sudo ./scripts/setup-master-node.sh --cni-plugin calico --pod-network-cidr 192.168.0.0/16

# Join worker node to cluster
sudo ./scripts/setup-worker-node.sh "kubeadm join 192.168.1.100:6443 --token xxx..."
```

### Maintenance and Troubleshooting
```bash
# Complete cleanup and reset
sudo ./scripts/utils/cleanup.sh

# Force cleanup without confirmation
sudo ./scripts/utils/cleanup.sh --force
```

## Architecture

### Script Organization
- `scripts/`: Main installation scripts with logging and error handling
  - `prerequisites.sh`: System configuration (SELinux, swap, firewall, kernel modules)
  - `install-containerd.sh`: containerd runtime installation with SystemdCgroup enabled
  - `install-kubernetes.sh`: Kubernetes components with v1.29 default
  - `setup-master-node.sh`: Cluster initialization with CNI plugin deployment
  - `setup-worker-node.sh`: Worker node joining with validation
- `scripts/utils/`: Utility scripts for system checks and cleanup
- `configs/`: Configuration templates for containerd, Kubernetes, and CNI
- `docs/`: Comprehensive documentation in Korean

### Key Design Decisions
- **containerd over Docker**: Uses containerd as the CRI with SystemdCgroup enabled
- **Modular Scripts**: Each script handles one specific phase with proper error handling
- **CNI Flexibility**: Supports both Flannel (default) and Calico CNI plugins
- **Security Focus**: Configures SELinux to permissive, manages firewall rules, disables swap
- **Red Hat Focus**: Optimized for Red Hat family distributions with dnf/yum compatibility

### Configuration Management
- containerd config with registry.k8s.io pause image
- Kubernetes repository configuration for v1.29
- Firewall rules for all required ports (6443, 2379-2380, 10250-10252, 30000-32767)
- Kernel module loading (overlay, br_netfilter) and sysctl parameters

### Error Handling and Logging
- Structured logging with timestamps in all scripts
- Comprehensive error checking with meaningful messages
- Service status validation and automatic restart capabilities
- Network connectivity and port availability checks

## Testing

Since this involves system-level configuration, testing requires:
- Virtual machines or physical hardware with supported OS
- Root privileges for installation scripts
- Network connectivity for package and image downloads
- Multiple nodes for cluster testing

## Supported Distributions

- Red Hat Enterprise Linux (RHEL) 8.x, 9.x
- CentOS Stream 8, 9
- Rocky Linux 8.x, 9.x  
- Fedora 37+

## Security Considerations

- All scripts require root privileges
- SELinux is set to permissive mode for Kubernetes compatibility
- Firewall rules are automatically configured for required ports
- swap is disabled as required by Kubernetes
- Container runtime uses SystemdCgroup for better integration