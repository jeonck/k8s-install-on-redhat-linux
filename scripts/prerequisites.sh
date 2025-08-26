#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

check_os() {
    if [[ ! -f /etc/redhat-release ]]; then
        error "This script is designed for Red Hat based distributions only"
    fi
    
    if grep -q "CentOS\|Red Hat\|Rocky\|Fedora" /etc/redhat-release; then
        log "Detected compatible OS: $(cat /etc/redhat-release)"
    else
        error "Unsupported OS version"
    fi
}

disable_selinux() {
    log "Configuring SELinux..."
    
    if command -v getenforce >/dev/null 2>&1; then
        if [[ "$(getenforce)" == "Enforcing" ]]; then
            setenforce 0
            sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
            log "SELinux set to permissive mode"
        else
            log "SELinux is already in permissive/disabled mode"
        fi
    else
        log "SELinux tools not found, skipping..."
    fi
}

disable_swap() {
    log "Disabling swap..."
    swapoff -a
    sed -i '/swap/d' /etc/fstab
    log "Swap disabled and removed from /etc/fstab"
}

configure_firewall() {
    log "Configuring firewall for Kubernetes..."
    
    if systemctl is-active --quiet firewalld; then
        log "Configuring firewalld..."
        
        # Master node ports
        firewall-cmd --permanent --add-port=6443/tcp  # API server
        firewall-cmd --permanent --add-port=2379-2380/tcp  # etcd
        firewall-cmd --permanent --add-port=10250/tcp  # kubelet
        firewall-cmd --permanent --add-port=10251/tcp  # kube-scheduler
        firewall-cmd --permanent --add-port=10252/tcp  # kube-controller-manager
        firewall-cmd --permanent --add-port=10255/tcp  # kubelet read-only
        
        # Worker node ports
        firewall-cmd --permanent --add-port=30000-32767/tcp  # NodePort services
        
        # CNI ports (Flannel/Calico)
        firewall-cmd --permanent --add-port=8285/udp  # Flannel
        firewall-cmd --permanent --add-port=8472/udp  # Flannel VXLAN
        firewall-cmd --permanent --add-port=179/tcp   # Calico BGP
        firewall-cmd --permanent --add-port=4789/udp  # Calico VXLAN
        
        firewall-cmd --reload
        log "Firewall configured for Kubernetes"
    else
        log "Firewalld is not active, skipping firewall configuration"
    fi
}

load_kernel_modules() {
    log "Loading required kernel modules..."
    
    modprobe overlay
    modprobe br_netfilter
    
    cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF
    
    log "Kernel modules loaded and configured for persistence"
}

configure_sysctl() {
    log "Configuring kernel parameters..."
    
    cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    
    sysctl --system
    log "Kernel parameters configured"
}

update_system() {
    log "Updating system packages..."
    
    if command -v dnf >/dev/null 2>&1; then
        dnf update -y
    elif command -v yum >/dev/null 2>&1; then
        yum update -y
    else
        error "Neither dnf nor yum package manager found"
    fi
    
    log "System packages updated"
}

install_dependencies() {
    log "Installing required dependencies..."
    
    if command -v dnf >/dev/null 2>&1; then
        dnf install -y curl wget tar
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl wget tar
    fi
    
    log "Dependencies installed"
}

main() {
    log "Starting Kubernetes prerequisites setup..."
    
    check_root
    check_os
    update_system
    install_dependencies
    disable_selinux
    disable_swap
    configure_firewall
    load_kernel_modules
    configure_sysctl
    
    log "Prerequisites setup completed successfully!"
    log "Please reboot the system before proceeding with containerd installation"
}

main "$@"