## 查看状态

```
kubectl -n kube-system exec -it cilium-ljhvg -- cilium status
KVStore:                Ok   Disabled
Kubernetes:             Ok   1.15 (v1.15.3) [linux/amd64]
Kubernetes APIs:        ["CustomResourceDefinition", "cilium/v2::CiliumClusterwideNetworkPolicy", "cilium/v2::CiliumEndpoint", "cilium/v2::CiliumNetworkPolicy", "cilium/v2::CiliumNode", "core/v1::Endpoint", "core/v1::Namespace", "core/v1::Pods", "core/v1::Service", "networking.k8s.io/v1::NetworkPolicy"]
KubeProxyReplacement:   Strict   [NodePort (DSR, 30000-32767), ExternalIPs, HostReachableServices (TCP, UDP)]
Cilium:                 Ok   OK
NodeMonitor:            Disabled
Cilium health daemon:   Ok
IPAM:                   IPv4: 6/255 allocated from 10.217.0.0/24,
Controller Status:      25/25 healthy
Proxy Status:           OK, ip 10.217.0.99, 0 redirects active on ports 10000-20000
Cluster health:         1/1 reachable   (2020-02-26T02:05:25Z)
```

## 查看健康情况

```
kubectl -n kube-system exec -it cilium-ljhvg -- cilium-health status
Probe time:   2020-02-26T02:18:25Z
Nodes:
  kubernetes/foo1001v (localhost):
    Host connectivity to 10.16.29.16:
      ICMP to stack:   OK, RTT=183.789µs
      HTTP to agent:   OK, RTT=216.978µs
    Endpoint connectivity to 10.217.0.231:
      ICMP to stack:   OK, RTT=161.362µs
      HTTP to agent:   OK, RTT=446.259µs
```

## 跟踪连接

```
kubectl -n kube-system exec -it cilium-ljhvg -- cilium monitor
-> endpoint 512 flow 0x6165c37b identity 1->4666 state reply ifindex lxcb3b4dcf575e6 orig-ip 10.16.29.16: 10.16.29.16:6952 -> 10.217.0.222:48664 tcp ACK
-> host from flow 0xe97a9ccb identity 4666->1 state established ifindex cilium_net orig-ip 0.0.0.0: 10.217.0.222:48664 -> 10.16.29.16:6952 tcp ACK
```

