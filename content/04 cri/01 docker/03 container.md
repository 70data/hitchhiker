## 查看 Docker 情况

`docker version`，当命令的输出包含 Client 和 Server 内容的时候，表示 daemon 已经启动。

`docker info`，返回所有容器和镜像的数量、Docker 使用的执行驱动和存储驱动，以及 Docker 的基本配置。

`service docker status`/`systemctl status docker`，查看 docker 的状态。

## 容器生命周期管理

大致可分为 4 个：创建、运行、休眠和销毁。

### 创建和运行

容器的创建和运行主要使用 `docker run`。

```shell script
docker run -it centos:7 /bin/bash
```

### 休眠和销毁

`docker stop` 可以让容器进入休眠状态。

`docker rm` 可以删除容器。删除容器的最佳方式就是先停止容器，然后再删除容器，这样可以给容器中运行的应用进程一个停止运行并清理残留数据的机会。

先 stop 的话，docker 会向容器内的 `PID 1` 进程发送 `SIGTERM` 信号，这样会给进程预留一个清理并优雅停止的机会。
如果进程在 10s 的时间内没有终止，那么会发送 `SIGKILL` 信号强制停止该容器。

docker 命令不会友好地发送 `SIGTERM`，而是直接发送 `SIGKILL` 信号。

### 重启策略

容器还可以配置重启策略，这是容器的一种自我修复能力，可以在指定事件或者错误后重启来完成自我修复。

配置重启策略有两种方式，一种是命令中直接传入参数，另一种是在 Compose 文件中声明。

通过命令中传入参数的方式，也就是在命令中加入 `--restart` 标志。
该标志会检查容器的退出代码，并根据退出码已经重启策略来决定。

Docker 支持的重启策略包括 `always`、`unless-stopped` 和 `on-failed`。

`always` 策略会一直尝试重启处于停止状态的容器，除非通过 `docker stop` 命令明确将容器停止。
另外，当 Docker daemon 重启的时候，被 `docker stop` 停止的设置了 `always` 策略的容器也会被重启。

```shell script
# 过几秒之后在终端中输入 exit，过几秒之后再来看一下
# 照理来说应该会处于 stop 状态，但是会发现又处于运行状态了
docker run -it --restart always centos:7 /bin/bash
```

`unless-stopped` 策略和 `always` 策略是差不多的，最大的区别是 `docker stop` 停止的容器在 Docker daemon 重启之后不会被重启。

`on-failure` 策略会在退出容器并且返回值不会 0 的时候，重启容器。
如果容器处于 `stopped` 状态，那么 Docker daemon 重启的时候也会被重启。
另外，`on-failure` 还接受一个可选的重启次数参数，如 `--restart=on-failure:5` 表示最多重启 5 次。

### 容器周期相关操作

`docker run` 等同于 `docker container run`。

```shell script
# 省略了 <tag>，那么默认是 latest
docker run <Options> <Repository>:<Tag> <App>
```

```shell script
# -it 参数表示将当前 shell 连接到容器的 shell 终端之上，并且与容器具有交互
# -i 表示容器中的 `STDIN` 是开启的
# -t 为要创建的容器分配一个伪 tty 终端
docker run -it ubuntu:latest /bin/bash
```

在启动的容器中运行某些指令，可能无法正常工作。
因为大部分容器镜像都是经过高度优化的，有些指令并没有被打包进去。

```shell script
# -d 表示后台模式，告知容器在后台运行
docker run -d ubuntu sleep 1m
```

```shell script
# 设置容器名字为 percy，合法的名字是可包含：大小写字母、数字、下划线、圆点、横线
docker run --name percy -it ubuntu:latest /bin/bash
```

```shell script
# 不指定要运行的 app 也是可以的，这是因为构建镜像时指定了默认命令
# 可以通过 docker image inspect 查看，如果设置了 CMD 那么表示在基于该镜像启动容器时会默认运行 CMD
docker run <Repository>:<Tag>
```

```shell script
docker run -d nginx:1.19.4
```

#### 查看容器状态

`docker ps`，查看当前系统中正在运行的容器，等同于 `docker container ls`

`docker ps -a`，查看当前系统中所有的容器，运行和停止，`docker container ls -a`

```shell script
docker history nginx:1.19.4
IMAGE         CREATED     CREATED BY                                     SIZE  COMMENT
c39a868aad02  2 days ago  /bin/sh -c #(nop) CMD ["nginx" "-g" "daemon…   0B
<missing>     2 days ago  /bin/sh -c #(nop) STOPSIGNAL SIGTERM           0B
<missing>     2 days ago  /bin/sh -c #(nop) EXPOSE 80                    0B
<missing>     2 days ago  /bin/sh -c #(nop) ENTRYPOINT ["/docker-entr…   0B
<missing>     2 days ago  /bin/sh -c #(nop) COPY file:0fd5fca330dcd6a7…  1.04kB
<missing>     2 days ago  /bin/sh -c #(nop) COPY file:13577a83b18ff90a…  1.96kB
<missing>     2 days ago  /bin/sh -c #(nop) COPY file:e7e183879c35719c…  1.2kB
<missing>     2 days ago  /bin/sh -c set -x && addgroup --system -…      63.6MB
<missing>     2 days ago  /bin/sh -c #(nop) ENV PKG_RELEASE=1~buster     0B
<missing>     2 days ago  /bin/sh -c #(nop) ENV NJS_VERSION=0.4.4        0B
<missing>     2 days ago  /bin/sh -c #(nop) ENV NGINX_VERSION=1.19.4     0B
<missing>     3 weeks ago /bin/sh -c #(nop) LABEL maintainer=NGINX Do…   0B
<missing>     3 weeks ago /bin/sh -c #(nop) CMD ["bash"]                 0B
<missing>     3 weeks ago /bin/sh -c #(nop) ADD file:0dc53e7886c35bc21…  69.2MB
```

