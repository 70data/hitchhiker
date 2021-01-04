## cgroup 是什么

Linux cgroup 的全称是 Linux Control Group。

它最主要的作用，就是限制一个进程组能够使用的资源上限，包括 CPU、内存、磁盘、网络带宽等等。

cgroup 提供了一个虚拟文件系统 /proc/cgroup，作为交互的接口，用于设置和管理各个子系统。
本质上来说，cgroup 是内核附加在程序上的一系列钩子(Hooks)，通过程序运行时对资源的调度触发相应的钩子以达到资源追踪和限制的目的。

### cgroup 的相关概念

1. 任务(task)。
在 cgroup 中，任务就是系统的一个进程。
2. 控制组(control group)。
control group 就是一组按照某种标准划分的进程。
cgroup 中的资源控制都是以 control group 为单位实现。
一个进程可以加入到某个 control group，也从一个进程组迁移到另一个 control group。
一个进程组的进程可以使用 cgroups 以 control group 为单位分配的资源，同时受到 cgroup 以 control group 为单位设定的限制。
3. 层级(hierarchy)。
control group 可以组织成层级的形式，类似一颗 control group 树。
control group 树上的子节点 control group 是父节点 control group 的后代，继承父节点 control group 的特定的属性。
4. 子系统(subsytem)。
一个子系统就是一个资源控制器。cpu 子系统就是控制 CPU 时间分配的一个控制器。
子系统必须附加(attach)到一个层级上才能起作用，一个子系统附加到某个层级以后，这个层级上的所有 control group 都受到这个子系统的控制。

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20201102221242.png)

### 相互关系

每次在系统中创建新层级时，该系统中的所有任务都是那个层级的默认 cgroup 的初始成员。
默认 cgroup 被称为 root cgroup，此 cgroup 在创建层级时自动创建，后面在该层级中创建的 cgroup 都是此 cgroup 的后代。

一个子系统最多只能附加到一个层级。

