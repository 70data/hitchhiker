## 工作原理

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20201202214135.png)

kube-proxy 监听 kube-apiserver 中 Service 和 Endpoint 的变化情况，并通过 userspace、winuserspace、iptables、IPVS 来为服务配置负载均衡。

仅支持 TCP 和 UDP，不支持 HTTP。

![images](http://70data.net/upload/kubernetes/assets-LDAOok5ngY4pc1lEDes-L_R0eNntcTjZth4bK9z-L_R0jM8Qzf5TfQy7ivkkube-proxy.png)

### userspace 模式

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201115235629.svg)

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201202220830.png)

应用发往 Service 的请求会通过 iptable 规则转发给 kube-proxy，kube-proxy 再转发到 Service 后端的 Pod。

发往 Service 的请求会先进入内核空间的 iptable，再回到用户空间由 kube-proxy 转发。
内核空间和用户空间来回地切换成为了该模式的主要性能问题。

由于发往后端 Pod 的请求是由 kube-proxy 转发的，请求失败时，是可以让 kube-proxy 重试的。

默认情况下，userspace 模式下的 kube-proxy 通过 round-robin 算法选择后端。

SessionAffinity 可以用来做会话亲和性。

### winuserspace 模式

同 userspace，但仅工作在 windows 节点上。

### iptables 模式

