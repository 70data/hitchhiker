## 虚拟化的前身

1979 年，在 Unix v7 系统开发过程中，引入了一个称为 chroot 系统调用的新特性。
这个新系统调用的本质是允许将进程及其子进程的根目录更改为文件系统中的新位置。
这是文件系统级别进程隔离的开始，即为每个进程隔离文件访问。

1982 年，chroot 系统调用于在 Marshall Kirk Mckusick(马绍尔)博士的建议下，Bill Joy 正式将其添加到 BSD 中。
再次谈到 chroot 就是 18 年后。

1999 年，另一特性出现 FreeBSD jails。

2000 年的最后几个月，经生产环境应用后，Poul-Henning Kamp 正式将该功能引入到 FreeBSD 中，并首次在 FreeBSD 4.0 中发布，因此许多 FreeBSD 后代都支持该功能。
主机托管提供商创建 FreeBSD jails 的动机是，出于安全和易于管理的需要，对其不同客户的服务实现明确的分离。
FreeBSD jails 允许系统管理员将一个 FreeBSD 系统划分为几个独立的、较小的系统(jails)，并能够为每个系统分配单独的系统配置和 IP 地址。

2001 年，Jacques Gélinas 开始了一个新的项目，其目的是在计算机系统中实现一个监狱机制。
为计算机系统提供安全的分区资源，即 CPU、内存、网络地址、文件系统。
Linux VServer 就是此次项目的结果。可以通过为 Linux 内核打补丁的方式实现 Linux VServer 操作系统虚拟化机制。

2004 年 2 月，Sun Microsystems 发布了 Solaris 容器(包括 Solaris Zone)，作为 x86 系统的操作系统虚拟化技术实现。
每个 Solaris 容器自己的节点名，可以访问虚拟或物理网络接口，并为其分配存储空间。
Solaris 容器不需要专用的 CPU、内存、物理网络接口或主机总线适配器。

## 虚拟化

人们习惯于把一个大的服务器资源切分为小的分区使用，而不是研发能够充分发挥大型服务器整机计算能力的软件。

两个制约因素：
1. 待解决问题本身内在的并行度有限。
随着多核多处理器系统的日益普及，开始阶段针对特定行业应用的并行化改造效果非常明显，但是后来发现随着并行度提高改造成本越来越大、收益却越来越低。
受阿姆达尔定律制约，解决特定问题的并行度超过一定临界点之后收益将逐渐变小。
所以一味提高系统并行度并不是经济的做法。
2. 人类智力有限。
受人类智力限制，系统越复杂、并行度越高，软件越容易出故障，软件维护代价成指数级增长。
从软件工程看，也趋向于接口化、模块化、单元化的软件架构设计，尽量控制软件的复杂度，降低工程成本。

进程隔离。
OS 以进程作为 Task 运行过程的抽象，进程拥有独立的地址空间和执行上下文，本质上 OS 对进程进行了 CPU 和内存虚拟化。
进程之间还共享了文件系统、网络协议栈、IPC 通信空间等多种资源，进程之间因为资源争抢导致的干扰很严重。
这个层级的隔离适合在不同的主机上运行单个用户的不同程序，由用户通过系统管理手段来保证资源分配与安全防护等问题。

OS 虚拟化。
OS 隔离，也就是操作系统虚拟化(OS virtualization)，是进程隔离的加强版。
OS 隔离则是利用操作系统分身术为每一组进程实例构造出一个独立的 OS 环境，以进一步虚拟化文件系统、网络协议栈、IPC 通信空间、进程 ID、用户 ID 等 OS 资源。
OS 隔离需要解决三个核心问题：独立视图、访问控制、安全防护。
chroot、Linux namespace 机制为进程组实现独立视图，cgroup 对进程组进行访问控制，Capabilities、Apparmor、seccomp 等机制则实现安全防护。

硬件虚拟化。
硬件虚拟化技术的出现，让同一个物理服务器上能够同时运行多个操作系统，每个操作系统都认为自己在管理一台完整的服务器。
不同操作系统之间是严格隔离的，硬件虚拟化既有很好的安全性，也有很好的隔离性，缺点就是引入的硬件虚拟化层导致了额外的性能开销。

语言运行时隔离。
对于 Java、Node.js 等需要 language runtime 的 managed language。
可以在 language runtime 里实现隔离。

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20201102123127.png)

虚拟化：
- 半虚拟化
- 完全虚拟化

半虚拟化的代表是 Xen。
完全虚拟化的代表是 KVM、ESXI、Hyper-V。

