# 오프라인 설치 가이드

이 가이드는 인터넷 연결이 제한된 온프레미스 환경에서 Kubernetes 클러스터를 설치하는 방법을 설명합니다.

## 개요

오프라인 환경에서는 다음 구성요소들을 수동으로 다운로드하고 설치해야 합니다:
- containerd 컨테이너 런타임
- runc 저수준 컨테이너 런타임
- Kubernetes 바이너리 (kubeadm, kubelet, kubectl)
- CNI 플러그인
- 컨테이너 이미지

## 시스템 요구사항

### RHEL 8.10 + Kubernetes 1.30 권장 조합 (검증됨)
- **OS**: RHEL 8.10 (커널 4.18.0-553, glibc 2.28)
- **containerd**: 1.7.27 (LTS, Docker 공식 지원, glibc 2.28 완전 호환)
- **runc**: 1.1.12 (보안 패치 포함, RHEL 8 검증된 호환성)
- **Kubernetes**: 1.30.x
- **glibc 호환성**: 완전 검증됨 (glibc 2.28 지원)

> ⚠️ **보안 알림**: runc 1.1.x는 공식 지원 종료. 1.2.x 이상으로 업그레이드 권장

## 1단계: 바이너리 다운로드

### containerd 다운로드

#### 방법 1: RPM 패키지 (RHEL 8.10 권장)
```bash
# RHEL 8.10 glibc 2.28 최적화 RPM 패키지
wget https://download.docker.com/linux/rhel/8/x86_64/stable/Packages/containerd.io-1.7.27-3.1.el8.x86_64.rpm
```

#### 방법 2: 정적 바이너리 (glibc 2.28 호환)
```bash
# containerd 1.7.27 정적 바이너리 (RHEL 8.10 glibc 2.28 완전 호환)
wget https://github.com/containerd/containerd/releases/download/v1.7.27/containerd-static-1.7.27-linux-amd64.tar.gz
wget https://github.com/containerd/containerd/releases/download/v1.7.27/containerd-static-1.7.27-linux-amd64.tar.gz.sha256sum
```

#### 방법 3: 일반 바이너리 (참고용)
```bash
# containerd 1.7.27 일반 바이너리 (높은 glibc 요구 가능성)
wget https://github.com/containerd/containerd/releases/download/v1.7.27/containerd-1.7.27-linux-amd64.tar.gz
wget https://github.com/containerd/containerd/releases/download/v1.7.27/containerd-1.7.27-linux-amd64.tar.gz.sha256sum
```

### runc 다운로드
```bash
# runc 1.1.12 (CVE-2024-21626 보안 패치 포함)
wget https://github.com/opencontainers/runc/releases/download/v1.1.12/runc.amd64
wget https://github.com/opencontainers/runc/releases/download/v1.1.12/runc.amd64.asc
```

### systemd 서비스 파일
```bash
# containerd systemd 서비스
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
```

### CNI 플러그인
```bash
# CNI 플러그인 (Calico 사용 시)
wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz
```

## 2단계: 호환성 세트 확인

스크립트를 사용하여 다운로드 정보 확인:
```bash
# 호환성 세트 목록 보기
sudo ./scripts/install-containerd.sh --list-sets

# RHEL 8.10 최적화 세트 다운로드 정보
sudo ./scripts/install-containerd.sh --set 3 --download-info

# 오프라인 모드로 실행
sudo ./scripts/install-containerd.sh --set 3 --offline
```

## 3단계: 바이너리 검증

### SHA256 체크섬 검증
```bash
# containerd 바이너리 검증
sha256sum -c containerd-1.7.27-linux-amd64.tar.gz.sha256sum

# runc 서명 검증 (GPG 키 필요)
gpg --verify runc.amd64.asc runc.amd64
```

## 4단계: 수동 설치

### containerd 설치

#### RPM 패키지 방식
```bash
sudo dnf install -y ./containerd.io-1.7.27-3.1.el8.x86_64.rpm
```

#### 바이너리 방식
```bash
# containerd 바이너리 설치
sudo tar -C /usr/local -xzf containerd-1.7.27-linux-amd64.tar.gz

# 심볼릭 링크 생성
sudo ln -sf /usr/local/bin/containerd /usr/bin/containerd
sudo ln -sf /usr/local/bin/containerd-shim /usr/bin/containerd-shim
sudo ln -sf /usr/local/bin/containerd-shim-runc-v1 /usr/bin/containerd-shim-runc-v1
sudo ln -sf /usr/local/bin/containerd-shim-runc-v2 /usr/bin/containerd-shim-runc-v2
sudo ln -sf /usr/local/bin/ctr /usr/bin/ctr

# systemd 서비스 설치
sudo cp containerd.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable containerd
```

### runc 설치
```bash
sudo cp runc.amd64 /usr/local/bin/runc
sudo chmod +x /usr/local/bin/runc
sudo ln -sf /usr/local/bin/runc /usr/bin/runc
```

### CNI 플러그인 설치
```bash
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins-linux-amd64-v1.3.0.tgz
```

## 5단계: 설정 및 시작

### containerd 설정
```bash
sudo mkdir -p /etc/containerd
sudo containerd config default > /etc/containerd/config.toml

# SystemdCgroup 활성화
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# pause 이미지 설정
sudo sed -i 's|sandbox_image = ".*"|sandbox_image = "registry.k8s.io/pause:3.9"|' /etc/containerd/config.toml
```

### 서비스 시작
```bash
sudo systemctl start containerd
sudo systemctl status containerd
```

## 6단계: Kubernetes 바이너리 설치

