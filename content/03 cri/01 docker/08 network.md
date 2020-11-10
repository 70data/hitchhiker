Docker 受一个 Github 上的 [issue](https://github.com/moby/moby/issues/9983) 启发，引入了容器网络模型(container network model，CNM)。

容器网络模型主要包含了 3 个概念：
- network，网络。可以理解为一个 Driver，是一个第三方网络栈，包含多种网络模式。单主机网络模式(bridge、host、joined container、none)，多主机网络模式(overlay、macvlan)。
- sandbox，沙箱。它定义了容器内的虚拟网卡、DNS 和路由表，是 Network namespace 的一种实现，是容器的内部网络栈。
- endpoint，端点。用于连接 sandbox 和 network。

可以类比传统网络模型，将 network 比作交换机，sandbox 比作网卡，endpoint 比作接口和网线。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201107221951.png)

Docker 在创建容器时，先调用控制器创建 sandbox 对象，再调用容器运行时为容器创建 Network namespace。

容器网络主要解决两大核心问题：
- 容器的 IP 地址分配
- 容器之间的相互通信

## bridge

桥接模式，docker run 默认模式。

此模式会为容器分配 Network namespace、设置 IP 等，并将容器网络桥接到一个虚拟网桥 docker0 上，可以和同一宿主机上桥接模式的其他容器进行通信。

Docker 会为容器创建独有的 Network namespace，也会为这个命名空间配置好虚拟网卡、路由、DNS、IP 地址、iptables 规则。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201107222827.png)

当 Docker 启动时，会自动在主机上创建一个 docker0 虚拟网桥。
实际上是 Linux 的一个 bridge，可以理解为一个软件交换机。它会在挂载到它的网口之间进行转发。

### 别的 Host 怎么访问该容器

跨节点访问容器时，由于不知道目标容器是住在哪台 Host 主机上，要访问那个容器，必须经过它所在的 Host，所以为了访问一个目标容器专门设置一条路由规则，并不方便。
所以一般直接用端口映射来访问。即：目标容器所在的 Host 主机 IP + 指定端口。然后当报文到达指定目标的 Host 主机时，通过指定端口映射进入容器。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201107210216.png)

```shell script
iptables -t nat -nL
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination
DOCKER     all  --  0.0.0.0/0            0.0.0.0/0            ADDRTYPE match dst-type LOCAL
Chain INPUT (policy ACCEPT)
target     prot opt source               destination
Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination
DOCKER     all  --  0.0.0.0/0           !127.0.0.0/8          ADDRTYPE match dst-type LOCAL
Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination
MASQUERADE  all  --  172.18.0.0/16        0.0.0.0/0
MASQUERADE  all  --  172.17.0.0/16        0.0.0.0/0
MASQUERADE  tcp  --  172.17.0.2           172.17.0.2           tcp dpt:80
Chain DOCKER (2 references)
target     prot opt source               destination
RETURN     all  --  0.0.0.0/0            0.0.0.0/0
RETURN     all  --  0.0.0.0/0            0.0.0.0/0
DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:8080 to:172.17.0.2:80

docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                  NAMES
4b610f763a21        js-nginx            "/docker-entrypoint.…"   27 hours ago        Up 27 hours         0.0.0.0:8080->80/tcp   nginx
```

### 该容器怎么访问别的 Host

所在的 Host 能通的地方，容器也能与它连通。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201107211900.png)

### 别的 Host 上的容器怎么访问该容器

- NAT 端口映射。容器里面直接用指定 IP + Port 访问目标容器。
- 隧道网络打通所有容器。所有容器处于同一个局域网中，Flannel、Weave、Calico 等实现。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201107213607.png)

### Docker 配置

```shell script
vim /etc/docker/daemon.json
{
    "bip":"10.50.0.1/16",
    "default-address-pools":[
        {
            "base":"10.51.0.1/16",
            "size":24
        }
    ]
}
```

设置 docker0 使用 10.50.0.1/16 网段，docker0 为 10.50.0.1。
后面服务再创建地址池使用 10.51.0.1/16 网段范围划分，每个子网掩码划分为 255.255.255.0。

下载 `centos:7` 镜像。

```
docker pull centos:7
7: Pulling from library/centos
75f829a71a1c: Pull complete
Digest: sha256:19a79828ca2e505eaee0ff38c2f3fd9901f4826737295157cc5212b7a372cd2b
Status: Downloaded newer image for centos:7
docker.io/library/centos:7
```

shell 1

```shell script
docker run -it centos:7 /bin/bash

yum install net-tools

ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.2  netmask 255.255.0.0  broadcast 172.17.255.255
        ether 02:42:ac:11:00:02  txqueuelen 0  (Ethernet)
        RX packets 4279  bytes 12041880 (11.4 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 2772  bytes 185681 (181.3 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

route
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         gateway         0.0.0.0         UG    0      0        0 eth0
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 eth0
```

