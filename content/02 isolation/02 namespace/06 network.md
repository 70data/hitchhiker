Network namespace 在逻辑上是网络堆栈的一个副本，它有自己的路由、防火墙规则和网络设备。

默认情况下，子进程继承其父进程的 Network namespace。
如果不显式创建新的 Network namespace，所有进程都从 init 进程继承相同的默认 Network namespace。

每个新创建的 Network namespace 默认有一个本地环回接口 lo。每个 socket 只能属于一个 Network namespace，其他网络设备(物理/虚拟网络接口、网桥)只能属于一个 Network namespace。

## 创建 Network namespace

```shell script
readlink /proc/$$/ns/net
net:[4026531992]

ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:16:3e:00:08:8c brd ff:ff:ff:ff:ff:ff
    inet 172.26.196.109/20 brd 172.26.207.255 scope global dynamic eth0
       valid_lft 315268189sec preferred_lft 315268189sec
    inet6 fe80::216:3eff:fe00:88c/64 scope link
       valid_lft forever preferred_lft forever

ip netns add js

ll /var/run/netns/
total 0
-r--r--r-- 1 root root 0 Nov  4 12:29 js

ip netns exec js bash

readlink /proc/$$/ns/net
net:[4026532214]

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00

ip link set lo up

ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever

ping 127.0.0.1 -c 5
PING 127.0.0.1 (127.0.0.1) 56(84) bytes of data.
64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.025 ms
64 bytes from 127.0.0.1: icmp_seq=2 ttl=64 time=0.036 ms
64 bytes from 127.0.0.1: icmp_seq=3 ttl=64 time=0.034 ms
64 bytes from 127.0.0.1: icmp_seq=4 ttl=64 time=0.033 ms
64 bytes from 127.0.0.1: icmp_seq=5 ttl=64 time=0.034 ms
--- 127.0.0.1 ping statistics ---
5 packets transmitted, 5 received, 0% packet loss, time 4111ms
rtt min/avg/max/mdev = 0.025/0.032/0.036/0.006 ms

ip netns ls

ip netns del js
Cannot remove namespace file "/var/run/netns/js": Device or resource busy

exit
exit

ip netns del js

ip netns ls
```

## 在两个 Network namespace 之间通信

```shell script
ip netns add net1

ip netns add net2

ip netns ls
net2
net1
```

创建一对 veth 设备，默认情况下会自动为 veth pair 生成名称。

```shell script
ip link add veth1 type veth peer name veth2

ip link ls
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1000
    link/ether 00:16:3e:00:08:8c brd ff:ff:ff:ff:ff:ff
5: veth2@veth1: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether e6:fb:be:5c:a8:db brd ff:ff:ff:ff:ff:ff
6: veth1@veth2: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 06:43:12:6a:d9:bb brd ff:ff:ff:ff:ff:ff

ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:16:3e:00:08:8c brd ff:ff:ff:ff:ff:ff
    inet 172.26.196.109/20 brd 172.26.207.255 scope global dynamic eth0
       valid_lft 315254976sec preferred_lft 315254976sec
    inet6 fe80::216:3eff:fe00:88c/64 scope link
       valid_lft forever preferred_lft forever
5: veth2@veth1: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether e6:fb:be:5c:a8:db brd ff:ff:ff:ff:ff:ff
6: veth1@veth2: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 06:43:12:6a:d9:bb brd ff:ff:ff:ff:ff:ff
```

把这一对 veth pair 分别放到 Network namespace net1 和 net2 中。

```shell script
ip link set veth1 netns net1

ip link set veth2 netns net2
```

shell 1

```shell script
ip netns exec net1 bash

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
6: veth1@if5: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 06:43:12:6a:d9:bb brd ff:ff:ff:ff:ff:ff link-netnsid 0
```

shell 2

```shell script
ip netns exec net2 bash

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
5: veth2@if6: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether e6:fb:be:5c:a8:db brd ff:ff:ff:ff:ff:ff link-netnsid 1
```

