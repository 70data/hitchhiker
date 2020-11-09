安装依赖

```shell script
yum install -y yum-utils device-mapper-persistent-data lvm2
```

加载 repo

```shell script
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```

安装 container-selinux

```shell script
yum install -y container-selinux
```

安装 Docker CE

- Docker CE 是个人版
- Docker EE 是企业版

```shell script
yum install -y docker-ce-19.03.4 docker-ce-cli-19.03.4 containerd.io-1.2.10
```

修改配置

```shell script
mkdir /etc/docker

vim /etc/docker/daemon.json
{
    "debug": true,
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "5g",
        "max-file": "5"
    },
    "storage-driver": "overlay2",
    "storage-opts": ["overlay2.override_kernel_check=true"],
    "registry-mirrors": ["https://6shzzc2g.mirror.aliyuncs.com"],
    "selinux-enabled": false
}
```

启动服务

```shell script
systemctl daemon-reload

systemctl status docker
● docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib/systemd/system/docker.service; disabled; vendor preset: disabled)
   Active: inactive (dead)
     Docs: https://docs.docker.com

systemctl start docker
```

添加 docker 组

```shell script
groupadd docker
```

用户加入 docker 组

```shell script
usermod -aG docker ${USER}
```

重启 docker 服务

```shell script
systemctl restart docker
```

```shell script
docker run hello-world
```

检查加速器是否生效

```shell script
docker info
 Registry Mirrors:
  https://6shzzc2g.mirror.aliyuncs.com/
```

