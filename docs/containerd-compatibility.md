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

### 세트 3: RHEL 8.10 Tested
- **containerd**: 1.6.28
- **runc**: 1.1.9
- **ctr**: 1.6.28
- **용도**: RHEL 8.10 + Kubernetes 1.30 조합에서 검증됨
- **권장 대상**: RHEL 8.10 사용자

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
- **RHEL 8.10**: 세트 3 (RHEL 8.10 Tested) 권장
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
| 3    | 1.6.28     | 1.1.9  | 1.30     | ✅✅     | ✅       | RHEL8최적화|
| 4    | latest     | latest | 최신     | ❓       | ❓       | 낮음   |

범례:
- ✅ 완전 호환 및 권장
- ⚠️ 호환 가능하나 주의 필요  
- ❓ 테스트되지 않음
- ✅✅ 특별히 최적화됨

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