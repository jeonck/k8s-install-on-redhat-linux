# RHEL 8.10 최적 Kubernetes 1.30 설치 가이드

RHEL 8.10 환경의 glibc 2.28 제약 조건에서 Kubernetes 1.30을 안정적으로 설치하기 위한 최적 조합과 설치 방법을 제시합니다.

## 환경 분석

### RHEL 8.10 시스템 특성
- **OS**: Red Hat Enterprise Linux 8.10
- **커널**: 4.18.0-553 (백포팅 기능 포함)
- **glibc**: 2.28 (RHEL 8 계열 표준)
- **패키지 관리**: dnf/yum
- **컨테이너 지원**: Podman, Docker CE

### 제약 조건
- **glibc 2.28**: 최신 containerd 공식 요구사항 (glibc 2.35) 미만
- **커널 4.18**: Kubernetes 1.33 권장 커널 (5.13+) 미만
- **장기 지원**: RHEL 8 계열의 보안 패치 지원 기간 고려

## 최적 버전 조합 (검증됨)

### 🎯 권장 조합 #1: 안정성 우선
```
Kubernetes: 1.30.8 (최신 패치)
containerd: 1.7.20 (glibc 2.31 지원, LTS)
runc: 1.1.12 (보안 패치 포함)
CNI: Flannel 또는 Calico
설치 방식: RPM 패키지 (강력 권장)
```

**장점**:
- RPM 패키지로 의존성 자동 해결
- RHEL 8.10 완전 호환성 검증
- Docker 공식 지원 및 업데이트

**단점**:
- runc 1.1.x EOL (보안 패치 제한)

### 🔧 권장 조합 #2: 최신성 및 호환성 균형
```
Kubernetes: 1.30.8
containerd: 1.6.33 (glibc 2.28 네이티브 지원)
runc: 1.1.12 또는 1.2.6
CNI: Flannel 또는 Calico
설치 방식: 바이너리 직접 설치
```

**장점**:
- glibc 2.28과 완전 네이티브 호환
- containerd 1.6 LTS (2025년 2월까지 지원)
- 유연한 버전 관리

**단점**:
- 수동 의존성 관리 필요
- 업데이트 관리 복잡성

## containerd 버전 히스토리 및 glibc 호환성

### glibc 요구사항 변천사
```
containerd 1.6.x      : glibc 2.28+ 지원 (CentOS 7/RHEL 8 호환)
containerd 1.7.0~1.7.x: glibc 2.31 지원 (Ubuntu 20.04 기준)
containerd 2.0.0~2.0.5: glibc 2.31 지원 
containerd 2.0.6+     : glibc 2.35 필요 (Ubuntu 22.04 기준)
containerd 2.1.0+     : glibc 2.35 필요
```

### RHEL 8.10에서 사용 가능한 containerd 버전
- ✅ **containerd 1.6.33**: 완전 네이티브 호환 (권장)
- ✅ **containerd 1.7.20**: glibc 2.31 지원 (RPM 사용 시 호환)
- ⚠️ **containerd 1.7.27**: glibc 2.35 필요 (정적 바이너리 또는 RPM만)
- ❌ **containerd 2.0.6+**: glibc 2.35 필요 (호환 불가)

## 설치 방법 상세 가이드

### 방법 1: RPM 패키지 설치 (강력 권장)

#### 1단계: Docker CE 저장소 추가
```bash
# Docker CE 저장소 추가
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo

# 저장소 업데이트
sudo dnf update
```

#### 2단계: containerd 설치
```bash
# RHEL 8 최적화 containerd 설치
sudo dnf install -y containerd.io-1.6.33

# 또는 containerd 1.7.20
sudo dnf install -y containerd.io-1.7.20
```

#### 3단계: containerd 설정
```bash
# 설정 디렉토리 생성
sudo mkdir -p /etc/containerd

# 기본 설정 생성
sudo containerd config default > /etc/containerd/config.toml

# SystemdCgroup 활성화
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# pause 이미지 설정
sudo sed -i 's|sandbox_image = ".*"|sandbox_image = "registry.k8s.io/pause:3.9"|' /etc/containerd/config.toml

# 서비스 시작
sudo systemctl enable --now containerd
```

### 방법 2: 바이너리 직접 설치

#### containerd 1.6.33 설치 (glibc 2.28 네이티브)
```bash
# containerd 1.6.33 다운로드
wget https://github.com/containerd/containerd/releases/download/v1.6.33/containerd-1.6.33-linux-amd64.tar.gz
wget https://github.com/containerd/containerd/releases/download/v1.6.33/containerd-1.6.33-linux-amd64.tar.gz.sha256sum

# 체크섬 검증
sha256sum -c containerd-1.6.33-linux-amd64.tar.gz.sha256sum

# 설치
sudo tar -C /usr/local -xzf containerd-1.6.33-linux-amd64.tar.gz

# 심볼릭 링크 생성
sudo ln -sf /usr/local/bin/containerd /usr/bin/containerd
sudo ln -sf /usr/local/bin/containerd-shim /usr/bin/containerd-shim
sudo ln -sf /usr/local/bin/containerd-shim-runc-v1 /usr/bin/containerd-shim-runc-v1
sudo ln -sf /usr/local/bin/containerd-shim-runc-v2 /usr/bin/containerd-shim-runc-v2
sudo ln -sf /usr/local/bin/ctr /usr/bin/ctr
```

