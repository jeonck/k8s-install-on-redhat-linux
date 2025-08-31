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

check_os_compatibility() {
    log "Checking OS compatibility..."
    
    if [[ ! -f /etc/redhat-release ]]; then
        error "This script is designed for Red Hat based distributions only"
        return 1
    fi
    
    local os_info
    os_info=$(cat /etc/redhat-release)
    log "OS: $os_info"
    
    local issues=0
    
    if grep -q "CentOS\|Red Hat\|Rocky\|Fedora" /etc/redhat-release; then
        log "✓ OS is compatible"
        
        # Check specific version requirements for Kubernetes 1.33
        if grep -q "Red Hat.*release 8\.[0-5]" /etc/redhat-release; then
            warning "✗ RHEL 8.0-8.5 detected. RHEL 8.6+ recommended for Kubernetes 1.33"
            issues=$((issues + 1))
        elif grep -q "Red Hat.*release 9\.[01]" /etc/redhat-release; then
            warning "✗ RHEL 9.0-9.1 detected. RHEL 9.2+ recommended for Kubernetes 1.33"
            issues=$((issues + 1))
        fi
    else
        error "✗ Unsupported OS version"
        return 1
    fi
    
    return $issues
}

check_system_resources() {
    log "Checking system resources..."
    
    local cpu_cores
    local memory_gb
    local disk_space_gb
    
    cpu_cores=$(nproc)
    memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    disk_space_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    
    log "CPU cores: $cpu_cores"
    log "Memory: ${memory_gb}GB"
    log "Available disk space: ${disk_space_gb}GB"
    
    local issues=0
    
    # Check CPU requirements
    if [[ $cpu_cores -lt 2 ]]; then
        warning "✗ CPU cores ($cpu_cores) is less than recommended (2 cores)"
        issues=$((issues + 1))
    else
        log "✓ CPU cores requirement met"
    fi
    
    # Check memory requirements
    if [[ $memory_gb -lt 2 ]]; then
        warning "✗ Memory (${memory_gb}GB) is less than recommended (2GB)"
        issues=$((issues + 1))
    else
        log "✓ Memory requirement met"
    fi
    
    # Check disk space requirements
    if [[ $disk_space_gb -lt 20 ]]; then
        warning "✗ Available disk space (${disk_space_gb}GB) is less than recommended (20GB)"
        issues=$((issues + 1))
    else
        log "✓ Disk space requirement met"
    fi
    
    return $issues
}

check_network_connectivity() {
    log "Checking network connectivity..."
    
    local issues=0
    local test_hosts=("8.8.8.8" "k8s.io" "github.com")
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 5 "$host" >/dev/null 2>&1; then
            log "✓ Can reach $host"
        else
            warning "✗ Cannot reach $host"
            issues=$((issues + 1))
        fi
    done
    
    return $issues
}

check_required_ports() {
    log "Checking required ports availability..."
    
    local issues=0
    local master_ports=(6443 2379 2380 10250 10251 10252 10255)
    local worker_ports=(10250 10255 30000)
    
    log "Checking master node ports..."
    for port in "${master_ports[@]}"; do
        if ss -tulpn | grep ":$port " >/dev/null 2>&1; then
            warning "✗ Port $port is already in use"
            issues=$((issues + 1))
        else
            log "✓ Port $port is available"
        fi
    done
    
    return $issues
}

check_swap_status() {
    log "Checking swap status..."
    
    if [[ $(swapon --show | wc -l) -gt 0 ]]; then
        warning "✗ Swap is enabled (Kubernetes requires swap to be disabled)"
        return 1
    else
        log "✓ Swap is disabled"
        return 0
    fi
}

check_selinux_status() {
    log "Checking SELinux status..."
    
    if command -v getenforce >/dev/null 2>&1; then
        local selinux_status
        selinux_status=$(getenforce)
        log "SELinux status: $selinux_status"
        
        if [[ "$selinux_status" == "Enforcing" ]]; then
            warning "✗ SELinux is in enforcing mode (should be permissive or disabled)"
            return 1
        else
            log "✓ SELinux is in appropriate mode"
            return 0
        fi
    else
        log "✓ SELinux tools not found (likely disabled)"
        return 0
    fi
}

check_kernel_modules() {
    log "Checking required kernel modules..."
    
    local issues=0
    local required_modules=("br_netfilter" "overlay")
    
    for module in "${required_modules[@]}"; do
        if lsmod | grep -q "^$module "; then
            log "✓ Module $module is loaded"
        elif modprobe "$module" 2>/dev/null; then
            log "✓ Module $module loaded successfully"
        else
            warning "✗ Cannot load module $module"
            issues=$((issues + 1))
        fi
    done
    
    return $issues
}

