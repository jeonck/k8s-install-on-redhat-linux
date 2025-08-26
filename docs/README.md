# Kubernetes Installation on Red Hat Linux with containerd

이 프로젝트는 Red Hat 기반 Linux 배포판(RHEL, CentOS, Rocky Linux, Fedora)에서 containerd 런타임을 사용하여 Kubernetes 클러스터를 설치하는 자동화 스크립트를 제공합니다.

## 지원 운영체제

- Red Hat Enterprise Linux (RHEL) 8/9
- CentOS Stream 8/9  
- Rocky Linux 8/9
- Fedora 37+

## 시스템 요구사항

### 마스터 노드
- CPU: 2코어 이상
- 메모리: 2GB 이상 (4GB 권장)
- 디스크: 20GB 이상 여유 공간

### 워커 노드  
- CPU: 1코어 이상
- 메모리: 1GB 이상 (2GB 권장)
- 디스크: 10GB 이상 여유 공간

### 네트워크
- 모든 노드 간 통신 가능
- 인터넷 접속 (패키지 다운로드용)
- 방화벽 포트 설정 (자동으로 구성됨)

## 설치 순서

### 1. 시스템 호환성 확인

```bash
sudo ./scripts/utils/system-check.sh
```

### 2. 마스터 노드 설치

```bash
# 1. 사전 요구사항 설정
sudo ./scripts/prerequisites.sh

# 2. containerd 설치
sudo ./scripts/install-containerd.sh

# 3. Kubernetes 컴포넌트 설치
sudo ./scripts/install-kubernetes.sh

# 4. 마스터 노드 초기화
sudo ./scripts/setup-master-node.sh
```

### 3. 워커 노드 설치

```bash
# 1. 사전 요구사항 설정
sudo ./scripts/prerequisites.sh

# 2. containerd 설치
sudo ./scripts/install-containerd.sh

# 3. Kubernetes 컴포넌트 설치  
sudo ./scripts/install-kubernetes.sh

# 4. 클러스터에 조인 (마스터 노드에서 제공된 명령어 사용)
sudo ./scripts/setup-worker-node.sh "kubeadm join 192.168.1.100:6443 --token xxx --discovery-token-ca-cert-hash sha256:xxx"
```

## 스크립트 옵션

### setup-master-node.sh 옵션

```bash
sudo ./scripts/setup-master-node.sh --help

Options:
  --pod-network-cidr CIDR    Pod 네트워크 CIDR (기본값: 10.244.0.0/16)
  --cni-plugin PLUGIN        CNI 플러그인: flannel 또는 calico (기본값: flannel)
  --control-plane-endpoint   HA 설정을 위한 컨트롤 플레인 엔드포인트
  -h, --help                 도움말 표시
```

예시:
```bash
sudo ./scripts/setup-master-node.sh --pod-network-cidr 192.168.0.0/16 --cni-plugin calico
```

## CNI 플러그인

### Flannel (기본값)
- 간단하고 안정적인 오버레이 네트워크
- VXLAN 사용
- 기본 Pod CIDR: 10.244.0.0/16

### Calico
- 고성능 네트워킹 및 보안 정책 지원
- BGP 또는 VXLAN 사용 가능
- 네트워크 정책 지원

## 설치 후 확인

### 클러스터 상태 확인
```bash
kubectl get nodes
kubectl get pods -A
```

### 테스트 애플리케이션 배포
```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get services
```

## 문제 해결

일반적인 문제와 해결 방법은 [troubleshooting.md](troubleshooting.md)를 참조하세요.

### 로그 확인
```bash
# kubelet 로그
sudo journalctl -xeu kubelet

# containerd 로그  
sudo journalctl -xeu containerd

# 클러스터 이벤트
kubectl get events --sort-by=.metadata.creationTimestamp
```

### 설치 롤백
```bash
# 완전한 정리 및 제거
sudo ./scripts/utils/cleanup.sh
```

## 보안 고려사항

- SELinux는 permissive 모드로 설정됩니다
- 방화벽 포트가 자동으로 열립니다
- swap은 비활성화됩니다
- 필요한 커널 모듈이 로드됩니다

## 디렉토리 구조

```
k8s-install-on-redhat-linux/
├── scripts/                 # 설치 스크립트
│   ├── prerequisites.sh     # 시스템 사전 요구사항 설정
│   ├── install-containerd.sh# containerd 설치
│   ├── install-kubernetes.sh# Kubernetes 컴포넌트 설치
│   ├── setup-master-node.sh # 마스터 노드 초기화
│   ├── setup-worker-node.sh # 워커 노드 조인
│   └── utils/              # 유틸리티 스크립트
│       ├── system-check.sh  # 시스템 호환성 확인
│       └── cleanup.sh       # 설치 롤백
├── configs/                 # 설정 파일 템플릿
│   ├── containerd-config.toml
│   ├── kubernetes.conf
│   ├── k8s.repo
│   └── cni/                # CNI 설정
├── docs/                   # 문서
└── CLAUDE.md              # 개발 가이드
```

## 라이센스

MIT License

## 기여하기

이슈 리포트나 풀 리퀘스트를 환영합니다.