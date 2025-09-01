#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_VERSION=${K8S_VERSION:-"1.33"}

# Auto-detect RHEL 8.10 and suggest Kubernetes 1.30
detect_rhel_version() {
    if [[ -f /etc/redhat-release ]]; then
        if grep -q "Red Hat.*release 8\.10" /etc/redhat-release; then
            if [[ "$K8S_VERSION" == "1.33" ]]; then
                log "RHEL 8.10 detected. Kubernetes 1.30 is more compatible with RHEL 8.x kernel 4.18"
                log "Consider using: K8S_VERSION=1.30 ./install-kubernetes.sh"
                log "Continuing with Kubernetes $K8S_VERSION..."
            fi
        fi
    fi
}

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

check_containerd() {
    if ! systemctl is-active --quiet containerd; then
        error "containerd is not running. Please install and start containerd first."
    fi
    log "containerd is running"
}

add_kubernetes_repository() {
    log "Adding Kubernetes repository..."
    
    # Create Kubernetes repository file
    cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
    
    log "Kubernetes repository added for version ${K8S_VERSION}"
}

install_kubernetes_components() {
    log "Installing Kubernetes components (kubeadm, kubelet, kubectl)..."
    
    if command -v dnf >/dev/null 2>&1; then
        dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    elif command -v yum >/dev/null 2>&1; then
        yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    else
        error "Neither dnf nor yum package manager found"
    fi
    
    log "Kubernetes components installed successfully"
}

configure_kubelet() {
    log "Configuring kubelet..."
    
    # Create kubelet configuration directory
    mkdir -p /etc/systemd/system/kubelet.service.d
    
    # Configure kubelet to use containerd
    cat > /etc/systemd/system/kubelet.service.d/20-containerd.conf << EOF
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime-endpoint=unix:///run/containerd/containerd.sock"
EOF
    
    systemctl daemon-reload
    systemctl enable kubelet
    
    log "kubelet configured and enabled"
}

verify_installation() {
    log "Verifying Kubernetes installation..."
    
    # Check kubeadm version
    if command -v kubeadm >/dev/null 2>&1; then
        log "kubeadm version: $(kubeadm version -o short)"
    else
        error "kubeadm not found"
    fi
    
    # Check kubelet version
    if command -v kubelet >/dev/null 2>&1; then
        log "kubelet version: $(kubelet --version)"
    else
        error "kubelet not found"
    fi
    
    # Check kubectl version
    if command -v kubectl >/dev/null 2>&1; then
        log "kubectl version: $(kubectl version --client -o yaml | grep gitVersion | awk '{print $2}')"
    else
        error "kubectl not found"
    fi
    
    # Check if kubelet is enabled
    if systemctl is-enabled --quiet kubelet; then
        log "kubelet service is enabled"
    else
        error "kubelet service is not enabled"
    fi
}

setup_bash_completion() {
    log "Setting up kubectl bash completion..."
    
    # Install bash-completion if not present
    if command -v dnf >/dev/null 2>&1; then
        dnf install -y bash-completion
    elif command -v yum >/dev/null 2>&1; then
        yum install -y bash-completion
    fi
    
    # Add kubectl completion
    kubectl completion bash > /etc/bash_completion.d/kubectl
    
    log "kubectl bash completion configured"
}

display_next_steps() {
    log "Next steps:"
    echo ""
    echo "For Master Node:"
    echo "  ./setup-master-node.sh"
    echo ""
    echo "For Worker Node:"
    echo "  ./setup-worker-node.sh [JOIN_COMMAND]"
    echo ""
    echo "Note: The JOIN_COMMAND will be provided after initializing the master node"
}

main() {
    log "Starting Kubernetes installation..."
    
    check_root
    check_os
    detect_rhel_version
    check_containerd
    add_kubernetes_repository
    install_kubernetes_components
    configure_kubelet
    verify_installation
    setup_bash_completion
    
    log "Kubernetes installation completed successfully!"
    display_next_steps
}

main "$@"