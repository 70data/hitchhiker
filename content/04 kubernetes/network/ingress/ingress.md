Ingress 是一个原生的 Kubernetes 资源，可以通过规则将外部流量转发到集群内部的服务 Endpoint。

Ingress 需要借助 Ingress Controller 来转发 Ingress 对象所指定的规则。

kube-proxy 是一个 4 层的接入层。
kube-proxy 主要是靠 iptables 内核转发，有问题基本无法定位，全靠猜，相对黑盒。

Ingress 是一个 7 层的、能转发的、可编程的一个接入层。
流量数据近乎透明。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201128010029.jpg)

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201128010856.png)

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201206171211.png)

## IngressClass

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: external-lb
  annotations:
    ingressclass.kubernetes.io/is-default-class: "True"
spec:
  controller: example.com/ingress-controller
  parameters:
    apiGroup: k8s.example.com
    kind: IngressParameters
    name: external-lb
```

```yaml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: example-ingress
spec:
  ingressClassName: external-lb
  rules:
  - host: k8s.example.com
    http:
      paths:
      - path: /example
        pathType: Prefix
        backend:
          serviceName: example-service
          servicePort: 80
```

```yaml
metadata:
  name: foo
  annotations:
    kubernetes.io/ingress.class: "nginx"
```

##### 设置缺省的 IngressClass

`ingressclass.kubernetes.io/is-default-class` annotations，设置为 True。
代表所在的 IngressClass 为缺省控制器。
没有显式指定 `ingressClassName` 的新的 Ingress 资源都会使用该控制器。

## pathType

该动能为 1.18 版本以后的改版。

- `ImplementationSpecific` 使用此路径类型，匹配取决于 IngressClass。
- `Exact` 与网址路径完全匹配且区分大小写
- `Prefix` 根据网址路径前缀进行匹配。匹配区分大小写，并且在逐个路径的基础上进行匹配。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201127144439.png)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: simple-fanout-example
spec:
  rules:
  - host: foo.bar.com
    http:
      paths:
      - path: /foo
        pathType: Prefix
        backend:
          service:
            name: service1
            port:
              number: 4200
      - path: /bar
        pathType: Prefix
        backend:
          service:
            name: service2
            port:
              number: 8080
```

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201127144636.png)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: name-virtual-host-ingress
spec:
  rules:
  - host: foo.bar.com
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: service1
            port:
              number: 80
  - host: bar.foo.com
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: service2
            port:
              number: 80
```

Ingress 未定义 `host`，则可以匹配到 Ingress Controller IP 地址的任何网络流量，而无需基于 `host`。

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: name-virtual-host-ingress-no-third-host
spec:
  rules:
  - http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: service3
            port:
              number: 80
```

## TLS

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: testsecret-tls
  namespace: default
data:
  tls.crt: base64 encoded cert
  tls.key: base64 encoded key
type: kubernetes.io/tls
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-example-ingress
spec:
  tls:
  - hosts:
      - https-example.foo.com
    secretName: testsecret-tls
  rules:
  - host: https-example.foo.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: service1
            port:
              number: 80
```

