UTS namespace 用来隔离系统的 hostname 以及 NIS domain name。

通过 `clone()` 函数创建 UTS 隔离的子进程

```
#define _GNU_SOURCE
#include <sys/wait.h>
#include <sys/utsname.h>
#include <sched.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

// 设置子进程的堆栈大小为 1M
#define STACK_SIZE (1024 * 1024)

#define errExit(msg) do { perror(msg); exit(EXIT_FAILURE); } while (0)

// 调用 clone 时执行的函数
static int childFunc(void *arg)
{
    struct utsname uts;
    char *shellname;
    // 在子进程的 UTS namespace 中设置 hostname
    if (sethostname(arg, strlen(arg)) == -1)
        errExit("sethostname");
    // 显示子进程的 hostname
    if (uname(&uts) == -1)
        errExit("uname");
    printf("uts.nodename in child:  %s\n", uts.nodename);
    printf("My PID is: %d\n", getpid());
    printf("My parent PID is: %d\n", getppid());
    // 获取系统的默认 shell
    shellname = getenv("SHELL");
    if (!shellname) {
        shellname = (char *)"/bin/sh";
    }
    // 在子进程中执行 shell
    execlp(shellname, shellname, (char *)NULL);
    return 0;
}

int main(int argc, char *argv[])
{
    char *stack;
    char *stackTop;
    pid_t pid;
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <child-hostname>\n", argv[0]);
        exit(EXIT_SUCCESS);
    }
    // 为子进程分配堆栈空间大小为 1M
    stack = malloc(STACK_SIZE);
    if (stack == NULL)
        errExit("malloc");
    // assume stack grows downward
    stackTop = stack + STACK_SIZE;
    // 通过 clone 函数创建子进程，CLONE_NEWUTS 标识指明为新进程创建新的 UTS namespace
    pid = clone(childFunc, stackTop, CLONE_NEWUTS | SIGCHLD, argv[1]);
    if (pid == -1)
        errExit("clone");
    // 等待子进程退出
    if (waitpid(pid, NULL, 0) == -1)
        errExit("waitpid");
    printf("child has terminated\n");
    exit(EXIT_SUCCESS);
}
```

编译

```
gcc -o uts_clone uts_clone.c
```

运行

```
# ./uts_clone hostname.clone
uts.nodename in child:  hostname.clone
My PID is: 30671
My parent PID is: 30670

# hostname
hostname.clone
```

通过 `setns()` 把当前进程加入到已存在的 UTS namespace

```
#define _GNU_SOURCE
#include <fcntl.h>
#include <sched.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

#define errExit(msg) do { perror(msg); exit(EXIT_FAILURE); } while (0)

int main(int argc, char *argv[])
{
    int fd;
    if (argc < 3) {
        fprintf(stderr, "%s /proc/PID/ns/FILE cmd args...\n", argv[0]);
        exit(EXIT_FAILURE);
    }
    // 打开一个现存的 UTS namespace 文件
    fd = open(argv[1], O_RDONLY);
    if (fd == -1)
        errExit("open");
    // 把当前进程的 UTS namespace 设置为命令行参数传入的 namespace
    if (setns(fd, 0) == -1)
        errExit("setns");
    // 在新的 UTS namespace 中运行用户指定的程序
    execvp(argv[2], &argv[2]);
    errExit("execvp");
}
```

编译

```
gcc -o uts_setns uts_setns.c
```

运行

```
# ./uts_clone hostname.clone
uts.nodename in child:  hostname.clone
My PID is: 30671
My parent PID is: 30670

readlink /proc/30671/ns/uts
uts:[4026532237]

# ./uts_setns /proc/30671/ns/uts ${SHELL}

# readlink /proc/$$/ns/uts
uts:[4026532237]
```

