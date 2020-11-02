User namespace 是 Linux 3.8 新增的一种 namespace，用于隔离安全相关的资源，包括 User IDs、Group IDs、Keys、Capabilities。
同样一个用户的 User ID 和 Group ID 在不同的 User namespace 中可以不一样。
User namespace 可以嵌套，最多 32 层。
当在一个进程中调用 unshare 或者 clone 创建新的 User namespace 时，当前进程原来所在的 User namespace 为父 User namespace，新的 User namespace 为子 User namespace。

