# Containerd 호환성 가이드

이 문서는 Kubernetes와 RHEL 환경에서 검증된 containerd, runc, ctr의 호환 버전 조합을 제공합니다.

## 호환성 세트 개요

각 호환성 세트는 서로 호환되는 버전들의 조합으로, 특정 사용 사례에 최적화되어 있습니다.

### 세트 0: Latest Stable (기본값)
- **containerd**: 1.7.22
- **runc**: 1.1.14  
- **ctr**: 1.7.22
- **용도**: Kubernetes 1.30+ 환경에서 최신 안정 버전
- **권장 대상**: 새로운 클러스터 구축

### 세트 1: Stable LTS
- **containerd**: 1.7.20
- **runc**: 1.1.12
- **ctr**: 1.7.20  
- **용도**: Kubernetes 1.28+ 환경에서 장기 지원
- **권장 대상**: 프로덕션 환경에서 안정성 우선

### 세트 2: Legacy Stable
- **containerd**: 1.6.33
- **runc**: 1.1.12
- **ctr**: 1.6.33
- **용도**: Kubernetes 1.26+ 환경에서 레거시 지원
- **권장 대상**: 기존 클러스터 유지보수

### 세트 3: RHEL 8.10 Optimized
- **containerd**: 1.7.27
- **runc**: 1.1.12
- **ctr**: 1.7.27
- **용도**: RHEL 8.10 + Kubernetes 1.30 최적화 조합
- **권장 대상**: RHEL 8.10 사용자 (Docker 공식 지원)
- **glibc 호환성**: RHEL 8.10 glibc 2.28과 제한적 호환 (RPM 패키지 권장)

### 세트 4: Latest Available
- **containerd**: latest
- **runc**: latest
- **ctr**: latest
- **용도**: 개발 및 테스트 환경
- **권장 대상**: 최신 기능 테스트 (프로덕션 비권장)

## 사용법

### 기본 설치 (세트 0)
```bash
sudo ./scripts/install-containerd.sh
```

### 특정 세트 선택
```bash
# 환경 변수로 설정
CONTAINERD_SET=3 sudo ./scripts/install-containerd.sh

# 명령행 옵션으로 설정
sudo ./scripts/install-containerd.sh --set 3
```

### 사용 가능한 세트 확인
```bash
sudo ./scripts/install-containerd.sh --list-sets
```

### 도움말 보기
```bash
sudo ./scripts/install-containerd.sh --help
```

## 선택 가이드

### RHEL/CentOS 8.x 사용자
- **RHEL 8.10**: 세트 3 (RHEL 8.10 Optimized) 권장
- **RHEL 8.x 기타**: 세트 1 (Stable LTS) 권장

### RHEL/CentOS 9.x 사용자
- **새 클러스터**: 세트 0 (Latest Stable) 권장
- **프로덕션**: 세트 1 (Stable LTS) 권장

### Kubernetes 버전별 권장사항
- **Kubernetes 1.33**: 세트 0 (Latest Stable)
- **Kubernetes 1.30**: 세트 0 또는 1
- **Kubernetes 1.28**: 세트 1 (Stable LTS)
- **Kubernetes 1.26**: 세트 2 (Legacy Stable)

## 호환성 매트릭스

| 세트 | containerd | runc | Kubernetes | RHEL 8.x | RHEL 9.x | 안정성 |
|------|------------|------|------------|----------|----------|--------|
| 0    | 1.7.22     | 1.1.14 | 1.30+    | ⚠️       | ✅       | 높음   |
| 1    | 1.7.20     | 1.1.12 | 1.28+    | ✅       | ✅       | 매우높음|
| 2    | 1.6.33     | 1.1.12 | 1.26+    | ✅       | ✅       | 높음   |
| 3    | 1.7.27     | 1.1.12 | 1.30     | ✅✅     | ✅       | RHEL8최적화|
| 4    | latest     | latest | 최신     | ❓       | ❓       | 낮음   |