check_sysctl_parameters() {
    log "Checking required sysctl parameters..."
    
    local issues=0
    local required_params=(
        "net.bridge.bridge-nf-call-iptables:1"
        "net.bridge.bridge-nf-call-ip6tables:1"
        "net.ipv4.ip_forward:1"
    )
    
    for param in "${required_params[@]}"; do
        local key="${param%:*}"
        local expected_value="${param#*:}"
        local current_value
        
        if current_value=$(sysctl -n "$key" 2>/dev/null); then
            if [[ "$current_value" == "$expected_value" ]]; then
                log "✓ $key = $current_value"
            else
                warning "✗ $key = $current_value (should be $expected_value)"
                issues=$((issues + 1))
            fi
        else
            warning "✗ Cannot read $key"
            issues=$((issues + 1))
        fi
    done
    
    return $issues
}

check_kernel_version() {
    log "Checking kernel version for Kubernetes 1.33..."
    
    local issues=0
    local kernel_version
    kernel_version=$(uname -r | cut -d- -f1)
    local kernel_major=$(echo "$kernel_version" | cut -d. -f1)
    local kernel_minor=$(echo "$kernel_version" | cut -d. -f2)
    
    log "Kernel version: $(uname -r)"
    
    # Special handling for RHEL 8.x with 4.18 kernel
    if [[ $kernel_major -eq 4 && $kernel_minor -eq 18 ]] && grep -q "Red Hat.*release 8" /etc/redhat-release 2>/dev/null; then
        warning "! RHEL 8.x detected with kernel 4.18"
        log "  Red Hat backports features to 4.18 - some Kubernetes 1.33 features may work"
        log "  Consider testing in development environment first"
        log "  For production, RHEL 9.2+ (kernel 5.14+) is recommended"
        issues=$((issues + 1))
    # Check for Kubernetes 1.33 requirements
    elif [[ $kernel_major -lt 5 ]] || [[ $kernel_major -eq 5 && $kernel_minor -lt 13 ]]; then
        if [[ $kernel_major -lt 5 ]] || [[ $kernel_major -eq 5 && $kernel_minor -lt 4 ]]; then
            error "✗ Kernel $kernel_version is too old. Minimum 5.4+ required for Kubernetes 1.33"
            issues=$((issues + 2))
        else
            warning "✗ Kernel $kernel_version < 5.13. nftables mode will be limited (development only)"
            log "  Production environments should use kernel 5.13+"
            issues=$((issues + 1))
        fi
    else
        log "✓ Kernel version meets Kubernetes 1.33 requirements"
    fi
    
    # Check for nftables tool if kernel supports it
    if command -v nft >/dev/null 2>&1; then
        local nft_version
        nft_version=$(nft --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
        if [[ -n "$nft_version" ]]; then
            log "✓ nftables tool found (version: $nft_version)"
        fi
    else
        warning "! nftables tool (nft) not found - may be needed for kube-proxy nftables mode"
    fi
    
    return $issues
}

check_existing_installations() {
    log "Checking for existing installations..."
    
    local issues=0
    
    # Check for Docker
    if command -v docker >/dev/null 2>&1; then
        warning "✗ Docker is installed (may conflict with containerd)"
        issues=$((issues + 1))
    else
        log "✓ Docker not found"
    fi
    
    # Check for existing Kubernetes
    if command -v kubeadm >/dev/null 2>&1; then
        warning "! Kubernetes tools already installed"
        log "  kubeadm version: $(kubeadm version -o short 2>/dev/null || echo 'unknown')"
    fi
    
    if command -v containerd >/dev/null 2>&1; then
        warning "! containerd already installed"
        if systemctl is-active --quiet containerd; then
            log "  containerd is running"
        else
            log "  containerd is not running"
        fi
    fi
    
    return $issues
}

generate_report() {
    local total_issues=$1
    
    echo ""
    log "=== SYSTEM CHECK SUMMARY ==="
    
    if [[ $total_issues -eq 0 ]]; then
        log "✓ All checks passed! System is ready for Kubernetes installation."
    elif [[ $total_issues -le 3 ]]; then
        warning "⚠ Found $total_issues minor issues. System should work but may need attention."
    else
        error "✗ Found $total_issues issues. Please resolve these before installing Kubernetes."
    fi
    
    echo ""
    log "Recommendations:"
    echo "1. Ensure you have root privileges for installation"
    echo "2. Run ./prerequisites.sh to configure the system"
    echo "3. Run ./install-containerd.sh to install container runtime"
    echo "4. Run ./install-kubernetes.sh to install Kubernetes components"
}

main() {
    log "Starting Kubernetes 1.33 system compatibility check..."
    
    local total_issues=0
    
    check_os_compatibility || total_issues=$((total_issues + $?))
    check_kernel_version || total_issues=$((total_issues + $?))
    check_system_resources || total_issues=$((total_issues + $?))
    check_network_connectivity || total_issues=$((total_issues + $?))
    check_required_ports || total_issues=$((total_issues + $?))
    check_swap_status || total_issues=$((total_issues + $?))
    check_selinux_status || total_issues=$((total_issues + $?))
    check_kernel_modules || total_issues=$((total_issues + $?))
    check_sysctl_parameters || total_issues=$((total_issues + $?))
    check_existing_installations || total_issues=$((total_issues + $?))
    
    generate_report $total_issues
    
    exit $total_issues
}

main "$@"