Calico 每个节点分配一个子网，Calico 分的是 26 位子网。

Calico 认为不是所有的内核都能自动分配 MAC 地址，所以 Calico 自己制定。
Calico 完全使用三层路由通信，MAC 地址是什么其实无所谓，因此直接都使用 ee:ee:ee:ee:ee:ee。

大多数都是把容器的网卡通过 veth 连接到一个 bridge 设备上，而这个 bridge 设备往往也是容器网关，相当于主机上多了一个虚拟网卡配置。
Calico 认为容器网络不应该影响主机网络，因此容器的网卡的 veth 另一端没有经过 bridge 直接挂在默认的 namespace 中。
容器配的网关其实也是假的，通过 proxy_arp 修改 MAC 地址模拟了网关的行为，所以网关 IP 是什么也无所谓，那就直接选择了 local link 的一个 IP。

容器配置的 IP 掩码居然是 32 位的，那也就是说跟谁都不在一个子网了，也就不存在二层的链路层直接通信了，所以说 Calico 是一个纯三层通信的 cni。
所以 MAC 地址一样也可以通信。

宿主机路由下一跳直接指向 host IP。
Calico 为每个容器的 IP 生成一条明细路由，通过 bgp 广播的形式，直接指向容器的网卡对端。
如果容器数量很多的话，主机路由规则数量也会越来越多，因此才有了路由反射。

RR 模式中会指定一个或多个 BGP Speaker 为 RouterReflection。
它与网络中其他 Speaker 建立连接，每个 Speaker 只要与 Router Reflection 建立 BGP 就可以获得全网的路由信息。
在 Calico 中可以通过 Global Peer 实现 RR 模式。

Calico 通过 iptables + ipset 实现多个网络的隔离。

