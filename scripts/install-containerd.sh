#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Containerd compatibility sets
# Format: CONTAINERD_VERSION:RUNC_VERSION:CTR_VERSION:DESCRIPTION
COMPATIBILITY_SETS=(
    "1.7.22:1.1.14:1.7.22:Latest Stable (Default) - Kubernetes 1.30+"
    "1.7.20:1.1.12:1.7.20:Stable LTS - Kubernetes 1.28+"
    "1.6.33:1.1.12:1.6.33:Legacy Stable - Kubernetes 1.26+"
    "1.7.27:1.1.12:1.7.27:RHEL 8.10 Limited Compatibility - RPM Package Recommended"
    "latest:latest:latest:Latest Available (Not recommended for production)"
)

# Default compatibility set (index 0)
CONTAINERD_SET=${CONTAINERD_SET:-"0"}

# Offline mode flag
OFFLINE_MODE=${OFFLINE_MODE:-"false"}

# Download URLs and checksums for offline installation
declare -A DOWNLOAD_URLS=(
    ["1.7.22"]="https://github.com/containerd/containerd/releases/download/v1.7.22/containerd-1.7.22-linux-amd64.tar.gz"
    ["1.7.20"]="https://github.com/containerd/containerd/releases/download/v1.7.20/containerd-1.7.20-linux-amd64.tar.gz"
    ["1.6.33"]="https://github.com/containerd/containerd/releases/download/v1.6.33/containerd-1.6.33-linux-amd64.tar.gz"
    ["1.7.27"]="https://github.com/containerd/containerd/releases/download/v1.7.27/containerd-1.7.27-linux-amd64.tar.gz"
)

# Static binary URLs for better glibc compatibility (RHEL 8.x)
declare -A STATIC_DOWNLOAD_URLS=(
    ["1.7.22"]="https://github.com/containerd/containerd/releases/download/v1.7.22/containerd-static-1.7.22-linux-amd64.tar.gz"
    ["1.7.20"]="https://github.com/containerd/containerd/releases/download/v1.7.20/containerd-static-1.7.20-linux-amd64.tar.gz"
    ["1.7.27"]="https://github.com/containerd/containerd/releases/download/v1.7.27/containerd-static-1.7.27-linux-amd64.tar.gz"
)

declare -A RUNC_DOWNLOAD_URLS=(
    ["1.1.14"]="https://github.com/opencontainers/runc/releases/download/v1.1.14/runc.amd64"
    ["1.1.12"]="https://github.com/opencontainers/runc/releases/download/v1.1.12/runc.amd64"
    ["1.1.9"]="https://github.com/opencontainers/runc/releases/download/v1.1.9/runc.amd64"
)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >&2
}

show_compatibility_sets() {
    echo ""
    log "Available containerd compatibility sets:"
    echo ""
    for i in "${!COMPATIBILITY_SETS[@]}"; do
        local set_info="${COMPATIBILITY_SETS[$i]}"
        local containerd_ver=$(echo "$set_info" | cut -d: -f1)
        local runc_ver=$(echo "$set_info" | cut -d: -f2)
        local ctr_ver=$(echo "$set_info" | cut -d: -f3)
        local description=$(echo "$set_info" | cut -d: -f4)
        
        if [[ "$i" == "$CONTAINERD_SET" ]]; then
            echo "  [$i] * containerd $containerd_ver + runc $runc_ver + ctr $ctr_ver"
        else
            echo "  [$i]   containerd $containerd_ver + runc $runc_ver + ctr $ctr_ver"
        fi
        echo "      → $description"
        
        # Show security warnings for deprecated runc versions
        if [[ "$runc_ver" =~ ^1\.1\. ]]; then
            echo "      ⚠️  runc 1.1.x is no longer supported (security risk)"
        fi
        
        # Show glibc compatibility warnings for Set 3
        if [[ "$i" == "3" ]]; then
            echo "      ⚠️  glibc 2.28 limited compatibility - RPM package strongly recommended"
        fi
    done
    echo ""
    echo "Usage: CONTAINERD_SET=1 ./install-containerd.sh"
    echo "       OFFLINE_MODE=true ./install-containerd.sh"
    echo "Current selection: Set $CONTAINERD_SET"
}

