## 虚拟化

为了避免资源浪费，诞生了虚拟机的技术。

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20200920152700.jpg)

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

## IaaS、PaaS

IaaS：Infrastructure as a Service
PaaS：Platform as a service

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20200920161826.png)

IaaS 解决的是软件的基础运行环境。

PaaS 解决的是软件的打包和分发。

## 容器

### Docker

Docker 镜像解决了软件的打包，Docker 镜像仓库又解决了软件的分发。

Docker 镜像的本质是一个压缩包。
包含了操作系统、软件运行时、可执行文件+脚本。

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20200920163700.jpg)

### Docker, Inc.

Docker 的本质还是工具，并不能解决用户的问题。
Docker 公司在 2014 年发布 Swarm，解决了编排的问题。

### Google

2014 年 6 月，Google 宣布凯源了一个叫 Kubernetes 的项目。
Kubernetes 项目融合了来自于 Borg 和 Omega 系统的内部特性。

### CoreOS

CoreOS 是一个基础设施领域创业公司，主要是定制化的操作系统，用户可以按照分布式集群的方式，管理所有安装了这个操作系统的节点。

Docker 项目发布后，CoreOS 公司积极参与贡献，并共建 Docker 生态。

2014 年底，CoreOS 公司以强烈的措辞宣布与 Docker 公司停止合作，并直接推出了自己研制的 Rocket（rkt）容器。这个容器引擎已在去年宣布不在维护了。

### Mesosphere

老牌集群管理项目 Mesos 和它背后的创业公司 Mesosphere。

Mesos 有自己的容器运行时，也支持 Docker 和 rkt。

早在几年前，Mesos 就已经通过了万台节点的验证。
2014 年之后又被广泛使用在 Twitter、eBay 等大型互联网公司的生产环境中。

Mesos 社区孵化了 Marathon，实现了超强的集群管理、应用编排等功能。

Mesos+Marathon 在当时是完全超过 Docker+Kubernetes 的存在。

### RedHat

RedHat 也是 Docker 项目早期的重要贡献者。

RedHat 当时主打 OpenShift，但发展并不是很好。

### OCI & CNCF

2015 年 6 月 22 日，由 Docker 公司牵头，CoreOS、Google、RedHat 等公司共同宣布，Docker 公司将 Libcontainer 捐出，并改名为 RunC 项目，交由一个完全中立的基金会管理，然后以 RunC 为依据，大家共同制定一套容器和镜像的标准和规范。
这套标准和规范，就是 OCI（ Open Container Initiative ）。

- 改善 Docker 公司在容器技术上一家独大的现状。
- 为其他玩家不依赖于 Docker 项目构建各自的平台层能力提供了可能。

2015 年，Google、RedHat 等开源基础设施领域玩家们，共同牵头发起了一个名为 CNCF（Cloud Native Computing Foundation）的基金会。

初衷：以 Kubernetes 项目为基础，建立一个由开源基础设施领域厂商主导的、按照独立基金会方式运营的平台级社区，来对抗以 Docker 公司为核心的容器商业生态。

三足鼎立：Docker 公司、Kubernetes 项目、Mesos 社区

### 尘埃落定

2016 年，Docker 公司宣布放弃 Swarm 项目，将容器编排和集群管理功能全部内置到 Docker 项目中。

2017 年，Docker 公司将 Docker 项目的容器运行时部分 Containerd 捐赠给 CNCF 社区，此时 Docker 项目已经全面升级成为一个 PaaS 平台。
同年，Docker 公司宣布将 Docker 项目改名为 Moby，然后交给社区自行维护，而 Docker 公司的商业产品将占有 Docker 这个注册商标。

2017 年 10 月，Docker 公司宣布，将 Docker 企业版中内置 Kubernetes 项目。编排之争至此结束。

2018 年 1 月 30 日，RedHat 宣布斥资 2.5 亿美元收购 CoreOS。

2018 年 3 月 28 日，Docker 公司的 CTO Solomon Hykes 宣布辞职。

2019 年 11 月 13 日，Mirantis 宣布已经收购了 Docker 的企业业务和团队。
Mirantis 最初是以 OpenStack 为主的云计算创业公司。2015 年的时候获得了由 Intel 领投的 1 亿美元投资。

## 虚拟机 & 容器发展历程

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20200920122709.png)

