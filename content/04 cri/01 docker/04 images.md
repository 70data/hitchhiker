![images](http://70data.net/upload/kubernetes/640-3.png)

## rootfs

rootfs 只是一个操作系统所包含的文件、配置和目录，并不包括操作系统内核。在 Linux 操作系统中，这两部分是分开存放的，操作系统只有在开机启动时才会加载指定版本的内核镜像。
rootfs 里打包的不只是应用，而是整个操作系统的文件和目录，也就意味着，应用以及它运行所需要的所有依赖，都被封装在了一起。

## AUFS

挂载信息记录在 `/sys/fs/aufs` 下。
镜像的层都放置在 `/var/lib/docker/aufs/diff` 目录下，然后被联合挂载在 `/var/lib/docker/aufs/mnt` 里面。

第一部分，只读层。

第二部分，可读写层。
它是这个容器的 rootfs 最上面的一层，它的挂载方式为：rw，即 read write。在没有写入文件之前，这个目录是空的。而一旦在容器里做了写操作，修改产生的内容就会以增量的方式出现在这个层中。
如果删除只读层里的一个文件，AUFS 会在可读写层创建一个 whiteout 文件，把只读层里的文件"遮挡"起来。这个功能，就是"ro+wh"的挂载方式，即只读 +whiteout 的含义。

第三部分，Init 层。
它是一个以"-init"结尾的层，夹在只读层和读写层之间。
Init 层是 Docker 项目单独生成的一个内部层，专门用来存放 `/etc/hosts`、`/etc/resolv.conf` 等信息。

上面的可读写层通常也称为容器层。
下面的只读层称为镜像层，所有的增删查改操作都只会作用在容器层，相同的文件上层会覆盖掉下层。
修改一个文件的时候，首先会从上到下查找有没有这个文件，找到就复制到容器层中修改，修改的结果就会作用到下层的文件，这种方式也被称为"copy-on-write"。

绑定挂载实际上是一个 inode 替换的过程。在 Linux 操作系统中，inode 可以理解为存放文件内容的"对象"，而 dentry 也叫目录项，就是访问这个 inode 所使用的"指针"。

![images](http://70data.net/upload/kubernetes/95c957b3c2813bb70eb784b8d1daedc6.png)

`mount --bind /home /test`，会将 `/home` 挂载到 `/test` 上。其实相当于将 `/test` 的 dentry，重定向到了 `/home` 的 inode。当修改 `/test` 目录时，实际修改的是 `/home` 目录的 inode。
一旦执行 umount 命令，`/test` 目录原先的内容就会恢复，因为修改真正发生在的，是 `/home` 目录里。

![images](http://70data.net/upload/kubernetes/2b1b470575817444aef07ae9f51b7a18.png)

## overlayfs

![images](http://70data.net/upload/kubernetes/igF3VQg2c-4ckZgi-K2WwQ.webp)

## lxcfs

top 是从 `/prof/stats` 目录下获取数据，所以容器不挂载宿主机的该目录就可以直接使用 top 命令查看容器内部信息。

lxcfs 是把宿主机的 `/var/lib/lxcfs/proc/memoinfo` 文件挂载到 Docker 容器的 `/proc/meminfo` 位置。
容器中进程读取相应文件内容时，lxcfs 的 FUSE 实现会从容器对应的 Cgroup 中读取正确的内存限制。从而使得应用获得正确的资源约束设定。