Xen 是通过代码修改已有的系统，形成一种新的可虚拟化的系统，调用硬件资源去启动多个系统。

KVM 虚拟化全称为 Kernel-based Virtual Machine。
基于内核的虚拟机（KVM）是针对包含虚拟化扩展（Intel VT 或 AMD-V）的 x86 硬件上的 Linux 的完全原生的虚拟化解决方案。

Linux 中还有一种虚拟化技术 Qemu，和 KVM 互为补充，叫做 Qemu-kvm，它补充了 KVM 技术的不足，而且在性能上对 KVM 进行了优化。

libvirt 是一系列提供出来的库函数，用以其他技术调用，来管理机器上的虚拟机。
包括各种虚拟机技术，KVM、Xen 与 lxc 等，不同虚拟机技术就可以使用不同驱动，都可以调用 libvirt 提供的 API 对虚拟机进行管理。

Xen 是 Linux 的一个应用。
KVM 是 Linux 的内核模块。

KVM 必须 CPU 支持虚拟化，而 Xen 都可以。

## OpenVZ 的诞生

OpenVZ 是一种用于 Linux 的操作系统虚拟化技术，它使用一个经过打补丁的 Linux 内核来进行虚拟化、隔离、资源管理和检查。
这些代码并没有作为官方 Linux 内核的一部分发布，但是它的后代在我们的故事中扮演了至关重要的角色。

2000 年，他们已经将实验代码移植到 Linux 内核 2.4.0 test1。

2002 年 1 月发布了 Virtuozzo v2.0。
随着时间的推移，更多的功能被添加进来，比如实时迁移功能。

2005 年，他们才意识到使用自由开源软件模式将极大地提高项目的实用性。
OpenVZ 作为一个独立的实体诞生了，作为商业版 Virtuozzo 的补充(后来更名为 Parallels Cloud Server, 缩写为 PCS)。

2014 年，时任 Virtuozzo 高级软件工程师的 Kir Kolyshkin 在 LiveJournal 上发表了一篇博文。
"事实上，早在 1999 年我们的工程师开始将容器技术添加到 Linux 内核 2.2 中。嗯，当时还不叫容器，而称之为虚拟环境。这在新技术中经常发生，只是术语有所不同而已。"
术语容器(container)一词是在 2004 年由 Sun Microsystems 提出的。

## LXC 的诞生

2006 年，Google 启动了 Process Containers 项目。
该技术主要由 Paul Menage 和 Rohit Seth 领导，旨在限制、计算和隔离进程的资源使用，例如 CPU、内存、磁盘 I/O 和网络。

2007 年，Process Containers 被重新命名为 Control Groups(或 cgroups)，并最终合并到 Linux 内核 v2.6.24 中。

2008 年，cgroups 进入了 Linux 内核主线。

2008 年，LXC(Linux Containers)是第一个完整的 Linux 容器管理器实现。
LXC 通过使用 cgroups 和 Linux namespace 实现，为应用程序提供了一个独立的运行环境。
LXC 通过创建自己的进程和网络空间提供虚拟环境，而不是创建一个完全的虚拟机。
它在 Linux 内核工作，不需要任何额外的补丁。

Virtuozzo、IBM 和 Google 负责 LXC 的内核级工作，由 Eric Biederman 等人领导。
而 namespace 团队则由 Daniel Lezcano, Serge Hallyn，Stephane Graber等人领导。

早期版本的 Docker 使用 LXC 作为容器执行驱动程序(Docker Rngine)。
尽管 LXC 在 v0.9 中是可选的，官方支持最终在 Docker v1.10 的发布中被删除了。

## 容器的萌芽

2011 年，Cloud Foundry 启动了 Warden 项目。
Warden 可以作为守护进程运行，提供一套 API 来管理隔离的环境，这些隔离的环境可以被称为"容器"，他们可以在 CPU、内存、磁盘以及设备访问权限方面做相应的限制。
Warden 还包括一个管理 cgroups、namespace 和进程生命周期的服务。
Warden 可以在任何操作系统上隔离环境。作为客户端-服务器模型开发，用于跨多个主机管理容器集合。
Warden 在早期阶段使用 LXC，但后来用它自己的实现替换了 LXC。

2013 年，Let Me Contain That For You(LMCTFY)作为 Google 的开源项目，提供 Linux 应用程序容器。
LMCTFY 中，应用程序可以被容器感知，创建和管理自己的子容器。

2015 年，Google 开始将 LMCTFY 的核心概念贡献给 Libcontainer。
现在 Libcontainer 是 Open Container Foundation 的一部分。
Libcontainer 是一段与 Linux 内核交互的代码。

