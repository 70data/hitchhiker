Network namespace 在逻辑上是网络堆栈的一个副本，它有自己的路由、防火墙规则和网络设备。

默认情况下，子进程继承其父进程的 Network namespace。
如果不显式创建新的 Network namespace，所有进程都从 init 进程继承相同的默认 Network namespace。

每个新创建的 Network namespace 默认有一个本地环回接口 lo。每个 socket 只能属于一个 Network namespace，其他网络设备(物理/虚拟网络接口、网桥)只能属于一个 Network namespace。

## 创建 Network namespace

```
# readlink /proc/$$/ns/net
net:[4026531992]

# ip addr
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

# ip netns add js

# ll /var/run/netns/
total 0
-r--r--r-- 1 root root 0 Nov  4 12:29 js

# ip netns exec js bash

# readlink /proc/$$/ns/net
net:[4026532214]

# ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00

# ip link set lo up

# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever

# ping 127.0.0.1 -c 5
PING 127.0.0.1 (127.0.0.1) 56(84) bytes of data.
64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.025 ms
64 bytes from 127.0.0.1: icmp_seq=2 ttl=64 time=0.036 ms
64 bytes from 127.0.0.1: icmp_seq=3 ttl=64 time=0.034 ms
64 bytes from 127.0.0.1: icmp_seq=4 ttl=64 time=0.033 ms
64 bytes from 127.0.0.1: icmp_seq=5 ttl=64 time=0.034 ms
--- 127.0.0.1 ping statistics ---
5 packets transmitted, 5 received, 0% packet loss, time 4111ms
rtt min/avg/max/mdev = 0.025/0.032/0.036/0.006 ms

# ip netns ls

# ip netns del js
Cannot remove namespace file "/var/run/netns/js": Device or resource busy

# exit
exit

# ip netns del js

# ip netns ls
```

## 在两个 Network namespace 之间通信

```
# ip netns add net1

# ip netns add net2

# ip netns ls
net2
net1
```

创建一对 veth 设备，默认情况下会自动为 veth pair 生成名称。

```
# ip link add veth1 type veth peer name veth2

# ip link ls
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1000
    link/ether 00:16:3e:00:08:8c brd ff:ff:ff:ff:ff:ff
5: veth2@veth1: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether e6:fb:be:5c:a8:db brd ff:ff:ff:ff:ff:ff
6: veth1@veth2: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 06:43:12:6a:d9:bb brd ff:ff:ff:ff:ff:ff

# ip addr
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

```
# ip link set veth1 netns net1

# ip link set veth2 netns net2
```

shell 1

```
# ip netns exec net1 bash

# ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
6: veth1@if5: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 06:43:12:6a:d9:bb brd ff:ff:ff:ff:ff:ff link-netnsid 0
```

shell 2

```
# ip netns exec net2 bash

# ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
5: veth2@if6: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether e6:fb:be:5c:a8:db brd ff:ff:ff:ff:ff:ff link-netnsid 1
```

veth pair 分配到 Network namespace 中后，在主机上看不到。

shell 1

```
# exit
exit

# ip link ls
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1000
    link/ether 00:16:3e:00:08:8c brd ff:ff:ff:ff:ff:ff
```

分配 ip 并启动。

shell 1

```
# ip link set veth1 up

# ip link ls
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
6: veth1@if5: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN mode DEFAULT group default qlen 1000
    link/ether 06:43:12:6a:d9:bb brd ff:ff:ff:ff:ff:ff link-netnsid 0

# ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
6: veth1@if5: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN group default qlen 1000
    link/ether 06:43:12:6a:d9:bb brd ff:ff:ff:ff:ff:ff link-netnsid 0

# ip addr add 10.0.1.1/24 dev veth1

# ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
6: veth1@if5: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN group default qlen 1000
    link/ether 06:43:12:6a:d9:bb brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.0.1.1/24 scope global veth1
       valid_lft forever preferred_lft forever

