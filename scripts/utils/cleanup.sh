#!/bin/bash

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >&2
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

confirm_cleanup() {
    warning "This will completely remove Kubernetes and containerd from this system!"
    warning "All cluster data, pods, and configurations will be lost!"
    echo ""
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " -r
    
    if [[ $REPLY != "yes" ]]; then
        log "Cleanup cancelled by user"
        exit 0
    fi
    
    echo ""
    log "Proceeding with cleanup..."
}

stop_services() {
    log "Stopping Kubernetes and containerd services..."
    
    # Stop kubelet
    if systemctl is-active --quiet kubelet; then
        systemctl stop kubelet
        log "kubelet service stopped"
    fi
    
    # Stop containerd
    if systemctl is-active --quiet containerd; then
        systemctl stop containerd
        log "containerd service stopped"
    fi
}

reset_kubernetes() {
    log "Resetting Kubernetes configuration..."
    
    if command -v kubeadm >/dev/null 2>&1; then
        kubeadm reset -f
        log "kubeadm reset completed"
    else
        log "kubeadm not found, skipping reset"
    fi
}

remove_kubernetes_packages() {
    log "Removing Kubernetes packages..."
    
    if command -v dnf >/dev/null 2>&1; then
        dnf remove -y kubelet kubeadm kubectl kubernetes-cni || true
    elif command -v yum >/dev/null 2>&1; then
        yum remove -y kubelet kubeadm kubectl kubernetes-cni || true
    fi
    
    log "Kubernetes packages removed"
}

remove_containerd() {
    log "Removing containerd..."
    
    if command -v dnf >/dev/null 2>&1; then
        dnf remove -y containerd.io docker-ce-cli || true
    elif command -v yum >/dev/null 2>&1; then
        yum remove -y containerd.io docker-ce-cli || true
    fi
    
    log "containerd packages removed"
}

clean_directories() {
    log "Cleaning up directories and files..."
    
    # Kubernetes directories
    rm -rf /etc/kubernetes/
    rm -rf /var/lib/kubelet/
    rm -rf /var/lib/etcd/
    rm -rf /etc/cni/
    rm -rf /opt/cni/
    rm -rf /var/lib/cni/
    rm -rf /run/kubernetes/
    
    # containerd directories
    rm -rf /etc/containerd/
    rm -rf /var/lib/containerd/
    rm -rf /run/containerd/
    
    # User kubectl configurations
    rm -rf /root/.kube/
    find /home -name ".kube" -type d -exec rm -rf {} \; 2>/dev/null || true
    
    # Temporary files
    rm -f /tmp/k8s-join-command.txt
    rm -f /tmp/kubectl-setup.sh
    rm -f /tmp/calico-custom-resources.yaml
    
    log "Directories cleaned up"
}

clean_network_configuration() {
    log "Cleaning up network configuration..."
    
    # Reset iptables rules
    iptables -F 2>/dev/null || true
    iptables -t nat -F 2>/dev/null || true
    iptables -t mangle -F 2>/dev/null || true
    iptables -X 2>/dev/null || true
    
    # Remove network interfaces created by CNI
    for iface in $(ip link show | grep -E "(cni|flannel|calico)" | awk -F: '{print $2}' | tr -d ' '); do
        if [[ -n "$iface" ]]; then
            ip link delete "$iface" 2>/dev/null || true
            log "Removed network interface: $iface"
        fi
    done
    
    log "Network configuration cleaned up"
}

remove_repositories() {
    log "Removing package repositories..."
    
    # Remove Kubernetes repository
    rm -f /etc/yum.repos.d/kubernetes.repo
    
    # Remove Docker repository (optional, comment out if you want to keep Docker repo)
    # rm -f /etc/yum.repos.d/docker-ce.repo
    
    log "Package repositories removed"
}

remove_systemd_configurations() {
    log "Removing systemd configurations..."
    
    # Disable services
    systemctl disable kubelet 2>/dev/null || true
    systemctl disable containerd 2>/dev/null || true
    
    # Remove service override files
    rm -rf /etc/systemd/system/kubelet.service.d/
    rm -rf /etc/systemd/system/containerd.service.d/
    
    # Reload systemd
    systemctl daemon-reload
    
    log "Systemd configurations removed"
}

remove_kernel_configurations() {
    log "Removing kernel configurations..."
    
    # Remove sysctl configurations
    rm -f /etc/sysctl.d/k8s.conf
    
    # Remove module loading configurations
    rm -f /etc/modules-load.d/k8s.conf
    
    # Unload kernel modules (optional, they'll be unloaded on reboot)
    modprobe -r br_netfilter 2>/dev/null || true
    modprobe -r overlay 2>/dev/null || true
    
    log "Kernel configurations removed"
}

clean_package_cache() {
    log "Cleaning package cache..."
    
    if command -v dnf >/dev/null 2>&1; then
        dnf clean all
    elif command -v yum >/dev/null 2>&1; then
        yum clean all
    fi
    
    log "Package cache cleaned"
}

display_cleanup_summary() {
    log "Cleanup completed successfully!"
    echo ""
    echo "=== CLEANUP SUMMARY ==="
    echo "✓ Kubernetes cluster reset"
    echo "✓ Kubernetes packages removed"
    echo "✓ containerd removed"
    echo "✓ Configuration directories cleaned"
    echo "✓ Network configuration reset"
    echo "✓ Systemd configurations removed"
    echo "✓ Kernel configurations removed"
    echo ""
    echo "NEXT STEPS:"
    echo "1. Reboot the system to ensure all changes take effect"
    echo "2. To reinstall Kubernetes:"
    echo "   - Run ./prerequisites.sh"
    echo "   - Run ./install-containerd.sh"
    echo "   - Run ./install-kubernetes.sh"
    echo "   - Run ./setup-master-node.sh or ./setup-worker-node.sh"
    echo ""
    warning "Please reboot the system before reinstalling Kubernetes"
}

main() {
    log "Starting Kubernetes cleanup process..."
    
    check_root
    confirm_cleanup
    stop_services
    reset_kubernetes
    remove_kubernetes_packages
    remove_containerd
    clean_directories
    clean_network_configuration
    remove_repositories
    remove_systemd_configurations
    remove_kernel_configurations
    clean_package_cache
    display_cleanup_summary
    
    log "Kubernetes cleanup process completed!"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_CLEANUP=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --force    Skip confirmation prompt"
            echo "  -h, --help Show this help message"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Override confirmation if force flag is set
if [[ "${FORCE_CLEANUP:-false}" == "true" ]]; then
    confirm_cleanup() {
        log "Force cleanup enabled, skipping confirmation"
    }
fi

main "$@"