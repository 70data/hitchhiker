# hitchhiker-container
<<<<<<< HEAD
=======

## 第一天

- 虚拟机、容器历史
- cgroup
- namespace
- docker
    - 安装 & 配置
    - 基础命令操作
    - dockerfile & image & 多阶段构建 & image registry
    - 网络模式
    - docker compose
    - 源码阅读
        - 容器启动流程

## 第二天

- kubernetes
    - 基础知识
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
        - hostNetwork
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
        - volume & pv & pvc & storageclass
        - emptydir
        - hostpath
        - nfs
    - 资源对象
        - configmap
        - secret
        - crd

## 第四天

- kubernetes
    - 调度
        - 策略
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
    - 源码阅读
        - 容器启动流程
        - 节点资源配额计算方式

## 第五天

- 监控
    - prometheus
        - 基础知识
        - 部署
    - 集群资源监控
    - 节点资源监控
    - grafana
        - 基础知识 & 部署
        - dashboard
- 日志
    - filebeat
    - elasticsearch
    - kibana

## 第六天

- CI/CD
    - tekton
- client-go
    - 操作集群资源
    - event 监控
    - sample controller
    - extend scheduler
- operator

## 第七天

- etcd
    - 基本概念
    - raft 原理
    - 日常运维操作
    - 故障模拟及恢复
    - etcd operator
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
- ceph
    - ceph 基础概念 crush、pool、pg、osd、object
    - ceph 基础操作
    - rook 部署与使用
    - rbd
    - cephfs
- kubectl 扩展
- helm
    - 基础使用
    - 内置函数 & values
    - 模板函数 & 管道
    - 控制流程
- kustomize
- GPU
    - cuda 版本选择及安装
    - cuda 容器内挂载
    - device plugin
    - kubeflow
- cert-manager
    - 安装
    - 使用cert-manager 管理证书
- linkerd2
- envoy
- harbor
- service catalog
- aggregation
- kube-advisor 检查应用程序问题

>>>>>>> f6e4202735ecd175ef2f68df543f7dc074ced26c