veth pair 分配到 Network namespace 中后，在主机上看不到。

shell 1

```shell script
exit
exit

ip link ls
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1000
    link/ether 00:16:3e:00:08:8c brd ff:ff:ff:ff:ff:ff
```

分配 ip 并启动。

shell 1

```shell script
ip link set veth1 up

ip link ls
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
6: veth1@if5: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN mode DEFAULT group default qlen 1000
    link/ether 06:43:12:6a:d9:bb brd ff:ff:ff:ff:ff:ff link-netnsid 0

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
6: veth1@if5: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN group default qlen 1000
    link/ether 06:43:12:6a:d9:bb brd ff:ff:ff:ff:ff:ff link-netnsid 0

ip addr add 10.0.1.1/24 dev veth1

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
6: veth1@if5: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN group default qlen 1000
    link/ether 06:43:12:6a:d9:bb brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.0.1.1/24 scope global veth1
       valid_lft forever preferred_lft forever

ip route
10.0.1.0/24 dev veth1 proto kernel scope link src 10.0.1.1 linkdown
```

shell 2

```shell script
ip link set veth2 up

ip link ls
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
5: veth2@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether e6:fb:be:5c:a8:db brd ff:ff:ff:ff:ff:ff link-netnsid 1

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
5: veth2@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether e6:fb:be:5c:a8:db brd ff:ff:ff:ff:ff:ff link-netnsid 1
    inet6 fe80::e4fb:beff:fe5c:a8db/64 scope link
       valid_lft forever preferred_lft forever

ip addr add 10.0.1.2/24 dev veth2

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
5: veth2@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether e6:fb:be:5c:a8:db brd ff:ff:ff:ff:ff:ff link-netnsid 1
    inet 10.0.1.2/24 scope global veth2
       valid_lft forever preferred_lft forever
    inet6 fe80::e4fb:beff:fe5c:a8db/64 scope link
       valid_lft forever preferred_lft forever

ip route
10.0.1.0/24 dev veth2 proto kernel scope link src 10.0.1.2
```

shell 1

```shell script
ping -c 3 10.0.1.2
PING 10.0.1.2 (10.0.1.2) 56(84) bytes of data.
64 bytes from 10.0.1.2: icmp_seq=1 ttl=64 time=0.034 ms
64 bytes from 10.0.1.2: icmp_seq=2 ttl=64 time=0.040 ms
64 bytes from 10.0.1.2: icmp_seq=3 ttl=64 time=0.039 ms
--- 10.0.1.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2056ms
rtt min/avg/max/mdev = 0.034/0.037/0.040/0.007 ms
```

shell 2

```shell script
ping -c 3 10.0.1.1
PING 10.0.1.1 (10.0.1.1) 56(84) bytes of data.
64 bytes from 10.0.1.1: icmp_seq=1 ttl=64 time=0.021 ms
64 bytes from 10.0.1.1: icmp_seq=2 ttl=64 time=0.035 ms
64 bytes from 10.0.1.1: icmp_seq=3 ttl=64 time=0.035 ms
--- 10.0.1.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2041ms
rtt min/avg/max/mdev = 0.021/0.030/0.035/0.008 ms
```

删除 Network namespace。

```shell script
exit
exit

ip net del net2

ip net del net1
```

## 通过 bridge 连接 Network namespace。

因为 veth pair 是一对，所以 veth pair 只能实现两个 Network namespace 之间的通信，无法支持在多个 Network namespace 之间通信。

添加网桥 js 并分配 ip

```shell script
ip link add js type bridge

ip link
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1000
    link/ether 00:16:3e:00:08:8c brd ff:ff:ff:ff:ff:ff
7: js: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether be:b6:dd:67:f4:40 brd ff:ff:ff:ff:ff:ff

ip addr add 10.0.1.0/24 dev js

ip link set dev js up
```

创建 Network namespace，分配 veth 设备，绑定网桥。