![image](http://70data.net/upload/kubernetes/assets_-LDAOok5ngY4pc1lEDes_-LM_rqip-tinVoiFZE0I_-LM_sIx5Qc9S275Z49_6_14731220608865.png)

![images](http://70data.net/upload/kubernetes/68747470733a2f2f63646e2e6a7364656c6976722e6e65742f67682f63696c.svg)

同步规则按照默认 30 秒的间隔或当收到新的 Service 或 Endpoints 事件时才会触发。

对每个 Service，它会配置 iptables 规则，捕获到达该 Service 的 clusterIP 和 port 的请求，进而将请求重定向到 Service 的一组后端中的某个 Pod 上面。
https://github.com/kubernetes/kubernetes/blob/master/pkg/proxy/iptables/proxier.go#L1007

默认情况下，iptables 模式下的 kube-proxy 会随机选择后端。

可以使用 Pod 的 readiness probes 验证后端 Pod 可以正常工作，以便 iptables 模式下的 kube-proxy 仅看到测试正常的后端。
这样做免将流量通过 kube-proxy 发送到已知已失败的 Pod。

通过 iptables 的 recent 模块实现会话亲和性。
https://github.com/kubernetes/kubernetes/blob/master/pkg/proxy/iptables/proxier.go#L1416

使用 iptables 处理流量具有较低的系统开销，因为流量由 Linux netfilter 处理，而无需在用户空间和内核空间之间切换。

iptables 使用链表存储路由规则。
Service 多的时候产生太多的 iptables 规则，非增量式更新会引入一定的时延，大规模情况下有明显的性能问题。

iptables 的规则更新是全量更新。
即使 `--no--flush` 也不行，`--no--flush` 只保证 iptables-restore 时不删除旧的规则链。

kube-proxy 会周期性的刷新 iptables 状态。
先 iptables-save 拷贝系统 iptables 状态。
然后再更新部分规则。
最后再通过 iptables-restore 写入到内核。
当规则数到达一定程度时，这个过程就会变得非常缓慢。

iptables 会整体更新 netfilter 的规则表，而一下子分配较大的内核内存(>128MB)就会出现较大的时延。

kube-proxy 使用了 iptables 的 filter 表和 nat 表，并对 iptables 的 Chain 进行了扩充。
自定义了 `KUBE-SERVICES`、`KUBE-EXTERNAL-SERVICES`、`KUBE-NODEPORTS`、`KUBE-POSTROUTING`、`KUBE-MARK-MASQ`、`KUBE-MARK-DROP`、`KUBE-FORWARD` 七条 Chain。
以及 `KUBE-SVC-*` 和 `KUBE-SEP-*` 开头的数个 Chain。

对于 `KUBE-MARK-MASQ` Chain 中所有规则设置了 Kubernetes 独有的 MARK 标记。
在 `KUBE-POSTROUTING` Chain 中对 Node 节点上匹配 Kubernetes 独有 MARK 标记的数据包，进行 SNAT 处理。

#### nat 表

##### `KUBE-SERVICES`

Service 包的入口点。

匹配目标 IP:Port 并将数据包分派到相应的 `KUBE-SVC-*` Chain。

1. 如果目标地址是 ClusterIP:Port，但源地址不在 Cluster CIDR 中，则设置 SNAT 的标记
2. 如果目标地址是 ClusterIP:Port，则跳转到 `KUBE-SVC-*` Chain

##### `KUBE-SVC-*`

为每个 Service 创建 `KUBE-SVC-*` Chain。

在 nat 表中将 `KUBE-SERVICES` Chain 中每个目标地址是 Service 的数据包导入这个 `KUBE-SVC-*` Chain。

充当负载平衡器，并将数据包平均分配到 `KUBE-SEP-*` Chain。
每个 `KUBE-SVC-*` 与其后面的 Endpoint 数量具有相同数量的 `KUBE-SEP-*` Chain。
如果 Endpoint 尚未创建，则 `KUBE-SVC-*` Chain 中没有规则。

1. 如果 Service 绑定了 N 个 Pods，则 `KUBE-SVC-*` 下面有 N 条 `KUBE-SEP-*` 规则，每条规则对应一个 PodIP
2. 每条 `KUBE-SEP-*` 规则指定了 statistic mode random probability，如果只有一条规则，则无需指定概率，iptabels 按概率执行某条规则

规则匹配失败后会被 `KUBE-MARK-DROP` 进行标记然后再 `FORWARD` Chain 中丢弃。

##### `KUBE-SEP-*`

表示 Service Endpoint，只做 DNAT，用 Pod 的 Endpoint IP:Port 替换 Service IP:Port。

对于 DNAT，`conntrack` 使用状态机启动并跟踪连接状态。
需要状态是因为它需要记住它更改为的目标地址，并在返回的数据包返回时将其更改回来。

1. 如果源地址是对应的 PodIP 则设置 SNAT 标记
2. 设置到目标 PodIP:Port 的 DNAT
3. 最后一条规则是匹配目标地址是本机的 NodePort 情况，复用对应 Service 的 `KUBE-SVC-*` Chain

#### filter 表

创建 `KUBE-SERVICES` Chain，REJECT 没有 Endpoint 的 ClusterIP 请求。

创建 `KUBE-FIREWALL` Chain，DROP 所有在 NAT 阶段标记为 drop 的包。

##### clusterIP

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20201202221330.png)

首先流量到达的是 nat 表 `OUTPUT` Chain。

```shell script
iptables-save -t nat | grep -- '-A OUTPUT'
-A OUTPUT -m comment --comment "kubernetes service portals" -j KUBE-SERVICES
```

跳转到 `KUBE-SERVICES` Chain。

```shell script
iptables-save -t nat | grep -- '-A KUBE-SERVICES'
-A KUBE-SERVICES ! -s 10.244.0.0/16 -d 10.106.224.41/32 -p tcp -m comment --comment "default/kubernetes-bootcamp-v1: cluster IP" -m tcp --dport 8080 -j KUBE-MARK-MASQ
-A KUBE-SERVICES -d 10.106.224.41/32 -p tcp -m comment --comment "default/kubernetes-bootcamp-v1: cluster IP" -m tcp --dport 8080 -j KUBE-SVC-RPP7DHNHMGOIIFDC
```

相关的有两条规则：
第一条负责打标记，跳转到 `KUBE-MARK-MASQ Chain`。
第二条规则，跳到 `KUBE-SVC-RPP7DHNHMGOIIFDC` Chain。

`KUBE-SVC-RPP7DHNHMGOIIFDC` Chain 的规则：

```shell script
iptables-save -t nat | grep -- '-A KUBE-SVC-RPP7DHNHMGOIIFDC'
-A KUBE-SVC-RPP7DHNHMGOIIFDC -m statistic --mode random --probability 0.33332999982 -j KUBE-SEP-FTIQ6MSD3LWO5HZX
-A KUBE-SVC-RPP7DHNHMGOIIFDC -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-SQBK6CVV7ZCKBTVI
-A KUBE-SVC-RPP7DHNHMGOIIFDC -j KUBE-SEP-IAZPHGLZVO2SWOVD
```

`KUBE-SVC-RPP7DHNHMGOIIFDC` 的功能就是按照概率均等的原则 DNAT 到其中一个 Endpoint IP，即 Pod IP。

`KUBE-SEP-FTIQ6MSD3LWO5HZX` Chain 的规则：

```shell script
iptables-save -t nat | grep -- '-A KUBE-SEP-FTIQ6MSD3LWO5HZX'
-A KUBE-SEP-FTIQ6MSD3LWO5HZX -p tcp -m tcp -j DNAT --to-destination 10.244.1.2:8080
```

做了一次 DNAT，DNAT 目标为其中一个 Endpoint，即 Pod。

```shell script
iptables-save -t nat | grep -- '-A POSTROUTING'
-A POSTROUTING -m comment --comment "kubernetes postrouting rules" -j KUBE-POSTROUTING

iptables-save -t nat | grep -- '-A KUBE-POSTROUTING'
-A KUBE-POSTROUTING -m comment --comment "kubernetes service traffic requiring SNAT" -m mark --mark 0x4000/0x4000 -j MASQUERADE
```

非本机访问：
1. `PREROUTING`
2. `KUBE-SERVICE`
3. `KUBE-SVC-*`
4. `KUBE-SEP-*`

本机访问：
1. `OUTPUT`
2. `KUBE-SERVICE`
3. `KUBE-SVC-*`
4. `KUBE-SEP-*`

##### NodePort

`KUBE-NODEPORTS` 位于 `KUBE-SERVICE` Chain 的最后一个。

iptables 在处理报文时会优先处理目的 IP 为 clusterIP 的数据包。
在前面的 `KUBE-SVC-*` 都匹配失败之后再去使用 nodePort 方式进行匹配。

通过外部 IP 访问 NodePort。

首先到达 `PREROUTING` Chain：

```shell script
iptables-save -t nat | grep -- '-A PREROUTING'
-A PREROUTING -m comment --comment "kubernetes service portals" -j KUBE-SERVICES

iptables-save -t nat | grep -- '-A KUBE-SERVICES'
-A KUBE-SERVICES -m addrtype --dst-type LOCAL -j KUBE-NODEPORTS
```

`PREROUTING` 的规则非常简单，凡是发给自己的包，则交给 `KUBE-NODEPORTS` 处理。

`KUBE-NODEPORTS` 的规则：

```shell script
iptables-save -t nat | grep -- '-A KUBE-NODEPORTS'
-A KUBE-NODEPORTS -p tcp -m comment --comment "default/kubernetes-bootcamp-v1:" -m tcp --dport 30419 -j KUBE-MARK-MASQ
-A KUBE-NODEPORTS -p tcp -m comment --comment "default/kubernetes-bootcamp-v1:" -m tcp --dport 30419 -j KUBE-SVC-RPP7DHNHMGOIIFDC
```

这个规则首先给包打上标记 0x4000/0x4000，然后交给 `KUBE-SVC-RPP7DHNHMGOIIFDC` 处理。

`KUBE-SVC-RPP7DHNHMGOIIFDC` 按照概率均等的原则 DNAT 到其中一个 Endpoint IP，即 Pod IP。

接着到了 `FORWARD` 链。

```shell script
iptables-save -t filter | grep -- '-A FORWARD'
-A FORWARD -m comment --comment "kubernetes forwarding rules" -j KUBE-FORWARD

iptables-save -t filter | grep -- '-A KUBE-FORWARD'
-A KUBE-FORWARD -m conntrack --ctstate INVALID -j DROP
-A KUBE-FORWARD -m comment --comment "kubernetes forwarding rules" -m mark --mark 0x4000/0x4000 -j ACCEPT
```

`FORWARD` 表在这里只是判断下，只允许打了标记的包才允许转发。

最后来到 `POSTROUTING` 链，这里和 `ClusterIP` 就完全一样了，在 `KUBE-POSTROUTING` 中做一次 `MASQUERADE`(SNAT)。

非本机访问：
1. `PREROUTING`
2. `KUBE-SERVICE`
3. `KUBE-NODEPORTS`
4. `KUBE-SVC-*`
5. `KUBE-SEP-*`

本机访问：
1. `OUTPUT`
2. `KUBE-SERVICE`
3. `KUBE-NODEPORTS`
4. `KUBE-SVC-*`
5. `KUBE-SEP-*`

##### conntrack

ConntrackMax 是要追踪的最大NAT连接数，优先于 ConntrackMaxPerCore 和 ConntrackMin。
`/proc/sys/net/nf_conntrack_max` 如果该目录是只读的，那么对它的设置将会失败，从而只能设置 `/sys/module/nf_conntrack/parameters/hashsize` 的值。
https://github.com/kubernetes/kubernetes/blob/release-1.15/cmd/kube-proxy/app/conntrack.go#L60

ConntrackMaxPerCore 是每个 CPU 核心要追踪的最大 NAT 连接数。

ConntrackMin 是连接追踪最小可分配的记录数。

ConntrackTCPEstablishedTimeout 表示一个空闲的 TCP 连接将会被保留多长时间。
https://github.com/kubernetes/kubernetes/blob/release-1.15/cmd/kube-proxy/app/conntrack.go#L87

ConntrackTCPCloseWaitTimeout 表示一个处于 `CLOSE_WAIT` 的空闲 conntrack 条目将会被保留的时间。
https://github.com/kubernetes/kubernetes/blob/release-1.15/cmd/kube-proxy/app/conntrack.go#L91

conntrack 启动之后首先依然是初始化。
从配置文件里获取 ConntrackMax 并设置，调用 sysctl 对 `/proc/sys/net/netfilter/nf_conntrack_max` 赋值。
如果该目录是只读的，那么对它的设置将会失败，从而只能设置 `/sys/module/nf_conntrack/parameters/hashsize` 的值，该值大小为 max/4。

### IPVS 模式

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201115235715.svg)

