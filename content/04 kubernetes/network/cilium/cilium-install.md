## 基于 kubeadm 安装

### requirements

如果 kube-apiserver 采用 outside of cluster 的方式部署，那么 Cilium 也需要在 kube-apiserver 上部署。
可以采用 static pod 或者其他方式来部署。

### 安装步骤

不安装 kube-proxy

1.16

```shell script
kubeadm init --config kubeadm.yaml --skip-phases=addon/kube-proxy
```

1.15

```shell script
kubeadm init --config kubeadm.yaml

kubectl -n kube-system delete ds kube-proxy

iptables-restore <(iptables-save | grep -v KUBE)

kubectl taint nodes <node-name> node-role.kubernetes.io/master:NoSchedule-
```

### 安装网络插件

##### 使用 yaml 安装

http://70data.net/upload/manifest/cilium/cilium-1.7.0.yaml

安装

```shell script
kubectl apply -f cilium-1.7.0.yaml

kubectl -n kube-system  get all

kubectl -n kube-system  get pods --selector=k8s-app=cilium
```

卸载

```shell script
kubectl delete -f cilium-1.7.0.yaml
```

##### 使用 helm 安装

```shell script
helm repo add cilium https://helm.cilium.io/

helm install cilium cilium/cilium --version 1.7.0 \
    --namespace kube-system \
    --set global.nodePort.mode=dsr \
    --set global.tunnel=disabled \
    --set global.autoDirectNodeRoutes=true \
    --set global.kubeProxyReplacement=strict \
    --set global.k8sServiceHost=API_SERVER_IP \
    --set global.k8sServicePort=API_SERVER_PORT
```

## 异常排查

1. `minimal supported kernel version is >= 4.8.0; kernel version that is running is: 3.10.0"`
升级内核
2. `open /proc/sys/net/ipv6/conf/all/forwarding: no such file or directory` 开启 IPv6

```shell script
vim /etc/default/grub
GRUB_CMDLINE_LINUX="crashkernel=auto rhgb quiet ipv6.disable=0"

cp /boot/grub2/grub.cfg /boot/grub2/grub.cfg.bak

grub2-mkconfig -o /boot/grub2/grub.cfg

# UEFI系统
grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg

reboot

ip -4 addr show
ip -6 addr show
```

