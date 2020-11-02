kubectl 是 Kubernetes 的命令行工具。

## kubectl run 

![images](http://70data.net/upload/kubernetes/assetsF-LDAOok5ngY4pc1lEDesF-LM_rqip-tinVoiFZE0IF-LM_sEq_NuMALezRGMtGFworkflow.png)

![images](http://70data.net/upload/kubernetes/assetsF-LDAOok5ngY4pc1lEDesF-LM_rqip-tinVoiFZE0IF-LM_sL_pUFd7POA_evvOFpod-start.png)

Pod 启动过程：

1. 通过 kubectl 命令行，创建一个包含 Nginx 的 Deployment 对象，kubectl 会调用 kube-apiserver 往 etcd 里面写入一个 Deployment 对象。
2. Deployment Controller 监听到有新的 Deployment 对象被写入，就获取到对象信息，根据对象信息来做任务调度，创建对应的 Replica Set 对象。
3. Replication Controller 监听到有新的对象被创建，也读取到对象信息来做任务调度，创建对应的 Pod。
4. kube-scheduler 监听到有新的 Pod 被创建，读取到 Pod 对象信息，根据集群状态将 Pod 调度到某一个 Node 上，然后更新 Pod，将 Pod 和 Node 进行 bind。然后把 bind 的结果写回到 etcd。
5. kubelet 监听到当前的节点被指定了新的 Pod，就根据对象信息运行 Pod。
6. kubelet 会先 run Sandbox，会先启动一个 infra 容器，并执行 /pause 让 infra 容器的主进程永远挂起。这个容器存在的目的就是维持住 Pod 的 Namespace。真正的业务容器只要加入 infra 容器的 Namespace 就能实现对应 Namespace 的共享。
7. kubelet 通过 CRI 接口 gRPC 调用 docker-shim，请求创建一个容器。kubelet 可以视作一个简单的 CRI client，而 docker-shim 就是接收请求的 server。目前 docker-shim 的代码其实是内嵌在 kubelet 中的，所以接收调用的就是 kubelet 进程。
8. docker-shim 收到请求后，它会转化成 docker daemon 能听懂的请求，发到 docker daemon 上，并请求创建一个容器。
9. docker daemon 在 1.12 版本中就已经将针对容器的操作移到另一个守护进程 containerd 中了。因此 docker daemon 仍然不能帮人们创建容器，而是需要请求 containerd 创建一个容器。
10. containerd 收到请求后，并不会自己直接去操作容器，而是创建一个叫做 containerd-shim 的进程，让 containerd-shim 去操作容器。容器进程需要一个父进程来做诸如收集状态等工作。假如这个父进程就是 containerd，那每次 containerd 挂掉或升级后，整个宿主机上所有的容器都需要退出，但是引入了 containerd-shim 就规避了这个问题。
11. 创建容器需要做一些基础设置（Namespace、Cgroups、挂载 root filesystem）操作。这些事已经有了公开的规范 OCI。它的一个参考实现叫做 runc。containerd-shim 在这一步需要调用 runc 这个命令行工具，来启动容器。
12. runc 启动完容器后，它会直接退出，containerd-shim 则会成为容器进程的父进程，负责收集容器进程的状态，上报给 containerd。并在容器中 pid 为 1 的进程退出后接管容器中的子进程，然后进行清理，确保不会出现僵尸进程。

## 指定配置文件

```
/data/server/kubernetes/bin/kubectl --kubeconfig=/data/server/kubernetes/kubeconfig
```

## 命令补全

```
yum install bash-completion

source /usr/share/bash-completion/bash_completion

source <(kubectl completion bash)
```

