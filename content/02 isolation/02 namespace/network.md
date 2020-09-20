Network namespace 在逻辑上是网络堆栈的一个副本，它有自己的路由、防火墙规则和网络设备。
默认情况下，子进程继承其父进程的 Network namespace。也就是说，如果不显式创建新的 Network namespace，所有进程都从 init 进程继承相同的默认 Network namespace。
每个新创建的 Network namespace 默认有一个本地环回接口 lo。每个 socket 只能属于一个 Network namespace，其他网络设备(物理/虚拟网络接口、网桥)只能属于一个 Network namespace。

## 创建 Network namespace

```
readlink /proc/$$/ns/net
net:[4026531956]

ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc pfifo_fast state UP qlen 1000
    link/ether fa:16:3e:2c:7e:2a brd ff:ff:ff:ff:ff:ff
    inet 10.16.29.16/23 brd 10.16.29.255 scope global eth0
       valid_lft forever preferred_lft forever
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN
    link/ether 02:42:8b:4b:e1:1e brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever

ip netns add mynet

ll /var/run/netns/
总用量 0
-r--r--r-- 1 root root 0 1月  24 11:56 mynet

ip netns exec mynet bash

readlink /proc/$$/ns/net
net:[4026532160]

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00

ip link set lo up

ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever

ping 127.0.0.1 -c 5
PING 127.0.0.1 (127.0.0.1) 56(84) bytes of data.
64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.037 ms
64 bytes from 127.0.0.1: icmp_seq=2 ttl=64 time=0.055 ms
64 bytes from 127.0.0.1: icmp_seq=3 ttl=64 time=0.039 ms
64 bytes from 127.0.0.1: icmp_seq=4 ttl=64 time=0.054 ms
64 bytes from 127.0.0.1: icmp_seq=5 ttl=64 time=0.054 ms
--- 127.0.0.1 ping statistics ---
5 packets transmitted, 5 received, 0% packet loss, time 3999ms
rtt min/avg/max/mdev = 0.037/0.047/0.055/0.011 ms

ip netns del mynet
```

## 在两个 Network namespace 之间通信

```
ip netns add net1

ip netns add net2

ip netns
net2
net1
```

创建一对 veth 设备，默认情况下会自动为 veth pair 生成名称。

```
ip link add veth1 type veth peer name veth2

ip link ls
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc pfifo_fast state UP mode DEFAULT qlen 1000
    link/ether fa:16:3e:2c:7e:2a brd ff:ff:ff:ff:ff:ff
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN mode DEFAULT
    link/ether 02:42:8b:4b:e1:1e brd ff:ff:ff:ff:ff:ff
6: veth2@veth1: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN mode DEFAULT qlen 1000
    link/ether c6:f6:cf:a0:56:c8 brd ff:ff:ff:ff:ff:ff
7: veth1@veth2: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN mode DEFAULT qlen 1000
    link/ether 86:c6:e9:1f:a8:9b brd ff:ff:ff:ff:ff:ff

ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc pfifo_fast state UP qlen 1000
    link/ether fa:16:3e:2c:7e:2a brd ff:ff:ff:ff:ff:ff
    inet 10.16.29.16/23 brd 10.16.29.255 scope global eth0
       valid_lft forever preferred_lft forever
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN
    link/ether 02:42:8b:4b:e1:1e brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
6: veth2@veth1: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN qlen 1000
    link/ether c6:f6:cf:a0:56:c8 brd ff:ff:ff:ff:ff:ff
7: veth1@veth2: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN qlen 1000
    link/ether 86:c6:e9:1f:a8:9b brd ff:ff:ff:ff:ff:ff
```

把这一对 veth pair 分别放到 Network namespace net1 和 net2 中。

```
ip link set veth1 netns net1

ip link set veth2 netns net2

ip netns exec net1 bash

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
7: veth1@if6: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN qlen 1000
    link/ether 86:c6:e9:1f:a8:9b brd ff:ff:ff:ff:ff:ff link-netnsid 1

ip netns exec net2 bash

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
6: veth2@if7: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN qlen 1000
    link/ether c6:f6:cf:a0:56:c8 brd ff:ff:ff:ff:ff:ff link-netnsid 0
```

veth pair 分配到 Network namespace 中后，在主机上看不到。

```
ip link ls
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc pfifo_fast state UP mode DEFAULT qlen 1000
    link/ether fa:16:3e:2c:7e:2a brd ff:ff:ff:ff:ff:ff
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN mode DEFAULT
    link/ether 02:42:8b:4b:e1:1e brd ff:ff:ff:ff:ff:ff
```

分配 ip 并启动。

