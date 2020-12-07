- Kubernetes v1.0：Service 仅是一个 4 层代理，代理模块只有 userspace
- Kubernetes v1.1：Ingress API 出现，其代理 7 层服务，并且增加了 iptables 代理模块
- Kubernetes v1.2：iptables 成为默认代理模式
- Kubernetes v1.8：引入 IPVS 代理模块
- Kubernetes v1.9：IPVS 代理模块成为 beta 版本
- Kubernetes v1.11：IPVS 代理模式 GA

当创建一个 Service 时，Kubernetes 会创建一个相应的 DNS 条目。
该条目的形式是 `servicename.namespace.svc.cluster.local`。
如果容器只使用 servicename，它将被解析到本地 Namespaces 的 Service。
如果跨 Namespaces 访问，则需要使用完全限定域名(FQDN)。

Service 能够将一个接收 `port` 映射到任意的 `targetPort`。
默认情况下，`targetPort` 将被设置为与 `port` 字段相同的值。

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
```

`appProtocol` 字段提供了一种为每个 Service 端口指定应用程序协议的方式。

##### 为什么不使用 DNS 轮询？

配置具有多个 A 值的 DNS 记录，并依靠轮询名称解析？

- DNS 实现的历史由来已久，它不遵守记录 TTL，并且在名称查找结果到期后对其进行缓存。
- 有些应用程序仅执行一次 DNS 查找，并无限期地缓存结果。
- 即使应用和库进行了适当的重新解析，DNS 记录上的 TTL 值低或为零也可能会给 DNS 带来高负载，从而使管理变得困难。

### 使用自己的 IP 地址

在 Service 创建的请求中，可以通过设置 `spec.clusterIP` 字段来指定自己的 clusterIP 地址。

用户的 IP 地址必须合法，并且这个 IP 地址在 `service-cluster-ip-range` CIDR 范围。

如果 IP 地址不合法，API server 会返回 HTTP 状态码 422，表示值不合法。

### 服务发现

##### 环境变量

当 Pod 运行在 Node 上，kubelet 会为每个 active Service 添加一组环境变量。

它支持 Docker links compatible 变量以及简单的 `{SVCNAME}_SERVICE_HOST` 和 `{SVCNAME}_SERVICE_PORT` 变量，Service 的名字需要大写，并且破折号转换为下划线。

当具有需要访问服务的 Pod 时，并且正在使用环境变量方法将 port 和 clusterIP 发布到客户端 Pod 时，必须在客户端 Pod 创建之前创建 Service，否则，这些客户端 Pod 将不会填充其环境变量。
如果仅使用 DNS 查找 Service 的 clusterIP，则无需担心此问题。

##### DNS

像 CoreDNS 这种支持 cluster-aware 的 DNS 服务器，会 watch Kubernetes API 中的新 Service，并为每个 Service 创建一组 DNS 记录。

如果在整个群集中都启用了 DNS，则所有 Pod 都应该能够通过其 DNS name 自动解析服务。

如果在 Kubernetes 命名空间 `my-ns` 中有一个名为 `my-service` 的 Service，则控制平面和 DNS 服务共同作用会为 `my-service.my-ns` 创建 DNS 记录。
通过简单地对 `my-service` 进行名称查找，`my-ns` 命名空间中的 `Pod` 应该能够找到它，`my-service.my-ns` 也可以。
其他命名空间中的 Pod 必须将名称限定为 `my-service.my-ns`。
这些将解析为 Service 分配的 clusterIP。

Kubernetes 还支持命名端口的 DNS SRV 记录。
SRV 记录是为普通 Service 或 Headless Service 的命名端口创建的。
对于每个命名端口，SRV 记录的形式为 `_my-port-name._my-port-protocol.my-svc.my-namespace.svc.cluster-domain.example`。

对于常规 Service，这将解析为端口号和域名 `my-svc.my-namespace.svc.cluster-domain.example`。
对于 Headless Service，这个解析为多个 answer，每个支持服务的 Pod 都有一个 answer，并且包含端口号和 Pod 的域名，其形式为 `auto-generated-name.my-svc.my-namespace.svc.cluster-domain.example`。

如果 `my-service.my-ns` 服务具有名为 `http` 的端口，且协议设置为 `TCP`，则可以对 `_http._tcp.my-service.my-ns` 执行 DNS SRV 查询。
可以发现该端口号、`http` 以及 `IP` 地址。

### ServiceTypes

##### ClusterIP

在群集内部 IP 上暴露 Service。
仅可从群集内访问。

这是 ServiceType 默认值。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201205012925.png)

##### NodePort

每个节点的 IP 上暴露 Service。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201205013442.png)

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201205013713.png)

Kubernetes control plane 会在 `--service-node-port-range` 标志指定的范围内分配端口，默认值 30000-32767。

kube-proxy 的 `--nodeport-addresses` 中的标志设置为特定 IP block。

##### LoadBalancer

使用 Cloud Provider 的 LoadBalancer 在外部暴露 Service。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201205013842.png)

LoadBalancer 的实际创建是异步进行的，

##### ExternalName

通过返回带有其值的记录，将 Service 映射到 externalName 字段的 CNAME。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201205014110.png)

Kubernetes DNS 服务器是唯一的一种能够访问 ExternalName 类型的 Service 的方式。

例如，此 Service 定义 my-service 将 prod 命空间中的 Service 映射到my.database.example.com。
查找 `my-service.prod.svc.cluster.local` 时，DNS 服务器将返回 CNAME 带有值的记录 my.database.example.com。

访问 my-service 与其他 Service 的工作方式相同，但主要区别在于重定向发生在 DNS 级别，而不是通过代理或转发。

##### externalIP

如果有 externalIPs 路由到一个或多个群集节点，则可以在这些 IP 上公开 Services。

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: MyApp
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 9376
  externalIPs:
    - 80.11.12.10
```

