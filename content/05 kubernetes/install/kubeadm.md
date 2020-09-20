## 准备工作

### 关闭防火墙

```
systemctl stop firewalld

systemctl disable firewalld
```

### 禁用 selinux
 
```   
setenforce 0

cat /etc/selinux/config
SELINUX=disabled
```

### 修改内核参数

```
cat /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
# Linux 的 bridge filter 提供了 bridge-nf-call-iptables 机制来使 bridge 的 Netfilter 可以复用 IP 层的 Netfilter 代码
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.tcp_challenge_ack_limit = 999999999
# 关闭 ipv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv6.conf.all.forwarding = 1
net.bridge.bridge-nf-call-ip6tables = 1
kernel.kptr_restrict = 1
vm.swappiness = 0

sysctl -p /etc/sysctl.d/k8s.conf
```

加载内核模块

```
modprobe br_netfilter
```

### 关闭 swap

```
swapoff -a
```

## ipvs 配置

配置 ipvs 模块

```
cat /etc/sysconfig/modules/ipvs.modules
#! /bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
```

加载 ipvs 模块

```
chmod 755 /etc/sysconfig/modules/ipvs.modules

bash /etc/sysconfig/modules/ipvs.modules
```

查看 ipvs 模块

```
lsmod | grep -e ip_vs -e nf_conntrack_ipv4
```

安装 ipvsadm

```
yum install ipvsadm
```

安装 ipset

```
yum install ipset
```

## 安装

### 安装 kubeadm

配置 yum 源

```
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
``` 

安装指定版本的 kubeadm、kubelet、kubectl

```
yum list kubelet kubeadm kubectl --showduplicates | sort -r

yum install kubelet-1.15.9 kubeadm-1.15.9 kubectl-1.15.9
```

## 配置

生成 kubeadm 配置文件

http://70data.net/upload/manifest/kubeadm/kubeadm-1.15.3.yaml

使用 kubeadm 安装集群

```
kubeadm init --config kubeadm.yaml
```

配置 kubeconfig

```
mkdir -p $HOME/.kube

sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

查看节点

```
kubectl get nodes
NAME      STATUS     ROLES    AGE     VERSION
foo1001   NotReady   master   3m42s   v1.15.9
```

取消节点 taint

```
kubectl taint nodes <node-name> node-role.kubernetes.io/master:NoSchedule-
```

kubeadm 配置参数 https://pkg.go.dev/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta2?tab=doc

清空重装

```
kubeadm reset

iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X

ipvsadm --clear
```

## 异常排查

1. https://stackoverflow.com/questions/52823871/unable-to-join-the-worker-node-to-k8-master-node
2. `[kubelet-check] Initial timeout of 40s passed.` 使用 `journalctl -xeu kubelet` 排查