IPVS 基于章文嵩博士开发的 LVS 实现。

调用 netlink 接口相应地创建 IPVS 规则，并定期将 IPVS 规则与 Kubernetes Service 和 Endpoint 同步。
该控制循环可确保 IPVS 状态与所需状态匹配。

访问服务时，IPVS 将流量定向到后端 Pod 之一。
IPVS 本身就是作为负载均衡功能，支持负载均衡算法：
- rr，round-robin
- lc，最少连接(打开连接的最小数量)
- dh，目的地址哈希
- sh，源地址哈希
- sed，最短的预期延迟
- nq，队列延迟

如果想确保每次都将来自特定客户端的连接传递到同一 Pod，需要使用 `service.spec.sessionAffinity`。
通过 `service.spec.sessionAffinityConfig.clientIP.timeoutSeconds` 设置最大会话，默认值为 10800，即 3 小时。

IPVS 模式基于类似于 iptables 模式的 netfilter hook 函数，但使用哈希表作为基础数据结构，并在内核空间工作。
流量包在查找下一跳规则时效率更高，减少流量包延迟。

IPVS 作用在 `INPUT` Chain，而不是像 iptables 作用在 `PREROUTING` Chain，所以 IPVS 模式需要给该 VIP 在本机设置个虚拟网卡。