## Docker 的诞生

Docker 是一种 Linux 容器(LXC)技术，增加了高级 API，提供了一种轻量级的虚拟化解决方案，可以独立运行 Unix 进程。
Docker 最初是作为一个开源平台发布的，名称是 dotCloud。
2013 年 9 月和 Red Hat 达成战略合作伙伴。

2014 年 4 月 15 号 Docker 正式对外公布。

Docker 因为和 Red Hat 的良好关系，甚至得到了Google、AWS、微软等商业公司的更多支持，进一步增强了其在容器化领域的影响力。

Docker 使用了标准容器概念。
Docker 包含一个软件组件及其所有依赖项，二进制文件、库、配置文件、脚本、虚拟环境、jar、gem、tar包等等，并且可以在任何支持 cgroups 的 x64 位 Linux 内核上运行。

2014 年 6 月 Docker 宣布发布 1.0 版本时，该软件的下载量已达到惊人的 275 万次。

## Docker, Inc.

Docker 的本质还是工具，并不能解决用户的问题。
Docker 公司在 2014 年发布 Swarm，解决了编排的问题。

## CoreOS

CoreOS 是一个基础设施领域创业公司，主要是定制化的操作系统，用户可以按照分布式集群的方式，管理所有安装了这个操作系统的节点。

Docker 项目发布后，CoreOS 公司积极参与贡献，并共建 Docker 生态。

许多用户很快指出 Docker 缺乏安全性，因为它使用了一个中央 Docker 守护进程。
CoreOS 等公司以此为线索，提供了自己的具有竞争力的容器管理软件，以确保用户获得更可靠、更安全的平台。

2014 年底，CoreOS 公司以强烈的措辞宣布与 Docker 公司停止合作。

2014 年 12 月，CoreOS 发布了 rkt 容器。
作为 Docker 的替代品，提供了应用程序容器镜像的另一种标准格式、容器运行时，以及容器发现和检索协议。
CoreOS 的 rkt 容器的出现，使用户有了更多的选择，并促成了容器社区的良性循环。

这个容器引擎已在去年宣布不在维护了

## IaaS PaaS

IaaS：Infrastructure as a Service
PaaS：Platform as a service

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20200920161826.png)

IaaS 解决的是软件的基础运行环境。

PaaS 解决的是软件的打包和分发。

## Google

Google 在 2003 年左右引进了 Borg 系统。
一开始只是一个小规模的项目，只有 3-4 个人。
Borg 是一个大型内部集群管理系统，用于运行数十万个作业，来自数千个不同的应用程序，并且跨许多集群，每个集群最多有数万台机器。

随着 Borg 的引入，Google 也随之推出了 Omega 集群管理系统。
Omega 是一款灵活、可伸缩的调度器，可用于大型集群。

2014 年 6 月，Google 宣布凯源了一个叫 Kubernetes 的项目。
Kubernetes 项目融合了来自于 Borg 和 Omega 系统的内部特性。

2018 年初，GitHub 上的 Kubernetes 项目拥有超过 1500 名贡献者，是最重要的开源社区之一，拥有超过 27000 颗星星。

## Mesosphere

老牌集群管理项目 Mesos 和它背后的创业公司 Mesosphere。

Mesos 有自己的容器运行时，也支持 Docker 和 rkt。
早在几年前，Mesos 就已经通过了万台节点的验证。

2014 年，Mesos 被广泛使用在 Twitter、eBay 等大型互联网公司的生产环境中。

Mesos 社区孵化了 Marathon，实现了超强的集群管理、应用编排等功能。

Mesos+Marathon 在当时是完全超过 Docker+Kubernetes 的存在。

## RedHat

RedHat 也是 Docker 项目早期的重要贡献者。

RedHat 当时主打 OpenShift，但发展并不是很好。

## OCI & CNCF

2015 年 6 月 22 日，由 Docker 公司牵头，CoreOS、Google、RedHat 等公司共同宣布，Docker 公司将 Libcontainer 捐出，并改名为 RunC 项目，交由一个完全中立的基金会管理，然后以 RunC 为依据，大家共同制定一套容器和镜像的标准和规范。
这套标准和规范，就是 OCI（ Open Container Initiative ）。

- 改善 Docker 公司在容器技术上一家独大的现状。
- 为其他玩家不依赖于 Docker 项目构建各自的平台层能力提供了可能。

2015 年，Google、RedHat 等开源基础设施领域玩家们，共同牵头发起了一个名为 CNCF（Cloud Native Computing Foundation）的基金会。

