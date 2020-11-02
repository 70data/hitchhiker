查看当前进程所属的 namespace 信息

```
# ll /proc/$$/ns
总用量 0
lrwxrwxrwx 1 root root 0 1月  23 20:56 ipc -> ipc:[4026531839]
lrwxrwxrwx 1 root root 0 1月  23 20:56 mnt -> mnt:[4026531840]
lrwxrwxrwx 1 root root 0 1月  23 20:56 net -> net:[4026531956]
lrwxrwxrwx 1 root root 0 1月  23 20:56 pid -> pid:[4026531836]
lrwxrwxrwx 1 root root 0 1月  23 20:56 user -> user:[4026531837]
lrwxrwxrwx 1 root root 0 1月  23 20:56 uts -> uts:[4026531838]
```

## API

Linux 提供的 namespace 操作 API 有 `clone()`、`setns()`、`unshare()`。 

`clone()` 是创建一个新的进程。
有别于系统调用 `fork()`，`clone()` 创建新进程时有许多的选项，通过选择不同的选项可以创建出合适的进程，可以使用 `clone()` 来创建一个属于新的 namespace 的进程。

`setns()` 是设置 namespace。
将进程加入到一个已经存在的 namespace 中。

`unshare()` 是做一个新的隔离。
在原进程上，通过选择 flags 来选择隔离的资源。

## namespace 之外

在 Linux 内核中，有很多资源和对象是不能被 namespace 化的，最典型的例子就是：时间。

