## 工作原理

![images](http://70data.net/upload/kubernetes/assets-LDAOok5ngY4pc1lEDes-L_R0eNntcTjZth4bK9z-L_R0jM8Qzf5TfQy7ivkkube-proxy.png)

kube-proxy 监听 kube-apiserver 中 Service 和 Endpoint 的变化情况，并通过 userspace、iptables、ipvs 或 winuserspace 等 proxier 来为服务配置负载均衡。
仅支持 TCP 和 UDP，不支持 HTTP。

- userspace 最早的负载均衡方案，它在用户空间监听一个端口，所有服务通过 iptables 转发到这个端口，然后在其内部负载均衡到实际的 Pod。该方式最主要的问题是效率低，有明显的性能瓶颈。
- iptables 完全以 iptables 规则的方式来实现 Service 负载均衡。该方式最主要的问题是在服务多的时候产生太多的 iptables 规则，非增量式更新会引入一定的时延，大规模情况下有明显的性能问题。
- ipvs 采用增量式更新，并可以保证 service 更新期间连接保持不断开。
- winuserspace 同 userspace，但仅工作在 windows 节点上。

## iptables

![images](http://70data.net/upload/kubernetes/68747470733a2f2f63646e2e6a7364656c6976722e6e65742f67682f63696c.svg)

同步规则按照默认 30 秒的间隔或当收到新的 Service 或 Endpoints 事件时才会触发。

## 通信过程

### Pod 到 Pod

在 Kubernetes 中，每个 Pod 都有自己的 IP 地址。
Pod 之间具有 L3 连接。它们可以相互 ping 通，并相互发送 TCP 或 UDP 数据包。
CNI 是解决在不同主机上运行的容器的此问题的标准。

### Pod 到 Service

Service 是一个在 Pod 前面的 L4 负载均衡器。
有几种不同类型的 Service，最基本的类型称为 ClusterIP。对于此类 Service，它具有唯一的VIP地址，该地址只能在群集内路由。Kubernetes 中实现此功能的组件称为 kube-proxy，通过 iptables 规则，以便在 Pod 和 Service 之间进行各种过滤和 NAT。通过 iptables-save 可以看到规则。`KUBE-SERVICES` 是服务包的入口点，它的作用是匹配目标 IP:Port 并将数据包分派到相应的 `KUBE-SVC-*` 链。`KUBE-SVC-*` 链充当负载平衡器，并将数据包平均分配到 `KUBE-SEP-*` 链。每个 `KUBE-SVC-*` 与其后面的端点数量具有相同数量的 `KUBE-SEP-*` 链。`KUBE-SEP-*` 链表示服务端点。它只是做 DNAT，用 Pod 的端点 IP:Port 替换服务IP:Port。对于 DNAT，`conntrack` 使用状态机启动并跟踪连接状态。需要状态是因为它需要记住它更改为的目标地址，并在返回的数据包返回时将其更改回来。iptables 还可以依靠 conntrack 状态（ctstate）来决定数据包的命运。

一个 TCP 连接在 Pod 和 Service 之间工顺序：

- 客户端 Pod 将数据包发送到服务 192.168.0.2:80
- 数据包通过客户端节点中的 iptables 规则，目标更改为 Pod IP 10.0.1.2:80
- 服务器 Pod 处理数据包并发回目标为 10.0.0.2 的数据包
- 数据包将返回客户端节点，conntrack 识别该数据包并将源地址重写回 192.169.0.2:80
- 客户端 Pod 接收响应数据包

### Pod 到外部

对于从 Pod 到外部地址的流量，Kubernetes 只使用 SNAT。
它的作用是用主机的 IP:Port 替换 Pod 的内部源 IP:Port。当返回数据包返回主机时，它会将 Pod 的 IP:Port 重写为目标并将其发送回原始 Pod。整个过程对原始 Pod 是透明的，原始 Pod 根本不知道地址转换。

### conntrack

4 个 conntrack 状态：

- NEW：conntrack 对此数据包一无所知，这是在收到 SYN 数据包时发生的。
- ESTABLISHED：conntrack 知道数据包属于已建立的连接，这在握手完成后发生。
- RELATED：数据包不属于任何连接，但它附属于另一个连接，这对于 FTP 等协议特别有用。
- INVALID：数据包有问题，conntrack 不知道如何处理它。这个状态在这个 Kubernetes 问题中起着中心作用。

conntrackMax 是要追踪的最大NAT连接数，优先于 conntrackMaxPerCore 和 conntrackMin。
`/proc/sys/net/nf_conntrack_max` 如果该目录是只读的，那么对它的设置将会失败，从而只能设置 `/sys/module/nf_conntrack/parameters/hashsize` 的值。
https://github.com/kubernetes/kubernetes/blob/release-1.15/cmd/kube-proxy/app/conntrack.go#L60

`conntrackTCPEstablishedTimeout` 表示一个空闲的 `TCP` 连接将会被保留多长时间。
https://github.com/kubernetes/kubernetes/blob/release-1.15/cmd/kube-proxy/app/conntrack.go#L87

`conntrackTCPCloseWaitTimeout` 表示一个处于 `CLOSE_WAIT` 的空闲 `conntrack` 条目将会被保留的时间。
https://github.com/kubernetes/kubernetes/blob/release-1.15/cmd/kube-proxy/app/conntrack.go#L91

