Docker 容器有两种 cgroup 驱动：systemd、cgroupfs。
 
cgroupfs 其实是直接把 pid 写入对应的一个 cgroup 文件，然后把对应需要限制的资源也写入相应的 CPU cgroup、memory cgroup 文件。

systemd 本身提供了一个 cgroup 管理方式，所有的写 cgroup 操作都必须通过 systemd 的接口来完成，不能手动更改 cgroup 的文件。

- CPU 设置 cpu share 和 cupset，控制 CPU 的使用率。
- memory 控制进程物理内存的使用量。限制虚拟内存要加 memsw。
- device 控制在容器中看到的 device 设备。
- freezer 停止容器时，freezer 会把当前的进程全部都写入 cgroup，然后把所有的进程都冻结掉。防止停止的时候有进程会去做 fork，相当于防止进程逃逸到宿主机上。
- blkio 限制容器用到的磁盘的一些 IOPS 还有 bps 的速率限制。
- pid 限制容器里面可以用到的最大进程数量。
- net_cls
- net_prio
- hugetlb
- perf_evet
- rdma