这个 eth0 是这个容器的默认路由设备。
可以通过第二条路由规则，看到所有对 172.17.0.0 网段的请求都会交由 eth0 来处理。

shell 2

```shell script
# 在宿主机执行
ifconfig
docker0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.1  netmask 255.255.0.0  broadcast 172.17.255.255
        inet6 fe80::42:2eff:fe7a:ea6b  prefixlen 64  scopeid 0x20<link>
        ether 02:42:2e:7a:ea:6b  txqueuelen 0  (Ethernet)
        RX packets 3542  bytes 185159 (180.8 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 5217  bytes 23858486 (22.7 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.26.196.109  netmask 255.255.240.0  broadcast 172.26.207.255
        inet6 fe80::216:3eff:fe00:88c  prefixlen 64  scopeid 0x20<link>
        ether 00:16:3e:00:08:8c  txqueuelen 1000  (Ethernet)
        RX packets 627457  bytes 469630247 (447.8 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 311870  bytes 112399236 (107.1 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 85  bytes 12928 (12.6 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 85  bytes 12928 (12.6 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
vethb6b65f4: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet6 fe80::3c81:45ff:fecf:fa15  prefixlen 64  scopeid 0x20<link>
        ether 3e:81:45:cf:fa:15  txqueuelen 0  (Ethernet)
        RX packets 2775  bytes 185848 (181.4 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 4283  bytes 12042171 (11.4 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

yum install bridge-utils

brctl show
bridge name    bridge id            STP enabled    interfaces
docker0        8000.02422e7aea6b    no             vethb6b65f4
```

可以清楚的看到 Veth Pair 的一端 vethb6b65f4 就插在 docker0 上。

现在执行 docker run 启动两个容器，就会发现 docker0 上插入两个容器的 Veth Pair 的另一端。

shell 3

```shell script
docker run -it centos:7 /bin/bash

yum install net-tools

ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.3  netmask 255.255.0.0  broadcast 172.17.255.255
        ether 02:42:ac:11:00:03  txqueuelen 0  (Ethernet)
        RX packets 6665  bytes 12199102 (11.6 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 2957  bytes 212198 (207.2 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

ping 172.17.0.2 -c 3
PING 172.17.0.2 (172.17.0.2) 56(84) bytes of data.
64 bytes from 172.17.0.2: icmp_seq=1 ttl=64 time=0.051 ms
64 bytes from 172.17.0.2: icmp_seq=2 ttl=64 time=0.064 ms
64 bytes from 172.17.0.2: icmp_seq=3 ttl=64 time=0.073 ms
--- 172.17.0.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2041ms
rtt min/avg/max/mdev = 0.051/0.062/0.073/0.012 ms
```

shell 2

```shell script
ifconfig
docker0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.1  netmask 255.255.0.0  broadcast 172.17.255.255
        inet6 fe80::42:2eff:fe7a:ea6b  prefixlen 64  scopeid 0x20<link>
        ether 02:42:2e:7a:ea:6b  txqueuelen 0  (Ethernet)
        RX packets 6502  bytes 356084 (347.7 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 11875  bytes 36057013 (34.3 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.26.196.109  netmask 255.255.240.0  broadcast 172.26.207.255
        inet6 fe80::216:3eff:fe00:88c  prefixlen 64  scopeid 0x20<link>
        ether 00:16:3e:00:08:8c  txqueuelen 1000  (Ethernet)
        RX packets 636119  bytes 481969086 (459.6 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 315142  bytes 112711077 (107.4 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 85  bytes 12928 (12.6 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 85  bytes 12928 (12.6 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
vetha567eb1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet6 fe80::249f:7aff:fe2f:8715  prefixlen 64  scopeid 0x20<link>
        ether 26:9f:7a:2f:87:15  txqueuelen 0  (Ethernet)
        RX packets 2960  bytes 212365 (207.3 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 6669  bytes 12199393 (11.6 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
vethb6b65f4: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet6 fe80::3c81:45ff:fecf:fa15  prefixlen 64  scopeid 0x20<link>
        ether 3e:81:45:cf:fa:15  txqueuelen 0  (Ethernet)
        RX packets 2775  bytes 185848 (181.4 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 4286  bytes 12042353 (11.4 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

bridge name    bridge id            STP enabled    interfaces
docker0        8000.02422e7aea6b    no             vetha567eb1
                                                   vethb6b65f4
```

## Host

主机模式。

容器与宿主机共用一个 Network namespace，也是说跟宿主机共用网络栈，表现为容器内和宿主机的 IP 一致。
需要注意容器中服务的端口号不能与 host 上已经使用的端口号冲突。