初衷：以 Kubernetes 项目为基础，建立一个由开源基础设施领域厂商主导的、按照独立基金会方式运营的平台级社区，来对抗以 Docker 公司为核心的容器商业生态。

CNCF 成立后，VMWare、Azure、AWS 和 Docker 公司宣布了它们对 Kubernetes 的支持和兼容性，Kubernetes 可以运行在它们自己的基础设施上并与之集成。

随着环境和市场的持续成长，一些工具已经开始定义容器生态标准。Ceph 和 REX-Ray 定义了容器存储标准，Flannel 成为了容器网络的默认实现。

三足鼎立：Docker 公司、Kubernetes 项目、Mesos 社区

## 尘埃落定

2016 年，Docker 公司宣布放弃 Swarm 项目，将容器编排和集群管理功能全部内置到 Docker 项目中。

2017 年，Docker 公司将 Docker 项目的容器运行时部分 Containerd 捐赠给 CNCF 社区，此时 Docker 项目已经全面升级成为一个 PaaS 平台。
同年，Docker 公司宣布将 Docker 项目改名为 Moby，然后交给社区自行维护，而 Docker 公司的商业产品将占有 Docker 这个注册商标。

2017 年，容器生态开始模块化、规范化。
CNCF 接受 Containerd、rkt 项目，OCI 发布 1.0，CRI/CNI 得到广泛支持。

2017 年 10 月，Docker 公司宣布，将 Docker 企业版中内置 Kubernetes 项目。编排之争至此结束。

2017 年，Kata Containers 社区成立。

2018 年 1 月 30 日，RedHat 宣布斥资 2.5 亿美元收购 CoreOS。

2018 年 3 月 28 日，Docker 公司的 CTO Solomon Hykes 宣布辞职。

2018 年 5 月，Google 开源 gVisor 代码。

2018 年 11 月，AWS 开源 firecracker，阿里云发布安全沙箱 1.0。

2018 年底，VMware 宣布收购咨询公司 Heptio，后者帮助企业部署和管理 Kubernetes。

2018 年，容器服务商业化。
AWS ECS、Google EKS、Alibaba ACK/ASK/ECI、华为 CCI、Oracle Container Engine for Kubernetes。
VMware，Redhat 和 Rancher 开始提供基于 Kubernetes 的商业服务产品。

2019 年，容器生态系统发生了重大变化。
新的运行时引擎试图取代了原来的 Docker 运行时引擎 containerd。
最著名的开源容器运行时引擎是 CRI-O，一种针对 Kubernetes 的轻量级运行时引擎。

2019 年，VMware 收购了 Pivotal Software。

2019 年 11 月 13 日，Mirantis 宣布已经收购了 Docker 的企业业务和团队。
Mirantis 最初是以 OpenStack 为主的云计算创业公司。2015 年的时候获得了由 Intel 领投的 1 亿美元投资。

2019 年，各厂商推出的基于 Kubernetes 的混合云解决方案。
IBM Cloud Paks、Google Anthos、Aws Outposts和Azure Arc。
这些云平台模糊了传统云和 on-prem 环境之间的界限，使客户可以管理 on-prem 和云上的集群。

2020 年，最新的 State of Kubernetes 报告。
Kubernetes 的使用率从 2018 年的 27% 上升到 2019 年的 48%。
57% 的受访者表示运行的 Kubernetes 集群少于 10 个。
多达 60% 的受访者表示有一半的容器化工作负载运行在 Kubernetes 上。
95% 的受访者表示，采用 Kubernetes 系统可以带来明显的好处。
56% 的受访者将资源利用列为 Kubernetes 系统最大的好处。
53% 的受访者表示缩短软件开发周期是最大的好处。

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20201102123452.png)

## 虚拟机 & 容器发展历程回顾

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20200920122709.png)

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20201102122936.png)

## Docker 的意义

容器技术需要解决的核心问题之一运行时的环境隔离。
容器的运行时环境隔离，目标是给容器构造一个无差别的运行时环境，用以在任意时间、任意位置运行容器镜像。

容器隔离技术解决的是资源供给问题。
根据摩尔定律，它让我们有了越来越多的计算资源可以使用。

Docker 镜像解决了软件的打包。
容器镜像打包了整个容器运行依赖的环境，以避免依赖运行容器的服务器的操作系统，从而实现 "build once，run anywhere"。
容器镜像一但构建完成，就变成 read only，成为不可变基础设施的一份子。

Docker 镜像的本质是一个压缩包。
包含了操作系统、软件运行时、可执行文件+脚本。

Docker 镜像仓库又解决了软件的分发。

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20201102120418.png)