### EndpointSlice

EndpointSlice 可以为 Endpoint 提供更可扩展的替代方案。

EndpointSlice 允许跨多个资源分布网络端点。

默认情况下，一旦到达 100 个 Endpoint，该 EndpointSlice 将被视为"已满"，届时将创建其他 EndpointSlice 来存储任何其他 Endpoint。

```yaml
apiVersion: discovery.k8s.io/v1beta1
kind: EndpointSlice
metadata:
  name: example-abc
  labels:
    kubernetes.io/service-name: example
addressType: IPv4
ports:
  - name: http
    protocol: TCP
    port: 80
endpoints:
  - addresses:
    - "10.1.2.3"
    conditions:
      ready: true
    hostname: pod-1
    topology:
      kubernetes.io/hostname: node-1
      topology.kubernetes.io/zone: us-west2-a
      topology.kubernetes.io/region: us-west2
```

EndpointSlice 支持三种地址类型：
- IPv4
- IPv6
- FQDN(完全限定域名)

Kubernetes 定义了 label `endpointslice.kubernetes.io/managed-by`，表示管理 EndpointSlice 的实体。
应该为这个 label 设置一个唯一的值。

EndpointSlice 的 label `kubernetes.io/service-name` 来表示所属的 Service。

### Headless Service 

Headless Service 与普通 Service 类似，但它没有 clusterIP。

只要在服务定义中加入 `clusterIP：none`，就可以创建一个无头服务。

```yaml
apiVersion: v1
kind: Service
metadata:
  name: zookeeper-server
  labels:
    app: zookeeper
spec:
  clusterIP: None
  ports:
  - port: 2888
    name: server
  - port: 3888
    name: leader-election
  selector:
    app: zookeeper
```

使用 Headless Service 的主要好处是流量能够直达每个 Pod。

如果这是一个普通 Service，那么这个 Service 将作为一个负载平衡器或代理，只需要使用 servicename `zookeeper-server` 就可以访问工作负载对象。
如果使用 Headless Service，Pod `zookeeper-0` 可以使用 `zookeeper-1.zookeeper-server` 访问 `zookeeper-1`。

普通 Service

```shell script
kubectl exec zookeeper-0 -- nslookup zookeeper
Server:  10.0.0.10
Address: 10.0.0.10#53

Name:    zookeeper.default.svc.cluster.local
Address: 10.0.0.213
```

Headless Service

```shell script
kubectl exec zookeeper-0 -- nslookup zookeeper
Server:  10.0.0.10
Address: 10.0.0.10#53

Name:    zookeeper.default.svc.cluster.local
Address: 172.17.0.6
Name:    zookeeper.default.svc.cluster.local
Address: 172.17.0.7
Name:    zookeeper.default.svc.cluster.local
Address: 172.17.0.8
```

对于定义了 selectors 的 Headless Service，endpoint controller 会自动创建 Endpoint 记录，并修改 DNS 配置以返回直接指向支持该 Service 的 Pod 的记录地址。

如果没有 selectors，endpoint controller 不会创建 Endpoint 记录。
但是 DNS 服务器会查找并配置任一一个。
CNAME 记录为 ExternalName 类型的 Service。A 记录为任何与 Service 共享 name 的 Endpoint。

### Service Topology

默认情况下，发往 clusterIP 或者 NodePort 服务的流量可能会被路由到任意一个服务后端的地址上。

Service Topology 可以将外部流量路由到节点上运行的 Pod 上，但不支持 clusterIP 服务。
允许 Service 创建者根据源 Node 和目的 Node 的标签来定义流量路由策略。

给 kube-apiserver 和 kube-proxy 启用 ServiceTopology 功能：

```shell script
--feature-gates="ServiceTopology=true"
```

通过 topologyKeys 在 Service Spec 上指定字段来控制服务流量路由。
该字段是节点标签的优先顺序列表，在访问 Service 时用于对 Endpoint 进行排序。
流量将被定向到与第一个 label 匹配的节点。
如果在匹配的节点上没有该 Service 的 Endpoint，则考虑第二个 label，依此类推。
如果找不到匹配项，则流量将被拒绝，就像该 Service 根本没有 Endpoint 一样。
如果使用了全部捕获值 `*`，则它必须是 topologyKeys 中的最后一个值。

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: my-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
  topologyKeys:
    - "kubernetes.io/hostname"
    - "topology.kubernetes.io/zone"
    - "topology.kubernetes.io/region"
    - "*"
```