# ip route
10.0.1.0/24 dev veth1 proto kernel scope link src 10.0.1.1 linkdown
```

shell 2

```
# ip link set veth2 up

# ip link ls
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
5: veth2@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether e6:fb:be:5c:a8:db brd ff:ff:ff:ff:ff:ff link-netnsid 1

# ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
5: veth2@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether e6:fb:be:5c:a8:db brd ff:ff:ff:ff:ff:ff link-netnsid 1
    inet6 fe80::e4fb:beff:fe5c:a8db/64 scope link
       valid_lft forever preferred_lft forever

# ip addr add 10.0.1.2/24 dev veth2

# ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
5: veth2@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether e6:fb:be:5c:a8:db brd ff:ff:ff:ff:ff:ff link-netnsid 1
    inet 10.0.1.2/24 scope global veth2
       valid_lft forever preferred_lft forever
    inet6 fe80::e4fb:beff:fe5c:a8db/64 scope link
       valid_lft forever preferred_lft forever

# ip route
10.0.1.0/24 dev veth2 proto kernel scope link src 10.0.1.2
```

shell 1

```
# ping -c 3 10.0.1.2
PING 10.0.1.2 (10.0.1.2) 56(84) bytes of data.
64 bytes from 10.0.1.2: icmp_seq=1 ttl=64 time=0.034 ms
64 bytes from 10.0.1.2: icmp_seq=2 ttl=64 time=0.040 ms
64 bytes from 10.0.1.2: icmp_seq=3 ttl=64 time=0.039 ms
--- 10.0.1.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2056ms
rtt min/avg/max/mdev = 0.034/0.037/0.040/0.007 ms
```

shell 2

```
# ping -c 3 10.0.1.1
PING 10.0.1.1 (10.0.1.1) 56(84) bytes of data.
64 bytes from 10.0.1.1: icmp_seq=1 ttl=64 time=0.021 ms
64 bytes from 10.0.1.1: icmp_seq=2 ttl=64 time=0.035 ms
64 bytes from 10.0.1.1: icmp_seq=3 ttl=64 time=0.035 ms
--- 10.0.1.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2041ms
rtt min/avg/max/mdev = 0.021/0.030/0.035/0.008 ms
```

删除 Network namespace。

```
# exit
exit

# ip net del net2

# ip net del net1
```

## 通过 bridge 连接 Network namespace。

因为 veth pair 是一对，所以 veth pair 只能实现两个 Network namespace 之间的通信，无法支持在多个 Network namespace 之间通信。

添加网桥 js 并分配 ip

```
# ip link add js type bridge

# ip link
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1000
    link/ether 00:16:3e:00:08:8c brd ff:ff:ff:ff:ff:ff
7: js: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether be:b6:dd:67:f4:40 brd ff:ff:ff:ff:ff:ff

# ip addr add 10.0.1.0/24 dev js

# ip link set dev js up
```

创建 Network namespace，分配 veth 设备，绑定网桥。

shell 1

```
# ip netns add net1

# ip link add veth1 type veth peer name veth1p

# ip link set dev veth1p netns net1
```

shell 2 中执行，把其中一个 veth1 放到 net1 里面，设置它的 ip 地址并启用它。

```
# ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
12: veth1p@if13: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 2a:82:c1:3b:02:a2 brd ff:ff:ff:ff:ff:ff link-netnsid 0

# ip link set dev veth1p name eth1

# ip addr add 10.0.1.1/24 dev eth1

# ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
12: eth1@if13: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 2a:82:c1:3b:02:a2 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.0.1.1/24 scope global eth1
       valid_lft forever preferred_lft forever

# ip link set dev eth1 up

# ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
12: eth1@if13: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN group default qlen 1000
    link/ether 2a:82:c1:3b:02:a2 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.0.1.1/24 scope global eth1
       valid_lft forever preferred_lft forever

# ip link set dev veth1 master js
Error: argument "js" is wrong: Device does not exist
```

把另一个 veth1 连接到创建的 bridge 上，并启用它。

shell 1

```
# ip link set dev veth1 master js

