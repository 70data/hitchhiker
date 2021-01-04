User namespace 是 Linux 3.8 新增的一种 namespace，用于隔离安全相关的资源，包括 User ID、Group ID、Key、Capability。

除了 User namespace 外，创建其它类型的 namespace 都需要 CAP_SYS_ADMIN 的 Capability。
当新的 User namespace 创建并映射好 User ID、Group ID 了之后，这个 User namespace 的第一个进程将拥有完整的所有 Capability，意味着它就可以创建新的其它类型 namespace。

同样一个用户的 User ID 和 Group ID 在不同的 User namespace 中可以不一样。
User namespace 可以嵌套，最多 32 层。

当在一个进程中调用 unshare 或者 clone 创建新的 User namespace 时，当前进程原来所在的 User namespace 为父 User namespace，新的 User namespace 为子 User namespace。

