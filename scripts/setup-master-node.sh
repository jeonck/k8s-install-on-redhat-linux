#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POD_NETWORK_CIDR=${POD_NETWORK_CIDR:-"10.244.0.0/16"}
CNI_PLUGIN=${CNI_PLUGIN:-"calico"}
CONTROL_PLANE_ENDPOINT=${CONTROL_PLANE_ENDPOINT:-""}

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

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if kubelet is installed and enabled
    if ! command -v kubeadm >/dev/null 2>&1; then
        error "kubeadm not found. Please run install-kubernetes.sh first"
    fi
    
    if ! systemctl is-enabled --quiet kubelet; then
        error "kubelet is not enabled. Please run install-kubernetes.sh first"
    fi
    
    # Check if containerd is running
    if ! systemctl is-active --quiet containerd; then
        error "containerd is not running. Please run install-containerd.sh first"
    fi
    
    log "Prerequisites check passed"
}

initialize_master_node() {
    log "Initializing Kubernetes master node..."
    
    local init_cmd="kubeadm init --pod-network-cidr=${POD_NETWORK_CIDR} --cri-socket=unix:///run/containerd/containerd.sock"
    
    if [[ -n "$CONTROL_PLANE_ENDPOINT" ]]; then
        init_cmd="${init_cmd} --control-plane-endpoint=${CONTROL_PLANE_ENDPOINT}"
    fi
    
    log "Running: $init_cmd"
    eval $init_cmd
    
    log "Master node initialized successfully"
}

setup_kubectl_for_root() {
    log "Setting up kubectl for root user..."
    
    mkdir -p /root/.kube
    cp -i /etc/kubernetes/admin.conf /root/.kube/config
    chown root:root /root/.kube/config
    
    log "kubectl configured for root user"
}

setup_kubectl_for_users() {
    log "Setting up kubectl configuration instructions for regular users..."
    
    cat > /tmp/kubectl-setup.sh << 'EOF'
#!/bin/bash
# Run this script as a regular user to set up kubectl

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "kubectl configured for user: $(whoami)"
echo "You can now run: kubectl get nodes"
EOF
    
    chmod +x /tmp/kubectl-setup.sh
    log "kubectl setup script created at /tmp/kubectl-setup.sh"
}

install_cni_plugin() {
    log "Installing CNI plugin: ${CNI_PLUGIN}"
    
    case ${CNI_PLUGIN} in
        "flannel")
            install_flannel
            ;;
        "calico")
            install_calico
            ;;
        *)
            error "Unsupported CNI plugin: ${CNI_PLUGIN}. Supported: flannel, calico"
            ;;
    esac
}

install_flannel() {
    log "Installing Flannel CNI plugin..."
    
    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
    
    log "Flannel installed successfully"
}

install_calico() {
    log "Installing Calico CNI plugin..."
    
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
    
    # Create custom-resources.yaml with the pod network CIDR
    cat > /tmp/calico-custom-resources.yaml << EOF
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: ${POD_NETWORK_CIDR}
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
---
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
EOF
    
    kubectl create -f /tmp/calico-custom-resources.yaml
    rm -f /tmp/calico-custom-resources.yaml
    
    log "Calico installed successfully"
}

wait_for_nodes() {
    log "Waiting for master node to become ready..."
    
    local timeout=300
    local counter=0
    
    while [[ $counter -lt $timeout ]]; do
        if kubectl get nodes | grep -q "Ready"; then
            log "Master node is ready"
            break
        fi
        
        sleep 10
        counter=$((counter + 10))
        log "Waiting for node to be ready... (${counter}s/${timeout}s)"
    done
    
    if [[ $counter -ge $timeout ]]; then
        error "Master node did not become ready within ${timeout} seconds"
    fi
}

generate_join_command() {
    log "Generating worker node join command..."
    
    local join_command
    join_command=$(kubeadm token create --print-join-command 2>/dev/null)
    
    if [[ -n "$join_command" ]]; then
        echo ""
        log "=== WORKER NODE JOIN COMMAND ==="
        echo "$join_command"
        echo ""
        echo "Save this command to join worker nodes to the cluster."
        echo "Run: ./setup-worker-node.sh \"$join_command\""
        echo ""
        
        # Save join command to file
        echo "$join_command" > /tmp/k8s-join-command.txt
        log "Join command saved to /tmp/k8s-join-command.txt"
    else
        error "Failed to generate join command"
    fi
}

display_cluster_status() {
    log "Displaying cluster status..."
    
    echo ""
    echo "=== CLUSTER STATUS ==="
    kubectl get nodes -o wide
    echo ""
    kubectl get pods -A
    echo ""
}

display_next_steps() {
    log "Master node setup completed!"
    echo ""
    echo "Next steps:"
    echo "1. For regular users, run: /tmp/kubectl-setup.sh"
    echo "2. To join worker nodes, use the join command displayed above"
    echo "3. To verify cluster: kubectl get nodes"
    echo "4. To deploy a test application: kubectl create deployment nginx --image=nginx"
    echo ""
}

main() {
    log "Starting Kubernetes master node setup..."
    
    check_root
    check_prerequisites
    initialize_master_node
    setup_kubectl_for_root
    setup_kubectl_for_users
    install_cni_plugin
    wait_for_nodes
    generate_join_command
    display_cluster_status
    display_next_steps
    
    log "Master node setup completed successfully!"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --pod-network-cidr)
            POD_NETWORK_CIDR="$2"
            shift 2
            ;;
        --cni-plugin)
            CNI_PLUGIN="$2"
            shift 2
            ;;
        --control-plane-endpoint)
            CONTROL_PLANE_ENDPOINT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --pod-network-cidr CIDR    Pod network CIDR (default: 10.244.0.0/16)"
            echo "  --cni-plugin PLUGIN        CNI plugin: flannel or calico (default: flannel)"
            echo "  --control-plane-endpoint   Control plane endpoint for HA setup"
            echo "  -h, --help                 Show this help message"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

main "$@"