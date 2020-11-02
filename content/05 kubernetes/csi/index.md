持久存储卷（Persistent Volume）和持久存储卷声明（Persistent Volume Claim）
PV 是资源的提供者，根据集群的基础设施变化而变化，由 Kubernetes 集群管理员配置。
PVC 是资源的使用者，根据业务服务的需求变化而变化，由 Kubernetes 集群使用者员配置。

### emptyDir

emptyDir 类型的 Volume 在 Pod 分配到 Node 上时被创建，Kubernetes 会在 Node 上自动分配一个目录，因此无需指定宿主机 Node 上对应的目录文件。

这个目录的初始内容为空，当 Pod 从 Node 上移除时，emptyDir 中的数据会被永久删除。容器的 crashing 事件并不会导致 emptyDir 中的数据被删除。

emptyDir 可以把数据存到tmpfs类型的本地文件系统中去。

emptyDir 是临时存储空间，完全不提供持久化支持。

### hostPath

hostPath 类型则是映射 node 文件系统中的文件或者目录到 pod 里。

在使用 hostPath 类型的存储卷时，也可以设置 type 字段，支持的类型有文件、目录、File、Socket、CharDevice和BlockDevice。

hostPath 的卷数据是持久化在 node 节点的文件系统中的，即便 pod 已经被删除了，volume 卷中的数据还会留存在 node 节点上。

### local-volume

通过标准 PVC 接口以简单且可移植的方式访问 node 的本地存储。

使用 local-volume 插件时，要求使用到了存储设备名或路径都相对固定，不会随着系统重启或增加、减少磁盘而发生变化。

静态 provisioner 配置程序仅支持发现和管理挂载点（对于 Filesystem 模式存储卷）或符号链接（对于块设备模式存储卷）。对于基于本地目录的存储卷，必须将它们通过 bind-mounted 的方式绑定到目录中。

官方推荐在使用 local volumes 时，创建一个 StorageClass 并把 volumeBindingMode 字段设置为 `WaitForFirstConsumer`。local-volume 不支持动态的 provisioning 管理功能，但可以创建一个 StorageClass 并使用 `WaitForFirstConsumer` 功能，将 volume binding 延迟至 pod scheduling 阶段执行。

```
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
    name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

provisioner 将通过为每个卷创建和清理 PersistentVolumes 来管理发现目录下的卷。

provisioner 要求管理员在每个 node 上预配置好 local-volume，并指明该 local-volume 是属于以下哪种类型，Filesystem volumeMode (default) PVs 还是 Block volumeMode PVs，并挂载到自动发现目录下。

有一个外部 provisioner 可用于帮助管理 node 上各个磁盘的本地 PersistentVolume 生命周期，包括创建 PersistentVolume 对象、清理并重用应用程序释放的磁盘。

### 流程分析

Volume 相关的模块主要在 controller-manager 和 Kubelet 里。Volume Plugins 在 controller-manager 和 Kubelet 中都注册了，每个 Plugin 为自己的存储后端实现了 `attach/detach` `mount/unmount` `provision` `recycle` `delete` 等一组标准操作。

在 controller-manager 中有两个 Volume 相关的 controllers。
1. Persistent Volume controller 主要是通过 apiserver 接口监控 PV/PVC object 在 etcd 中的变化，然后进行 PV 和 PVC 相互绑定和解绑定的操作。
2. AttachDetach controller 监控 etcd 中 Pod、PV 的相应变化对 Network Volume 进行 attach 或者 detach 到 Node 的操作。

Kubelet 中有一个 Volume Manager controller，它的功能主要是监控 etcd 中 Pod、PV 的变化，然后调用 Volume Plugin 的接口进行 mount 和 umount 操作。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201101152928.png)

### ebay 实践

1. Volume Plugin。首先实现了一个 LocalVolume Plugin，Plugin 里主要包含的 `mounter` `unmounter` `provisioner` `recycler` `delete` 等接口的实现。
2. Persistent Volume。支持 PV/PVC，在 PersistentVolume 的 PersistentVolumeSource 里增加了 LocalVolume。然后为 dynamic volume provisioning 提供 Storage Classes。
3. Scheduler。在 Scheduler 方面亦有所改动，LocalVolume 和其它 Network Volume 不一样，应为它是和 Node 绑定的，一旦选择了 Volume 也就是选择了 Node。所以我们需要在 Pod Scheduler 里增加了一个 predicate function，也就是在 Pod 调度的时候需要看 Node 上有没有 LocalVolume 资源，此外还要在 Persistent Volume controller 里，PVC 绑定 PV 的时候要考虑一些 LocalVolume 特殊的情况。

Volume 回收。在用户将 PVC 删除的时候，需要将对应 Volume 上的数据删除。Network Volume 只要在删除 PVC 的时候把对应的 PV 也删除就行了，但 Local Volume 需要到指定的 Node，把指定磁盘上的数据删除， 问题在于接受处理 PVC 删除的是在 Master 的 controller-manager 上，而数据在某个 Node 上。

目前采用的方法是：创建一个特殊Pod，指定Pod调度到需要的Node上删除指定磁盘上的数据。

一个Pod使用多个LocalVolume PVC

当一个Pod需要同时用几个LocalVolume时，会创建几个PVC。我们需要保证这几个PVC所绑定的LocalVolume PV都在同一个Node上。

目前采用的方法是：在PVC中加入一个group的annotation, 里面包含group name和count, 在进行PVC和PV绑定的时候，只有同一个group name的PVC数目达到count指定的数目时，才做绑定操作并且保证被绑定的Local Volume都在同一个Node上。

反关联（Anti-affinity）

用户在部署应用的时候，考虑到可用性（availability ）往往会有anti-affinity的需求，同一类的Pod需要在不同的Node或者不同的Rack上，这个功能在Kubernetes Pod上已经实现了，但是一旦使用LocalVolume PVC, 就会把anti-affinity的选择提前到PVC与PV绑定的阶段。

