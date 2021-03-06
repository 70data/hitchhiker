## Borg

Google Stack

![images](http://70data.net/upload/kubernetes/c7ed0043465bccff2efc1a1257e970bd.png)

Borg 主要由 BorgMaster、Borglet、borgcfg 和 Scheduler 组成。

![images](http://70data.net/upload/kubernetes/assets_-LDAOok5ngY4pc1lEDes_-LpOIkR-zouVcB8QsFj__-LpOIpVMFQyXyJo5lim-_borg.png)

## Kubernetes

![images](http://70data.net/upload/kubernetes/8ee9f2fa987eccb490cfaa91c6484f67.png)

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20201114142804.svg)

- etcd 保存了整个集群的状态。
- kube-apiserver 提供了资源操作的唯一入口，并提供认证、授权、访问控制、API 注册和发现等机制。
- kube-controller-manager 负责维护集群的状态，比如故障检测、自动扩展、滚动更新等。
- kube-scheduler 负责资源的调度，按照预定的调度策略将 Pod 调度到相应的机器上。
- kubelet 负责维持容器的生命周期，同时也负责 Volume（CVI）和网络（CNI）的管理。
- Container runtime 负责镜像管理以及 Pod 和容器的真正运行（CRI），默认的容器运行时为 Docker。
- kube-proxy 负责为 Service 提供 cluster 内部的服务发现和负载均衡。

##### 核心功能

![images](http://70data.net/upload/kubernetes/16c095d6efb8d8c226ad9b098689f306.png)

![images](http://70data.net/upload/kubernetes/222392-cfb2274a7fea6df0.png)

### 基础设施的抽象

容器运行时接口（CRI）、容器网络接口（CNI）、容器存储接口（CSI）。
这些接口让 Kubernetes 变得无比开放，而其本身则可以专注于内部部署及容器调度。

### API 的抽象

功能操作绑定资源对象，对象都可以通过 API 被提交到集群的 etcd 中。
API 的定义和实现都符合 HTTP REST 的格式，用户可以通过标准的 HTTP 动词（POST、PUT、GET、DELETE）来完成对相关资源对象的增删改查。

声明式设计及控制闭环。

解析流程：
1. 匹配 API 对象的组
2. 匹配 API 对象的版本号
3. 匹配 API 对象的资源类型

![images](http://70data.net/upload/kubernetes/assetsF-LDAOok5ngY4pc1lEDesF-La8Wy3SQAP-8onLZ7uTF-La8X6ljrf3pM1bbtQ_0Fcore-packages.png)

