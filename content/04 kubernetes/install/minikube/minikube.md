## 概念

Minikube 是一个运行在 Linux、macOS、Windows 的本地 Kubernetes 集群。

支持：

- Multi-cluster
- LoadBalancer
- NodePorts
- Ingress
- Dashboard
- Persistent Volumes
- Filesystem mounts
- RBAC
- Container runtimes
- Addons
- GPU support

## 使用

下载 Minikube。
https://github.com/kubernetes/minikube/releases

```shell script
wget https://github.com/kubernetes/minikube/releases/download/v1.6.2/minikube-linux-amd64
```

启动

因为是物理机（bare-metal）启动，所以需要加参数 `--vm-driver=none`。

```shell script
minikube start --vm-driver=none
```

查看部署

```shell script
/data/server/k8s/bin/kubectl --kubeconfig=/data/server/k8s/config/mini.kubeconfig  get all --all-namespaces
NAMESPACE     NAME                                   READY   STATUS    RESTARTS   AGE
kube-system   pod/coredns-6955765f44-254pd           1/1     Running   0          8m45s
kube-system   pod/coredns-6955765f44-6bl2n           1/1     Running   0          8m45s
kube-system   pod/etcd-minikube                      1/1     Running   0          8m32s
kube-system   pod/kube-addon-manager-minikube        1/1     Running   0          8m32s
kube-system   pod/kube-apiserver-minikube            1/1     Running   0          8m32s
kube-system   pod/kube-controller-manager-minikube   1/1     Running   0          8m32s
kube-system   pod/kube-proxy-hnwxp                   1/1     Running   0          8m45s
kube-system   pod/kube-scheduler-minikube            1/1     Running   0          8m31s
kube-system   pod/storage-provisioner                1/1     Running   0          8m43s

NAMESPACE     NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
default       service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP                  8m54s
kube-system   service/kube-dns     ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   8m53s

NAMESPACE     NAME                        DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                 AGE
kube-system   daemonset.apps/kube-proxy   1         1         1       1            1           beta.kubernetes.io/os=linux   8m52s

NAMESPACE     NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
kube-system   deployment.apps/coredns   2/2     2            2           8m53s

NAMESPACE     NAME                                 DESIRED   CURRENT   READY   AGE
kube-system   replicaset.apps/coredns-6955765f44   2         2         2       8m45s
```

停止

```shell script
minikube stop
```

删除

```shell script
minikube delete --all
```

## 清理环境

```shell script
systemctl stop kubelet.service

rm -rf /var/lib/kubelet/

rm -f /usr/lib/systemd/system/kubelet.service

rm -rf /etc/systemd/system/kubelet.service.d/

systemctl daemon-reload

docker stop $(docker ps -qa)

docker rm $(docker ps -qa)

rm -rf /root/.kube/

rm -rf /root/.minikube/

rm -rf /var/lib/minikube/

rm -rf /etc/kubernetes/

rm -rf /var/run/kubernetes

rm -rf /var/lib/etcd

rm -rf /etc/cni/net.d

iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X

ipvsadm --clear
```

