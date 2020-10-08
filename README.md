# hitchhiker-container

## 第一天

- 虚拟机、容器历史
- cgroup
- namespace
- docker
    - 安装 & 配置
    - 使用实践
    - dockerfile & image & image registry
    - 网络模式
    - docker compose
    - 源码阅读
        - 组件间调用流程
        - cgroup、namespace 的交互

## 第二天

- kubernetes
    - 基础知识
        - 概念
        - 组件
        - 生态与周边
    - 集群环境搭建
        - kubeadm
    - 容器编排与应用负载管理
        - pod
        - replicaset & replication controller & deployment
        - static pod
        - daemonset
        - statefulset
        - job & cronjob

## 第三天

- kubernetes
    - 网络模型
        - cni 插件
        - flannel
        - host-network
    - 负载均衡 & 流量接入
        - iptables & ipvs
        - service & endpoint
            - clusterip
            - nodeport
            - loadbalancer
        - coredns
        - ingress & ingress controller
            - nginx ingress controller
    - 存储
        - csi 插件
        - volume & pv & pvc
        - storageclass
        - hostpath
        - emptydir
        - nfs

## 第四天

- kubernetes
    - 资源对象
        - configmap
        - secret
        - crd
    - 调度
        - 调度策略
        - label
        - 亲和 & 反亲和
        - 污点 & 容忍
        - unschedulable
    - 权限策略
        - rbac
        - admission controller
    - 容器生命周期管理
        - initContainer
        - poststart & prestop
        - liveness & readiness

## 第五天

- kubernetes
    - 容器启动流程
    - 节点资源配额计算方式
- 监控
    - prometheus
        - 概念介绍
        - 部署
    - 集群资源监控
    - 节点资源监控
    - grafana
        - 安装
        - dashboard

## 第六天

- 日志
    - filebeat
    - elasticsearch 集群
    - kibana 可视化组件
- CI/CD
    - tekton
- client-go
    - 操作集群资源

## 第七天

- client-go
    - event 监控
    - sample controller
    - extend scheduler
- kubernetes 之外的故事
    - etcd
        - 基本概念
        - 日常运维操作
        - 故障模拟及恢复
    - operator
    - service mesh
        - istio
            - istio核心功能 & 使用场景
            - istio架构与组件
            - istio部署
            - 基于istio的服务部署
            - 灰度发布
            - 流量监控
    - serverless
    - cloud provider
    - cluster api

## 其他

- runc
- containerd
    - 安装 & 配置
    - 使用实践
- cri-o
- kata
- ospf & bgp
- calico
- bpf & ebpf
- cilium
- traefik ingress controller
- 弹性伸缩
    - hpa
    - vpa
- csi插件编写指南 glusterfs为例
    - ceph
    - ceph基础概念（crush、pool、pg、osd、object） 
    - ceph基础操作
    - rook部署与使用
    - rbd
    - cephfs
- CI/CD
    - jenkins
        - pipeline
    - tekton
- helm
    - 基础使用
    - 内置函数 & values
    - 模板函数 & 管道
    - 控制流程
- kustomize
- GPU
    - cuda版本选择及安装
    - cuda容器内挂载
    - device plugin
    - 部署kubeflow
- 镜像
    - harbor
- 扩展
    - service catalog
    - aggregation
    - kubectl扩展
- cert-manager
    - 安装
    - 使用cert-manager管理证书
- etcd
    - raft原理
    - etcd operator
- kube-advisor 检查应用程序问题
- Linkerd2
- envoy
