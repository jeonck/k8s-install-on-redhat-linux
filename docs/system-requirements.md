# Kubernetes 설치 시스템 요구사항

## 지원 운영체제

### Red Hat Enterprise Linux (RHEL)
- RHEL 8.x (8.6 이상 권장, Kubernetes 1.33용)
- RHEL 9.x (9.2 이상 권장, Kubernetes 1.33용)

> **Kubernetes 1.33 호환성**: RHEL 8.6+ 또는 9.2+ 사용 권장

### CentOS
- CentOS Stream 8 (8-stream)
- CentOS Stream 9 (9-stream)

### Rocky Linux
- Rocky Linux 8.x (8.5 이상)
- Rocky Linux 9.x (9.0 이상)

### Fedora
- Fedora 37 이상
- Fedora 38, 39 (테스트됨)

## 하드웨어 요구사항

### 마스터 노드 (Control Plane)

#### 최소 요구사항
- **CPU**: 2코어 이상
- **메모리**: 2GB RAM 이상
- **디스크**: 20GB 여유 공간 이상
- **네트워크**: 1Gbps 이더넷

#### 권장 요구사항
- **CPU**: 4코어 이상
- **메모리**: 4GB RAM 이상
- **디스크**: 50GB 이상 (SSD 권장)
- **네트워크**: 1Gbps 이더넷

#### 프로덕션 환경
- **CPU**: 8코어 이상
- **메모리**: 8GB RAM 이상
- **디스크**: 100GB 이상 (SSD 필수)
- **네트워크**: 10Gbps 이더넷 (가능한 경우)

### 워커 노드

#### 최소 요구사항
- **CPU**: 1코어 이상
- **메모리**: 1GB RAM 이상
- **디스크**: 10GB 여유 공간 이상
- **네트워크**: 1Gbps 이더넷

#### 권장 요구사항
- **CPU**: 2코어 이상
- **메모리**: 2GB RAM 이상
- **디스크**: 20GB 이상 (SSD 권장)
- **네트워크**: 1Gbps 이더넷

#### 프로덕션 환경
- **CPU**: 4코어 이상
- **메모리**: 8GB RAM 이상
- **디스크**: 50GB 이상 (SSD 권장)
- **네트워크**: 10Gbps 이더넷 (가능한 경우)

## 네트워크 요구사항

### 필수 포트

#### 마스터 노드
| 프로토콜 | 포트 범위 | 목적 | 사용자 |
|---------|----------|------|--------|
| TCP | 6443 | Kubernetes API 서버 | 모든 노드 |
| TCP | 2379-2380 | etcd 서버 클라이언트 API | kube-apiserver, etcd |
| TCP | 10250 | kubelet API | 마스터 노드 |
| TCP | 10251 | kube-scheduler | kube-scheduler |
| TCP | 10252 | kube-controller-manager | kube-controller-manager |
| TCP | 10255 | kubelet (읽기 전용) | Heapster |

#### 워커 노드
| 프로토콜 | 포트 범위 | 목적 | 사용자 |
|---------|----------|------|--------|
| TCP | 10250 | kubelet API | 마스터 노드 |
| TCP | 10255 | kubelet (읽기 전용) | Heapster |
| TCP | 30000-32767 | NodePort 서비스 | 외부 클라이언트 |

#### CNI 플러그인 포트

##### Flannel
| 프로토콜 | 포트 | 목적 |
|---------|------|------|
| UDP | 8285 | Flannel |
| UDP | 8472 | Flannel VXLAN |

##### Calico
| 프로토콜 | 포트 | 목적 |
|---------|------|------|
| TCP | 179 | Calico BGP |
| UDP | 4789 | Calico VXLAN |
| TCP | 5473 | Calico Typha |

### 네트워크 설정

#### Pod 네트워크 CIDR
- 기본값: `10.244.0.0/16`
- 기존 네트워크와 충돌하지 않도록 설정
- 클러스터 전체에서 고유해야 함

#### 서비스 네트워크 CIDR
- 기본값: `10.96.0.0/12`
- Pod 네트워크와 다른 대역 사용

#### 인터넷 연결
- 패키지 다운로드 필요
- 컨테이너 이미지 다운로드 필요
- DNS 해상도 필요

## 소프트웨어 요구사항

### 커널 버전

#### Kubernetes 1.33 요구사항
- **nftables 모드 (프로덕션)**: Linux 커널 5.13+ **필수**
- **테스트/개발 환경**: Linux 커널 5.4+ (프로덕션 비권장)
- **PSI 기능 사용시**: Linux 커널 4.20+ (`CONFIG_PSI=y`)

