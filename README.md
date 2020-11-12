# hitchhiker-container

- 第一天
    - [x] 虚拟机、容器历史
    - [x] namespace
    - [x] cgroup
    - docker
        - [x] 基础知识
        - [x] 安装 & 配置
        - [x] 容器基础操作
        - [x] 镜像基础操作
        - [x] 镜像仓库
        - [x] dockerfile & 多阶段构建
        - [x] 存储卷
        - [x] 网络模式
        - [x] ufs
        - [x] 基于 wordpress 的小样例
- 第二天
    - docker
        - [x] docker compose
        - [ ] 容器启动流程
        - [ ] docker debug
        - [ ] gocker
    - kubernetes
        - 基础知识
            - 组件
            - 生态与周边
        - 集群环境搭建
            - kubeadm
                - check流程
                - 证书年限
        - 容器编排与应用负载管理
            - pod
            - replicaset & replication controller & deployment
- 第三天
    - kubernetes
        - 容器编排与应用负载管理
            - static pod
            - daemonset
            - statefulset
            - job & cronjob
            - preset
        - 网络模型
            - cni 插件
            - flannel
            - hostNetwork
- 第四天
    - kubernetes
        - 资源对象
            - configmap
            - secret
        - 存储
            - csi 插件
            - volume & pv & pvc & storageclass
            - emptydir
            - hostpath
                - hostpath-provisioner
            - nfs
- 第五天
    - kubernetes
        - 负载均衡 & 流量接入
            - iptables & ipvs
            - service & endpoint
                - clusterip
                - nodeport
                - loadbalancer
            - coredns
            - ingress & ingress controller
                - nginx ingress controller
        - 容器生命周期管理
            - initContainer
            - poststart & prestop
            - liveness & readiness
- 第六天
    - kubernetes
        - 调度
            - 策略
            - label
            - 亲和 & 反亲和
            - 污点 & 容忍
            - unschedulable
        - kubelet
            - 容器启动流程
            - NodeStatus
            - NodeLease
            - node节点资源配额计算方式
        - 权限策略
            - rbac
            - admission controller
- 第七天
    - helm
        - 基础使用
        - 内置函数 & values
        - 模板函数 & 管道
        - 控制流程
        - kubeapps
    - CI/CD
        - gitlab
            - 自动化构建docker镜像
            - 自动化镜像扫描
            - 自动化部署
        - tekton
        - drone
- 第八天
    - kubernetes
        - crd
    - client-go
        - 操作集群资源
        - event 监控
        - sample controller
        - extend scheduler
    - kubebuilder
- 第九天
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
- 第十天
    - etcd
    - envoy
        - 微服务及服务⽹格基础
        - envoy基础
        - envoy使⽤⼊⻔
        - 流量管理
        - 可观测性应⽤
    - istio
        - istio基础
        - istio架构与组件
        - istio部署
        - 基于istio的服务部署
        - istio流量治理

