##### kube-apiserver

`--feature-gates="IPv6DualStack=true"`

`--service-cluster-ip-range=<IPv4 CIDR>,<IPv6 CIDR>`

##### kube-controller-manager

`--feature-gates="IPv6DualStack=true"`

`--cluster-cidr=<IPv4 CIDR>,<IPv6 CIDR>`

`--service-cluster-ip-range=<IPv4 CIDR>,<IPv6 CIDR>`

`--node-cidr-mask-size-ipv4|--node-cidr-mask-size-ipv6`
对于 IPv4 默认为 `/24`，对于 IPv6 默认为 `/64`。

##### kubelet

`--feature-gates="IPv6DualStack=true"`

##### kube-proxy

`--cluster-cidr=<IPv4 CIDR>,<IPv6 CIDR>`

`--feature-gates="IPv6DualStack=true"`

