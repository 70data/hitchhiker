![image](http://70data.net/upload/kubernetes/Ali-GPU-Share.png)

GPU Share Scheduler Extender: 利用 Kubernetes 的调度器扩展机制，负责在全局调度器 `Filter` 和 `Bind` 的时候判断节点上单个 GPU 卡是否能够提供足够的 GPU Mem，并且在 Bind 的时候将 GPU 的分配结果通过 annotation 记录到 Pod Spec 以供后续 `Filter` 检查分配结果。

GPU Share Device Plugin: 利用 nvml 库查询到 GPU 卡的数量和每张 GPU 卡的显存，通过 `ListAndWatch` 将节点的 GPU 总显存（数量 * 显存）作为另外 Extended Resource 汇报给 Kubelet。Kubelet 进一步汇报给 Kubernetes API Server。利用 Device Plugin 机制，在节点上被 Kubelet 调用负责 GPU 卡的分配，依赖 scheduler Extender 分配结果执行。

Kubernetes 默认调度器在进行完所有 `Filter` 行为后会通过 http 方式调用 GPU Share Scheduler Extender 的 `Filter` 方法, 这是由于默认调度器计算 Extended Resource 时，只能判断资源总量是否有满足需求的空闲资源，无法具体判断单张卡上是否满足需求，所以就需要由 GPU Share Scheduler Extender 检查单张卡上是否含有可用资源。

![image](http://70data.net/upload/kubernetes/Ali-GPU-Share-Scheduler-Extender.png)

当调度器找到满足条件的节点，就会委托 GPU Share Scheduler Extender 的 `Bind` 方法进行节点和 Pod 的绑定，这里 Extender 需要做的是两件事情：
1. 以 binpack 的规则找到节点中最优选择的 GPU 卡 id，此处的最优含义是对于同一个节点不同的 GPU 卡，以 binpack 的原则作为判断条件，优先选择空闲资源满足条件但同时又是所剩资源最少的 GPU 卡，并且将其作为 `ALIYUN_COM_GPU_MEM_IDX` 保存到 Pod 的 annotation 中。同时也保存该 Pod 申请的 GPU Memory 作为 `ALIYUN_COM_GPU_MEM_POD` 和 `ALIYUN_COM_GPU_MEM_ASSUME_TIME` 保存至 Pod 的 annotation 中，并且在此时进行 Pod 和所选节点的绑定。这时还会保存 `ALIYUN_COM_GPU_MEM_ASSIGNED` 的 Pod annotation，它被初始化为 `false`，表示该 Pod 在调度时刻被指定到了某块 GPU 卡，但是并没有真正在节点上创建该 Pod。如果此时发现分配节点上没有 GPU 资源符合条件，此时不进行绑定，直接不报错退出，默认调度器会在 assume 超时后重新调度。
2. 调用 Kubernetes API 执行节点和 Pod 的绑定。

![image](http://70data.net/upload/kubernetes/Ali-Kubernetes-API-Node-Pod-Bind.png)

3. 节点上运行
当 Pod 和节点绑定的事件被 Kubelet 接收到后，Kubelet 就会在节点上创建真正的 Pod 实体，在这个过程中, Kubelet 会调用 GPU Share Device Plugin 的 `Allocate` 方法，`Allocate` 方法的参数是 Pod 申请的 gpu-mem。而在 `Allocate` 方法中，会根据 GPU Share Scheduler Extender 的调度决策运行对应的 Pod 会列出该节点中所有状态为 Pending 并且 `ALIYUN_COM_GPU_MEM_ASSIGNED` 为 `false` 的 GPU Share Pod 选择出其中 Pod Annotation 的 `ALIYUN_COM_GPU_MEM_POD` 的数量与 `Allocate` 申请数量一致的 Pod。如果有多个符合这种条件的 Pod，就会选择其中 `ALIYUN_COM_GPU_MEM_ASSUME_TIME` 最早的 Pod。将该 Pod 的 annotation `ALIYUN_COM_GPU_MEM_ASSIGNED` 设置为 `true`，并且将 Pod annotation 中的 GPU 信息转化为环境变量返回给 Kubelet 用以真正的创建 Pod。

![image](http://70data.net/upload/kubernetes/Ali-Run-On-Node.png)

