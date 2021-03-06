![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20201109105703.png)

传统虚拟机技术是虚拟出一套硬件后，在其上运行一个完整操作系统，在该系统上再运行所需应用进程。
容器内的应用进程直接运行于宿主的内核，容器内没有自己的内核，而且也没有进行硬件虚拟。因此容器要比传统虚拟机更为轻便。

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20201109105816.png)

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20201109105858.png)

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20201109224933.png)

## 为什么要用 Docker

##### 更高效的利用系统资源

由于容器不需要进行硬件虚拟以及运行完整操作系统等额外开销，Docker 对系统资源的利用率更高。
无论是应用执行速度、内存损耗或者文件存储速度，都要比传统虚拟机技术更高效。

相比虚拟机技术，一个相同配置的主机，往往可以运行更多数量的应用。

##### 更快速的启动时间

传统的虚拟机技术启动应用服务往往需要数分钟。
Docker 容器应用，由于直接运行于宿主内核，无需启动完整的操作系统。

Docker 可以做到秒级、甚至毫秒级的启动时间。大大的节约了开发、测试、部署的时间。

##### 一致的运行环境

开发过程中一个常见的问题是环境一致性问题。
由于开发环境、测试环境、生产环境不一致，导致有些 bug 并未在开发过程中被发现。

Docker 的镜像提供了除内核外完整的运行时环境，确保了应用运行环境一致性，从而不会再出现"这段代码在我机器上没问题啊"这类问题。

##### 持续交付和部署

对开发和运维(DevOps)人员来说，最希望的就是一次创建或配置，可以在任意地方正常运行。
使用 Docker 可以通过定制应用镜像来实现持续集成、持续交付、部署。开发人员可以通过 Dockerfile 来进行镜像构建，并结合持续集成(Continuous Integration)系统进行集成测试。
运维人员则可以直接在生产环境中快速部署该镜像，甚至结合持续部署(Continuous Delivery/Deployment)系统进行自动部署。

使用 Dockerfile 使镜像构建透明化，不仅仅开发团队可以理解应用运行环境，也方便运维团队理解应用运行所需条件，帮助更好的生产环境中部署该镜像。

##### 更轻松的迁移

由于 Docker 确保了执行环境的一致性，使得应用的迁移更加容易。
Docker 可以在很多平台上运行，无论是物理机、虚拟机、公有云、私有云，甚至是笔记本，其运行结果是一致的。

用户可以很轻易的将在一个平台上运行的应用，迁移到另一个平台上，而不用担心运行环境的变化导致应用无法正常运行的情况。

##### 更轻松的维护和扩展

Docker 使用的分层存储以及镜像的技术，使得应用重复部分的复用更为容易，也使得应用的维护更新更加简单，基于基础镜像进一步扩展镜像也变得非常简单。

此外，Docker 团队同各个开源项目团队一起维护了一大批高质量的 官方镜像，既可以直接在生产环境使用，又可以作为基础进一步定制，大大的降低了应用服务的镜像制作成本。

## Docker 镜像 镜像仓库 & 容器

##### 镜像

Docker 镜像是一个特殊的文件系统，除了提供容器运行时所需的程序、库、资源、配置等文件外，还包含了一些为运行时准备的一些配置参数(匿名卷、环境变量、用户等)。

镜像不包含任何动态数据，其内容在构建之后也不会被改变。

##### 镜像仓库

镜像构建或者拉去完成后，可以很容易的在当前宿主机上运行。
但是，如果需要在其它服务器上使用这个镜像，就需要一个集中的存储、分发镜像的服务，镜像仓库(Docker Registry)就是这样的服务。

##### 容器

镜像(Image)和容器(Container)的关系，就像是面向对象程序设计中的类和实例一样，镜像是静态的定义，容器是镜像运行时的实体。

容器可以被创建、启动、停止、删除、暂停等。

容器的实质是进程，但与直接在宿主执行的进程不同，容器进程运行于属于自己的独立的命名空间。
因此容器可以拥有自己的 root 文件系统、网络配置、进程空间，甚至用户 ID 空间。

容器内的进程是运行在一个隔离的环境里，使用起来，就好像是在一个独立于宿主的系统下操作一样。这种特性使得容器封装的应用比直接在宿主运行更加安全。