shell 1

```shell script
ip netns add net1

ip link add veth1 type veth peer name veth1p

ip link set dev veth1p netns net1
```

shell 2 中执行，把其中一个 veth1 放到 net1 里面，设置它的 ip 地址并启用它。

```shell script
ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
12: veth1p@if13: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 2a:82:c1:3b:02:a2 brd ff:ff:ff:ff:ff:ff link-netnsid 0

ip link set dev veth1p name eth1

ip addr add 10.0.1.1/24 dev eth1

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
12: eth1@if13: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 2a:82:c1:3b:02:a2 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.0.1.1/24 scope global eth1
       valid_lft forever preferred_lft forever

ip link set dev eth1 up

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
12: eth1@if13: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN group default qlen 1000
    link/ether 2a:82:c1:3b:02:a2 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.0.1.1/24 scope global eth1
       valid_lft forever preferred_lft forever

ip link set dev veth1 master js
Error: argument "js" is wrong: Device does not exist
```

把另一个 veth1 连接到创建的 bridge 上，并启用它。

shell 1

```shell script
ip link set dev veth1 master js

bridge link
13: veth1 state DOWN @(null): <BROADCAST,MULTICAST> mtu 1500 master js state disabled priority 32 cost 2

ip link set dev veth1 up

bridge link
13: veth1 state UP @(null): <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master js state forwarding priority 32 cost 2
```

shell 2

```shell script
ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
12: eth1@if13: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 2a:82:c1:3b:02:a2 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.0.1.1/24 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::2882:c1ff:fe3b:2a2/64 scope link
       valid_lft forever preferred_lft forever
```

操作一个 Network namespace。

shell 1

```shell script
ip netns add net2

ip link add veth2 type veth peer name veth2p

ip link set dev veth2p netns net2
```

shell 3 中执行，把其中一个 veth2 放到 net2 里面，设置它的 ip 地址并启用它。

```shell script
ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
14: veth2p@if15: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 66:09:a7:37:e4:30 brd ff:ff:ff:ff:ff:ff link-netnsid 0

ip link set dev veth2p name eth2

ip addr add 10.0.1.2/24 dev eth2

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
14: eth2@if15: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 66:09:a7:37:e4:30 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.0.1.2/24 scope global eth2
       valid_lft forever preferred_lft forever

ip link set dev eth2 up

ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
14: eth2@if15: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN group default qlen 1000
    link/ether 66:09:a7:37:e4:30 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.0.1.2/24 scope global eth2
       valid_lft forever preferred_lft forever
```

把另一个 veth2 连接到创建的 bridge 上，并启用它。

shell 1

```shell script
ip link set dev veth2 master js

bridge link
13: veth1 state UP @(null): <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master js state forwarding priority 32 cost 2
15: veth2 state DOWN @(null): <BROADCAST,MULTICAST> mtu 1500 master js state disabled priority 32 cost 2

ip link set dev veth2 up

bridge link
13: veth1 state UP @(null): <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master js state forwarding priority 32 cost 2
15: veth2 state UP @(null): <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master js state forwarding priority 32 cost 2
```

shell 3

```shell script
ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
14: eth2@if15: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 66:09:a7:37:e4:30 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.0.1.2/24 scope global eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::6409:a7ff:fe37:e430/64 scope link
       valid_lft forever preferred_lft forever
```

测试连通性。

shell 2

```shell script
ping -c 3 10.0.1.2
PING 10.0.1.2 (10.0.1.2) 56(84) bytes of data.
64 bytes from 10.0.1.2: icmp_seq=1 ttl=64 time=0.028 ms
64 bytes from 10.0.1.2: icmp_seq=2 ttl=64 time=0.047 ms
64 bytes from 10.0.1.2: icmp_seq=3 ttl=64 time=0.047 ms
--- 10.0.1.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2086ms
rtt min/avg/max/mdev = 0.028/0.040/0.047/0.011 ms
```

shell 3

