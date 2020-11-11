CRI 描述了，对于 kubernetes 来说，一个 container 应该有哪些操作，每个操作有哪些参数。

![images](http://70data.net/upload/kubernetes/640-4.png)

## runc

![images](http://70data.net/upload/kubernetes/runc.png)

## containerd

containerd 曾经是 Docker 项目的一部分，现在它是一个独立的软件，自称为容器运行时。

runc 只是一个命令行工具，containerd 是一个长活的守护进程。

![images](http://70data.net/upload/kubernetes/containerd.png)

![images](http://70data.net/upload/kubernetes/952033-20180520115610144-588472749.png)

## cri-o

cri-o 是 RedHat 实现的兼容 CRI 的运行时，与 containerd 一样，它也是一个守护进程，通过开放一个 gRPC 服务接口来创建、启动、停止容器以及其他操作。

在底层，cri-o 可以使用任何符合 OCI 标准的低阶运行时和容器工作，默认的运行时仍然是 runc。

cri-o 的主要目标是作为 Kubernetes 的容器运行时，版本控制也与 K8s 一致。

Kubernetes 可以同时使用 containerd 和 cri-o 作为运行时。

![images](http://70data.net/upload/kubernetes/cri-o.png)

## docker-shim

运行容器的真实载体，每启动一个容器都会起一个新的 docker-shim，运行时调用 runc 的 API 创建一个容器。

## dockerd

对容器相关操作的 API 的最上层封装，直接面向操作用户。

![images](http://70data.net/upload/kubernetes/dockerd.png)

## podman

提供名为 libpod 的库来管理镜像、容器生命周期和 Pod，并不是守护进程。
podman 是一个构建在这个库之上的命令行管理工具。作为一个低阶的容器运行时，这个项目也使用runc。

守护进程作为容器管理器的问题是，它们大多数时候必须使用 root 权限运行。
尽管由于守护进程的整体性，系统中没有 root 权限也可以完成其 90% 的功能，但是剩下的 10% 需要以 root 启动守护进程。
使用 podman，最终有可能使 Linux 用户的 Namespace 拥有无根（rootless）容器。

## 演进

![images](http://70data.net/upload/kubernetes/Q4tbDwOGMVGxHg.webp)

第一阶段。
在 Kubernetes v1.5 之前，kubelet 内置了 Docker 和 rkt 的支持，并且通过 CNI 网络插件给它们配置容器网络。
用户如果需要自定义运行时的功能是比较痛苦的，需要修改 kubelet 的代码，维护和升级都非常麻烦。

第二阶段。
从 v1.5 开始增加了 CRI 接口，通过容器运行时的抽象层消除了这些障碍，使得无需修改 kubelet 就可以支持运行多种容器运行时。
CRI 接口包括了一组 Protocol Buffer、gRPC API 、用于 streaming 接口的库以及用于调试和验证的一系列工具等。
内置的 Docker 实现也逐步迁移到了 CRI 的接口下。

第三阶段。
从 v1.11 开始，Kubelet 内置的 rkt 代码删除，CNI 的实现迁移到 docker-shim 之内。

![images](http://70data.net/upload/kubernetes/m1C3a8QvNTdibBHg.webp)

## CRI 接口

CRI 接口包括 RuntimeService 和 ImageService 两个服务。
这两个服务可以在一个 gRPC server 中实现，也可以分开成两个独立服务。

![images](http://70data.net/upload/kubernetes/TLsA6HibU3k6Mtew.webp)