```shell script
# 在运行时覆盖原 Dockerfile 中的 ENTRYPOINT 指令
docker run <Options> --entrypoint <Command> <Repository>:<Tag> <Params>
```

```shell script
docker run -it --entrypoint /bin/bash nginx:1.19.4
```

```shell script
# -p 8080:80 将 Docker 主机的 8080 端口映射到容器内的 80 端口
# 当有流量访问主机的 8080 端口时流量会直接映射到容器内的 80 端口
docker run -d -p 8080:80 <Repository>:<Tag> <App>
```

```shell script
docker run -d -p 8080:80 nginx:1.19.4

curl 127.0.0.1:8080
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>
<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

```shell script
# 在宿主机上随便选择一个位于 49153~65535 之间的一个端口来映射到容器的 80 端口
# 可以通过 docker ps -l 或者 docker port 来查看端口映射情况
docker run -d -p 80 <Repository>:<Tag> <App>
```

```shell script
# 查看指定容器的指定端口的映射情况
docker port <ContainerName>||<ContainerID>
```

```shell script
docker run -d -p 80 nginx:1.19.4

docker ps
CONTAINER ID  IMAGE        COMMAND                 CREATED        STATUS        PORTS                       NAMES
9791dd6b5bc1  nginx:1.19.4 "/docker-entrypoint.…"  3 seconds ago  Up 2 seconds  0.0.0.0:32768->80/tcp  elastic_bhaskara

docker port 9791dd6b5bc1
80/tcp -> 0.0.0.0:32768

curl 127.0.0.1:32768
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>
<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

```shell script
# 将容器内的 80 端口绑定到本地宿主机 127.0.0.1 这个 IP 地址的 80 端口上
docker run -d -p 127.0.0.1:8080:80 <Repository>:<Tag> <App>

# 没有指定要绑定的宿主机端口号，随机绑定到宿主机 127.0.0.1 的一个端口上
docker run -d -p 127.0.0.1::80 <Repository>:<Tag> <App>

# 将 Dockerfile 中 EXPOSE 指令的端口都随机映射到主机的端口上
# 注意是大写的 P
docker run -d -P <Repository>:<Tag> <App>
```

```shell script
docker run -d -P nginx:1.19.4

docker port 7b4a6f80a82c
80/tcp -> 0.0.0.0:32769
```

```shell script
# 停止运行中的容器，并将状态设置为 Exited(0)，发送 SIGTERM 信号
docker stop <ContainerName>||<ContainerID>

# 也可以使用 docker kill 命令停止容器，只是发出的是 SIGKILL 信号
docker kill <ContainerName>||<ContainerID>
```

```shell script
# 重启处于停止(Exited)状态的容器
docker start <ContainerName>||<ContainerID>
```

```shell script
# 删除停止运行的容器
docker rm <ContainerName>||<ContainerID>

# 一次性删除运行中的容器，但是建议先停止之后再删除。
docker rm -f <ContainerName>||<ContainerID>

# 删除历史容器
docker rm $(sudo docker ps -a | grep Exited | awk '{print $1}')

# 清理主机上全部运行的容器
docker rm -f $(docker ps -aq)

docker system prune -f
```

## 与容器交互

在使用 -d 参数时，容器启动后会进入后台。

某些时候需要进入容器进行操作，包括使用 `docker attach` 命令或 `docker exec` 命令

### `docker attach`

```shell script
docker run -dit centos:7
eebc6ddf2026bfda38e0bc69860f65da61c3b272b6978983640bbe64e60c058e

docker ps
CONTAINER ID    IMAGE    COMMAND      CREATED        STATUS        PORTS    NAMES
eebc6ddf2026    centos:7 "/bin/bash"  3 seconds ago  Up 2 seconds           suspicious_fermat

docker attach eebc6ddf2026

exit
exit

docker ps
CONTAINER ID    IMAGE    COMMAND      CREATED        STATUS        PORTS    NAMES
```

如果从这个 stdin 中 exit，会导致容器的停止。

### `docker exec`

```shell script
# 使用 exec 命令在运行状态的容器中，启动一个新进程
docker exec <options> <ContainerName>/<ContainerID> <app>
```

### `nsenter`

通过 `nsenter` 的方式

```shell script
nsenter --target `docker inspect --format '{{.State.Pid}}' containerid` --mount --uts --ipc --net --pid
```

## 容器细节信息

```shell script
# 显示容器的配置信息
docker inspect <ContainerName>||<ContainerID>

# 支持 -f 或者 --format 标志查看选定内容的结果
docker inspect --format '{{.NetworkSettings.IPAddress}}'
```

## 容器日志

```shell script
# 获取容器的日志
docker logs

# 监控容器的日志，跟 tail 命令差不多
docker logs -f

# 显示容器日志的时间戳
docker logs -t
```

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20201109142121.png)