범례:
- ✅ 호환 및 권장
- ⚠️ 호환 가능하나 주의 필요  
- ❓ 테스트되지 않음
- ✅✅ 특별히 최적화됨

## 오프라인 설치 지원

온프레미스 환경을 위한 오프라인 설치를 지원합니다:

```bash
# 다운로드 링크 및 정보 확인
sudo ./scripts/install-containerd.sh --set 3 --download-info

# 오프라인 모드 실행
OFFLINE_MODE=true sudo ./scripts/install-containerd.sh --set 3
```

상세한 오프라인 설치 방법은 [오프라인 설치 가이드](offline-installation.md)를 참조하세요.

## glibc 호환성 정보

### RHEL 8.10 호환성 (제한적)
세트 3은 RHEL 8.10 환경에서 신중한 설치 방법 선택이 필요합니다:

**호환성 분석 결과**:
- **RHEL 8.10 glibc**: 2.28 (containerd 공식 요구사항 glibc 2.35 미만)
- **containerd 1.7.27**: 동적 바이너리는 glibc 2.35 필요, 정적 바이너리는 제한적 지원
- **runc 1.1.12**: RHEL 8 에코시스템에서 검증된 호환성
- **권장 설치 방법**: RPM 패키지 (Docker 공식 RHEL 8 지원)

**권장 설치 방식 우선순위**:
```bash
# 1순위: RPM 패키지 방식 (강력 권장 - RHEL 8 최적화)
wget https://download.docker.com/linux/rhel/8/x86_64/stable/Packages/containerd.io-1.7.27-3.1.el8.x86_64.rpm
sudo dnf install -y ./containerd.io-1.7.27-3.1.el8.x86_64.rpm

# 2순위: 정적 바이너리 방식 (오프라인 환경, 주의사항 숙지 필요)
# ⚠️ 주의: position-independent 미지원, 별도 runc/CNI 설치 필요
wget https://github.com/containerd/containerd/releases/download/v1.7.27/containerd-static-1.7.27-linux-amd64.tar.gz

# 3순위: 동적 바이너리 (호환 불가능 - glibc 2.35 필요)
# ❌ RHEL 8.10에서 사용 불가
```

## 보안 권장사항

### runc 버전 주의사항
- **runc 1.1.x**: 공식 지원 종료 (보안 업데이트 없음)
- **권장**: runc 1.2.x 이상으로 업그레이드
- **CVE-2024-21626**: runc 1.1.12에 보안 패치 포함됨
- **RHEL 8.10 호환성**: glibc 2.28에서 안정적 동작 검증

## 문제 해결

### 버전 불일치 문제
다른 호환성 세트로 재설치:
```bash
# 기존 containerd 제거
sudo ./scripts/utils/cleanup.sh

# 다른 세트로 설치
CONTAINERD_SET=1 sudo ./scripts/install-containerd.sh
```

### 바이너리 설치 문제
패키지 매니저 사용 권장:
```bash
CONTAINERD_SET=4 sudo ./scripts/install-containerd.sh  # latest 사용
```

### 호환성 검증
```bash
# 설치된 버전 확인
containerd --version
runc --version
ctr --version

# containerd 서비스 상태 확인
sudo systemctl status containerd
```

## 업데이트 정책

- **정기 업데이트**: 월 1회 호환성 세트 검토 및 업데이트
- **보안 패치**: 중요 보안 업데이트 시 즉시 반영
- **Kubernetes 호환성**: 새 Kubernetes 버전 출시 시 호환성 검증

## 참고 자료

- [containerd 릴리스 노트](https://github.com/containerd/containerd/releases)
- [runc 릴리스 노트](https://github.com/opencontainers/runc/releases)
- [Kubernetes containerd 호환성](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd)
- [Red Hat Container 호환성 매트릭스](https://access.redhat.com/support/policy/rhel-container-compatibility)