### Kubernetes 1.30 바이너리 다운로드
```bash
# Kubernetes 바이너리
K8S_VERSION="v1.30.8"  # 최신 패치 버전 확인 후 사용

wget https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubeadm
wget https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubelet
wget https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl

# 체크섬 검증
wget https://dl.k8s.io/${K8S_VERSION}/bin/linux/amd64/kubeadm.sha256
wget https://dl.k8s.io/${K8S_VERSION}/bin/linux/amd64/kubelet.sha256
wget https://dl.k8s.io/${K8S_VERSION}/bin/linux/amd64/kubectl.sha256

echo "$(cat kubeadm.sha256) kubeadm" | sha256sum --check
echo "$(cat kubelet.sha256) kubelet" | sha256sum --check
echo "$(cat kubectl.sha256) kubectl" | sha256sum --check
```

### 설치 및 권한 설정
```bash
sudo install -o root -g root -m 0755 kubeadm /usr/local/bin/kubeadm
sudo install -o root -g root -m 0755 kubelet /usr/local/bin/kubelet
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# 심볼릭 링크
sudo ln -sf /usr/local/bin/kubeadm /usr/bin/kubeadm
sudo ln -sf /usr/local/bin/kubelet /usr/bin/kubelet
sudo ln -sf /usr/local/bin/kubectl /usr/bin/kubectl
```

## 7단계: 컨테이너 이미지 사전 준비

### 필수 이미지 목록 확인
```bash
kubeadm config images list --kubernetes-version v1.30.8
```

### 이미지 다운로드 및 저장
```bash
# 이미지 다운로드 (인터넷 연결된 환경에서)
kubeadm config images pull --kubernetes-version v1.30.8

# 이미지를 tar 파일로 저장
sudo ctr -n k8s.io images export k8s-images.tar \
  registry.k8s.io/kube-apiserver:v1.30.8 \
  registry.k8s.io/kube-controller-manager:v1.30.8 \
  registry.k8s.io/kube-scheduler:v1.30.8 \
  registry.k8s.io/kube-proxy:v1.30.8 \
  registry.k8s.io/pause:3.9 \
  registry.k8s.io/etcd:3.5.12-0 \
  registry.k8s.io/coredns/coredns:v1.11.1

# 오프라인 환경에서 이미지 로드
sudo ctr -n k8s.io images import k8s-images.tar
```

### Calico 이미지 (CNI 플러그인)
```bash
# Calico 이미지 다운로드 및 저장
sudo ctr images pull docker.io/calico/cni:v3.26.1
sudo ctr images pull docker.io/calico/node:v3.26.1
sudo ctr images pull docker.io/calico/kube-controllers:v3.26.1
sudo ctr images pull quay.io/tigera/operator:v1.30.4

# Calico 이미지 내보내기
sudo ctr images export calico-images.tar \
  docker.io/calico/cni:v3.26.1 \
  docker.io/calico/node:v3.26.1 \
  docker.io/calico/kube-controllers:v3.26.1 \
  quay.io/tigera/operator:v1.30.4
```

## 8단계: 검증

### 설치 검증
```bash
# 버전 확인
containerd --version
runc --version
kubeadm version
kubelet --version
kubectl version --client

# 서비스 상태 확인
sudo systemctl status containerd
```

### 클러스터 초기화 (마스터 노드)
```bash
# kubeadm으로 클러스터 초기화
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --kubernetes-version=v1.30.8 \
  --cri-socket=unix:///run/containerd/containerd.sock
```

## glibc 호환성 및 보안 고려사항

### RHEL 8.10 glibc 2.28 호환성 검증
RHEL 8.10 + containerd 1.7.27 + runc 1.1.12 조합의 glibc 호환성이 완전히 검증되었습니다:

**호환성 확인 결과**:
- **RHEL 8.10**: glibc 2.28 표준 탑재
- **containerd 1.7.27**: 정적 바이너리로 glibc 2.28 완전 지원
- **runc 1.1.12**: RHEL 8 컨테이너 에코시스템에서 검증된 호환성
- **권장 설치**: RPM 패키지 방식 (RHEL 8 최적화)

**최적 설치 검증 방법**:
```bash
# glibc 버전 확인
ldd --version

# 설치 후 버전 검증
containerd --version  # v1.7.27
runc --version        # 1.1.12

# 호환성 테스트
sudo ctr version
sudo systemctl status containerd
```

### runc 업그레이드 권장
현재 사용 중인 runc 1.1.12는 보안 패치가 포함되어 있지만, 1.1.x 브랜치는 더 이상 지원되지 않습니다.

**권장 업그레이드 경로:**
```bash
# runc 1.2.x 또는 1.3.x로 업그레이드
wget https://github.com/opencontainers/runc/releases/download/v1.2.6/runc.amd64
sudo cp runc.amd64 /usr/local/bin/runc
sudo chmod +x /usr/local/bin/runc
```

## 문제 해결

### 일반적인 문제
1. **컨테이너 이미지 로딩 실패**: containerd 네임스페이스 확인 (`k8s.io`)
2. **권한 문제**: 모든 바이너리가 실행 권한을 가지고 있는지 확인
3. **서비스 시작 실패**: systemd 서비스 파일 위치 및 권한 확인

### 로그 확인
```bash
# containerd 로그
sudo journalctl -u containerd -f

# kubelet 로그
sudo journalctl -u kubelet -f
```

## 추가 리소스

- [공식 containerd 문서](https://containerd.io/docs/)
- [Kubernetes 오프라인 설치 가이드](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [RHEL 8 컨테이너 도구](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/building_running_and_managing_containers/)

이 가이드를 통해 완전한 오프라인 환경에서도 안정적인 Kubernetes 클러스터를 구축할 수 있습니다.