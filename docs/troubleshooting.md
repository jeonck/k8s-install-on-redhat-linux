# Kubernetes 설치 문제 해결 가이드

## 일반적인 문제

### 1. kubelet 시작 실패

#### 증상
```
sudo systemctl status kubelet
● kubelet.service - kubelet: The Kubernetes Node Agent
   Active: failed (Result: exit-code)
```

#### 해결 방법
```bash
# 1. kubelet 로그 확인
sudo journalctl -xeu kubelet

# 2. containerd 상태 확인
sudo systemctl status containerd

# 3. swap이 비활성화되어 있는지 확인
swapon --show

# 4. 설정 파일 확인
sudo cat /etc/systemd/system/kubelet.service.d/20-containerd.conf
```

### 2. 노드가 Ready 상태가 되지 않음

#### 증상
```bash
kubectl get nodes
NAME     STATUS     ROLES           AGE   VERSION
master   NotReady   control-plane   5m    v1.29.0
```

#### 해결 방법
```bash
# 1. CNI 플러그인 상태 확인
kubectl get pods -n kube-system

# 2. CNI 설정 확인
ls -la /etc/cni/net.d/
ls -la /opt/cni/bin/

# 3. Flannel 재설치 (Flannel 사용 시)
kubectl delete -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

### 3. 컨테이너 이미지 풀 실패

#### 증상
```
Failed to pull image "registry.k8s.io/pause:3.9": rpc error: code = Unknown
```

#### 해결 방법
```bash
# 1. containerd 설정 확인
sudo cat /etc/containerd/config.toml | grep sandbox_image

# 2. 네트워크 연결 확인
ping registry.k8s.io

# 3. containerd 재시작
sudo systemctl restart containerd

# 4. 수동으로 이미지 다운로드 테스트
sudo ctr image pull registry.k8s.io/pause:3.9
```

### 4. 워커 노드 조인 실패

#### 증상
```
[ERROR] unable to add node to cluster: unable to connect to endpoint
```

#### 해결 방법
```bash
# 1. 마스터 노드에서 토큰 확인
kubeadm token list

# 2. 새 토큰 생성 (만료된 경우)
kubeadm token create --print-join-command

# 3. 방화벽 확인
sudo firewall-cmd --list-ports

# 4. 네트워크 연결 확인
telnet <master-ip> 6443

# 5. 노드 리셋 후 재시도
sudo kubeadm reset -f
```

### 5. DNS 해상도 문제

#### 증상
```bash
# 테스트 Pod에서
nslookup kubernetes.default
;; connection timed out; no servers could be reached
```

#### 해결 방법
```bash
# 1. CoreDNS 상태 확인
kubectl get pods -n kube-system | grep coredns

# 2. CoreDNS 로그 확인
kubectl logs -n kube-system -l k8s-app=kube-dns

# 3. DNS 서비스 확인
kubectl get svc -n kube-system

# 4. CoreDNS 재시작
kubectl delete pod -n kube-system -l k8s-app=kube-dns
```

## CNI 관련 문제

### Flannel 문제

#### flannel Pod가 시작되지 않음
```bash
# 1. flannel 로그 확인
kubectl logs -n kube-flannel daemonset/kube-flannel-ds

# 2. 호스트 네트워크 인터페이스 확인
ip addr show

# 3. flannel 설정 확인
kubectl get configmap -n kube-flannel kube-flannel-cfg -o yaml

# 4. 재설치
kubectl delete namespace kube-flannel
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

### Calico 문제

#### Calico 노드가 시작되지 않음
```bash
# 1. Calico 상태 확인
kubectl get pods -n calico-system

# 2. Tigera operator 확인
kubectl get pods -n tigera-operator

# 3. Installation 상태 확인
kubectl get installation -o yaml

# 4. 재설치
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
```

## 시스템 관련 문제

### SELinux 관련 문제

#### 증상
```
SELinux is preventing access
```

#### 해결 방법
```bash
# 1. SELinux 상태 확인
getenforce

# 2. SELinux를 permissive 모드로 변경
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# 3. 재부팅
sudo reboot
```

### 방화벽 관련 문제

#### 연결이 차단됨
```bash
# 1. 방화벽 상태 확인
sudo firewall-cmd --list-all

# 2. 필요한 포트 열기
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --permanent --add-port=2379-2380/tcp
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --permanent --add-port=10251/tcp
sudo firewall-cmd --permanent --add-port=10252/tcp
sudo firewall-cmd --reload

# 3. 방화벽 비활성화 (테스트용)
sudo systemctl stop firewalld
sudo systemctl disable firewalld
```

### 디스크 공간 부족

#### 증상
```
no space left on device
```

#### 해결 방법
```bash
# 1. 디스크 사용량 확인
df -h
du -sh /var/lib/containerd/*
du -sh /var/lib/kubelet/*

# 2. containerd 이미지 정리
sudo ctr image prune

# 3. 사용하지 않는 컨테이너 정리
sudo ctr container rm $(sudo ctr container list -q)

# 4. 로그 파일 정리
sudo journalctl --vacuum-time=7d
```

## 성능 최적화

### kubelet 설정 최적화

```bash
# /var/lib/kubelet/config.yaml 수정
sudo vi /var/lib/kubelet/config.yaml

# 추가 설정:
# maxPods: 110
# imageGCHighThreshold: 85
# imageGCLowThreshold: 80
# evictionHard:
#   memory.available: "100Mi"
#   nodefs.available: "10%"
```

### containerd 설정 최적화

```bash
# /etc/containerd/config.toml 수정
sudo vi /etc/containerd/config.toml

# 설정 확인:
# [plugins."io.containerd.grpc.v1.cri".registry]
#   config_path = "/etc/containerd/certs.d"
```

## 완전 재설치

문제가 해결되지 않는 경우, 완전히 정리 후 재설치:

```bash
# 1. 완전 정리
sudo ./scripts/utils/cleanup.sh

# 2. 시스템 재부팅
sudo reboot

# 3. 재설치
sudo ./scripts/prerequisites.sh
sudo ./scripts/install-containerd.sh
sudo ./scripts/install-kubernetes.sh
sudo ./scripts/setup-master-node.sh
```

## 유용한 진단 명령어

```bash
# 시스템 정보
hostnamectl
cat /etc/redhat-release
uname -r

# 네트워크 정보
ip addr show
ip route show
ss -tulpn | grep -E "(6443|2379|10250)"

# Kubernetes 정보
kubectl version
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events --sort-by=.metadata.creationTimestamp

# containerd 정보
sudo ctr version
sudo ctr image list
sudo ctr container list

# 로그 수집
sudo journalctl -xeu kubelet > kubelet.log
sudo journalctl -xeu containerd > containerd.log
```

## 추가 도움말

- [Kubernetes 공식 문서](https://kubernetes.io/docs/home/)
- [containerd 공식 문서](https://containerd.io/)
- [Red Hat OpenShift 문서](https://docs.openshift.com/)