![images](http://70data.net/upload/kubernetes/RMG-rule2.png)

一个层级可以附加多个子系统。

![images](http://70data.net/upload/kubernetes/RMG-rule1.png)

一个任务不能是同一个层级下的不同 cgroup 的成员。
一个任务可以是多个 cgroup 的成员，但是这些 cgroup 必须在不同的层级。

![images](http://70data.net/upload/kubernetes/RMG-rule3.png)

系统中的进程(任务)创建子进程(任务)时，该子任务自动成为其父进程所在 cgroup 的成员。
可根据需要将该子任务移动到不同的 cgroup 中，但开始时它总是继承其父任务的 cgroup。

![images](http://70data.net/upload/kubernetes/RMG-rule4.png)

### cgroup 层级

P 代表一个进程。
每一个进程的描述符中有一个指针指向了一个辅助数据结构 css_set(cgroups subsystem set)。
指向某一个 css_set 的进程会被加入到当前 css_set 的进程链表中。
一个进程只能隶属于一个 css_set。
一个 css_set 可以包含多个进程，隶属于同一 css_set 的进程受到同一个 css_set 所关联的资源限制。

"M×N Linkage" 说明的是 css_set 通过辅助数据结构可以与 cgroup 节点进行多对多的关联。
但是 cgroup 的实现不允许 css_set 同时关联同一个 cgroup 层级结构下多个节点。因为 cgroups 对同一种资源不允许有多个限制配置。

![images](http://70data.net/upload/kubernetes/cgroups-logic-graph.png)

## cgroup 子系统

- blkio，这个子系统为块设备设定输入/输出限制，比如物理设备(磁盘，固态硬盘，USB 等等)。
- cpu，这个子系统用于控制 cgroup 中所有进程可以使用的 CPU 时间片。
cpu 子系统是通过 Linux CFS调度器实现的。
- cpuacct，这个子系统自动生成 cgroup 中任务所使用的 CPU 报告。
- cpuset，这个子系统为 cgroup 中的任务分配独立 CPU 和内存节点。
- memory，这个子系统设定 cgroup 中任务使用的内存限制，并自动生成由那些任务使用的内存资源报告。
- net_cls，这个子系统使用等级识别符(classid)标记网络数据包，可允许 Linux 流量控制程序(tc)识别从具体 cgroup 中生成的数据包。
- devices，这个子系统可允许或者拒绝 cgroup 中的任务访问设备。
- freezer，这个子系统挂起或者恢复 cgroup 中的任务。
- ns，名称空间子系统。

> CFS调度器。
按照作者 Ingo Molnar 的说法："CFS 百分之八十的工作可以用一句话概括，CFS 在真实的硬件上模拟了完全理想的多任务处理器"。
在"完全理想的多任务处理器"下，每个进程都能同时获得 CPU 的执行时间。
当系统中有两个进程时，CPU 的计算时间被分成两份，每个进程获得50%。
然而在实际的硬件上，当一个进程占用 CPU 时，其它进程就必须等待。所以 CFS 将惩罚当前进程，使其它进程能够在下次调度时尽可能取代当前进程。最终实现所有进程的公平调度。

## cgroup 能做什么

cgroup 最初的目标是为资源管理提供的一个统一的框架，既整合现有的 cpuset 等子系统，也为未来开发新的子系统提供接口。
现在的 cgroup 适用于多种应用场景，从单个进程的资源控制，到实现操作系统层次的虚拟化(OS Level Virtualization)。

1. 限制进程组可以使用的资源数量(Resource limiting)。
memory 子系统可以为进程组设定一个 memory 使用上限，一旦进程组使用的内存达到限额再申请内存，就会触发 OOM(out of memory)。
2. 进程组的优先级控制(Prioritization)。
可以使用 cpu 子系统为某个进程组分配特定 cpu share。
3. 记录进程组使用的资源数量(Accounting)。
可以使用 cpuacct 子系统记录某个进程组使用的 CPU 时间。
4. 进程组隔离(isolation)。
使用 ns 子系统可以使不同的进程组使用不同的 namespace，以达到隔离的目的，不同的进程组有各自的进程、网络、文件系统挂载空间。
5. 进程组控制(control)。
使用 freezer 子系统可以将进程组挂起和恢复。

## 操作

在 Linux 中，cgroup 给用户暴露出来的操作接口是文件系统，即它以文件和目录的方式组织在操作系统的 `/sys/fs/cgroup` 路径下。

创建一个 cgroup。

```shell script
cd /sys/fs/cgroup/cpu/

mkdir js
```

cgroup 会自动个创建对应的控制文件，这些控制文件存储的值就是对相应的 cgroup 的控制信息。
可以写控制文件来更改控制信息。

```shell script
cd js

ls
cgroup.clone_children  cpuacct.stat   cpuacct.usage_all     cpuacct.usage_percpu_sys   cpuacct.usage_sys   cpu.cfs_period_us  cpu.shares  notify_on_release
cgroup.procs           cpuacct.usage  cpuacct.usage_percpu  cpuacct.usage_percpu_user  cpuacct.usage_user  cpu.cfs_quota_us   cpu.stat    tasks
```

`tasks` 文件包含了所有属于这个 cgroup 的进程的进程号。
每创建一个层级的时候，系统的所有进程都会自动被加到该层级的根 cgroup 里面。

```shell script
cat cpu.cfs_quota_us
-1

cat cpu.cfs_period_us
100000
```

修改 cgroup 组的 CPU 资源。

```shell script
echo 10000 > cpu.cfs_quota_us
```

它意味着在每 100 ms 的时间里，被该控制组限制的进程只能使用 10ms 的 CPU 时间。
也就是说这个进程只能使用到 10% 的 CPU 资源。

将进程的 PID 写入 tasks 文件，设置就会对该进程生效。

```shell script
echo pid > tasks
```

取消限制，需要 umount 后删除 cgroup 目录下的文件。
也可以直接删除。

```shell script
rmdir js
```