IPVS 的负载是直接运行在内核态的，因此不会出现监听端口。
netstat 只能看到用户态的。

当 kube-proxy 以 IPVS 代理模式启动时，它将验证 IPVS 内核模块是否可用。
如果未检测到 IPVS 内核模块，则 kube-proxy 将退回到以 iptables 代理模式运行。

IPVS 创建 ClusterIP 类型的 Service 时，IPVS 模式的 kube-proxy 将执行以下三件事：
1. 确保节点中存在一个虚拟网卡，默认为 kube-ipvs0
2. 将服务 IP 地址绑定到虚拟网卡
3. 分别为每个服务 IP 地址创建 IPVS 虚拟服务器

Service 和 IPVS 虚拟服务器之间的关系是 1：N。
ExternalIP类型的 Service，就有 clusterIP 和 ExternalIP 两个地址。
然后，IPVS 代理将创建 2 个 IPVS 虚拟服务器，一个用于 clusterIP，另一个用于 ExternalIP。
而 Kubernetes Endpoint 和 IPVS 虚拟服务器之间的关系是 1：1。

删除 Kubernetes Service 将触发相应 IPVS 虚拟服务器，IPVS 真实服务器及其绑定到虚拟网卡的 IP 地址的删除。

##### 端口映射

IPVS 中有三种代理模式：
- NAT(masq)
- IPIP
- DR

