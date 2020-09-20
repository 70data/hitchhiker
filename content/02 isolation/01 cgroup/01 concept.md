## 概念

Linux cgroup 的全称是 Linux Control Group。它最主要的作用，就是限制一个进程组能够使用的资源上限，包括 CPU、内存、磁盘、网络带宽等等。

cgroup 提供了一个虚拟文件系统 /proc/cgroup，作为交互的接口，用于设置和管理各个子系统。
本质上来说，cgroup 是内核附加在程序上的一系列钩子（Hooks），通过程序运行时对资源的调度触发相应的钩子以达到资源追踪和限制的目的。

一个层次结构，可以附着一个或者多个子系统。

![images](http://70data.net/upload/kubernetes/RMG-rule1.png)

一个子系统不能附着第二个已经附着过子系统的层次结构。

![images](http://70data.net/upload/kubernetes/RMG-rule2.png)

一个任务不能是同一个层次结构下的不同控制组的成员。

![images](http://70data.net/upload/kubernetes/RMG-rule3.png)

fork 出来的进程严格继承父进程的控制组。

![images](http://70data.net/upload/kubernetes/RMG-rule4.png)

cgroup 的实现方式

![images](http://70data.net/upload/kubernetes/cgroups-source-graph.png)

从逻辑层面看 cgroup 的内核数据结构

![images](http://70data.net/upload/kubernetes/cgroups-logic-graph.png)

## 操作

在 Linux 中，cgroup 给用户暴露出来的操作接口是文件系统，即它以文件和目录的方式组织在操作系统的 `/sys/fs/cgroup` 路径下。

cgroup 会自动个创建对应的资源限制文件。

```
cd /sys/fs/cgroup/cpu

mkdir container

cd container/

ls
cgroup.clone_children  cgroup.procs  cpuacct.usage         cpu.cfs_period_us  cpu.rt_period_us   cpu.shares  notify_on_release
cgroup.event_control   cpuacct.stat  cpuacct.usage_percpu  cpu.cfs_quota_us   cpu.rt_runtime_us  cpu.stat    tasks
```

```
cat /sys/fs/cgroup/cpu/container/cpu.cfs_quota_us
-1

cat /sys/fs/cgroup/cpu/container/cpu.cfs_period_us
100000

echo 20000 > /sys/fs/cgroup/cpu/container/cpu.cfs_quota_us
```

它意味着在每 100 ms 的时间里，被该控制组限制的进程只能使用 20ms 的 CPU 时间，也就是说这个进程只能使用到 20% 的 CPU 资源。

将进程的 PID 写入 container 组里的 tasks 文件，设置就会对该进程生效。

```
echo 226 > /sys/fs/cgroup/cpu/container/tasks
```

取消限制，需要 umount 后删除 cgroup 目录下的文件。