#### RHEL 8.x 커널 호환성
- **RHEL 8.x 기본 커널**: 4.18 기반 (모든 마이너 버전)
  - RHEL 8.6: 4.18.0-372.x
  - RHEL 8.8: 4.18.0-477.x  
  - RHEL 8.10: 4.18.0-5xx.x
- **백포팅 기능**: Red Hat이 5.x 기능을 4.18에 백포팅
- **nftables 지원**: 백포팅을 통해 제한적 지원 가능

#### RHEL 8.10 특별 권장사항
- **Kubernetes 1.30**: RHEL 8.10에서 완전히 테스트되고 안정적
- **Kubernetes 1.33**: 백포팅된 기능으로 동작 가능하지만 검증 필요
- **사용법**: `K8S_VERSION=1.30 ./install-kubernetes.sh`

#### 일반 요구사항
- **최소**: Linux 커널 3.10 이상
- **권장**: Linux 커널 5.13 이상 (Kubernetes 1.33)
- **RHEL 특이사항**: 백포팅으로 인해 커널 버전만으로는 판단 어려움

> **주의**: 
> - kube-proxy nftables 모드 사용시 커널 5.13+ 및 nft 1.0.1+ 필요
> - RHEL 8.x는 4.18 커널이지만 백포팅된 기능으로 일부 지원 가능
> - 프로덕션 환경에서는 RHEL 9.2+ (커널 5.14 기반) 권장

### 필수 커널 모듈
- `overlay`: OverlayFS 파일 시스템
- `br_netfilter`: 브리지 네트워크 필터링

### 필수 시스템 도구 (Kubernetes 1.33)
- `nft`: nftables 명령줄 도구 v1.0.1+ (nftables 모드 사용시)
- `containerd`: 컨테이너 런타임 (RHEL 8/9에서 Docker 대신 필수)

### 시스템 설정

#### swap 비활성화
```bash
# swap 상태 확인
swapon --show

# swap 비활성화 (필수)
swapoff -a
```

#### SELinux 설정
- **권장**: permissive 또는 disabled
- enforcing 모드에서는 추가 설정 필요

#### 방화벽 설정
- 필수 포트 오픈
- firewalld 또는 iptables 설정

### 패키지 매니저
- **RHEL/CentOS**: yum 또는 dnf
- **Rocky Linux**: dnf
- **Fedora**: dnf

## 성능 권장사항

### CPU 설정
- CPU 거버너: `performance` 모드 권장
- NUMA 노드 고려사항 (멀티소켓 시스템)

### 메모리 설정
- Huge Pages 설정 (대용량 메모리 사용 시)
- Memory swappiness 설정: `vm.swappiness=1`

### 디스크 설정
- SSD 사용 권장 (특히 etcd)
- 디스크 I/O 스케줄러: `deadline` 또는 `noop`
- 파일 시스템: `ext4` 또는 `xfs`

### 네트워크 설정
- MTU 크기: 1500 (기본값)
- TCP window scaling 활성화
- 네트워크 버퍼 크기 최적화

## 보안 요구사항

### 방화벽 설정
- 최소 권한 원칙 적용
- 불필요한 포트 차단
- SSH 접근 제한

### 사용자 권한
- root 권한 필요 (설치 시)
- 일반 사용자 kubectl 설정

### 인증서 관리
- kubeadm 자동 인증서 생성
- 인증서 만료 모니터링 (기본 1년)

## 모니터링 요구사항

### 시스템 모니터링
- CPU, 메모리, 디스크, 네트워크 사용량
- 로그 수집 및 분석

### Kubernetes 모니터링
- 클러스터 상태 모니터링
- Pod 및 서비스 상태
- 리소스 사용량 추적

## 백업 요구사항

### etcd 백업
- 정기적인 etcd 스냅샷
- 백업 복구 절차 준비

### 설정 백업
- Kubernetes 설정 파일
- containerd 설정
- 네트워크 설정

## 고가용성 구성

### 마스터 노드 HA
- 최소 3개 마스터 노드 권장
- 로드 밸런서 필요
- etcd 클러스터링

### 네트워크 HA
- 다중 네트워크 경로
- 네트워크 이중화

## 확장성 고려사항

### 클러스터 크기
- 최대 노드 수: 5000개
- 최대 Pod 수: 150,000개
- 노드당 최대 Pod 수: 110개

### 네트워크 확장성
- Pod 네트워크 CIDR 크기
- 서비스 네트워크 확장성

이러한 요구사항을 충족하지 않으면 설치나 운영 중 문제가 발생할 수 있습니다. 설치 전 `./scripts/utils/system-check.sh`를 실행하여 시스템 호환성을 확인하는 것을 권장합니다.