### Pod 到 Pod

如果使用 Calico 网络插件，则使用的是路由转发，会找到路由规则即 Pod IP，在这个 IP 段内请跳转到该节点 IP 上。
这些路由规则动态更新是 Calico Felix 做的，路由规则广播是 Calico bird 做的，从而实现了跨节点的 Pod 相互通信。