```shell script
ping -c 3 10.0.1.1
PING 10.0.1.1 (10.0.1.1) 56(84) bytes of data.
64 bytes from 10.0.1.1: icmp_seq=1 ttl=64 time=0.062 ms
64 bytes from 10.0.1.1: icmp_seq=2 ttl=64 time=0.049 ms
64 bytes from 10.0.1.1: icmp_seq=3 ttl=64 time=0.046 ms
--- 10.0.1.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2080ms
rtt min/avg/max/mdev = 0.046/0.052/0.062/0.009 ms
```

shell 1

```shell script
ping -c 3 10.0.1.1
PING 10.0.1.1 (10.0.1.1) 56(84) bytes of data.
64 bytes from 10.0.1.1: icmp_seq=1 ttl=64 time=0.046 ms
64 bytes from 10.0.1.1: icmp_seq=2 ttl=64 time=0.046 ms
64 bytes from 10.0.1.1: icmp_seq=3 ttl=64 time=0.048 ms
--- 10.0.1.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2024ms
rtt min/avg/max/mdev = 0.046/0.046/0.048/0.007 ms

ping -c 3 10.0.1.2
PING 10.0.1.2 (10.0.1.2) 56(84) bytes of data.
64 bytes from 10.0.1.2: icmp_seq=1 ttl=64 time=0.048 ms
64 bytes from 10.0.1.2: icmp_seq=2 ttl=64 time=0.053 ms
64 bytes from 10.0.1.2: icmp_seq=3 ttl=64 time=0.046 ms
--- 10.0.1.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2086ms
rtt min/avg/max/mdev = 0.046/0.049/0.053/0.003 ms
```

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201108095535.png)

## bridge

网桥是一个二层的虚拟网络设备，也就是数据链路层(data link)的设备。

网桥把若干个网络接口"连接"起来，使得网口之间的报文可以转发。
网桥能够解析收发的报文，读取目标的 MAC 地址信息，和自己的 MAC 地址表结合，来决策报文转发的目标网口。

网桥会学习源 MAC 地址。
在转发报文时，网桥只需要向特定的端口转发，从而避免不必要的网络交互。
如果它遇到了一个自己从未学过的地址，就无法知道这个报文应该向哪个网口转发，就将报文广播给除了报文来源之外的所有网口。

在实际网络中，网络拓扑不可能永久不变。
如果设备移动到另一个端口上，而它没有发送任何数据，那么网桥设备就无法感知到这个变化，结果网桥还是向原来的端口发数据包，在这种情况下数据就会丢失。
网桥还要对学习到的 MAC 地址表加上超时时间，默认 5min。
如果网桥收到了对应端口 MAC 地址回发的包，重置超时时间，否则过了超时时间后，就认为哪个设备不在那个端口上了，就会广播重发。

Linux 为了支持越来越多的网卡以及虚拟设备，所以使用网桥去提供这些设备之间转发数据的二层设备。
Linux 内核支持网口的桥接(以太网接口)，这与单纯的交换机还是不太一样。
交换机仅仅是一个二层设备，对于接受到的报文，要么转发，要么丢弃。
Linux 本身就是一台主机，有可能是网络报文的目的地，其收到的报文要么转发，要么丢弃，还可能被送到网络协议的网络层，从而被自己主机本身的协议栈消化。
所以可以把网桥看作一个二层设备，也可以看做是一个三层设备。

### Linux 中 bridge 实现

Linux 内核是通过一个虚拟的网桥设备(Net Device)来实现桥接的。

这个虚拟设备可以绑定若干个以太网接口，从而将它们连接起来。

Net Device 网桥和普通的设备不同，最明显的是它还可以有一个ip地址。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201108102634.png)

网桥设备 br0 绑定 eth0 和 eth1。

对于网络协议栈的上层来说，只看到 br0。
因为桥接是在数据链路层实现的，上层不需要关心桥接的细节。
协议栈上层需要发送的报文被送到 br0，网桥设备的处理代码判断报文被转发到 eth0 还是 eth1，或者两者皆转发。

