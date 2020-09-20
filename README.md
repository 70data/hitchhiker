# hitchhiker-container

## 虚拟机、容器历史

## cgroup

## namespace

## cri
- docker
    - 安装 & 配置
    - 使用实践
    - image
    - dockerfile
    - docker 网络模式
    - docker compose
    - 源码阅读
        - docker调用cgroup
        - 组件间建通信流程
- runc
- containerd
    - 安装 & 配置
    - 使用实践
- cri-o
- kata

## kubernetes
- 调度系统
- 设计原理
- 核心组件
    - kubelet
        - NodeStatus
        - NodeLease
        - pod cgroup信息
        - 资源配额计算方式
        - 启动流程
- 部署
- 网络
    - 网络模型
    - cni网络插件
    - iptables
    - ipvs
    - host-network
    - coredns
    - flanne
    - ospf & bgp
    - calico
    - bpf & ebpf
    - cilium
- 资源对象
    - pod
        - 启动流程
        - 优先级调度
        - HugePage
        - preset
    - replicaset & replication controller
    - deployment
    - configmap
    - secret
    - job & cronjob
    - static pod
    - daemonset
    - statefulset
- 负载均衡 & 流量接入
    - service & endpoint
    - clusterip
    - nodeport
    - loadbalancer
    - ingress & ingress controller
    - nginx ingress controller
    - traefik ingress controller
- 调度
    - 调度策略
    - 亲和 & 反亲和
    - 污点 & 容忍
    - unschedulable
    - admission controller & rbac
- 弹性伸缩
    - hpa
    - vpa
- 存储
    - volume & pv & pvc
    - hostpath
    - emptydir
    - ceph基础概念（crush、pool、pg、osd、object） 
    - ceph基础操作
    - storageclass
    - csi插件编写指南 glusterfs为例
    - rook部署与使用
    - rbd
    - cephfs
- CI/CD
    - jenkins
        - pipeline
    - drone
    - tekton
- 监控
- 日志
    - filebeat
    - Elasticsearch 集群
    - Kibana 可视化组件
- 镜像
    - harbor
- 扩展
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
    - 声明式api
    - crd
    - sample controller
    - operator
    - extend scheduler
    - cloud provider
    - service catalog
    - aggregation
    - kubectl扩展

## 应用
- cert-manager
    - 安装
    - 使用cert-manager管理证书
- etcd
    - raft原理
    - 基本概念
    - 日常运维操作
    - etcd operator
- kube-advisor 检查应用程序问题

## service mesh
- istio
    - istio核心功能 & 使用场景
    - istio架构与组件
    - istio部署
    - 基于istio的服务部署
    - 灰度发布
    - 流量监控
- Linkerd2
- envoy

## serverless


第一天，Docker 部分
一、Docker简介及安装
二、Docker主要组件与概念
三、容器技术介绍（cgroup, Namespace）
四、Docker基础命令
五、Dockefile 构建镜像和Docker registry
六、Docker网络模式
八、课后作业：自己按照教程，搭建Kubernetes 51Reboot 运维开发

第二天， Kubernte环境搭建
一、Kubernetes 基础
1．Docker 与Kubernetes 的关系
2．Kubernetes 生态与架构
3．Kubernete 基本概念和组件
二、Kubernetes 集群环境搭建
1．运行部署脚本将Kubernetes 环境一键部署
2．Kubenetes 部署讲解
3．Kubernetes 的架构和工作原理
三、通过一个完整的Deployment 的例子，讲解里面的基础知识：简单的网络和存储基础知识
四、课后作业：试着自己改变Kubelet 和Apiserver 之间的认证方式

第三天，Kubernetes基础
一、Pod 与生命周期管理
1．Pod 概述
2．YAML资源描述文件介绍
3．静态Pod
4．初始化容器（initContainer）
5．Pod 生命周期管理
6．Pod 健康检查及探针
二、Kubernetes 集群资源管理与调度管理
1．Label 概念与使用
2．节点亲和性
3．Pod 亲和性与污点和容忍
三、Kubernetes 控制器和常用资源类型
1．RC(Replication Controller)\ RS(Replca Set)介绍与应用
2．Deployment 概念与应用
3．Pod 自动扩所容（HPA、Horizontal Pod Autoscaling）
4．Job 概念与应用
5．CronJob 概念与应用
6．Service 概念与应用
7．Configmap 概念与应用
8．Configmap 热更新
9．Secret 概念及应用
10．入控制介绍
四、使用Golang/Python sdk 实现有认证的请求Apiserver 去创建Deployment
五、课后作业：自己实现编程调用Kubernestes 的其他资源

第四天，自定义资源CRD 编写与Helm
一、使用Kubebuilder自定义一个Kubernetes 资源
二、Helm 工具的使用
1．Helm 简介
2．Helm 安装和使用
3．Helm 模版详解之函数
4．Helm 详解之管道
5．Helm 详解之控制流程
6．Helm 详解之最佳实践
7．Helm 插件diff

第五天，网络服务发现和存储
一、集群内和集群外的服务发现
1．CLusterIP 、NodePort、LoadBalancer
2．Ingress 和Ingress Controller
3．Nginx Ingress Controller 简介
二、持久化存储
1．Volume 应用
2．PV 的概念及应用
3．PVC 的概念及应用
4．StorageClass 的概念及应用
5．NFS 存储方案

第六天，实战Kubernetes 集群网络
一、Kubernetes 集群网络常用方案比较及选型建议
二、Flannel 网络组件详解
三、Flannel 网络组件配置及应用
四、Flannel 生产环境应用经验
五、Calico 网络组件详解
六、Calico 网络组件配置及应用

第七天， K8S 集群监控
一、Prometheus 介绍
二、部署Prometheus
三、监控Kubernetes 集群及应用
四、NodeExporter 的安装使用
五、Prometheus 的自动发现
六、Kubernetes 常用资源对象监控
七、Grafana 的安装与使用
八、Grafana 的插件与监控
九、Kubernetes 官方插件的使用
十、Alertmanager 的安装使用
十一、Alertmanager 结合钉钉的告警
十二、Prometheus Operator 的安装使用
十三、自定义Prometheus Operator 监控
十四、自定义Prometheus Operator 告警
十五、Prometheus Operator 高级配置

第八天，日志收集
一、日志收集架构
二、Elasticsearch 集群
三、Kibana 可视化组件
四、Fluentd 采集组件
五、生产环境采集日志方案详解

第九/十天，企业级K8S 自动化运维-DevOps
一、动态Jenkins Slave
二、Jenkins Pipeline
三、Jenkins Blue Ocean
四、Harbor 详解
五、Gitlab 安装与使用
六、Gitlab CI Runner
七、Gitlab CI 示例
八、Kubernetes 开源管理平台
九、完整devops 项目实例

