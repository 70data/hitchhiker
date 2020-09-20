IPC namespace 用来隔离 System V IPC 对象和 POSIX message queues。
System V IPC 对象包含共享内存、信号量和消息队列。

创建包含 10 个信号量的信号量集

```
ipcmk -S 10
信号量 id：0
```

显示当前系统中 IPC 资源的信息

```
ipcs -s
--------- 信号量数组 -----------
键        semid      拥有者  权限     nsems
0x19e9079a 0          root       644        10
```

删除系统中的 IPC 资源

```
ipcrm -s 0

ipcs -s
--------- 信号量数组 -----------
键        semid      拥有者  权限     nsems
```

## unshare & nsenter

unshare 把当前进程加入到一个新建的 namespace 中，然后运行指定的程序。

nsenter 把当前进程加入到指定进程的 namespace 中，然后运行指定的程序。

shell1

```
readlink /proc/$$/ns/ipc
ipc:[4026531839]
```

shell2

```
readlink /proc/$$/ns/ipc
ipc:[4026532159]
```

shell1

```
ipcmk -S 10
信号量 id：32768

ipcs -s
--------- 信号量数组 -----------
键        semid      拥有者  权限     nsems
0xafcc1fc6 32768      root       644        10
```

shell2

```
ipcs -s
--------- 信号量数组 -----------
键        semid      拥有者  权限     nsems
```

shell1

```
echo $$
27679
```

shell2

```
nsenter -t 27679 -i

echo $$
28551

ipcs -s
--------- 信号量数组 -----------
键        semid      拥有者  权限     nsems
0xafcc1fc6 32768      root       644        10

readlink /proc/$$/ns/ipc
ipc:[4026531839]
```
