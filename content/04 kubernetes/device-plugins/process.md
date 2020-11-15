## 申请

```
apiVersion: v1
kind: Pod
metadata:
  name: demo-pod
spec:
  containers:
    - name: demo-container-1
      image: k8s.gcr.io/pause:2.0
      resources:
        limits:
          vendor-domain/resource: 2
```

## 实现

1. 初始化
2. 启动 gRPC 服务，在主机路径 `/var/lib/kubelet/device-plugins/` 下使用 Unix socket，实现接口。

```go
service DevicePlugin {
    // ListAndWatch returns a stream of List of Devices
    // Whenever a Device state change or a Device disappears, ListAndWatch
    // returns the new list
    rpc ListAndWatch(Empty) returns (stream ListAndWatchResponse) {}
    // Allocate is called during container creation so that the Device
    // Plugin can run device specific operations and instruct Kubelet
    // of the steps to make the Device available in the container
    rpc Allocate(AllocateRequest) returns (AllocateResponse) {}
}
```

3. 通过 Unix socket 向 kubelet 注册。

```go
service Registration {
	rpc Register(RegisterRequest) returns (Empty) {}
}
```

```go
message RegisterRequest {
    string version = 1 // 版本信息
    string endpoint = 2 // 插件的 endpoint
    string resource_name = 3 // 资源名称
    DevicePluginOptions options = 4 // 插件选项
}
// 插件选项
message DevicePluginOptions {
    bool pre_start_required = 1 // 启动容器前是否调用DevicePlugin.PreStartContainer()
}
```

4. device plugins 会持续运行并监视设备健康状态。
5. 通过 `Allocate` 处理 gRPC 请求。`Allocate` 阶段中可以对设备进行初始化等特殊操作。
6. 操作成功后，会通过 `AllocateResponse` 返回容器需要的设备信息。
7. kubelet 将此信息传递给容器运行时。

device plugins 将设备数量上报给 kubelet，kubelet 将设备数量上报给 API server。

- 扩展资源只支持整数资源，不能过度提交。
- 设备不能在容器之间共享。

## 参考资料

- https://blog.csdn.net/weixin_42663840/article/details/81231013
- https://github.com/kubernetes/community/blob/master/contributors/design-proposals/resource-management/device-plugin.md

