Linux namespace 是 Linux 提供的一种内核级别环境隔离的方法。

Linux namespace 将全局系统资源封装在一个抽象中，从而使 namespace 内的进程认为自己具有独立的资源实例。

| 分类 | 系统调用参数 | 相关内核版本 |
|---|---|---|
| UTS namespace | CLONE_NEWUTS | Linux 2.6.19 |
| IPC namespace | CLONE_NEWIPC | Linux 2.6.19 |
| PID namespace | CLONE_NEWPID | Linux 2.6.24 |
| Mount namespace | CLONE_NEWNS | Linux 2.4.19 |
| Network namespace | CLONE_NEWNET | Linux 2.6.29 |
| User namespace | CLONE_NEWUSER | Linux 3.8 |

## proc

每个进程都有一个 `/proc/pid/ns` 目录，其下面的文件依次表示每个 namespace。

查看当前进程所属的 namespace 信息

```shell script
ll /proc/$$/ns
total 0
lrwxrwxrwx 1 root root 0 Nov  3 11:50 cgroup -> cgroup:[4026531835]
lrwxrwxrwx 1 root root 0 Nov  3 11:50 ipc -> ipc:[4026531839]
lrwxrwxrwx 1 root root 0 Nov  3 11:50 mnt -> mnt:[4026531840]
lrwxrwxrwx 1 root root 0 Nov  3 11:50 net -> net:[4026531992]
lrwxrwxrwx 1 root root 0 Nov  3 11:50 pid -> pid:[4026531836]
lrwxrwxrwx 1 root root 0 Nov  3 11:50 pid_for_children -> pid:[4026531836]
lrwxrwxrwx 1 root root 0 Nov  3 11:50 user -> user:[4026531837]
lrwxrwxrwx 1 root root 0 Nov  3 11:50 uts -> uts:[4026531838]
```

从 3.8 版本的内核开始，该目录下的每个文件都是一个特殊的符号链接，链接指向 `$namespace:[$namespace-inode-number]`。
前半部份为 namespace 的名称，后半部份的数字表示这个 namespace 的 inode number(句柄号)，inode number 用来对进程所关联的 namespace 执行某些操作。

这些符号链接的用途之一是用来确认两个不同的进程是否处于同一 namespace 中。
如果两个进程指向的 namespace inode number 相同，就说明他们在同一个 namespace 下，否则就在不同的 namespace 下。
这些符号链接指向的文件比较特殊，不能直接访问，事实上指向的文件存放在被称为 nsfs 的文件系统中，该文件系统用户不可见。可以使用系统调用 stat() 在返回的结构体的 st_ino 字段中获取 inode number，shell 命令也可以查看。

```shell script
stat -L /proc/$$/ns/net
  File: ‘/proc/1244/ns/net’
  Size: 0         	Blocks: 0          IO Block: 4096   regular empty file
Device: 4h/4d	Inode: 4026531992  Links: 1
Access: (0444/-r--r--r--)  Uid: (    0/    root)   Gid: (    0/    root)
Access: 2020-11-03 12:22:39.789973532 +0800
Modify: 2020-11-03 12:22:39.789973532 +0800
Change: 2020-11-03 12:22:39.789973532 +0800
 Birth: -
```

如果打开了其中一个文件，那么只要与该文件相关联的文件描述符处于打开状态。
即使该 namespace 中的所有进程都终止了，该 namespace 依然不会被删除。

## API

Linux 提供的 namespace 操作 API 有 `clone()`、`setns()`、`unshare()`。 

### `clone()`

创建一个新的进程。

```shell script
int clone(int (*child_func)(void *), void *child_stack, int flags, void *arg);
```

- `child_func` 传入子进程运行的程序主函数。
- `child_stack` 传入子进程使用的栈空间。
- `flags` 使用哪些 `CLONE_*` 标志位。
- `args` 用于传入用户参数。

有别于系统调用 `fork()`，虽然都相当于把当前进程复制了一份。
但 `clone()` 可以更细粒度地控制与子进程共享的资源，包括虚拟内存、打开的文件描述符和信号量等等。
一旦指定了标志位 `CLONE_NEW*`，相对应类型的 namespace 就会被创建，新创建的进程也会成为该 namespace 中的一员。

### `setns()`

将进程加入到一个已经存在的 namespace 中。

将调用的进程与特定类型 namespace 的一个实例分离，并将该进程与该类型 namespace 的另一个实例重新关联。

```shell script
int setns(int fd, int nstype);
```

- `fd` 表示要加入的 namespace 的文件描述符，可以通过打开其中一个符号链接来获取，也可以通过打开 bind mount 到其中一个链接的文件来获取。
- `nstype` 让调用者可以去检查 `fd` 指向的 namespace 类型，值可以设置为前文提到的常量 `CLONE_NEW*`，填 0 表示不检查。如果调用者已经明确知道自己要加入了 namespace 类型，或者不关心 namespace 类型，就可以使用该参数来自动校验。

结合 `setns()` 和 `execve()` 可以实现一个简单但非常有用的功能：将某个进程加入某个特定的 namespace，然后在该 namespace 中执行命令。
util-linux 包里提供了 nsenter 命令，其提供了一种方式将新创建的进程运行在指定的 namespace 里面。
通过命令行(-t 参数)指定要进入的 namespace 的符号链接，然后利用 `setns()` 将当前的进程放到指定的 namespace 里面，再调用 `clone()` 运行指定的执行文件。

```shell script
# 通过 nsenter 的方式进入 docker
nsenter --target $pid --mount --uts --ipc --net --pid
```

### `unshare()`

让进程脱离当前 namespace，加入一个新的 namespace。

```shell script
int unshare(int flags);
```

`unshare()` 与 `clone()` 类似，但它运行在原先的进程上，不需要创建一个新进程。
先通过指定的 `flags` 参数 `CLONE_NEW*` 创建一个新的 namespace，然后将调用者加入该 namespace。

Linux 自带 unshare 命令。

```shell script
# 显示当前 shell 的 PID
echo $$
1244

# 显示当前 namespace 中的某个挂载点
cat /proc/1244/mounts | grep mq
mqueue /dev/mqueue mqueue rw,relatime 0 0

# 显示当前 namespace 的 ID
readlink /proc/1244/ns/mnt
mnt:[4026531840]

# 在新创建的 mount namespace 中执行新的 shell
unshare -m /bin/bash

# 显示新 namespace 的 ID
readlink /proc/$$/ns/mnt
mnt:[4026532213]
```

对比两个 readlink 命令的输出，可以知道两个 shell 处于不同的 mount namespace 中。

```shell script
# 移除新 namespace 中的挂载点
# mqueue 是 Linux 的进程间消息队列
umount /dev/mqueue

# 检查是否生效
cat /proc/$$/mounts | grep mq

# 查看原来的 namespace 中的挂载点是否依然存在
cat /proc/1244/mounts | grep mq
mqueue /dev/mqueue mqueue rw,relatime 0 0
```

改变新的 namespace 中的某个挂载点。
可以看出，新的 namespace 中的挂载点 /dev/mqueue 已经消失了，但在原来的 namespace 中依然存在。

## namespace 之外

在 Linux 内核中，有很多资源和对象是不能被 namespace 化的，最典型的例子就是：时间。

