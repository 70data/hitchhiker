Controller Manager 由 kube-controller-manager 和 cloud-controller-manager 组成。

![images](http://70data.net/upload/kubernetes/assets_-LDAOok5ngY4pc1lEDes_-LpOIkR-zouVcB8QsFj__-LpOIpaT3nX7htWnseyK_post-ccm-arch.png)

kube-controller-manager：

- Replication Controller
- Node Controller
- CronJob Controller
- Daemon Controller
- Deployment Controller
- Endpoint Controller
- Garbage Collector
- Namespace Controller
- Job Controller
- Pod AutoScaler
- RelicaSet
- Service Controller
- ServiceAccount Controller
- StatefulSet Controller
- Volume Controller
- Resource quota Controller

`--kube-api-qps` 和 `--kube-api-burst` 参数的值越大，kube-apiserver 和 etcd 的负载就越高。
`--kube-api-qps`，默认值 20，与 kube-apiserver 通信时每秒请求数(QPS)限制。
`--kube-api-burst`，默认值 30，与 kube-apiserve 通信时突发峰值请求个数上限。

