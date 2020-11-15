emptyDir 类型的 Volume 在 Pod 分配到 Node 上时被创建，Kubernetes 会在 Node 上自动分配一个目录，因此无需指定宿主机 Node 上对应的目录文件。

这个目录的初始内容为空，当 Pod 从 Node 上移除时，emptyDir 中的数据会被永久删除。容器的 crashing 事件并不会导致 emptyDir 中的数据被删除。

emptyDir 可以把数据存到tmpfs类型的本地文件系统中去。

emptyDir 是临时存储空间，完全不提供持久化支持。