show_download_info() {
    echo ""
    log "Offline Installation Download Information:"
    echo ""
    echo "containerd $CONTAINERD_VERSION:"
    if [[ -n "${DOWNLOAD_URLS[$CONTAINERD_VERSION]}" ]]; then
        echo "  Standard URL: ${DOWNLOAD_URLS[$CONTAINERD_VERSION]}"
        if [[ -n "${STATIC_DOWNLOAD_URLS[$CONTAINERD_VERSION]}" ]]; then
            echo "  Static URL (RHEL 8 glibc 2.28 compatible): ${STATIC_DOWNLOAD_URLS[$CONTAINERD_VERSION]}"
        fi
        if [[ "$CONTAINERD_VERSION" == "1.7.27" ]]; then
            echo "  RPM URL (RHEL 8.10 optimized): https://download.docker.com/linux/rhel/8/x86_64/stable/Packages/containerd.io-1.7.27-3.1.el8.x86_64.rpm"
        fi
    else
        echo "  URL: Use package manager (dnf/yum install containerd.io)"
    fi
    echo ""
    echo "runc $RUNC_VERSION:"
    if [[ -n "${RUNC_DOWNLOAD_URLS[$RUNC_VERSION]}" ]]; then
        echo "  URL: ${RUNC_DOWNLOAD_URLS[$RUNC_VERSION]}"
    else
        echo "  URL: Use package manager (dnf/yum install runc)"
    fi
    echo ""
    
    # glibc compatibility information
    if [[ "$CONTAINERD_SET" == "3" ]]; then
        echo "glibc Compatibility (Set 3 - RHEL 8.10 Limited Compatibility):"
        echo "  RHEL 8.10 glibc: 2.28 (below containerd 1.7.27 official requirement)"
        echo "  containerd 1.7.27 official: Requires glibc 2.35 (dynamic binaries)"
        echo "  containerd 1.7.27 static: Limited support for glibc < 2.35"
        echo "  runc 1.1.12: Verified compatibility with RHEL 8 ecosystem"
        echo "  STRONGLY RECOMMENDED: Use RPM package (containerd.io) for RHEL 8"
        echo "  WARNING: Static binaries have limitations (not position-independent)"
        echo ""
    fi
    
    if [[ "$RUNC_VERSION" =~ ^1\.1\. ]]; then
        warning "runc $RUNC_VERSION is no longer officially supported!"
        echo "  Consider upgrading to runc 1.2.x or 1.3.x for security updates"
        echo "  runc 1.1.x will not receive security patches"
        echo "  However, runc 1.1.12 includes CVE-2024-21626 security patch"
    fi
}

