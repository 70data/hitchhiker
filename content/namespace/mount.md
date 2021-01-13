Mount namespace 为进程提供独立的文件系统视图，隔离文件系统的挂载点，进程就只能看到自己的 Mount namespace 中的文件系统挂载点。

![images](http://70data.net/upload/kubernetes/286774-1f3fd2635887f8a2.png)

当前进程所在 Mount namespace 里的所有挂载信息可以在 `/proc/pid/mounts`、`/proc/pid/mountinfo`  和 `/proc/pid/mountstats`  里面找到。

每个 Mount namespace 都拥有一份自己的挂载点列表。
当用 `clone()` 或者 `unshare()` 函数创建新的 Mount namespace 时，新创建的 namespace 将拷贝一份老 namespace 里的挂载点列表，但从这之后，他们就没有关系了，通过 mount 和 umount 增加和删除各自 namespace 里面的挂载点都不会相互影响。

## 共享子树(Shared subtrees)

在某些情况下，比如系统添加了一个新的硬盘，这个时候如果 Mount namespace 是完全隔离的。
想要在各个 namespace 里面用这个硬盘，就需要在每个 namespace 里面手动 mount 这个硬盘，Shared subtrees 可以解决这个问题。

peer group 和 propagation type 都是随着 Shared subtrees 一起被引入的概念。

### peer group

peer group 就是一个或多个挂载点的集合，他们之间可以共享挂载信息。

目前在下面两种情况下会使两个挂载点属于同一个 peer group，前提条件是挂载点的 propagation type 是 shared：
- 利用 `mount --bind` 命令，将会使源和目的挂载点属于同一个 peer group，当然前提条件是"源"必须要是一个挂载点。
- 当创建新的 Mount namespace 时，新 namespace 会拷贝一份老 namespace 的挂载点信息，于是新的和老的 namespace 里面的相同挂载点就会属于同一个 peer group。

### propagation type

propagation type 是挂载点的属性，每个挂载点都是独立的。

每个挂载点都有一个 propagation type 标志，由它来决定当一个挂载点的下面创建和移除挂载点的时候，是否会传播到属于相同 peer group 的其他挂载点下去，即同一个 peer group 里的其他的挂载点下面是不是也会创建和移除相应的挂载点。

挂载点是有父子关系的。
比如挂载点 `/`  和 `/mnt/cdrom`，`/mnt/cdrom`  都是 `/`  的子挂载点，`/`  是 `/mnt/cdrom`  的父挂载点。

现在有4种不同类型的 propagation type：
- `MS_SHARED` 挂载信息会在同一个 peer group 的不同挂载点之间共享传播。当一个挂载点下面添加或者删除挂载点的时候，同一个 peer group 里的其他挂载点下面也会挂载和卸载同样的挂载点。
- `MS_PRIVATE` 挂载信息根本就不共享。private 的挂载点不会属于任何 peer group。
- `MS_SLAVE` 信息的传播是单向的。在同一个 peer group 里面，master 的挂载点下面发生变化的时候，slave 的挂载点下面也跟着变化；但反之则不然，slave 下发生变化的时候不会通知 master，master 不会发生变化。
- `MS_UNBINDABLE` 和 `MS_PRIVATE` 相同，这种类型的挂载点不能作为 bind mount 的源。主要用来防止递归嵌套情况的出现。

