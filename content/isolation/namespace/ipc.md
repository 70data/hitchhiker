IPC namespace 用来隔离 System V IPC 对象和 POSIX message queues。

System V IPC 对象包含共享内存、信号量和消息队列。

创建包含 10 个信号量的信号量集

```shell script
ipcmk -S 10
Semaphore id: 0
```

显示当前系统中 IPC 资源的信息

```shell script
ipcs -s
------ Semaphore Arrays --------
key        semid      owner      perms      nsems
0x38d009e5 0          root       644        10
```

删除系统中的 IPC 资源

```shell script
ipcrm -s 0

ipcs -s
------ Semaphore Arrays --------
key        semid      owner      perms      nsems
```

## unshare & nsenter

shell 1

```shell script
readlink /proc/$$/ns/ipc
ipc:[4026531839]
```

shell 2

```shell script
readlink /proc/$$/ns/ipc
ipc:[4026531839]
```

shell 1

```shell script
unshare -i

readlink /proc/$$/ns/ipc
ipc:[4026532213]
```

shell 2

```shell script
unshare -i

readlink /proc/$$/ns/ipc
ipc:[4026532214]
```

shell 1

```shell script
ipcmk -S 10
Semaphore id: 0

ipcs -s
------ Semaphore Arrays --------
key        semid      owner      perms      nsems
0x1a9ce028 0          root       644        10
```

shell 2

```shell script
ipcs -s
------ Semaphore Arrays --------
key        semid      owner      perms      nsems
```

shell 1

```shell script
echo $$
2326
```

shell 2

```shell script
nsenter -t 2326 -i

ipcs -s
------ Semaphore Arrays --------
key        semid      owner      perms      nsems
0x1a9ce028 0          root       644        10

readlink /proc/$$/ns/ipc
ipc:[4026532213]
```

