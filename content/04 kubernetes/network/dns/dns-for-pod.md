一般来说，一个 Pod 有以下 DNS 解析。

`pod-ip-address.my-namespace.pod.cluster-domain.example.`

当一个 Pod 被创建时，它的 hostname 就是 Pod 的 `metadata.name` 值。
Pod Spec 有一个可选的 hostname 字段，可以用来指定 Pod 的 hostname。当指定时，它优先于 Pod 的名称，成为 Pod 的 hostname。

Pod Spec 还有一个可选的 subdomain 字段，可以用来指定其 subdomain。
例如，Pod 的 hostname 设置为 foo，subdomain 设置为 bar，在命名空间 my-namespace 中，将拥有完全合格域名(FQDN) `foo.bar.my-namespace.svc.cluster-domain.example`。

如果在与 Pod 相同的命名空间中存在一个与 subdomain 同名的 Headless Service，DNS 服务器也会返回一个 A/AAAA 记录，用于 Pod 的完全限定主机名。
例如，Pod 的 hostname 设置为 busybox-1，subdomain 设置为 default-subdomain，以及在同一命名空间中名为 default-subdomain 的 Headless Service，则该 Pod 将看到自己的 FQDN 为 `busybox-1.default-subdomain.my-namespace.svc.cluster-domain.example`。

注意：
因为 A/AAAA 记录不是为 Pod 名称创建的，所以需要 hostname 才能创建 Pod 的 A/AAAA 记录。
没有 hostname 但有 subdomain 的 Pod，只会为 Headless Service 创建 A/AAAA 记录 `default-subdomain.my-namespace.svc.cluster-domain.example`，指向 Pod 的 IP 地址。
如果想让 Pod 完整支持 Headless Service，需要完整配置 hostname 和 subdomain。

Pod 需要成为就绪状态才能有记录，除非在 Service 上设置 `publishNotReadyAddresses=True`。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox2
  labels:
    name: busybox
spec:
  hostname: busybox-2
  subdomain: default-subdomain
  containers:
  - image: busybox:1.28
    command:
      - sleep
      - "3600"
    name: busybox
```

### setHostnameAsFQDN

API server 必须启用 `SetHostnameAsFQDN` 功能。

当一个 Pod 被配置为具有完全合格域名 FQDN 时，它的 hostname 就是简称 hostname。
例如，有一个 Pod 的域名为完全限定域名 `busybox-1.default-subdomain.my-namespace.svc.cluster-domain.example`，该 Pod 里面的 hostname 命令返回 `busybox-1`，`hostname --fqdn` 返回 Pod 的 FQDN。

Pod Spec 中设置 `setHostnameAsFQDN: true` 时，kubelet 会将 Pod 的 FQDN 写入该 Pod 的命名空间的 hostname 中。
在这种情况下，`hostname` 和 `hostname --fqdn` 都会返回 Pod 的 FQDN。

在 Linux 中，内核的 hostname 字段 `struct utsname` 的 `nodename` 字段被限制为 64 个字符。

如果一个 Pod 启用了这个功能，并且它的 FQDN 长于64个字符，它将无法启动。
Pod 将保持在 Pending 状态，kubectl 看到是 ContainerCreating，产生错误事件，如 `Failed to construct FQDN from pod hostname and cluster domain, FQDN long-FQDN is too long (64 characters is the max, 70 characters requested)`。

## dnsPolicy

1. `None`。
表示空的 DNS 设置。
允许 Pod 忽略来自 Kubernetes 环境的 DNS 设置。所有的 DNS 设置都应该使用 Pod Spec 中的 dnsConfig 字段提供。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201206184952.jpeg)

2. `Default`。
Pod 从 Pod 运行的节点继承解析配置。让 kubelet 来决定使用何种 DNS 策略。
kubelet 默认的方式，使用宿主机的 /etc/resolv.conf。
kubelet 可以灵活来配置使用什么文件来进行 DNS 策略，参数 `–resolv-conf=/etc/resolv.conf`。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201206185136.jpeg)

3. `ClusterFirst`。
先使用 Kubernetes 中的 DNS 服务。
如果解析不成功，才会使用宿主机的 DNS 配置进行解析。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201206185242.jpeg)

`ClusterFirst` 还有一个冲突。
如果的 Pod 设置了 `HostNetwork=true`，则 `ClusterFirst` 就会被强制转换成 `Default`。

4. `ClusterFirstWithHostNet`。
hostNetwork 模式，还继续使用 Kubernetes 的 DNS 服务。
对于使用 hostNetwork 运行的 Pod，应该明确设置其 DNS 策略 `ClusterFirstWithHostNet`。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201206185649.jpeg)

##### dnsConfig

- `nameservers`。Pod 的 DNS 服务器的 IP 地址列表。最多可以指定 3 个 IP 地址。
- `searches`。在 Pod 中查找 hostname 的 DNS 搜索域列表。
- `options`。一个可选的对象列表，每个对象可以有一个名称属性(必填)和一个值属性(可选)。

```yaml
apiVersion: v1
kind: Pod
metadata:
  namespace: default
  name: dns-example
spec:
  containers:
    - name: test
      image: nginx
  dnsPolicy: "None"
  dnsConfig:
    nameservers:
      - 1.2.3.4
    searches:
      - ns1.svc.cluster-domain.example
      - my.dns.search.suffix
    options:
      - name: ndots
        value: "2"
      - name: edns0
```

## 配置

```yaml
linear: '{"coresPerReplica":256,"min":1,"nodesPerReplica":16}'
```

`replicas = max(ceil( cores × 1/coresPerReplica ) , ceil( nodes × 1/nodesPerReplica ) )`

当一个集群使用的节点核心较多时，corePerReplica 占主导地位。
当一个集群使用的节点核心较少时，nodesPerReplica 占主导地位。

## Debug

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dnsutils
  namespace: default
spec:
  containers:
  - name: dnsutils
    image: gcr.io/kubernetes-e2e-test-images/dnsutils:1.3
    command:
      - sleep
      - "3600"
    imagePullPolicy: IfNotPresent
  restartPolicy: Always
```

```shell script
kubectl exec -it dnsutils -- nslookup kubernetes.default

kubectl exec -it dnsutils -- cat /etc/resolv.conf
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        log # add log
        errors
        health
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          upstream
          fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
```

## issues

Linux 的 libc(glibc) 对 DNS 服务器记录的限制默认为 3 条。
比 glibc-2.17-222 更老的 glibc 版本允许的 DNS 搜索记录数被限制为 6 条。

Kubernetes 需要消耗 1 条服务器记录和 3 条搜索记录。

为了绕过 DNS 服务器记录的限制，节点可以运行 dnsmasq，它将提供更多的 DNS 服务器条目。
也可以使用 kubelet 的 `--resolv-conf`。

如果使用 Alpine 3.3 或更早的版本作为基础镜像，由于 Alpine 的一个已知问题，DNS 可能无法正常工作。

