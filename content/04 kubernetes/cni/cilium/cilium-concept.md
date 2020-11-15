## 概念

Cilium 是一个开源软件，为使用 Kubernetes、Docker 和 Mesos 等 Linux 容器管理平台部署的应用程序，透明地提供和保护服务之间的网络和 API 连接。

Cilium 基于一种名为 BPF 的新 Linux 内核技术，它可以在 Linux 内部动态插入逻辑，以实现安全、可观察和网络控制需求。
Cilium 能够探测 Linux 内核中可用的特性，并在检测到最新特性时自动利用它们。
除了提供传统的网络级别的安全控制之外，BPF 的灵活性还可以在 API 和进程级别上实现安全控制，以保护容器或容器内的通信。
由于 BPF 在 Linux 内核中运行，因此可以做到在应用和更新 Cilium 安全策略时，无需对应用程序代码或容器配置进行任何更改。

## 组件

![images](http://70data.net/upload/kubernetes/cilium-arch.png)

### CNI 插件

每个容器平台都有自己的插件模型，用于外部网络集成。
对于 Docker，每个 Linux 节点都运行一个进程 cilium-docker 来处理每个 Docker libnetwork 调用，并将数据/请求传递给 Cilium Agent。

### Cilium Agent

用户空间守护程序，通过插件与容器运行时和编排系统交互，以便为在本地服务器上运行的容器设置网络和安全策略。
在每个 Linux 容器主机上运行。它会监听容器运行时中的事件，以了解容器何时启动或停止，并创建自定义 BPF 程序。Linux 内核使用这些程序来控制进出这些容器的所有网络访问。

- 开放 API， 允许被调用，包括配置、监控等。
- 采集新容器的 metadata，用于标识 Cilium 安全策略中的 Endpoint。
- 与 CNI 插件交互以执行 IPAM。IPAM 由 Agent 管理。
- 结合容器标识与策略，生成 BPF 程序，将 BPF 程序编译为字节码，并将它们传递给 Linux 内核。

除了在每个 Linux 容器主机上运行的组件之外，Cilium 还利用 KV 存储在不同节点上运行的 Cilium Agent 之间共享数据。目前支持的 KV 存储是 etcd、consul。

### Cilium CLI Client

用于与本地 Cilium Agent 通信。

### Cilium Operator

Cilium Operator 负责管理集群中的任务。
从逻辑上讲，应该以集群为粒度统一处理任务，而不是以节点为粒度处理任务。它的设计有助于解决在大型 Kubernetes 集群（>1000 节点）中的应用。

- 通过 etcd 同步节点资源
- 通过 etcd 为 Cluster Mesh 同步 Kubernetes Services
- 确保 Pod 的 DNS 可以被 Cilium 管理
- 转换 toGroups 安全策略
- 为每个 CiliumNetworkPolicy 向 kube-apiserver 发送来自整个集群的 CiliumNetworkPolicyNodeStatus 更新
- 对 Cilium Endpoints 进行垃圾回收，KV 存储中未使用的 security identities，CiliumNetworkPolicy 中已删除的节点的状态
- 与 AWS API 交互，管理 AWS ENI

## 网络模型

Cilium 完全控制了集群内端到端的连接，通过将信息嵌入到封装的报头中，它可以在两个容器主机之间传输状态和安全上下文信息，从而可以跟踪哪些 label 被作用到容器上。
容器本身不知道它所运行的底层网络。它只包含一个指向集群节点的 IP 地址的默认路由。由于在 Linux 内核中删除了路由缓存，减少了每个连接流缓存（TCP metrics）中需要保持的状态数量，从而允许终止每个容器中的数百万个连接。

https://docs.cilium.io/en/v1.8/concepts/networking/

