监听 kube-apiserver，查询还未分配 Node 的 Pod，然后根据调度策略为这些 Pod 分配节点，更新 Pod 的 NodeName 字段。

## 调度流程

调度主要分为以下几个部分：

- Predicate 预选过程，过滤掉不满足条件的节点 。
- Prioritie 优选过程，对通过的节点按照优先级排序，选择优先级最高的节点。
- 从中选择优先级最高的节点，如果中间任何一步骤有错误，就直接返回错误。

![images](http://70data.net/upload/kubernetes/kube-scheduler-filter.jpg)

Predicate 策略：

- `PodFitsHostPorts` 检查是否有 Host 冲突
- `PodFitsPorts` 检查是否有 Ports 冲突
- `PodFitsResources` 检查 Node 的资源是否充足，包括允许的 Pod 数量、CPU、内存、GPU 个数以及其他的 OpaqueIntResources
- `HostName` 检查 pod.Spec.NodeName 是否与候选节点一致
- `MatchNodeSelector` 检查候选节点的 pod.Spec.NodeSelector 是否匹配
- `NoVolumeZoneConflict` 检查 Volume zone 是否冲突
- `MatchInterPodAffinity` 检查是否匹配 Pod 的亲和性要求
- `NoDiskConflict` 检查是否存在 Volume 冲突，仅限于 GCE PD、AWS EBS、Ceph RBD 以及 ISCSI
- `GeneralPredicates` 分为 noncriticalPredicates 和 EssentialPredicates。noncriticalPredicates 中包含 PodFitsResources，EssentialPredicates 中包含 PodFitsHost、PodFitsHostPorts、PodSelectorMatches。
- `PodToleratesNodeTaints` 检查 Pod 是否容忍 Node Taints
- `CheckNodeMemoryPressure` 检查 Pod 是否可以调度到 MemoryPressure 的节点上
- `CheckNodeDiskPressure` 检查 Pod 是否可以调度到 DiskPressure 的节点上
- `NoVolumeNodeConflict` 检查节点是否满足 Pod 所引用的 Volume 的条件

Prioritie 策略：

- `ServiceSpreadingPriority` 尽量将同一个 Service 的 Pod 分布到不同节点上，已经被 SelectorSpreadPriority 替代
- `SelectorSpreadPriority` 优先减少节点上属于同一个 Service 或 Replication Controller 的 Pod 数量
- `InterPodAffinityPriority` 优先将 Pod 调度到相同的拓扑上
- `LeastRequestedPriority` 优先调度到请求资源少的节点上
- `BalancedResourceAllocation` 优先平衡各节点的资源使用
- `NodePreferAvoidPodsPriority` alpha.kubernetes.io/preferAvoidPods 字段判断, 权重为 10000，避免其他优先级策略的影响
- `NodeAffinityPriority` 优先调度到匹配 NodeAffinity 的节点上
- `TaintTolerationPriority` 优先调度到匹配 TaintToleration 的节点上
- `EqualPriority` 将所有节点的优先级设置为 1
- `ImageLocalityPriority` 尽量将使用大镜像的容器调度到已经下拉了该镜像的节点上
- `MostRequestedPriority` 尽量调度到已经使用过的 Node 上，特别适用于 cluster-autoscaler

## 优先级调度

从 v1.8 开始，kube-scheduler 支持定义 Pod 的优先级，从而保证高优先级的 Pod 优先调度。
从 v1.11 开始默认开启。

- apiserver 配置 `--feature-gates=PodPriority=true` 和 `--runtime-config=scheduling.k8s.io/v1alpha1=true`
- kube-scheduler 配置 `--feature-gates=PodPriority=true`

指定 Pod 的优先级之前需要先定义一个 PriorityClass

```yaml
apiVersion: v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
description: "This priority class should be used for XYZ service pods only."
```

- `value` 为 32 位整数的优先级，该值越大，优先级越高。
- `globalDefault` 用于未配置 PriorityClassName 的 Pod，整个集群中应该只有一个 PriorityClass 将其设置为 true。

在 PodSpec 中通过 PriorityClassName 设置 Pod 的优先级

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    env: test
spec:
  containers:
  - name: nginx
    image: nginx
    imagePullPolicy: IfNotPresent
  priorityClassName: high-priority
```

## Pod 调度流程

### nodeSelector

Kubernetes 中常用 label 来管理集群的资源，nodeSelector 可通过标签实现 Pod 调度到指定节点上。

### nodeAffinity

node 节点 Affinity，是节点亲和性，控制 Pod 是否调度到指定节点。
node 节点 AntiAffinity 是反亲和性。

- requiredDuringSchedulingIgnoredDuringExecution (必须条件)
- preferredDuringSchedulingIgnoredDuringExecution (优选条件)

### podAffinity

nodeSelector 和 nodeAffinity 都是控制Pod调度到节点的操作，在实际项目部署场景中，希望根据服务与服务之间的关系进行调度，也就是根据 Pod 之间的关系进行调度。kubernetes 的 podAffinity 就可以实现这样的场景。

podAffinity 基于 Pod 的标签来选择 Node，仅调度到满足条件 Pod 所在的 Node 上，支持 podAffinity 和 podAntiAffinity。

### Taints & Tolerations

Taints 污点。应用于 Node 上。
Tolerations 容忍。如果设置了污点还是希望某些 Pod 能够调度上去，可以给 Pod 针对污点加容忍。应用于 Pod 上。

![images](http://70data.net/upload/kubernetes/640-5.png)

- NoSchedule 新的 Pod 不调度到该 Node 上，不影响正在运行的 Pod。
- PreferNoSchedule 尽量不调度到该 Node 上。
- NoExecute 新的 Pod 不调度到该 Node 上，并且删除（evict）已在运行的 Pod。
当 Pod 的 Tolerations 匹配 Node 的所有 Taints 的时候可以调度到该 Node 上。
当 Pod 是已经运行的时候，也不会被删除（evicted）。
如果 Pod 增加了一个 tolerationSeconds，则会在该时间之后才删除 Pod。
DaemonSet 创建的 Pod 会自动加上对 node.alpha.kubernetes.io/unreachable 和 node.alpha.kubernetes.io/notReady 的 NoExecute Toleration，以避免它们因此被删除。

## 影响调度的因素

- 如果 Node Condition 处于 MemoryPressure，则所有 BestEffort 的新 Pod 不会调度到该 Node 上。BestEffort 是指未指定 resources limits 和 requests。
- 如果 Node Condition 处于 DiskPressure，则所有新 Pod 都不会调度到该 Node 上。
- 为了保证 Critical Pod 的正常运行，当它们处于异常状态时会自动重新调度。

Critical Pod：

- `annotation` 包括 `scheduler.alpha.kubernetes.io/critical-pod=''`
- `tolerations` 包括 `[{"key":"CriticalAddonsOnly", "operator":"Exists"}]`
- `priorityClass` 为 `system-cluster-critical` 或者 `system-node-critical`

