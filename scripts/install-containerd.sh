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
}

add_docker_repository() {
    log "Adding Docker CE repository..."
    
    if command -v dnf >/dev/null 2>&1; then
        dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
    elif command -v yum >/dev/null 2>&1; then
        yum-config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
    else
        error "Neither dnf nor yum package manager found"
    fi
    
    log "Docker CE repository added successfully"
}

install_containerd() {
    log "Installing containerd..."
    
    if command -v dnf >/dev/null 2>&1; then
        dnf install -y containerd.io
    elif command -v yum >/dev/null 2>&1; then
        yum install -y containerd.io
    fi
    
    log "containerd installed successfully"
}

configure_containerd() {
    log "Configuring containerd..."
    
    # Create containerd configuration directory
    mkdir -p /etc/containerd
    
    # Generate default configuration
    containerd config default > /etc/containerd/config.toml
    
    # Enable SystemdCgroup
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    
    # Set sandbox image to use registry.k8s.io (recommended for Kubernetes 1.25+)
    sed -i 's|sandbox_image = ".*"|sandbox_image = "registry.k8s.io/pause:3.9"|' /etc/containerd/config.toml
    
    log "containerd configuration completed"
}

start_containerd() {
    log "Starting and enabling containerd service..."
    
    systemctl daemon-reload
    systemctl enable containerd
    systemctl restart containerd
    
    # Wait for containerd to be ready
    sleep 5
    
    if systemctl is-active --quiet containerd; then
        log "containerd service is running"
    else
        error "Failed to start containerd service"
    fi
}

verify_installation() {
    log "Verifying containerd installation..."
    
    if command -v ctr >/dev/null 2>&1; then
        ctr version
        log "containerd installation verified"
    else
        error "containerd CLI (ctr) not found"
    fi
    
    # Check if containerd socket is available
    if [[ -e /run/containerd/containerd.sock ]]; then
        log "containerd socket is available"
    else
        error "containerd socket not found"
    fi
}

cleanup_packages() {
    log "Cleaning up unnecessary packages..."
    
    if command -v dnf >/dev/null 2>&1; then
        dnf autoremove -y
    elif command -v yum >/dev/null 2>&1; then
        yum autoremove -y
    fi
    
    log "Package cleanup completed"
}

main() {
    log "Starting containerd installation..."
    
    check_root
    check_os
    add_docker_repository
    install_containerd
    configure_containerd
    start_containerd
    verify_installation
    cleanup_packages
    
    log "containerd installation completed successfully!"
    log "containerd is now ready for Kubernetes installation"
    
    # Display containerd status
    log "containerd service status:"
    systemctl status containerd --no-pager -l
}

main "$@"