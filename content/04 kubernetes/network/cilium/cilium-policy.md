## L3/L4 策略

默认是没有网络策略的。

### 部署星球大战 demo

http://70data.net/upload/manifest/cilium/star-wars-app.yaml

```shell script
kubectl create -f star-wars-app.yaml

kubectl get pods,svc
NAME                           READY   STATUS    RESTARTS   AGE
pod/deathstar-d7d9cc8b-hcskx   1/1     Running   0          34s
pod/tiefighter                 1/1     Running   0          34s
pod/xwing                      1/1     Running   0          34s
NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/deathstar    ClusterIP   10.105.87.211   <none>        80/TCP    34s
```

![images](http://70data.net/upload/kubernetes/cilium_http_gsg.png)

查看访问状态

```shell script
kubectl -n kube-system get pods -l k8s-app=cilium
NAME           READY   STATUS    RESTARTS   AGE
cilium-zrl7g   1/1     Running   0          4h17m

kubectl -n kube-system  exec cilium-zrl7g -- cilium endpoint list  | grep app=star-wars
ENDPOINT   POLICY (ingress)   POLICY (egress)   IDENTITY   LABELS (source:key[=value])                       IPv6   IPv4           STATUS
           ENFORCEMENT        ENFORCEMENT
732        Disabled           Disabled          62790      k8s:app=star-wars                                        10.217.0.238   ready
                                                           k8s:class=xwing
                                                           k8s:io.cilium.k8s.policy.cluster=kubernetes
                                                           k8s:io.cilium.k8s.policy.serviceaccount=default
                                                           k8s:io.kubernetes.pod.namespace=default
                                                           k8s:org=alliance
1792       Disabled           Disabled          52040      k8s:class=deathstar                                      10.217.0.37    ready
                                                           k8s:io.cilium.k8s.policy.cluster=kubernetes
                                                           k8s:io.cilium.k8s.policy.serviceaccount=default
                                                           k8s:io.kubernetes.pod.namespace=default
                                                           k8s:org=empire
3519       Disabled           Disabled          20287      k8s:app=star-wars                                        10.217.0.79    ready
                                                           k8s:class=tiefighter
                                                           k8s:io.cilium.k8s.policy.cluster=kubernetes
                                                           k8s:io.cilium.k8s.policy.serviceaccount=default
                                                           k8s:io.kubernetes.pod.namespace=default                  10.217.0.79    ready
```

deathstar 只允许 label 为 org=empire 应用访问。
默认是没有规则的，所以 xwing、tiefighter 都可以访问。

```shell script
kubectl exec xwing -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing

# 由于没有执行规则 和都可以请求着陆 要测试这一点 请使用下面的命令
kubectl exec tiefighter -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
```

### Cilium 通过 label 来定义策略

不允许任何 `org=empire` 的应用访问。

![images](http://70data.net/upload/kubernetes/cilium_http_l3_l4_gsg.png)

http://70data.net/upload/manifest/cilium/star-wars-policy-l3l4.yaml

```shell script
kubectl apply -f star-wars-policy-l3l4.yaml

kubectl exec tiefighter -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
Ship landed

kubectl exec xwing -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
```

查看访问状态

```shell script
ENDPOINT   POLICY (ingress)   POLICY (egress)   IDENTITY   LABELS (source:key[=value])                       IPv6   IPv4           STATUS
           ENFORCEMENT        ENFORCEMENT
732        Disabled           Disabled          62790      k8s:app=star-wars                                        10.217.0.238   ready
                                                           k8s:class=xwing
                                                           k8s:io.cilium.k8s.policy.cluster=kubernetes
                                                           k8s:io.cilium.k8s.policy.serviceaccount=default
                                                           k8s:io.kubernetes.pod.namespace=default
                                                           k8s:org=alliance                                         10.217.0.202   ready
1792       Enabled            Disabled          52040      k8s:class=deathstar                                      10.217.0.37    ready
                                                           k8s:io.cilium.k8s.policy.cluster=kubernetes
                                                           k8s:io.cilium.k8s.policy.serviceaccount=default
                                                           k8s:io.kubernetes.pod.namespace=default
                                                           k8s:org=empire
3519       Disabled           Disabled          20287      k8s:app=star-wars                                        10.217.0.79    ready
                                                           k8s:class=tiefighter
                                                           k8s:io.cilium.k8s.policy.cluster=kubernetes
                                                           k8s:io.cilium.k8s.policy.serviceaccount=default
                                                           k8s:io.kubernetes.pod.namespace=default
                                                           k8s:org=empire
```

## L7 策略

```shell script
kubectl exec tiefighter -- curl -s -XPUT deathstar.default.svc.cluster.local/v1/exhaust-port
Panic: deathstar exploded
goroutine 1 [running]:
main.HandleGarbage(0x2080c3f50, 0x2, 0x4, 0x425c0, 0x5, 0xa)
        /code/src/github.com/empire/deathstar/
        temp/main.go:9 +0x64
main.main()
        /code/src/github.com/empire/deathstar/
        temp/main.go:5 +0x85
```

![images](http://70data.net/upload/kubernetes/cilium_http_l3_l4_l7_gsg.png)

http://70data.net/upload/manifest/cilium/star-wars-policy-l7.yaml

```shell script
kubectl apply -f star-wars-policy-l7.yaml

kubectl exec tiefighter -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
Ship landed

kubectl exec tiefighter -- curl -s -XPUT deathstar.default.svc.cluster.local/v1/exhaust-port
Access denied

kubectl -n kube-system exec cilium-zrl7g cilium policy get
[
  {
    "endpointSelector": {
      "matchLabels": {
        "any:class": "deathstar",
        "any:org": "empire",
        "k8s:io.kubernetes.pod.namespace": "default"
      }
    },
    "ingress": [
      {
        "fromEndpoints": [
          {
            "matchLabels": {
              "any:org": "empire",
              "k8s:io.kubernetes.pod.namespace": "default"
            }
          }
        ],
        "toPorts": [
          {
            "ports": [
              {
                "port": "80",
                "protocol": "TCP"
              }
            ],
            "rules": {
              "http": [
                {
                  "path": "/v1/request-landing",
                  "method": "POST"
                }
              ]
            }
          }
        ]
      }
    ],
    "labels": [
      {
        "key": "io.cilium.k8s.policy.derived-from",
        "value": "CiliumNetworkPolicy",
        "source": "k8s"
      },
      {
        "key": "io.cilium.k8s.policy.name",
        "value": "rule1",
        "source": "k8s"
      },
      {
        "key": "io.cilium.k8s.policy.namespace",
        "value": "default",
        "source": "k8s"
      },
      {
        "key": "io.cilium.k8s.policy.uid",
        "value": "4ec91dba-c738-4a68-9727-06b737498d73",
        "source": "k8s"
      }
    ]
  }
]
Revision: 4
```

