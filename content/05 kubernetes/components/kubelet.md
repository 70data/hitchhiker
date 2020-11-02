## 架构

每个 Node 节点上都运行一个 kubelet 服务进程，默认监听 10250 端口。
kubelet 接收并执行 Master 发来的指令，管理 Pod 及 Pod 中的容器。
每个 kubelet 进程会在 kube-apiserver 上注册所在 Node 节点的信息，定期向 Master 节点汇报该节点的资源使用情况，并通过 cAdvisor 监控节点和容器的资源。

![images](http://70data.net/upload/kubernetes/ibCMjn7KxKJjSLUBoXMBSziaOIm9iaxW9VQ.webp)

![images](http://70data.net/upload/kubernetes/assetsF-LDAOok5ngY4pc1lEDesF-LM_rqip-tinVoiFZE0IF-LM_sL_nrAJ7vw0gM2BvFkubelet.png)

- kubelet Server 对外提供 API，供 kube-apiserver、metrics-server 等服务调用。
- Container Manager 管理容器的各种资源，比如 Cgroups、QoS、cpuset、device 等。
- Volume Manager 管理容器的存储卷，比如格式化资盘、挂载到 Node 本地、最后再将挂载路径传给容器。
- cAdvisor 负责为容器提供 Metrics。
- Metrics 和 stats 提供容器和节点的度量数据。
- Eviction 负责容器的驱逐。
- Generic Runtime Manager 是容器运行时的管理者，负责于 CRI 交互，完成容器和镜像的管理。
- CRI gRPC server 监听 unix socket。
- Streaming Server 提供 streaming API，包括 Exec、Attach、Port Forward。
- CNI 给容器配置网络。
- Container Engine 容器管理引擎，支持 runc 、containerd、Kata 或者支持多个容器引擎。

## 节点管理

节点管理主要是节点自注册和节点状态更新。

kubelet 可以通过设置启动参数 `--register-node` 来确定是否向 kube-apiserver 注册自己。
如果 kubelet 没有选择自注册模式，则需要用户自己配置 Node 资源信息，同时需要告知 kubelet 集群上的 kube-apiserver 的位置。

kubelet 会默认保留 30000-32767 端口。如果有 service 采用 NodePort 的形式，暴露的端口也在这个范围内。

节点状态分四类

- Addresses
- Condition
- Capacity
- Info

### Addresses

- Hostname。可以通过 kubelet 的 `--hostname-override` 参数进行覆盖。
- ExternalIP。通常是可以外部路由的 Node IP 地址（从集群外可访问）。
- InternalIP。通常是仅可在集群内部路由的 Node IP 地址。

### Condition

Condition 字段描述了所有 Running nodes 的状态。

### Capacity

描述 Node 上的可用资源，CPU、Memory 和可以调度到该 Node 上的最大 Pod 数量。

### Info

描述 Node 的一些通用信息。内核版本、Kubernetes 版本（kubelet 和 kube-proxy 版本）、Docker 版本和系统版本。

### 状态上报

如果一个 Node 处于非 Ready 状态超过 pod-eviction-timeout 的值（默认值 5 分钟，在 kube-controller-manager 中定义），会触发 Node 上 Pod 的状态变更。
在 v1.5 之前的版本中 kube-controller-manager 会 force delete Pod，然后调度该宿主上的 Pod 到其他宿主。
在 v1.5 之后的版本中 kube-controller-manager 不会 force delete Pod。Pod 会一直处于 Terminating 或 Unknown 状态，直到 Node 被从 Master 中删除或 kubelet 状态变为 Ready。
在 Node NotReady 期间，Daemonset 的 Pod 状态变为 Nodelost，Deployment、Statefulset 和 Static Pod 的状态先变为 NodeLost，然后马上变为 Unknown。Deployment 的 Pod 会 recreate。Statefulset 和 Static Pod 会一直处于 Unknown 状态。
当 kubelet 变为 Ready 状态时，Daemonset 的 Pod 不会 recreate，旧 Pod 状态直接变为 Running。Deployment 的 Pod 则是将 kubelet 进程停止的 Node 删除。Statefulset 的 Pod 会重新 recreate。Staic Pod 会被删除。

kubelet 有两种上报状态的方式。

- NodeStatus,定期向 kube-apiserver 发送心跳消息。
- NodeLease。

在 v1.13 之前的版本中，节点的心跳只有 NodeStatus。
从 v1.13 开始，NodeLease feature 作为 alpha 特性引入。
当启用 NodeLease feature 时，每个节点在 `kube-node-lease` 名称空间中都有一个关联的 `Lease` 对象，该对象由节点定期更新，NodeStatus 和 NodeLease 都被视为来自节点的心跳。

## Pod 管理

### 容器健康检查

- LivenessProbe 探针，用于判断容器是否健康。
- ReadinessProbe 探针，用于判断容器是否启动完成且准备接收请求。

#### LivenessProbe

探测应用是否处于健康状态，如果不健康则删除并重新创建容器。
LivenessProbe 能让 Kubernetes 知道应用是否存活。
如果应用是存活的，Kubernetes 不做任何处理。
如果 LivenessProbe 探测到容器不健康，则 kubelet 将删除该容器，并根据容器的重启策略做相应的处理。
如果一个容器不包含 LivenessProbe，那么 kubelet 认为该容器的 LivenessProbe 返回的值永远是 "Success"。

#### ReadinessProbe

探测应用是否启动完成并且处于正常服务状态，如果不正常则不会接收来自 Service 的流量。
设计 ReadinessProbe 的目的是用来让 Kubernetes 知道应用何时能对外提供服务。
在服务发送流量到 Pod 之前，Kubernetes 必须确保 ReadinessProbe 检测成功。
如果 ReadinessProbe 检测失败了，Kubernetes 会停掉 Pod 的流量，直到 ReadinessProbe 检测成功。如果 ReadinessProbe 探测到失败，Endpoint Controller 将从 Service 的 Endpoint 中删除包含该容器所在 Pod 的 IP 地址的 Endpoint。

#### 应用场景

假设应用需要时间进行预热和启动。即便进程已经启动，服务依然是不可用的，直到它真的运行起来。
如果想让应用横向部署多实例，这也可能会导致一些问题。因为新的副本在没有完全准备好之前，不应该接收请求。但是默认情况下，只要容器内的进程启动完成，Kubernetes 就会开始发送流量过来。如果使用 ReadinessProbe，Kubernetes 就会一直等待，直到应用完全启动，才会允许发送流量到新的副本。

![images](http://70data.net/upload/kubernetes/640.gif)

如果应用产生死锁，导致进程一直夯住，并且停止处理请求。因为进程还处在活跃状态，默认情况下，Kubernetes 认为一切正常，会继续向异常 Pod 发送流量。通过使用 LivenessProbe，Kubernetes 会发现应用不再处理请求，然后重启异常的 Pod。

![images](http://70data.net/upload/kubernetes/641.gif)

## 资源管理

目前 Kubernetes 默认带有两类基本资源

- CPU
- Memory

```
status:
  allocatable:
    cpu: "8"
    ephemeral-storage: "190116174329"
    hugepages-1Gi: "0"
    hugepages-2Mi: "0"
    memory: 16320016Ki
    pods: "110"
  capacity:
    cpu: "8"
    ephemeral-storage: 206289252Ki
    hugepages-1Gi: "0"
    hugepages-2Mi: "0"
    memory: 16422416Ki
    pods: "110"
```

capacity 是 Node 的 `资源真实量`。capacity 由 cAdvisor 采集。
allocatable 是 Node 的 `可以被容器所使用的资源量`。

在默认情况下，针对每一种基本资源（CPU、Memory），Kubernetes 首先会创建一个 Cgroup 组，作为所有容器 Cgroup 的根，名字叫做 kubepods。
这个 Cgroup 组用来限制节点上所有 Pod 所使用的资源。默认情况 kubepods Cgroup 组所获取的资源就等同于节点的全部资源。

Kube-Reserved 和 System-Reserved 会分别为 Kubernetes daemon 和 System daemon 预留资源。
如果开启 Kube-Reserved 和 System-Reserved，Kubernetes 会创建两个额外的 Cgroup 组 kube-reserved 和 system-reserved 以达到预留资源的目的。

当节点面的 `Memory` 以及 `磁盘资源` 这两种不可压缩资源严重不足时，很有可能导致物理机自身进入一种不稳定的状态。
Eviction Threshold 对应的是 Kubernetes 的 eviction policy 特性。允许用户为每台机器针对 `Memory`、`磁盘资源` 指定 eviction hard threshold，资源量的阈值。
假设 Memory 的 eviction hard threshold 为 100M，那么当节点的 Memory 可用资源不足 100M 时，kubelet 会根据节点上所有 Pod 的 Qos 级别以及 Memory 使用情况，进行一个综合排名，把排名最靠前的 Pod 进行驱逐迁移，从而释放出足够的 Memory 资源。
allocatable 为 `[capacity] - [kube-reserved] - [system-reserved] - [hard-eviction]`。

如果没有开启 Kube-Reserved 和 System-Reserved，通过 `kubectl get node <node_name> -o yaml` 看到的 CPU Capacity 等于 CPU Allocatable，Memory Capacity 大于 Memory Allocatable。
eviction policy 在默认情况下，会有一个 100M 的 memory eviction 默认预留。

一个单位的 CPU 资源会被标准化为一个 `Kubernetes Compute Unit`，大致和 x86 处理器的一个单个超线程核心是相同的。
CPU 资源指的是 CPU 时间，基本单位是 millicores，1 核等于 1000 millicores。

### 资源申请

- request。容器希望能够保证能够获取到的最少的量。CPU request 可以通过 cpu.shares 特性实现。
- limit。容器对这个资源使用的上限。

在容器没有指定 request 的时候，request 的值和 limit 默认相等。
在容器没有指定 limit 的时候，request 和 limit 会被设置成的值则根据不同的资源有不同的策略。

对 CPU 来说，容器使用量超过 limit，内核调度器就会切换，使其使用的量不会超过 limit。
对 Memory 来说，容器使用量超过 limit，容器就会被 OOM kill 掉，从而发生容器的重启。

当某个容器的 CPU request 值为 x millicores 时，Kubernetes 会为这个 container 所在的 Cgroup 的 `cpu.shares` 的值设为 `x * 1024 / 1000`。

```
cpu.shares = (cpu in millicores * 1024) / 1000
```

container 的 CPU request 的值为 1 时，它相当于 1000 millicores，此时这个 container 所在的 Cgroup 组的 `cpu.shares` 的值为 1024。

CPU limit，Kubernetes 是通过 CPU Cgroup 控制模块中的 `cpu.cfs_period_us`、`cpu.cfs_quota_us` 两个配置来实现的。

Kubernetes 会为这个 container Cgroup 配置两条信息：

```
cpu.cfs_period_us = 100000 (i.e. 100ms)
cpu.cfs_quota_us = quota = (cpu in millicores * 100000) / 1000
```

在 Cgroup 的 CPU 子系统中，可以通过这两个配置，严格控制这个 Cgroup 中的进程对 CPU 的使用量，保证使用的 CPU 资源不会超过 `cpu.cfs_quota_us/cpu.cfs_period_us`，也正就是申请的 limit 值。

container level Cgroup 中有不会体现 Memory request，只会体现 Memory limit。
依赖配置 `memory.limit_in_bytes`。

```
memory.limit_in_bytes = memory limit bytes
```

`limit_in_bytes` 可以限制一个 Cgroup 中的所有进程可以申请使用的内存的最大量，如果超过这个值，容器会被 OOM killed，容器实例会重启。

Pod 没有指定 limit，`cpu.cfs_quota_us` 将会被设置为 -1（没有限制），`memory.limit_in_bytes` 将会被指定为一个非常大的值（一般是 2^64）。
Pod 没有指定 request 和 limit，`cpu.shares` 将会被指定为 2（允许的最小值）。

`cpu.shares` 真实代表的这个 Cgroup 能够获取机器 CPU 资源的"比重"，并非"绝对值"。
比如某个 Cgroup A 它的 `cpu.shares = 1024` 并不代表这个 Cgroup A 能够获取 1 核的计算资源，如果这个 Cgroup 所在机器一共有 2 核 CPU，除了这个 Cgroup 还有另外 Cgroup B 的 `cpu.shares` 的值为 2048 的话，那么在 CPU 资源被高度抢占的时候，Cgroup A 只能够获取 `2 * (1024/(1024 + 2048))` 即 2/3 的 CPU 核资源。

### Pod QoS

Pod 的 QoS 级别分三种。

- Guaranteed
- Burstable
- BestEffort

Guaranteed

1. Pod 中的每个 container 都必须包含 CPU 资源的 limit、request 信息，并且这两个值必须相等。
2. Pod 中的每个 container 都必须包含 Memory 资源的 limit、request 信息，并且这两个值必须相等。

Burstable

1. 资源申请信息不满足 Guaranteed 级别的要求。
2. Pod 中至少有一个 container 指定了 CPU 或者 Memory 的 request 信息。

BestEffort

1. Pod 中任何一个 container 都不能指定 CPU 或者 Memory 的 request，limit 信息。

Guaranteed level 的 Pod 是优先级最高的，这类 Pod 的资源占用量比较明确。
Burstable level 的 Pod 优先级其次，这类 Pod 的资源需求是最小量，但是当机器资源充足的时候，希望能够使用更多的资源。所以一般 limit > request。
BestEffort level 的 Pod 优先级最低，一般不需要对这类 Pod 指定资源量。无论当前资源使用情况如何，这个 Pod 一定会被调度上去，并且它使用资源的逻辑也是见缝插针。当机器资源充足的时候，它可以充分使用，但是当机器资源被 Guaranteed、Burstable 的 Pod 所抢占的时候，它的资源也会被剥夺，被无限压缩。

![images](http://70data.net/upload/kubernetes/v6uP0lGcBZ4ZsbibSib7ic.png)

### PLEG

Pod Lifecycle Event Generator

![images](http://70data.net/upload/kubernetes/qFG6mghhA4bRGpic.webp)

#### PLEG is not healthy 

`Healthy()` 函数会以 `PLEG` 的形式添加到 runtimeState 中，kubelet 在一个同步循环 `SyncLoop()` 函数中会定期（默认是 10s）调用 `Healthy()` 函数。`Healthy()` 函数会检查 relist 进程（PLEG 的关键任务）是否在 3 分钟内完成。如果 relist 进程的完成时间超过了 3 分钟，就会报告 `PLEG is not healthy`。

`Healthy()`

![images](http://70data.net/upload/kubernetes/qFG6mghhA4bRGpicNWf1vG4y.webp)

`relist()`

![images](http://70data.net/upload/kubernetes/qFG6mghhA4bRGpicNWf1v.png)

![images](http://70data.net/upload/kubernetes/qFG6mghhA4bRGpicLhw.png)

`GetPods()`

![images](http://70data.net/upload/kubernetes/qFG6mghhA4bRGpicNWf1vG442k8A.webp)

监控 kubelet 的指标可以监控到 relist 的延时。
relist 的调用周期是 1s，那么 relist 的完成时间 + 1s 就等于 `kubelet_pleg_relist_interval_microseconds` 指标的值。

可能会造成 PLEG is not healthy 的因素：

- RPC 调用过程中容器运行时响应超时。
- [relist 出现了死锁](https://github.com/kubernetes/kubernetes/issues/72482)，该 bug 已在 Kubernetes 1.14 中修复。
- 节点上 Pod 数量太多，导致 relist 无法在 3 分钟内完成。事件数量和延时与 Pod 数量成正比，与节点资源无关。
- 获取 Pod 的网络堆栈信息时 CNI 出现了 bug。

### cAdvisor

cAdvisor 是一个开源的分析容器资源使用率和性能特性的代理工具，集成到 kubelet 中。
当 kubelet 启动时会同时启动 cAdvisor，且一个 cAdvisor 只监控一个 Node 节点的信息。
cAdvisor 自动查找所有在其所在节点上的容器，自动采集 CPU、Memory、文件系统和网络使用的统计信息。cAdvisor 通过它所在节点机的 Root 容器，采集并分析该节点机的全面使用情况。

### Eviction

kubelet 会监控资源的使用情况，并使用驱逐机制防止计算和存储资源耗尽。
在驱逐时，kubelet 将 Pod 的所有容器停止，并将 PodPhase 设置为 Failed。

#### Pod GC

- `--minimum-container-ttl-duration` Pod 中的容器退出时间超过阈值后会被标记为可回收（只是标记，不是回收）。默认值 0s。
- `--maximum-dead-containers-per-container`  Pod 中最多可以保留的已经停止的容器数量。默认值 1。针对 Pod 整体。
- `--maximum-dead-containers` Node 上最多可以保留的已经停止的容器数量。默认值 -1，没有限制。与 `--maximum-dead-containers-per-container`  冲突时，以 `--maximum-dead-containers` 为准。不适用于非 kubelet 管理的容器。

回收容器时，kubelet 会按照容器的退出时间排序，最先回收退出时间最久的容器。
kubelet 会将 Pod 中的 container 与 sandboxes 分别进行回收，且在回收容器后会将其对应的 log dir 也进行回收。

通过同一个 yaml 文件创建一个 Pod，再删除这个 Pod，然后再创建这个 Pod，之前的 Pod 不会算作新启动 Pod 的已停止容器集。

#### Image GC

- `--minimum-image-ttl-duration` 未使用镜像的最小生命周期，默认值 2m。
- `--image-gc-high-threshold` 磁盘使用百分比达到阈值是触发 GC，默认值 85。
- `--image-gc-low-threshold` 触发 GC 直到磁盘使用百分比达到阈值，默认值 80。

#### 内存 GC

触发条件 `memory.available < 100Mi`。

当内存使用量超过阈值时，kubelet 就会向 kube-apiserver 注册一个 MemoryPressure condition，此时 kubelet 不会接受新的 QoS 等级为 BestEffort 的 Pod 在该节点上运行，并按照以下顺序来驱逐 Pod：

- Pod 内存使用量超过了 request 指定的值
- 根据 priority 排序，优先级低的 Pod 先被驱逐
- 比较 Pod 内存使用量与 request 指定的值之差，差值大的先被驱逐

按照这个顺序，可以确保 QoS 等级为 Guaranteed 的 Pod 不会在 QoS 等级为 BestEffort 的 Pod 之前被驱逐，但不能保证它不会在 QoS 等级为 Burstable 的 Pod 之前被驱逐。

#### Node OOM

![images](http://70data.net/upload/kubernetes/20200316182905.png)

`容器使用的内存占系统内存的百分比 + oom_score_adj = oom_score`

OOM killer 会杀掉 oom_score_adj 值最高的容器。
如果有多个容器的 oom_score_adj 值相同，就会杀掉内存使用量最多的容器（oom_score 值最高）。

## 容器运行时

Container Runtime Interface（CRI）是 Kubernetes v1.5 引入的容器运行时接口，它将 kubelet 与容器运行时解耦，将原来完全面向 Pod 级别的内部接口拆分成面向 Sandbox 和 Container 的 gRPC 接口，并将镜像管理和容器管理分离到不同的服务。

![images](http://70data.net/upload/kubernetes/assets_-LDAOok5ngY4pc1lEDes_-LpOIkR-zouVcB8QsFj__-LpOIpbX7mEF1NuiAHRv_cri.png)

