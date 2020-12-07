通过标准 PVC 接口以简单且可移植的方式访问 node 的本地存储。

使用 local-volume 插件时，要求使用到了存储设备名或路径都相对固定，不会随着系统重启或增加、减少磁盘而发生变化。

静态 provisioner 配置程序仅支持发现和管理挂载点（对于 Filesystem 模式存储卷）或符号链接（对于块设备模式存储卷）。对于基于本地目录的存储卷，必须将它们通过 bind-mounted 的方式绑定到目录中。

官方推荐在使用 local volumes 时，创建一个 StorageClass 并把 volumeBindingMode 字段设置为 `WaitForFirstConsumer`。local-volume 不支持动态的 provisioning 管理功能，但可以创建一个 StorageClass 并使用 `WaitForFirstConsumer` 功能，将 volume binding 延迟至 pod scheduling 阶段执行。

```yaml
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

