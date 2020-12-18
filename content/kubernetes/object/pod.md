## 概念

Pod 是一组紧密关联的容器集合，它们共享 IPC、Network 和 UTS namespace，是 Kubernetes 调度的基本单位。
Pod 的设计理念是支持多个容器在一个 Pod 中共享网络和文件系统，可以通过进程间通信和文件共享这种简单高效的方式组合完成服务。

## Docker 支持

### Dockerfile 指令

| Dockerfile 指令 | 描述                    | 支持 | 说明                                          |
| --------------- | ---------------------- | ---- | -------------------------------------------- |
| USER            | 进程运行用户以及用户组     | 是   | securityContext.runAsUser/supplementalGroups |
| WORKDIR         | 工作目录                | 是    | containerSpec.workingDir                     |
| ENV             | 环境变量                | 是    | containerSpec.env                            |
| VOLUME          | 数据卷                  | 是   | 使用 volumes 和 volumeMounts                   |
| ENTRYPOINT      | 启动命令                | 是    | containerSpec.command                        |
| CMD             | 命令的参数列表           | 是    | containerSpec.args                           |
| SHELL           | 运行启动命令的 SHELL     | 否    | 使用镜像默认 SHELL 启动命令                      |
| STOPSIGNAL      | 停止容器时给进程发送的信号 | 是    | SIGKILL                                      |
| EXPOSE          | 对外开放的端口           | 否    | 使用 containerSpec.ports.containerPort 替代    |
| HEALTHCHECK     | 健康检查                | 否    | 使用 livenessProbe 和 readinessProbe 替代      |

## 镜像

在使用私有镜像时，需要创建一个 docker registry secret，并在容器中引用。

```shell script
kubectl create secret docker-registry regsecret --docker-server=<registry-server> --docker-username=<name> --docker-password=<pword> --docker-email=<email>
```

在引用 docker registry secret 时，有两种可选的方法.

一种是直接在 Pod 的 yaml 描述文件中引用该 secret。

一种是把 secret 添加到 service account 中，再通过 service account 引用。
引用 service account 需要指定 namespace。

### ImagePullPolicy

- Always 不管本地镜像是否存在都会去仓库进行一次镜像拉取。校验如果镜像有变化则会覆盖本地镜像，否则不会覆盖。
- Never 只是用本地镜像，不会去仓库拉取镜像，如果本地镜像不存在则 Pod 运行失败。
- IfNotPresent 只有本地镜像不存在时，才会去仓库拉取镜像。ImagePullPolicy 的默认值。

如果镜像标签为 :latest，即使默认是 IfNotPresent，也会 Always 拉取。
拉取镜像时 Docker 会进行校验，如果镜像中的 MD5 码没有变，则不会拉取镜像数据。

## Pod 生命周期

- Pending。API Server 已经创建该 Pod，但一个或多个容器还没有被创建，调度器没有进行介入。
- Waiting。镜像没有正常拉取，包括通过网络下载镜像的过程。
- Running。Pod 中的所有容器都已经被创建且已经调度到 Node 上面，但至少有一个容器还在运行或者正在启动。
- Succeeded。Pod 调度到 Node 上面后均成功运行结束，并且不会重启。
- Failed。Pod 中的所有容器都被终止了，但至少有一个容器退出失败（即退出码不为 0 或者被系统终止）。
- Crashing。Pod 不断被拉起，而且可以看到类似像 backoff。
- Unknonwn。状态未知，因为一些原因 Pod 无法被正常获取，通常是由于 kubelet 无法与 kube-apiserver 通信导致。

### RestartPolicy

- Always 当容器失效时，由 kubelet 自动重启该容器。RestartPolicy 的默认值。
- OnFailure 当容器终止运行且退出码不为 0 时由 kubelet 重启。
- Never 无论何种情况下，kubelet 都不会重启该容器。

### 健康检查

- LivenessProbe 探针，用于判断容器是否健康。
- ReadinessProbe 探针，用于判断容器是否启动完成且准备接收请求。

##### LivenessProbe

探测应用是否处于健康状态，如果不健康则删除并重新创建容器。
LivenessProbe 能让 Kubernetes 知道应用是否存活。
如果应用是存活的，Kubernetes 不做任何处理。
如果 LivenessProbe 探测到容器不健康，则 kubelet 将删除该容器，并根据容器的重启策略做相应的处理。
如果一个容器不包含 LivenessProbe，那么 kubelet 认为该容器的 LivenessProbe 返回的值永远是 "Success"。

##### ReadinessProbe

探测应用是否启动完成并且处于正常服务状态，如果不正常则不会接收来自 Service 的流量。
设计 ReadinessProbe 的目的是用来让 Kubernetes 知道应用何时能对外提供服务。
在服务发送流量到 Pod 之前，Kubernetes 必须确保 ReadinessProbe 检测成功。
如果 ReadinessProbe 检测失败了，Kubernetes 会停掉 Pod 的流量，直到 ReadinessProbe 检测成功。如果 ReadinessProbe 探测到失败，Endpoint Controller 将从 Service 的 Endpoint 中删除包含该容器所在 Pod 的 IP 地址的 Endpoint。

Kubernetes 支持三种方式来执行探针

