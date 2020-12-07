实现方式：路由信息 + arp + fdb

Flannel 初始化时通常指定一个 16 位的网络，然后每个 Node 单独分配一个独立的 24 位子网。

Flannel 只有一张网卡，本地通信直接使用原生的 bridge 网络。

到本地的流量直接交给 cni0/docker0 去处理即可。
因为这里不涉及跨节点的访问，而跨节点的流量由 flannel.1 网卡去代理。

在容器内部通过网桥查看本地路由，可以看到不同的子网都有不同的网关。

```
ip route
default via 192.168.1.1 dev eth0 proto dhcp src 192.168.1.68 metric 100
40.15.26.0/24 via 40.15.26.0 dev flannel.1 onlink
40.15.43.0/24 dev docker0 proto kernel scope link src 40.15.43.1
40.15.56.0/24 via 40.15.56.0 dev flannel.1 onlink
```

本地路由这里只有 IP。
获取 MAC 要从 arp 表里获取，实际上这个 MAC 就是目标宿主机的 flannel.1 的 MAC 地址。

获取到 MAC 地址以后，vxlan 部分的已经封包完成。

`[目的 MAC:node2.flannel.1.MAC, 目的 IP:container2.IP, ...]`

然后增加 VXLAN Header。

`[VxlanHeader:VNI:1 [目的 MAC:node2.flannel.1.MAC, 目的 IP:container2.IP, ...]]`

目标 MAC 地址对应的宿主机的 IP 可以从 fdb 表去获取。

生成外 UDP 包。

`[目的 MAC:node2.MAC, 目的 IP:node2.IP [VxlanHeader:VNI:1 [目的 MAC:node2.flannel.1.MAC, 目的 IP:container2.IP, ...]]]`

外部的包也封好了，确定了数据包应该发到哪台宿主机上。

数据包封装好以后，先经过 iptables Chain，再到达目标机器的 eth0。
通过拆包根据 vni 值转发到 Flannel 设备。对比 MAC 地址相等以后，转发到本地的 flannel.1。
通过 cni0/docker0 转发到目标容器的 veth。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201207215632)