# bridge link
13: veth1 state DOWN @(null): <BROADCAST,MULTICAST> mtu 1500 master js state disabled priority 32 cost 2

# ip link set dev veth1 up

# bridge link
13: veth1 state UP @(null): <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master js state forwarding priority 32 cost 2
```

shell 2

```
# ip addr
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

```
# ip netns add net2

# ip link add veth2 type veth peer name veth2p

# ip link set dev veth2p netns net2
```

shell 3 中执行，把其中一个 veth2 放到 net2 里面，设置它的 ip 地址并启用它。

```
# ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
14: veth2p@if15: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 66:09:a7:37:e4:30 brd ff:ff:ff:ff:ff:ff link-netnsid 0

# ip link set dev veth2p name eth2

# ip addr add 10.0.1.2/24 dev eth2

# ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
14: eth2@if15: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 66:09:a7:37:e4:30 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.0.1.2/24 scope global eth2
       valid_lft forever preferred_lft forever

# ip link set dev eth2 up

# ip addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
14: eth2@if15: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN group default qlen 1000
    link/ether 66:09:a7:37:e4:30 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.0.1.2/24 scope global eth2
       valid_lft forever preferred_lft forever
```

把另一个 veth2 连接到创建的 bridge 上，并启用它。

shell 1

```
# ip link set dev veth2 master js

# bridge link
13: veth1 state UP @(null): <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master js state forwarding priority 32 cost 2
15: veth2 state DOWN @(null): <BROADCAST,MULTICAST> mtu 1500 master js state disabled priority 32 cost 2

# ip link set dev veth2 up

# bridge link
13: veth1 state UP @(null): <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master js state forwarding priority 32 cost 2
15: veth2 state UP @(null): <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master js state forwarding priority 32 cost 2
```

shell 3

```
# ip addr
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

```
# ping -c 3 10.0.1.2
PING 10.0.1.2 (10.0.1.2) 56(84) bytes of data.
64 bytes from 10.0.1.2: icmp_seq=1 ttl=64 time=0.028 ms
64 bytes from 10.0.1.2: icmp_seq=2 ttl=64 time=0.047 ms
64 bytes from 10.0.1.2: icmp_seq=3 ttl=64 time=0.047 ms
--- 10.0.1.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2086ms
rtt min/avg/max/mdev = 0.028/0.040/0.047/0.011 ms
```

shell 3

```
# ping -c 3 10.0.1.1
PING 10.0.1.1 (10.0.1.1) 56(84) bytes of data.
64 bytes from 10.0.1.1: icmp_seq=1 ttl=64 time=0.062 ms
64 bytes from 10.0.1.1: icmp_seq=2 ttl=64 time=0.049 ms
64 bytes from 10.0.1.1: icmp_seq=3 ttl=64 time=0.046 ms
--- 10.0.1.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2080ms
rtt min/avg/max/mdev = 0.046/0.052/0.062/0.009 ms
```

shell 1

```
# ping -c 3 10.0.1.1
PING 10.0.1.1 (10.0.1.1) 56(84) bytes of data.
64 bytes from 10.0.1.1: icmp_seq=1 ttl=64 time=0.046 ms
64 bytes from 10.0.1.1: icmp_seq=2 ttl=64 time=0.046 ms
64 bytes from 10.0.1.1: icmp_seq=3 ttl=64 time=0.048 ms
--- 10.0.1.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2024ms
rtt min/avg/max/mdev = 0.046/0.046/0.048/0.007 ms

# ping -c 3 10.0.1.2
PING 10.0.1.2 (10.0.1.2) 56(84) bytes of data.
64 bytes from 10.0.1.2: icmp_seq=1 ttl=64 time=0.048 ms
64 bytes from 10.0.1.2: icmp_seq=2 ttl=64 time=0.053 ms
64 bytes from 10.0.1.2: icmp_seq=3 ttl=64 time=0.046 ms
--- 10.0.1.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2086ms
rtt min/avg/max/mdev = 0.046/0.049/0.053/0.003 ms
```