- exec 在容器中执行一个命令，如果命令退出码返回 0 则表示探测成功，否则表示失败。
- tcpSocket 对指定的容器 IP 及端口执行一个 TCP 检查，如果端口是开放的则表示探测成功，否则表示失败。
- httpGet 对指定的容器 IP、端口及路径执行一个 HTTP Get 请求，如果返回的状态码在 [200,400) 之间则表示探测成功，否则表示失败。

### Init Container

Init 容器在所有容器运行之前执行（run-to-completion），常用来初始化配置。
如果为一个 Pod 指定了多个 Init 容器，那些容器会按顺序一次运行一个。每个 Init 容器必须运行成功，下一个才能够运行。当所有的 Init 容器运行完成时，Kubernetes 初始化 Pod 并像平常一样运行应用容器。

Init 容器的资源计算，选择一下两者的较大值：

- 所有 Init 容器中的资源使用的最大值
- Pod 中所有容器资源使用的总和

Init 容器的重启策略：

- 如果 Init 容器执行失败，Pod 设置的 restartPolicy 为 Never，则 Pod 将处于 fail 状态。否则 Pod 将一直重新执行每一个 Init 容器直到所有的 Init 容器都成功。
- 如果 Pod 异常退出，重新拉取 Pod 后，Init 容器也会被重新执行。

### 容器生命周期钩子

容器生命周期钩子（Container Lifecycle Hooks）监听容器生命周期的特定事件，并在事件发生时执行已注册的回调函数。

- postStart 容器创建后立即执行，注意由于是异步执行，它无法保证一定在 ENTRYPOINT 之前运行。如果失败，容器会被杀死，并根据 RestartPolicy 决定是否重启。
- preStop 容器终止前执行。如果失败，容器同样也会被杀死。

## 启动流程

### 为 Pod 创建新的沙箱

##### pause

创建 Pod 时 kubelet 先调用 CRI 接口 RuntimeService.RunPodSandbox 来创建一个沙箱（Pod Sandbox），为 Pod 设置基础运行环境。
当 Pod Sandbox 建立起来后，kubelet 就可以在里面创建用户容器。
删除 Pod 时，kubelet 会先移除 Pod Sandbox 然后再停止用户容器。

在 Linux CRI 体系里，Pod Sandbox 其实就是 pause 容器。

- 在 Pod 中它作为共享 Linux Namespace 的基础。
- 启用 PID Namespace 共享，它为每个 Pod 提供 1 号进程，并收集 Pod 内的僵尸进程。

##### Namespace 挂载

使用主机的 IPC 命名空间 `spec.hostIPC: true`，默认为 false。

使用主机的网络命名空间 `spec.hostNetwork: true`，默认为 false。同一个 Pod 中的多个容器会被共同分配到同一个 Host 上并且共享网络栈。

使用主机的 PID 命名空间 `spec.hostPID: true`，默认为 false。

### 创建 Pod 规格中指定的初始化容器

### 依次创建 Pod 规格中指定的常规容器

### 通过镜像拉取器获得当前容器中使用镜像的引用

### 调用远程的 runtimeService 创建容器

### 调用内部的生命周期方法 PreStartContainer 为当前的容器设置分配的 CPU 等资源

### 调用远程的 runtimeService 开始运行镜像

### Volume

```go
func (kl *kubelet) syncPod(o syncPodOptions) error {
    if !kl.podIsTerminated(pod) {
        kl.volumeManager.WaitForAttachAndMount(pod)
    }
    pullSecrets := kl.getPullSecretsForPod(pod)
    result := kl.containerRuntime.SyncPod(pod, apiPodStatus, podStatus, pullSecrets, kl.backOff)
    kl.reasonCache.Update(pod.UID, result)
    return nil
}
```

### 网络

```go
func (ds *dockerService) RunPodSandbox(ctx context.Context, r *runtimeapi.RunPodSandboxRequest) (*runtimeapi.RunPodSandboxResponse, error) {
    config := r.GetConfig()
    // Step 1: Pull the image for the sandbox.
    image := defaultSandboxImage
    // Step 2: Create the sandbox container.
    createConfig, _ := ds.makeSandboxDockerConfig(config, image)
    createResp, _ := ds.client.CreateContainer(*createConfig)
    resp := &runtimeapi.RunPodSandboxResponse{PodSandboxId: createResp.ID}
    ds.setNetworkReady(createResp.ID, false)
    // Step 3: Create Sandbox Checkpoint.
    ds.checkpointManager.CreateCheckpoint(createResp.ID, constructPodSandboxCheckpoint(config))
    // Step 4: Start the sandbox container.
    ds.client.StartContainer(createResp.ID)
    // Step 5: Setup networking for the sandbox.
    cID := kubecontainer.BuildContainerID(runtimeName, createResp.ID)
    networkOptions := make(map[string]string)
    ds.network.SetUpPod(config.GetMetadata().Namespace, config.GetMetadata().Name, cID, config.Annotations, networkOptions)
    return resp, nil
}
```

### PostStart

如果当前的容器包含 PostStart，钩子就会执行该回调

## 优先级

## hostAliases

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostaliases-pod
spec:
  restartPolicy: Never
  hostAliases:
  - ip: "127.0.0.1"
    hostnames:
    - "foo.local"
    - "bar.local"
  - ip: "10.1.2.3"
    hostnames:
    - "foo.remote"
    - "bar.remote"
  containers:
  - name: cat-hosts
    image: busybox
    command:
    - cat
    args:
    - "/etc/hosts"
```