仅 NAT 模式支持端口映射。kube-proxy 利用 NAT 模式进行端口映射。

```shell script
# IPVS 将 Service 端口 3080 映射到 Pod 端口 8080
TCP  10.102.128.4:3080 rr
  -> 10.244.0.235:8080            Masq    1      0          0
  -> 10.244.1.237:8080            Masq    1      0
```

##### 会话保持

IPVS 可以保证 Service 更新期间连接保持不断开。

当 Service 指定会话保持时，IPVS 代理将在 IPVS 虚拟服务器中设置超时时间，默认为 180min = 10800s。

```shell script
kubectl describe svc nginx-service
Name:				nginx-service
IP:					10.102.128.4
Port:				http	3080/TCP
Session Affinity:	ClientIP

ipvsadm -ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.102.128.4:3080 rr persistent 10800
```

##### IPVS Proxier 中的 iptables 和 ipset 

IPVS 用于负载均衡，无法实现 kube-proxy 中的其他功能，例如数据包过滤、hairpin-masquerade tricks、源地址转换等。

ipvs proxier 依赖 iptables：
1. kube-proxy 包含参数 –masquerade-all = true
2. 在 kube-proxy 启动指定 CIDR 参数
3. 支持负载均衡器类型 Service
4. 支持 NodePort 类型 Service

为了减少 iptables 规则，可以采用 ipset。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201204204656.png)

对于 Kubernetes v1.10，特性开关 SupportIPVSProxyMode 默认设置为 true。

##### clusterIP

1. 进入 `PREROUTING` Chain

2. 从 `PREROUTING` Chain 会转到 `KUBE-SERVICES` Chain

```shell script
-A PREROUTING -m comment --comment "kubernetes service portals" -j KUBE-SERVICES
```

3. 在 `KUBE-SERVICES` Chain 打标记

4. 从 `KUBE-SERVICES` Chain 再进入到 `KUBE-CLUSTER-IP` Chain

```shell script
# 10.244.0.0/16 为 ClusterIP 网段
-A KUBE-SERVICES ! -s 10.244.0.0/16 -m comment --comment "Kubernetes service cluster ip + port for masquerade purpose" -m set --match-set KUBE-CLUSTER-IP dst,dst -j KUBE-MARK-MASQ

-A KUBE-MARK-MASQ -j MARK --set-xmark 0x4000/0x4000

-A KUBE-SERVICES -m set --match-set KUBE-CLUSTER-IP dst,dst -j ACCEPT
```

5. `KUBE-CLUSTER-IP` 为 ipset 集合，在此处会进行 DNAT

6. 进入 `INPUT` Chain

7. 从 `INPUT` Chain 会转到 `KUBE-FIREWALL` Chain，在此处检查标记