从 eth0 或者 从eth1 接收到的报文被提交给网桥的处理代码，在这里判断报文应该被转发、丢弃或者提交到协议栈上层。
有时 eth0、eth1 也可能会作为报文的源地址或目的地址，直接参与报文的发送和接收，从而绕过网桥。

## Veth Pair

Veth Pair 虚拟设备。

Veth Pair 就是为了在不同的 Network Namespace 之间进行通信，利用它可以将两个 Network Namespace 连接起来。

Veth Pair 设备的特点是：它被创建出来后，总是以两张虚拟网卡(Veth Peer)的形式出现。并且，其中一个网卡发出的数据包，可以直接出现在另一张"网卡"上，哪怕这两张网卡在不同的 Network Namespace 中。
正是因为这样的特点，Veth Pair 成对出现，很像是一对以太网卡，常常被看做是不同 Network Namespace 直连的"网线"。在 Veth 一端发送数据时，它会将数据发送到另一端并触发另一端的接收操作。可以把 Veth Pair 其中一端看做另一端的一个 Peer。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201108110138.png)

## 使用 bridge 和 Veth 构建网络

```
                           +------------------------+
                           |                        | iptables +----------+
                           |  br01 192.168.88.1/24  |          |          |
                +----------+                        <--------->+ eth0   |
                |          +------------------+-----+          |          |
                |                             |                +----------+
           +----+---------+       +-----------+-----+
           |              |       |                 |
           | br-veth01    |       |   br-veth02     |
           +--------------+       +-----------+-----+
                |                             |
+--------+------+-----------+     +-------+---+-------------+
|        |                  |     |       |                 |
|  ns01  |   veth01         |     |  ns02 |  veth01         |
|        |                  |     |       |                 |
|        |   192.168.88.11  |     |       |  192.168.88.12  |
|        |                  |     |       |                 |
|        +------------------+     |       +-----------------+
|                           |     |                         |
|                           |     |                         |
+---------------------------+     +-------------------------+
```

br01 是创建的 bridge，链接着两个 Veth。
两个 Veth 的另一端分别在另外两个 namespace 里。

eth0 是宿主机对外的网卡，namespace 对外的数据包会通过 `SNAT`/`MASQUERADE` 出去 。

创建 bridge。

```shell script
brctl addbr br01
```

启动 bridge。

```shell script
ip link set dev br01 up

# 也可以用下面这种方式启动
ifconfig br01 up 
```

给 bridge 分配IP地址。

```shell script
ifconfig br01 192.168.88.1/24 up
```

创建 Network namespace，ns01、ns02。

```shell script
ip netns add ns01

ip netns add ns02

# 查看创建的ns
sudo ip netns list
ns02
ns01
```

设置 Veth Pair。

创建两对 Veth。

```shell script
# 创建 veth 设备，`ip link add link [DEVICE NAME] type veth`
ip link add veth01 type veth peer name br-veth01

ip link add veth02 type veth peer name br-veth02
```

将其中一端的 Veth(br-veth$) 挂载到 br01 下面。

```shell script
# attach 设备到 bridge，brctl addif [BRIDGE NAME] [DEVICE NAME]
brctl addif br01 br-veth01

brctl addif br01 br-veth02

# 查看挂载详情
sudo brctl show br01
bridge name     bridge id               STP enabled     interfaces
br01            8000.321bc3fd56fd       no              br-veth01
                                                        br-veth02
```

启动这两对 Veth。

```shell script
ip link set dev br-veth01 up

ip link set dev br-veth02 up
```

将另一端的 Veth 分配给创建好的 namespace。

```shell script
ip link set veth01 netns ns01

ip link set veth02 netns ns02
```

部署 Veth 在 namespace 的网络。

通过 `ip netns [NS] [COMMAND]` 命令可以在特定的网络命名空间执行命令。