用于网络性能较高的场景，但安全隔离性相对差一些。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201107222351.png)

## joined container

该网络模式是 Docker 中一种较为特别的网络的模式。

处于这个模式下的 Docker 容器会共享其他容器的 Network namespace，因此，在该 Network namespace 下的容器不存网络隔离。

这种模式是 Docker 模式的一种延伸，一组容器共享一个 Network namespace。

对外表现为他们有共同的 IP 地址，共享一个网络栈。

Kubernetes 的 Pod 就是使用的这一模式。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201107223234.png)

## overlay

overlay 网络将多个 Docker 守护程序连接在一起，并使群集服务能够相互通信。

可以使用 overlay 网络来促进群集服务和独立容器之间或不同 Docker 守护程序上的两个独立容器之间的通信。
这种策略消除了在这些容器之间进行操作系统级路由的需要。

## macvlan

macvlan 网络允许将 MAC 地址分配给容器，使其在网络上显示为物理设备。

Docker 守护程序通过其 MAC 地址将流量路由到容器。
在处理希望直接连接到物理网络而不是通过 Docker 主机的网络堆栈进行路由的传统应用程序时，使用 macvlan 驱动程序有时是最佳选择。

## None

不为容器创造任何的网络环境，容器内部就只能使用 loopback`网络设备，不会再有其他的网络资源。

## 容器互联

查看 docker 的网络

```shell script
docker network ls
NETWORK ID          NAME                DRIVER              SCOPE
27ef241af0da        bridge              bridge              local
2b0bfe5bf708        host                host                local
ea93ada1070f        none                null                local
```

创建一个新的网络，`-d` 是指定网络类型。

```shell script
docker network create -d bridge my-net
cef1546fa081db48994e5557ec58c2aca80ca351aa29321bc0f62cb65ce868ee

docker network ls
NETWORK ID          NAME                DRIVER              SCOPE
27ef241af0da        bridge              bridge              local
2b0bfe5bf708        host                host                local
cef1546fa081        my-net              bridge              local
ea93ada1070f        none                null                local
```

运行容器并连接到新建的 my-net 网络

shell 1

```shell script
docker run -it --rm --name busybox1 --network my-net busybox sh
```

shell 2

```shell script
docker run -it --rm --name busybox2 --network my-net busybox sh
```

shell 3

```shell script
docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                  NAMES
a8df5a20ca8c        busybox             "sh"                     52 seconds ago      Up 51 seconds                              busybox2
ef78cd41a5d2        busybox             "sh"                     2 minutes ago       Up 2 minutes                               busybox1

docker network inspect my-net
[
    {
        "Name": "my-net",
        "Id": "cef1546fa081db48994e5557ec58c2aca80ca351aa29321bc0f62cb65ce868ee",
        "Created": "2020-11-10T15:59:20.594267397+08:00",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": {},
            "Config": [
                {
                    "Subnet": "172.18.0.0/16",
                    "Gateway": "172.18.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {
            "a8df5a20ca8ce0ddb230302abf16df9a1cfee936380bd837c27293ceafa25e2a": {
                "Name": "busybox2",
                "EndpointID": "1e4aecb9c9337b01994554318a74284a8e9ac5b8d6685508f29fec9e21c3c9c3",
                "MacAddress": "02:42:ac:12:00:03",
                "IPv4Address": "172.18.0.3/16",
                "IPv6Address": ""
            },
            "ef78cd41a5d247940773d7ad62272e2e83f8ac0b9a1a57d17beb4db006420466": {
                "Name": "busybox1",
                "EndpointID": "5d8efaf80ca41e59ebc54d57e793451379218e59fc15febc1a403b5d1d1a3b68",
                "MacAddress": "02:42:ac:12:00:02",
                "IPv4Address": "172.18.0.2/16",
                "IPv6Address": ""
            }
        },
        "Options": {},
        "Labels": {}
    }
]
```

shell 1

```shell script
ping busybox2 -c 3
PING busybox2 (172.18.0.3): 56 data bytes
64 bytes from 172.18.0.3: seq=0 ttl=64 time=0.063 ms
64 bytes from 172.18.0.3: seq=1 ttl=64 time=0.098 ms
64 bytes from 172.18.0.3: seq=2 ttl=64 time=0.072 ms
--- busybox2 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.063/0.077/0.098 ms
```

shell 2

```shell script
ping busybox1 -c 3
PING busybox1 (172.18.0.2): 56 data bytes
64 bytes from 172.18.0.2: seq=0 ttl=64 time=0.061 ms
64 bytes from 172.18.0.2: seq=1 ttl=64 time=0.083 ms
64 bytes from 172.18.0.2: seq=2 ttl=64 time=0.093 ms
--- busybox1 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.061/0.079/0.093 ms
```

