PID namespace 用来隔离进程的 PID 空间，使得不同 PID namespace 里的进程 PID 可以重复且互不影响。

![images](http://70data.net/upload/kubernetes/286774-a736076226eb26ab.png)

Linux 下的每个进程都有一个对应的 `/proc/PID` 目录，该目录包含了大量的有关当前进程的信息。对一个 PID namespace 而言，`/proc` 目录只包含当前 namespace 和它所有子 namespace 里的进程的信息。
创建一个新的 PID namespace 后，如果想让子进程中的 top、ps 等依赖 `/proc` 文件系统的命令工作，还需要挂载 `/proc` 文件系统。

```
echo $$
28982

readlink /proc/$$/ns/pid
pid:[4026531836]

unshare --pid --mount --fork /bin/bash

readlink /proc/$$/ns/pid
pid:[4026531836]

ps
  PID TTY          TIME CMD
28981 pts/1    00:00:00 sudo
28982 pts/1    00:00:00 bash
29072 pts/1    00:00:00 unshare
29073 pts/1    00:00:00 bash
29085 pts/1    00:00:00 ps

unshare --pid --mount-proc --fork /bin/bash

readlink /proc/$$/ns/pid
pid:[4026532160]

ps
  PID TTY          TIME CMD
    1 pts/1    00:00:00 bash
   13 pts/1    00:00:00 ps
```

`--mount-proc` 在创建了 PID 和 Mount namespace 后，会自动挂载 `/proc` 文件系统。

`--fork` 是为了让 unshare 进程 fork 一个新的进程出来，然后再用 `/bin/bash` 替换掉新的进程中执行的命令。
进程所属的 PID namespace 在它创建的时候就确定了，不能更改。调用 unshare 和 nsenter 命令，原进程还是属于老的 PID namespace，新 fork 出来的进程才属于新的 PID namespace。
PID namespace 最多可以嵌套 32 层，由内核中的宏 MAX_PID_NS_LEVEL 来定义。

在 Linux 系统中，进程的 PID 从 1 开始往后不断增加，并且不能重复。当然进程退出后，PID 会被回收再利用。
在一个新的 PID namespace 中创建的第一个进程的 PID 为 1，该进程被称为这个 PID namespace 中的 init 进程。这个进程具有特殊意义，当 init 进程退出时，系统也将退出。所以除了在 init 进程里指定了 handler 的信号外，内核会帮 init 进程屏蔽掉其他任何信号，这样可以防止其他进程不小心 kill 掉 init 进程导致系统挂掉。
可以通过在父 PID namespace 中发送 SIGKILL 或者 SIGSTOP 信号来终止子 PID namespace 中的 PID 为 1 的进程。由于 PID 为 1 的进程的特殊性，当这个进程停止后，内核将会给这个 PID namespace 里的所有其他进程发送 SIGKILL 信号，致使其他所有进程都停止，最终 PID namespace 被销毁掉。
当一个进程的父进程退出后，该进程就变成了孤儿进程。孤儿进程会被当前 PID namespace 中 PID 为 1 的进程接管，而不是被最外层的系统级别的 init 进程接管。