```shell script
# 如果进来的数据带有 0x8000/0x8000 标记则丢弃，若有 0x4000/0x4000 标记则正常执行
-A INPUT -j KUBE-FIREWALL

-A KUBE-FIREWALL -m comment --comment "kubernetes firewall for dropping marked packets" -m mark --mark 0x8000/0x8000 -j DROP
```

8. 在 `INPUT` Chain 处，IPVS 的 LOCAL_IN Hook 发现此包在 IPVS 规则中则直接转发到 `POSTROUTING` Chain

```shell script
-A POSTROUTING -m comment --comment "kubernetes postrouting rules" -j KUBE-POSTROUTING
-A KUBE-POSTROUTING -m comment --comment "kubernetes service traffic requiring SNAT" -m mark --mark 0x4000/0x4000 -j MASQUERADE
```

##### NodePort

1. 进入 `PREROUTING` Chain

2. 从 `PREROUTING` Chain 会转到 `KUBE-SERVICES` Chain

```shell script
-A PREROUTING -m comment --comment "kubernetes service portals" -j KUBE-SERVICES
```

3. 在 `KUBE-SERVICES` Chain 打标记

```shell script
-A KUBE-SERVICES ! -s 10.244.0.0/16 -m comment --comment "Kubernetes service cluster ip + port for masquerade purpose" -m set --match-set KUBE-CLUSTER-IP dst,dst -j KUBE-MARK-MASQ

-A KUBE-MARK-MASQ -j MARK --set-xmark 0x4000/0x4000
```

4. 从 `KUBE-SERVICES` Chain 再进入到 `KUBE-NODE-PORT` Chain

```shell script
-A KUBE-SERVICES -m addrtype --dst-type LOCAL -j KUBE-NODE-PORT
```

5. `KUBE-NODE-PORT` 为 ipset 集合，在此处会进行 DNAT

6. 然后会进入 `INPUT` Chain

7. 从 `INPUT` Chain 会转到 `KUBE-FIREWALL` Chain，在此处检查标记

8. 在 `INPUT` Chain 处，IPVS 的 LOCAL_IN Hook 发现此包在 IPVS 规则中则直接转发到 `POSTROUTING` Chain

9. 流入 `INPUT` 后与 ClusterIP 的访问方式相同。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201204205750.png)

使用 userspace 模式，将只适合小型到中型规模的集群，不能够扩展到上千 Service 的大型集群。
使用 userspace 模式，隐藏了访问 Service 的数据包的源 IP 地址，这使得一些类型的防火墙无法起作用。
iptables 代理不会隐藏 Kubernetes 集群内部的 IP 地址，但却要求客户端请求必须通过一个负载均衡器或 Node 端口。

## 通信过程

### Pod 到 Pod

在 Kubernetes 中，每个 Pod 都有自己的 IP 地址。

Pod 之间具有 L3 连接。

它们可以相互 ping 通，并相互发送 TCP 或 UDP 数据包。

### Pod 到 Service

Service 是一个在 Pod 前面的 L4 负载均衡器。

一个 TCP 连接在 Pod 和 Service 之间工顺序：
- 客户端 Pod 将数据包发送到 Service 192.168.0.2:80。
- 数据包通过客户端节点中的 iptables 规则，目标更改为 Pod IP 10.0.1.2:80。
- Service 后端的 Pod 处理数据包并发回数据包。
- 数据包将返回客户端节点，conntrack 识别该数据包并将源地址重写回 192.169.0.2:80。
- 客户端 Pod 接收响应数据包。

### Pod 到外部

对于从 Pod 到外部地址的流量，Kubernetes 只使用 SNAT。
它的作用是用主机的 IP:Port 替换 Pod 的内部源 IP:Port。

当返回数据包返回主机时，它会将 Pod 的 IP:Port 重写为目标并将其发送回原始 Pod。
整个过程对原始 Pod 是透明的，原始 Pod 根本不知道地址转换。