#### runc 설치
```bash
# runc 1.2.6 다운로드 (최신 지원 버전)
wget https://github.com/opencontainers/runc/releases/download/v1.2.6/runc.amd64
wget https://github.com/opencontainers/runc/releases/download/v1.2.6/runc.amd64.asc

# 설치
sudo cp runc.amd64 /usr/local/bin/runc
sudo chmod +x /usr/local/bin/runc
sudo ln -sf /usr/local/bin/runc /usr/bin/runc
```

#### systemd 서비스 설정
```bash
# containerd 서비스 파일 다운로드
sudo curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service \
     -o /etc/systemd/system/containerd.service

# 서비스 활성화
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
```

## Kubernetes 1.30 설치

### kubeadm, kubelet, kubectl 설치
```bash
# Kubernetes 저장소 추가
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
EOF

# Kubernetes 컴포넌트 설치
sudo dnf install -y kubelet-1.30.8 kubeadm-1.30.8 kubectl-1.30.8 --disableexcludes=kubernetes

# kubelet 서비스 활성화
sudo systemctl enable kubelet
```

### 클러스터 초기화 (마스터 노드)
```bash
# kubeadm 초기화
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --kubernetes-version=v1.30.8 \
  --cri-socket=unix:///run/containerd/containerd.sock \
  --ignore-preflight-errors=SystemVerification

# kubectl 설정
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## 호환성 검증 방법

### 시스템 정보 확인
```bash
# OS 및 커널 정보
cat /etc/redhat-release
uname -r

# glibc 버전 확인
ldd --version

# 설치된 패키지 확인
rpm -qa | grep -E "containerd|runc"
```

### containerd 기능 테스트
```bash
# containerd 버전 확인
containerd --version
runc --version

# containerd 기본 기능 테스트
sudo ctr version
sudo ctr namespaces list
sudo ctr images list

# 서비스 상태 확인
sudo systemctl status containerd
sudo systemctl status kubelet
```

### 간단한 파드 배포 테스트
```bash
# 테스트 파드 배포
kubectl run test-nginx --image=nginx:latest --port=80

# 파드 상태 확인
kubectl get pods
kubectl describe pod test-nginx

# 정리
kubectl delete pod test-nginx
```

## 문제 해결

### containerd 호환성 문제
```bash
# glibc 버전 불일치 오류 시
sudo dnf install -y containerd.io-1.6.33

# 또는 정적 바이너리 사용
wget https://github.com/containerd/containerd/releases/download/v1.6.33/containerd-static-1.6.33-linux-amd64.tar.gz
```

### runc 보안 경고
```bash
# runc 1.1.12에서 1.2.6으로 업그레이드
wget https://github.com/opencontainers/runc/releases/download/v1.2.6/runc.amd64
sudo cp runc.amd64 /usr/local/bin/runc
sudo systemctl restart containerd
sudo systemctl restart kubelet
```

### kubelet 시작 실패
```bash
# SELinux 설정 확인
sudo sestatus
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# 방화벽 포트 확인
sudo firewall-cmd --add-port=6443/tcp --permanent
sudo firewall-cmd --add-port=10250-10252/tcp --permanent
sudo firewall-cmd --reload

# swap 비활성화 확인
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab
```

## 보안 고려사항

### runc 버전 선택
- **runc 1.1.12**: CVE-2024-21626 보안 패치 포함, EOL 상태
- **runc 1.2.6**: 최신 지원 버전, 보안 업데이트 지속
- **권장**: runc 1.2.6 사용 (장기간 보안 지원)

### containerd 보안 설정
```bash
# containerd 네임스페이스 분리
sudo ctr --namespace k8s.io images list

# 컨테이너 보안 정책 적용 (선택사항)
sudo mkdir -p /etc/containerd/policies
```

## 성능 최적화

### containerd 튜닝
```bash
# /etc/containerd/config.toml 최적화
[plugins."io.containerd.grpc.v1.cri"]
  max_container_log_line_size = 16384
  
[plugins."io.containerd.grpc.v1.cri".containerd]
  default_runtime_name = "runc"
  
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
  Root = "/run/containerd/runc"
```

### 시스템 리소스 모니터링
```bash
# containerd 리소스 사용량
sudo systemctl status containerd
sudo journalctl -u containerd -f

# Kubernetes 리소스 확인
kubectl top nodes
kubectl top pods --all-namespaces
```

## 결론

RHEL 8.10 환경에서 Kubernetes 1.30을 안정적으로 운영하기 위해서는:

1. **RPM 패키지 방식** 우선 고려 (의존성 자동 해결)
2. **containerd 1.6.33** 또는 **1.7.20** 사용 (glibc 2.28 호환)
3. **runc 1.2.6** 업그레이드 권장 (보안 지원 지속)
4. **충분한 테스트** 후 프로덕션 적용

이 가이드의 조합은 RHEL 8.10의 glibc 2.28 제약 조건에서 최적화된 안정성과 보안성을 제공합니다.