```
ip netns exec net1 bash

ip link
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
7: veth1@if6: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT qlen 1000
    link/ether 86:c6:e9:1f:a8:9b brd ff:ff:ff:ff:ff:ff link-netnsid 1

ip link set veth1 up

ip link
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
7: veth1@if6: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN mode DEFAULT qlen 1000
    link/ether 86:c6:e9:1f:a8:9b brd ff:ff:ff:ff:ff:ff link-netnsid 1

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
7: veth1@if6: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN qlen 1000
    link/ether 86:c6:e9:1f:a8:9b brd ff:ff:ff:ff:ff:ff link-netnsid 1

ip addr add 10.0.1.1/24 dev veth1

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
7: veth1@if6: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN qlen 1000
    link/ether 86:c6:e9:1f:a8:9b brd ff:ff:ff:ff:ff:ff link-netnsid 1
    inet 10.0.1.1/24 scope global veth1
       valid_lft forever preferred_lft forever

ip route
10.0.1.0/24 dev veth1  proto kernel  scope link  src 10.0.1.1
```

```
ip netns exec net2 bash

ip link
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
6: veth2@if7: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT qlen 1000
    link/ether c6:f6:cf:a0:56:c8 brd ff:ff:ff:ff:ff:ff link-netnsid 0

ip link set veth2 up

ip link
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
6: veth2@if7: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT qlen 1000
    link/ether c6:f6:cf:a0:56:c8 brd ff:ff:ff:ff:ff:ff link-netnsid 0

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
6: veth2@if7: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP qlen 1000
    link/ether c6:f6:cf:a0:56:c8 brd ff:ff:ff:ff:ff:ff link-netnsid 0

ip addr add 10.0.1.2/24 dev veth2

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
6: veth2@if7: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP qlen 1000
    link/ether c6:f6:cf:a0:56:c8 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.0.1.2/24 scope global veth2
       valid_lft forever preferred_lft forever

ip route
10.0.1.0/24 dev veth2  proto kernel  scope link  src 10.0.1.2
```

```
ip netns exec net1 ping -c 3 10.0.1.2
PING 10.0.1.2 (10.0.1.2) 56(84) bytes of data.
64 bytes from 10.0.1.2: icmp_seq=1 ttl=64 time=0.060 ms
64 bytes from 10.0.1.2: icmp_seq=2 ttl=64 time=0.048 ms
64 bytes from 10.0.1.2: icmp_seq=3 ttl=64 time=0.048 ms
--- 10.0.1.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 1999ms
rtt min/avg/max/mdev = 0.048/0.052/0.060/0.005 ms

ip netns exec net2 ping -c 3 10.0.1.1
PING 10.0.1.1 (10.0.1.1) 56(84) bytes of data.
64 bytes from 10.0.1.1: icmp_seq=1 ttl=64 time=0.052 ms
64 bytes from 10.0.1.1: icmp_seq=2 ttl=64 time=0.059 ms
64 bytes from 10.0.1.1: icmp_seq=3 ttl=64 time=0.063 ms
--- 10.0.1.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 1999ms
rtt min/avg/max/mdev = 0.052/0.058/0.063/0.004 ms
```

## 通过 bridge 连接 Network namespace

veth pair 只能实现两个 Network namespace 之间的通信，无法支持在多个 Network namespace 之间通信。

添加网桥 mybridge0 并分配 ip

```
ip link add mybridge0 type bridge

ip link
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc pfifo_fast state UP mode DEFAULT qlen 1000
    link/ether fa:16:3e:2c:7e:2a brd ff:ff:ff:ff:ff:ff
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN mode DEFAULT
    link/ether 02:42:8b:4b:e1:1e brd ff:ff:ff:ff:ff:ff
8: mybridge0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT qlen 1000
    link/ether aa:a1:91:01:f3:08 brd ff:ff:ff:ff:ff:ff

ip addr add 10.0.1.0/24 dev mybridge0

ip link set dev mybridge0 up
```

创建 Network namespace net1，分配 veth 设备，绑定网桥

```
ip netns add net1

ip link add veth1 type veth peer name veth1p

ip link set dev veth1p netns net1

ip netns exec net1 ip link set dev veth1p name eth0

ip netns exec net1 ip addr add 10.0.1.1/24 dev eth0

ip netns exec net1 ip link set dev eth0 up

ip netns exec net1 ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
9: eth0@if10: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN qlen 1000
    link/ether f2:2e:68:0e:87:58 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.0.1.1/24 scope global eth0
       valid_lft forever preferred_lft forever

ip link set dev veth1 master mybridge0

ip link set dev veth1 up
```

按上述方案创建 net2。

查看网桥链接状态

```
bridge link
12: veth1 state UP @(null): <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master mybridge0 state forwarding priority 32 cost 2
14: veth2 state UP @(null): <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master mybridge0 state forwarding priority 32 cost 2
```