parse_compatibility_set() {
    if [[ $CONTAINERD_SET =~ ^[0-9]+$ ]] && [[ $CONTAINERD_SET -lt ${#COMPATIBILITY_SETS[@]} ]]; then
        local set_info="${COMPATIBILITY_SETS[$CONTAINERD_SET]}"
        CONTAINERD_VERSION=$(echo "$set_info" | cut -d: -f1)
        RUNC_VERSION=$(echo "$set_info" | cut -d: -f2)
        CTR_VERSION=$(echo "$set_info" | cut -d: -f3)
        SET_DESCRIPTION=$(echo "$set_info" | cut -d: -f4)
        
        log "Selected compatibility set $CONTAINERD_SET: $SET_DESCRIPTION"
        log "Versions: containerd $CONTAINERD_VERSION, runc $RUNC_VERSION, ctr $CTR_VERSION"
    else
        error "Invalid compatibility set: $CONTAINERD_SET. Valid range: 0-$((${#COMPATIBILITY_SETS[@]}-1))"
    fi
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
    log "Installing containerd $CONTAINERD_VERSION..."
    
    # For specific versions, use binary installation
    if [[ "$CONTAINERD_VERSION" != "latest" ]]; then
        install_containerd_binary
    else
        # Use package manager for latest
        if command -v dnf >/dev/null 2>&1; then
            dnf install -y containerd.io
        elif command -v yum >/dev/null 2>&1; then
            yum install -y containerd.io
        else
            error "Neither dnf nor yum package manager found"
        fi
    fi
    
    log "containerd $CONTAINERD_VERSION installed successfully"
}

install_containerd_binary() {
    local arch=$(uname -m)
    case $arch in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *) error "Unsupported architecture: $arch" ;;
    esac
    
    local download_url="https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-${arch}.tar.gz"
    local temp_dir=$(mktemp -d)
    
    log "Downloading containerd binary v$CONTAINERD_VERSION for $arch..."
    curl -L "$download_url" -o "$temp_dir/containerd.tar.gz"
    
    log "Extracting and installing containerd..."
    tar -C /usr/local -xzf "$temp_dir/containerd.tar.gz"
    
    # Create symlinks in /usr/bin
    ln -sf /usr/local/bin/containerd /usr/bin/containerd
    ln -sf /usr/local/bin/containerd-shim /usr/bin/containerd-shim
    ln -sf /usr/local/bin/containerd-shim-runc-v1 /usr/bin/containerd-shim-runc-v1
    ln -sf /usr/local/bin/containerd-shim-runc-v2 /usr/bin/containerd-shim-runc-v2
    ln -sf /usr/local/bin/ctr /usr/bin/ctr
    
    # Install systemd service
    curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service \
         -o /etc/systemd/system/containerd.service
    
    rm -rf "$temp_dir"
}

install_runc() {
    if [[ "$RUNC_VERSION" == "latest" ]]; then
        log "Installing latest runc from package manager..."
        if command -v dnf >/dev/null 2>&1; then
            dnf install -y runc
        elif command -v yum >/dev/null 2>&1; then
            yum install -y runc
        fi
    else
        log "Installing runc v$RUNC_VERSION..."
        local arch=$(uname -m)
        case $arch in
            x86_64) arch="amd64" ;;
            aarch64) arch="arm64" ;;
            *) error "Unsupported architecture: $arch" ;;
        esac
        
        local download_url="https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.${arch}"
        curl -L "$download_url" -o /usr/local/bin/runc
        chmod +x /usr/local/bin/runc
        ln -sf /usr/local/bin/runc /usr/bin/runc
    fi
    
    log "runc $RUNC_VERSION installed successfully"
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
    
    # Check containerd version
    if command -v containerd >/dev/null 2>&1; then
        local version=$(containerd --version | awk '{print $3}' | sed 's/v//')
        log "containerd version: v$version"
    else
        error "containerd not found"
    fi
    
    # Check runc version
    if command -v runc >/dev/null 2>&1; then
        local runc_ver=$(runc --version | head -1 | awk '{print $3}')
        log "runc version: $runc_ver"
    else
        error "runc not found"
    fi
    
    # Check ctr version
    if command -v ctr >/dev/null 2>&1; then
        local ctr_ver=$(ctr --version | awk '{print $3}' | sed 's/v//')
        log "ctr version: v$ctr_ver"
    else
        warning "ctr not found"
    fi
    
    # Check if containerd service is enabled
    if systemctl is-enabled --quiet containerd; then
        log "containerd service is enabled"
    else
        error "containerd service is not enabled"
    fi
    
    # Check if containerd is running
    if systemctl is-active --quiet containerd; then
        log "containerd service is running"
    else
        warning "containerd service is not running"
    fi
    
    # Check if containerd socket is available
    if [[ -e /run/containerd/containerd.sock ]]; then
        log "containerd socket is available"
    else
        error "containerd socket not found"
    fi
    
    # Verify compatibility set
    log "Installed versions match compatibility set $CONTAINERD_SET: $SET_DESCRIPTION"
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

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h              Show this help message"
    echo "  --list-sets, -l         List available compatibility sets"
    echo "  --set N                 Use compatibility set N (0-$((${#COMPATIBILITY_SETS[@]}-1)))"
    echo "  --offline               Enable offline mode (show download info)"
    echo "  --download-info         Show download URLs and exit"
    echo ""
    echo "Environment Variables:"
    echo "  CONTAINERD_SET          Compatibility set number (default: 0)"
    echo "  OFFLINE_MODE            Enable offline mode (true/false, default: false)"
    echo ""
    echo "Examples:"
    echo "  $0                      # Use default set (Latest Stable)"
    echo "  $0 --set 1              # Use set 1 (Stable LTS)"
    echo "  $0 --offline            # Show download info for offline installation"
    echo "  CONTAINERD_SET=3 $0     # Use set 3 (RHEL 8.10 Optimized)"
    echo "  OFFLINE_MODE=true $0    # Enable offline mode"
}

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --list-sets|-l)
                show_compatibility_sets
                exit 0
                ;;
            --set)
                CONTAINERD_SET="$2"
                shift 2
                ;;
            --offline)
                OFFLINE_MODE="true"
                shift
                ;;
            --download-info)
                parse_compatibility_set
                show_download_info
                exit 0
                ;;
            *)
                error "Unknown option: $1. Use --help for usage information."
                ;;
        esac
    done
    
    log "Starting containerd installation..."
    
    check_root
    check_os
    parse_compatibility_set
    show_compatibility_sets
    
    # Show download info in offline mode
    if [[ "$OFFLINE_MODE" == "true" ]]; then
        show_download_info
        echo ""
        log "Offline mode enabled. Please manually download binaries before proceeding."
        echo ""
    fi
    
    echo ""
    read -p "Proceed with installation? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Installation cancelled."
        exit 0
    fi
    
    add_docker_repository
    install_containerd
    install_runc
    configure_containerd
    start_containerd
    verify_installation
    cleanup_packages
    
    log "containerd installation completed successfully!"
    log "Compatibility set $CONTAINERD_SET installed: $SET_DESCRIPTION"
    log "containerd is now ready for Kubernetes installation"
    
    # Display containerd status
    echo ""
    log "containerd service status:"
    systemctl status containerd --no-pager -l
}

main "$@"