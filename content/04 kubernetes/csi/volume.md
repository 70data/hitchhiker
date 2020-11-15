持久存储卷(Persistent Volume)和持久存储卷声明(Persistent Volume Claim)。

PV 是资源的提供者，根据集群的基础设施变化而变化，由 Kubernetes 集群管理员配置。
PVC 是资源的使用者，根据业务服务的需求变化而变化，由 Kubernetes 集群使用者员配置。

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

