安装依赖

```
# yum install -y yum-utils device-mapper-persistent-data lvm2
```

加载 repo

```
# yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```

安装 container-selinux

```
# yum install -y container-selinux
```

安装 Docker CE

```
# yum install -y docker-ce-19.03.4 docker-ce-cli-19.03.4 containerd.io-1.2.10
```

修改配置

```
# mkdir /etc/docker

# vim /etc/docker/daemon.json
{
    "debug": true,
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "5g",
        "max-file": "5"
    },
    "storage-driver": "overlay2",
    "storage-opts": ["overlay2.override_kernel_check=true"]
    "selinux-enabled": false
}

```

启动服务

```
# systemctl daemon-reload

# systemctl status docker
● docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib/systemd/system/docker.service; disabled; vendor preset: disabled)
   Active: inactive (dead)
     Docs: https://docs.docker.com

# systemctl start docker
```













添加 docker 组

```
sudo groupadd docker
```

用户加入 docker 组

```
sudo usermod -aG docker ${USER}
```

重启 docker 服务

```
sudo systemctl restart docker
```

