## 场景

StatefulSet 为每个 Pod 维护了一个固定的 ID。
这些 Pod 是基于相同的声明来创建的，但是不能相互替换。
无论怎么调度，每个 Pod 都有一个永久不变的 ID。

- 稳定的、唯一的网络标识符
- 稳定的、持久的存储
- 有序的、优雅的部署和扩缩容
- 有序的、自动的滚动更新

## 特性

##### 有序索引

对于具有 N 个副本的 StatefulSet，StatefulSet 中的每个 Pod 将被分配一个整数序号，从 0 到 N-1，该序号在 StatefulSet 上是唯一的。

##### Pod label

当 StatefulSet Controller 创建 Pod 时，它会添加一个标签 `statefulset.kubernetes.io/pod-name`。

这个标签允许给 StatefulSet 中的特定 Pod 绑定一个 Service。

##### 稳定的网络 ID

StatefulSet 中的每个 Pod 根据 StatefulSet 的名称和 Pod 的序号派生出它的主机名。

组合主机名的格式为 `$(StatefulSet 名称)-$(序号)`。

```shell script
web-0
```

StatefulSet 可以使用 Headless Services 控制它的 Pod 的网络，但需要预先创建。

Services 格式：`$(Services 名称).$(命名空间).svc.cluster.local`。

```shell script
nginx.default.svc.cluster.local
```

一旦每个 Pod 创建成功，就会得到一个匹配的 DNS 子域。

格式为：`$(Pod 名称).$(所属服务的 DNS 域名)`

```shell script
web-0.nginx.default.svc.cluster.local
```

##### 稳定的存储

Pod 的存储必须由 PVC 驱动。
为每个 `VolumeClaimTemplate` 创建一个持久卷。

基于所请求的 StorageClass 来提供，如果没有指定 StorageClass，那么将使用默认的 StorageClass。
或者由管理员预先提供。

当一个 Pod 被调度或者重新调度到节点上时，它的 `volumeMounts` 会挂载与其 PVC 相关联的 PV。

当 Pod 或者 StatefulSet 被删除时，与 PVC 相关联的 PV 并不会被删除，PVC 也不会被删除。
要删除必须通过手动方式来完成。删除 PVC 后，才会真正删除对应的 PV。
这样做是为了保证数据安全。

如果是远程卷(动态 PV)，无论 Pod 飘到哪个节点上，它们的 PV 都会被挂载到相应的挂载点。

## 创建

- 创建 Headless Service
- 创建 StorageClass
- 创建 PVC
- 创建 StatefulSet

## 部署和扩缩容

对于包含 N 个副本的 StatefulSet：
- 当部署 Pod 时，它们是依次创建的，顺序为 0..N-1。
- 当删除 Pod 时，它们是逆序终止的，顺序为 N-1..0。
- 在扩缩容操作应用到 Pod 之前，它前面的所有 Pod 必须是 Running 和 Ready 状态。
- 在 Pod 被删除的时候，它后面所有的 Pod 必须被关闭的。

当删除 StatefulSets 时，StatefulSet 不提供任何终止 Pod 的保证。
为了实现 StatefulSet 中的 Pod 可以有序和优雅的终止，可以在删除之前将 StatefulSet 缩放为 0。

StatefulSet 不应将 `pod.Spec.TerminationGracePeriodSeconds` 设置为 0。 这种做法是不安全的，要强烈阻止。

在默认 Pod 管理策略(OrderedReady)时，使用滚动更新，可能进入需要人工干预才能修复的损坏状态。

当 StatefulSet 任何一个 Pod 不健康时，不能做扩缩容操作。
只有 Pod 都进入 Ready 状态，才能做扩缩容操作。

如果 `spec.replicas` > 1，Kubernetes 无法确定不健康 Pod 的原因。
它可能是永久故障或瞬时故障的结果。
暂时性故障可能是升级或维护所需的重启造成的。

如果 Pod 因永久性故障而不健康，在不纠正故障的情况下进行扩缩容，可能会导致 StatefulSet 的 Pod 副本书数降至低于正确运行所需的特定最小副本数的状态。
如果 Pod 因暂时性故障而不健康，可能会干扰扩缩容操作，最好在应用层面通过完善逻辑解决。

##### `.spec.podManagementPolicy`

- `OrderedReady`，默认值，即顺序。
- `Parallel`，并行，不要等 Pod Ready。只影响扩缩容操作，不影响更新操作。

## 更新

`.spec.updateStrategy` 配置更新策略。

### On Delete

当 StatefulSet 的 `.spec.updateStrategy.type` 设置为 OnDelete 时，它的 controller 将不会自动更新 StatefulSet 中的 Pod。
用户必须手动删除 Pod 以便让 controller 创建新的 Pod。

### Rolling Updates

https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/#rolling-update

默认策略。

当 StatefulSet 的 `.spec.updateStrategy.type` 设置为 RollingUpdate 时，controller 将删除并重新创建 StatefulSet 中的每个Pod。
它将按照与 Pod 终止相同的顺序进行，从最大的序号到最小的序号，每次更新一个 Pod。

##### 分区

如果声明了一个分区，当 StatefulSet 的 `.spec.template` 被更新时：
- 所有序号大于等于该分区序号的 Pod 都会被更新。
- 所有序号小于该分区序号的 Pod 都不会被更新。

即使被删除也会依据之前的版本进行重建。

如果 StatefulSet 的 `.spec.updateStrategy.rollingUpdate.partition` 大于它的 `.spec.replicas`，对它的 `.spec.template` 的更新将不会传递到它的 Pod。

场景：
- 金丝雀
- 阶段更新

##### 强制回滚

如果将 Pod 的 `.spec.template` 更新为一个永远不会运行和就绪的配置，StatefulSet 将停止 rollout 并等待。

仅仅将 Pod `.spec.template` 恢复是不够的。
由于已知的问题，StatefulSet 将继续等待损坏的 Pod 进入 Ready 状态，但这个状态永远不会发生。

`.spec.template` 恢复之后，还必须删除 StatefulSet 已经尝试使用错误配置运行的 Pod。
然后 StatefulSet 使用恢复的 `.spec.template` 重新创建 Pod。

## 删除

StatefulSet 支持 Non-Cascading 和 Cascading 两种删除方式。

- Non-Cascading，当 StatefulSet 被删除时，StatefulSet 的 Pod 不会被删除
- Cascading，StatefulSet 和它的 Pod 都会被删除，倒序依次终止