```shell script
# 查看 Network namespace 里的网络设备
ip netns exec ns01 ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: sit0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN group default qlen 1000
    link/sit 0.0.0.0 brd 0.0.0.0
8: veth01@if7: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether d2:88:ec:62:cd:0a brd ff:ff:ff:ff:ff:ff link-netnsid 0
```

可以看到刚刚被加进来的 veth01 还没有 IP 地址。

给两个 Network namespace 的 Veth 设置 IP 地址和默认路由。

默认网关设置为 bridge 的 IP。

```shell script
ip netns exec ns01 ip link set dev veth01 up

ip netns exec ns01 ifconfig veth01 192.168.88.11/24 up

ip netns exec ns01 ip route add default via 192.168.88.1

ip netns exec ns02 ip link set dev veth02 up

ip netns exec ns02 ifconfig veth02 192.168.88.12/24 up

ip netns exec ns02 ip route add default via 192.168.88.1
```

查看 namespace 的 Veth 是否分配了 IP。

```shell script
ip netns exec ns02 ifconfig veth02
veth02: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.88.12  netmask 255.255.255.0  broadcast 192.168.88.255
        inet6 fe80::fca2:57ff:fe1c:67df  prefixlen 64  scopeid 0x20<link>
        ether fe:a2:57:1c:67:df  txqueuelen 1000  (以太网)
        RX packets 15  bytes 1146 (1.1 KB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 11  bytes 866 (866.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

验证 namespace 内网络情况。

从 ns01 里 `ping ns02`，同时在默认用 tcpdump 在 br01 bridge 上抓包。

```shell script
# 抓包
tcpdump -i br01 -nn
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on br01, link-type EN10MB (Ethernet), capture size 262144 bytes

# 从 ns01 ping ns02
sudo ip netns exec ns01 ping 192.168.88.12 -c 1

PING 192.168.88.12 (192.168.88.12) 56(84) bytes of data.
64 bytes from 192.168.88.12: icmp_seq=1 ttl=64 time=0.086 ms
--- 192.168.88.12 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.086/0.086/0.086/0.000 ms

# 查看抓包信息
16:19:42.739429 ARP, Request who-has 192.168.88.12 tell 192.168.88.11, length 28
16:19:42.739471 ARP, Reply 192.168.88.12 is-at fe:a2:57:1c:67:df, length 28
16:19:42.739476 IP 192.168.88.11 > 192.168.88.12: ICMP echo request, id 984, seq 1, length 64
16:19:42.739489 IP 192.168.88.12 > 192.168.88.11: ICMP echo reply, id 984, seq 1, length 64
16:19:47.794415 ARP, Request who-has 192.168.88.11 tell 192.168.88.12, length 28
16:19:47.794451 ARP, Reply 192.168.88.11 is-at d2:88:ec:62:cd:0a, length 28
```

可以看到 ARP 能正确定位到 MAC 地址，并且 reply 包能正确返回到 ns01 中。
反之在 ns02 中 `ping ns01` 也是通的。

在 ns01 内执行 ARP。

```shell script
ip netns exec ns01 arp
地址                     类型    硬件地址            标志  Mask            接口
192.168.88.12           ether   fe:a2:57:1c:67:df  C                   veth01
192.168.88.1            ether   32:1b:c3:fd:56:fd  C                   veth01
```

可以看到 192.168.88.1 的 MAC 地址是正确的，跟 ip link 打印出来的是一致。

```shell script
ip link
6: br01: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 32:1b:c3:fd:56:fd brd ff:ff:ff:ff:ff:ff
```

namespace 与外网互通。

从 ns02 ping 外网地址。

``shell script
ip netns exec ns02 ping 114.114.114.114 -c 1
PING 114.114.114.114 (114.114.114.114) 56(84) bytes of data.
--- 114.114.114.114 ping statistics ---
1 packets transmitted, 0 received, 100% packet loss, time 0ms
```

发现是 ping 不通的，抓包查看详情。

