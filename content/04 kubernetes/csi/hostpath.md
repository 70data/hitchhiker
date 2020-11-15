hostPath 类型则是映射 node 文件系统中的文件或者目录到 pod 里。

在使用 hostPath 类型的存储卷时，也可以设置 type 字段，支持的类型有文件、目录、File、Socket、CharDevice和BlockDevice。

hostPath 的卷数据是持久化在 node 节点的文件系统中的，即便 pod 已经被删除了，volume 卷中的数据还会留存在 node 节点上。