```shell script
# 抓 bridge 设备
tcpdump -i br01 -nn -vv host 114.114.114.114
tcpdump: listening on br01, link-type EN10MB (Ethernet), capture size 262144 bytes
17:02:59.027478 IP (tos 0x0, ttl 64, id 51092, offset 0, flags [DF], proto ICMP (1), length 84)
    192.168.88.12 > 114.114.114.114: ICMP echo request, id 1045, seq 1, length 64

# 抓出口设备
tcpdump -i eth0 -nn -vv host 114.114.114.114
```

发现只有 br01 有出口流量，而出口网卡 eth0 没有任何反应，说明没有开启 `ip_forward`。

```shell script
# 开启 ip_forward
sysctl -w net.ipv4.conf.all.forwarding=1
```

再次尝试抓包 eth0 设备。

```shell script
tcpdump -i eth0 -nn -vv host 114.114.114.114
tcpdump: listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
17:11:26.517292 IP (tos 0x0, ttl 63, id 15277, offset 0, flags [DF], proto ICMP (1), length 84)
    192.168.88.12 > 114.114.114.114: ICMP echo request, id 1059, seq 1, length 64
```

发现只有发出去的包 request 没有回来 replay 的包。
原因是因为源地址是私有地址，如果发回来的包是私有地址会被丢弃
解决方法是将发出去的包 sourceIP 改成 gatewayIP，可以用 `SNAT` 或者 `MAQUERADE`。

- `SNAT`，需要搭配静态 IP。
- `MAQUERADE`，可以用于动态分配的 IP，但每次数据包被匹配中时，都会检查使用的 IP 地址。

```shell script
iptables -t nat -A POSTROUTING -s 192.168.88.0/24 -j MASQUERADE
# 查看防火墙规 iptables -t nat -nL --line-number
Chain PREROUTING (policy ACCEPT)
num  target     prot opt source               destination         
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination         
Chain OUTPUT (policy ACCEPT)
num  target     prot opt source               destination         
Chain POSTROUTING (policy ACCEPT)
num  target     prot opt source               destination         
1    MASQUERADE  all  --  192.168.88.0/24      0.0.0.0/0
```

再次尝试 `ping 114.114.114.114`。

```shell script
ip netns exec ns02 ping 114.114.114.114 -c 1
```

抓包查看

```shell script
tcpdump -i eth0 -nn -vv host 114.114.114.114
tcpdump: listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
17:43:54.744599 IP (tos 0x0, ttl 63, id 46107, offset 0, flags [DF], proto ICMP (1), length 84)
    172.22.36.202 > 114.114.114.114: ICMP echo request, id 1068, seq 1, length 64
17:43:54.783749 IP (tos 0x4, ttl 71, id 62825, offset 0, flags [none], proto ICMP (1), length 84)
    114.114.114.114 > 172.22.36.202: ICMP echo reply, id 1068, seq 1, length 64

tcpdump -i br01 -nn -vv
tcpdump: listening on br01, link-type EN10MB (Ethernet), capture size 262144 bytes17:43:54.744560 IP (tos 0x0, ttl 64, id 46107, offset 0, flags [DF], proto ICMP (1), length 84)
    192.168.88.12 > 114.114.114.114: ICMP echo request, id 1068, seq 1, length 64
17:43:54.783805 IP (tos 0x4, ttl 70, id 62825, offset 0, flags [none], proto ICMP (1), length 84)
    114.114.114.114 > 192.168.88.12: ICMP echo reply, id 1068, seq 1, length 64
```

可以看到从 eth0 出去的数据包的 sourceIP 已经变成网卡 IP 了。
br01 收到的包的 sourceIP 还是 ns02 的 192.168.88.12`

清理环境。

```bash
ip netns del ns01
ip netns del ns02
ifconfig br01 down
brctl delbr br01
iptables -t nat -D POSTROUTING -s 192.168.88.0/24 -j MASQUERADE
```

