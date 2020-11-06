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





镜像层 ID 在拉取镜像的时候会看到，SHA256 散列值可以通过 docker image inspect <image> 看到。

所有的 Docker 镜像都起始于一个基础镜像层，当进行修改或者增加新的内容时，就会在当前镜像层之上，创建新的镜像层。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201106115435.png)

并且在添加额外的镜像层的时候，镜像始终保持当前所有镜像层的组合，即所有镜像层堆叠之后的结果。

每个镜像层包含 3 个文件，而镜像包含了来自两个镜像层的 6 个文件。
第三层镜像层的文件 7 是文件 5 的一个更新版本，但是在外部看来整个镜像还是只有 6 个文件，因为对外展示时相当于把所有镜像层堆叠合并。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201106115707.png)

Docker 通过快照的方式来实现镜像层堆栈，并保证多镜像层对外展示为统一的文件系统。

另外，多个镜像之间会共享镜像层，这样可以有效节省空间并提升性能。Docker 在拉取镜像时会识别出要拉取的镜像中有哪几层已经在本地了的，如果有些镜像层已经在本地了，那么这些镜像层就不会被拉取。

在 pull 镜像的时候，需要给出镜像仓库服务的网络地址、仓库名称（镜像名）以及标签即可定位到某个镜像（名字和标签使用 : 分隔）。如下 <Registry> 就是上图中的镜像仓库服务，<Repository> 相当于上图中的仓库，<Tag> 相当于这个仓库中镜像的版本。先根据 <Registry> 定位到镜像仓库所在网络位置，之后再根据  <Repository> 定位到某个仓库，再根据 <Tag> 定位到某个具体的镜像。

# 完整命令
docker image pull <Registry>/<Repository>:<Tag>

由于 Docker 客户端的镜像仓库服务默认使用官方 Docker hub（默认镜像仓库服务是可配置的），所以默认情况下在 pull 镜像时可以省略 <Registry>，只需要给出镜像的名字和标签，就能在官方 Docker Hub 中定位到一个镜像（当然 Tag 也可以不填，默认情况下使用的是 latest）。

# 默认从 Docker Hub 上拉取镜像时
docker image pull <Repository>:<Tag>

除了官方仓库之外（官方 Docker Hub），还有非官方 Docker Hub。非官方的相当于用户注册了个 Docker ID，使用 Docker 提供的 Docker Hub 功能，可将自己的 Docker 镜像传到 Docker Hub 中自己的镜像仓库服务上。此时，仓库的命名是 <YourDockerID>/<Repository>，因为我们在这个二级仓库下我们才是有操作权限的。

# 从非官方的 Docker Hub 中拉取，仓库前面需要加上 Docker Hub 的用户名或者组织名。
docker image pull <YourDockerID>/<Repository>:<Tag>

另外还有第三方镜像仓库服务，比如阿里运镜像仓库服务这些，这个时候就需要在前面加上第三方镜像仓库服务的域名等，这样才能定位到相应的镜像文件。

# 从第三方仓库服务（非 docker hub）中拉取镜像
docker image pull gcr.io/demp/tu-demp:v2
总的来说 pull 镜像的定位方式是，先根据给定的第一个斜杠前的内容定位到基本镜像仓库服务，这个可以不填，默认情况下不填写是官方 Docker Hub；之后再根据第一个斜杠后面和冒号前面的内容定位到位于该镜像仓库服务中的仓库；最后根据标签找到所需镜像，这个也可以不填，默认是 latest。

# 完整命令
docker image pull <Registry>/<Repository>:<Tag>

# 默认从 Docker Hub 上拉取镜像时
docker image pull <Repository>:<Repository>：<Tag>

# 从非官方的 Docker Hub 中拉取，仓库前面需要加上 Docker Hub 的用户名或者组织名。
docker image pull <YourDockerID>/<Repository>:<Tag>

# 从第三方仓库服务（非 docker hub）中拉取镜像
docker image pull gcr.io/demp/tu-demp:v2

docker image pull alpine:latest	# 从官方 Docker Hub 的 alpine 仓库中拉取标有 latest 标签的镜像
docker image pull ubuntu:latest
docker image pull redis:latest

docker image pull alpine 		# 默认拉取标签为 latest 的镜像

docker image pull mongo:3.3.11	# 拉取非 latest 标签的镜像

docker image pull dawnguo/docker-hexo:alpine  # 从非官方的 Docker Hub 中拉取，仓库前面需要加上 Docker Hub 的用户名或者组织名

docker image rm/prune 删除镜像

# 从 Docker 主机删除镜像，删除操作会在当前主机上删除该镜像以及相关的镜像层。但是，如果某个镜像层被多个镜像共享，那么只有当全部依赖该镜像层的镜像全都删除之后，该镜像层才会删除。
# 另外被删除的镜像上存在运行状态的容器，删除不会被允许，所以需要停止并删除该镜像相关的全部容器之后才能删除镜像。
# 输出内容中：每一个 Deleted：行都表示一个镜像层被删除
docker image rm <ImageID>	# 根据 image id 来删除镜像
docker rmi	# 也可以

docker image rm <ImageID1> <ImageID2> ...	# 删除多个

docker image rm <Repository>:<Tag>	# tag 同样可以省略

docker image rm $(docker image ls -q) -f # 删除本地系统中的全部镜像

docker image prune # 移除全部的 dangling 镜像

docker image prune -a # 额外移除没有被使用的镜像（没有被任何容器使用的镜像）
docker image ls 查看镜像

docker image ls
docker image ls <Repository>	# 显示名为 Repository 的镜像
docker image ls -a	# 显示所有镜像
docker image ls -q # 只返回系统本地拉取的全部镜像 ID 列表
docker image ls --digests # 查看镜像的 SHA256 签名

docker images # 等同于 docker image ls
可以使用 --filter 参数来过滤 docker image ls 命令返回的镜像列表内容，支持四种过滤器：

dangling：可以指定为 true 或者 false，指定 true 仅返回悬虚镜像，指定 false 仅返回非悬虚镜像。
before：需要镜像名称或者 ID 作为参数，返回在指定镜像之前被创建的全部镜像
since：与 before 类似，不过返回的是指定镜像之后创建的全部镜像
label：根据标注（label）的名称或者值，对镜像进行过滤。docker image ls 命令输出中将不显示标注内容。
docker image ls --filter dangling=true# dangling 镜像是指那些没有标签的镜像，在列表中显示 <none>：<none>。通常出现这种情况是因为构建了一个新的镜像，并且为这个镜像打上了已经存在的标签。那么旧镜像就变成了悬虚（dangling）镜像了。
还可以使用 reference 的方式过滤。

# 过滤并只显示标签带 latest 的
docker image ls --filter=reference="*:latest"
使用 --format 来通过 Go 模板对输出内容进行格式化

docker image ls --format "{{.Size}}"# 只返回 Docker 主机上的镜像的大小属性
docker image ls --format "{{.Reposity}}:{{.Tag}}:{{.Size}}"# 只显示仓库、标签和大小
docker search 查找镜像

# docker search 命令允许通过 CLI 的方式搜索 Docker Hub。可通过 "Repository" 字段（仓库名称）的内容进行匹配，并且对返回内容中任意列的值进行过滤。返回的镜像中既有官方的也有非官方的。并且默认情况下只显示 25 行
docker search alpine	# 查找 Repository 字段中带有 alpine 的

docker search apline --filter "is-official=true"
docker search apline --filter "is-automated=true"

docker search apline --limit 30 # 增加返回内容的行数，最多 100 行
docker image inspect

# 查看镜像的组成情况
docker image inspect <ImageID>||<Repository>:<Tag

4.1. 容器周期
容器的生命周期大致可分为 4 个：创建、运行、休眠和销毁。

创建和运行

容器的创建和运行主要使用 docker container run 命名，比如下面的命令会从 Ubuntu:latest 这个镜像中启动 /bin/bash 这个程序。那么 /bin/bash 成为了容器中唯一运行的进程。

docker container run -it ubuntu:latest /bin/bash

休眠和销毁

docker container stop 命令可以让容器进入休眠状态，使用 docker container rm 可以删除容器。删除容器的最佳方式就是先停止容器，然后再删除容器，这样可以给容器中运行的应用/进程一个停止运行并清理残留数据的机会。因为先 stop 的话，docker container stop 命令会像容器内的 PID 1 进程发送 SIGTERM 信号，这样会给进程预留一个清理并优雅停止的机会。如果进程在 10s 的时间内没有终止，那么会发送 SIGKILL 信号强制停止该容器。但是 docker container rm 命令不会友好地发送 SIGTERM ，而是直接发送 SIGKILL 信号。

重启策略

容器还可以配置重启策略，这是容器的一种自我修复能力，可以在指定事件或者错误后重启来完成自我修复。配置重启策略有两种方式，一种是命令中直接传入参数，另一种是在 Compose 文件中声明。下面阐述命令中传入参数的方式，也就是在命令中加入 --restart 标志，该标志会检查容器的退出代码，并根据退出码已经重启策略来决定。Docker 支持的重启策略包括 always、unless-stopped 和 on-failed 四种。

always 策略会一直尝试重启处于停止状态的容器，除非通过 docker container stop 命令明确将容器停止。另外，当 daemon 重启的时候，被 docker container stop 停止的设置了 always 策略的容器也会被重启。

$ docker container run --it --restart always apline sh
# 过几秒之后，在终端中输入 exit，过几秒之后再来看一下。照理来说应该会处于 stop 状态，但是你会发现又处于运行状态了。
unless-stopped 策略和 always 策略是差不多的，最大的区别是，docker container stop 停止的容器在 daemon 重启之后不会被重启。

on-failure 策略会在退出容器并且返回值不会 0 的时候，重启容器。如果容器处于 stopped 状态，那么 daemon 重启的时候也会被重启。另外，on-failure 还接受一个可选的重启次数参数，如--restart=on-failure:5 表示最多重启 5 次。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201106122832.png)

Docker 容器内的进程只对可读写层拥有写权限，其他层对进程而言都是只读的（Read-Only）。

比如想修改一个文件，这个文件会从该读写层下面的只读层复制到该读写层，该文件的只读版本仍然存在，但是已经被读写层中的该文件副本所隐藏了。这种机制被称为写时复制（copy on write）（在 AUFS 等文件系统下，写下层镜像内容就会涉及 COW （Copy-on-Write）技术）。另外，关于 VOLUME 以及容器的 hosts、hostname 、resolv.conf 文件等都会挂载到这里。需要额外注意的是，虽然 Docker 容器有能力在可读写层看到 VOLUME 以及 hosts 文件等内容，但那都仅仅是挂载点，真实内容位于宿主机上。

查看 Docker 情况

docker version		# 当命令的输出包含 Client 和 Server 内容的时候，表示 daemon 已经启动

docker info	# 返回所有容器和镜像的数量、Docker 使用的执行驱动和存储驱动，以及 Docker 的基本配置

service docker status	# 查看 docker 的状态

systemctl is-active docker	# 查看 docker 的状态
容器周期相关操作

# 启动容器最基础的格式，指定了启动所需的镜像以及要运行的应用
# 省略了 <tag>,那么默认是 latest
docker container run <Options> <Repository>:<Tag> <App>	
docker run <Options> <Repository>:<Tag> <App>	# 这个命令也可以

# 启动某个 Ubuntu Linux 容器，并在其中运行 bash shell 作为其应用。
# -it 参数表示将当前 shell 连接到容器的 shell 终端之上，并且与容器具有交互。具体为：-i 表示容器中的 STDIN 是开启的，-t 为要创建的容器分配一个伪 tty 终端
# 在启动的容器中运行某些指令，可能无法正常工作，这是因为大部分容器镜像都是经过高度优化的，有些指令并没有被打包进去。
docker container run -it ubuntu:latest	/bin/bash	

# -d 表示后台模式，告知容器在后台运行
docker container run -d ubuntu sleep 1m	

# 设置容器名字为 percy（合法的名字是可包含：大小写字母、数字、下划线、圆点、横线）
docker container run --name percy -it ubuntu:latest /bin/bash	

# 配置重启策略，采用 always 策略，--restar 标志会检查容器的退出代码
docker container run --restart -it always ubuntu:latest /bin/bash

# -p 80:8080 将 Docker 主机的 80 端口映射到容器内的 8080 端口。当有流量访问主机的 80 端口时
# 流量会直接映射到容器内的 8080 端口。
docker container run -d -p 80:8080 <Repository>:<Tag> <App>

# 在宿主机上随便选择一个位于 49153~65535 之间的一个端口来映射到容器的 80 端口，之后可以通过 docker ps -l 或者 docker port 来查看端口映射情况
docker container run -d -p 80 <Repository>:<Tag> <App>

# 将 Dockerfile 中 EXPOSE 指令的端口都随机映射到主机的端口上，注意是大写的 P
docker container run -d -P <Repository>:<Tag> <App>

# 将容器内的 80 端口绑定到本地宿主机 127.0.0.1 这个 IP 地址的 80 端口上
docker container run -d -p 127.0.0.1:80:80	

# 没有指定要绑定的宿主机端口号，随机绑定到宿主机 127.0.0.1 的一个端口上
docker container run -d -p 127.0.0.1::80	


# 有时不指定要运行的 app 也是可以的，这是因为构建镜像时指定了默认命令。可以通过 docker image inspect 查看，如果有设置了 Cmd 那么表示在基于该镜像启动容器时会默认运行 Cmd。当然，也可以自己指定，但是这种在构建时指定默认命令是一种很普遍的做法，可以简化容器的启动。
docker container run <Repository>:<Tag>

# 在这次运行时覆盖原 Dockerfile 中的 ENTRYPOINT 指令
docker container run --entrypoint <Command> <Repository>:<Tag> <Params>
# 停止运行中的容器，并将状态设置为 Exited(0)，发送 SIGTERM 信号
docker container stop <ContainerName>||<ContainerID>
docker stop <ContainerName>||<ContainerID> # 同理也可以

# 也可以使用 docker kill 命令停止容器，只是发出的是 SIGKILL 信号
docker kill <ContainerName>||<ContainerID>
# 重启处于停止（Exited）状态的容器
docker container start <ContainerName>||<ContainerID>
docker start <ContainerName>||<ContainerID>
# 删除停止运行的容器
docker container rm <ContainerName>||<ContainerID>
docker rm <ContainerName>||<ContainerID>

# 一次性删除运行中的容器，但是建议先停止之后再删除。
docker container rm <ContainerName>||<ContainerID> -f

# 清理掉 Docker 主机上全部运行的容器
docker container rm $(docker container ls -aq) -f
# Docker 1.3 之后允许使用 docker container exec（或者 docker exec）命令在运行状态的容器中，启动一个新进程，也就是会创建新进程。在将 Docker 主机的 Shell 连到一个正在运行中容器的终端十分有用。
docker container exec <options> <ContainerName>/<ContainerID> <app>
docker container exec -it ubuntu bash	# 会在容器内部启动一个新的 Bash Shell，并连接到该 bash
docker exec

# 重新附着到该容器的会话上，比如之前开了一个 shell，之后退出又重新 start 了，那么可以可以使用这个，重新连接之前的 shell
docker attach <ContainerName>||<ContainerID>
Ctrl-PQ 	# 退出容器，但并不终止容器运行。会切回 Docker 主机的 shell，并保持容器在后台运行
查看容器

docker container ls		# 观察当前系统正在运行(UP)状态的容器，如果有 port 选项的话，那么是 host-port:container-port 的格式
docker container ls -a	# 观察当前系统正在运行的容器容器，包括 stop 状态的
docker ps		# 查看当前系统中正在运行的容器
docker ps -a	# 查看当前系统中所有的容器（运行和停止）
dokcer ps -l	# 列出最后一次运行的容器（运行和停止）
docker ps -n x	# 显示最后 x 个容器（运行和停止）
# 查看指定容器的指定端口的映射情况
docker port <ContainerName>||<ContainerID> 80
其他

docker inspect <ContainerName>||<ContainerID>
docker container inspect <ContainerName>||<ContainerID> # 显示容器的配置信息（名称、命令、网络配置等）和运行时信息
docker inspect --format '{{.NetworkSettings.IPAddress}}'# 支持 -f 或者 --format 标志查看选定内容的结果，就跟 image ls 那个一样的

docker logs	# 获取守护式容器的日志
docker logs -f # 监控守护式容器的日志（跟 tail 命令使用差不多）
docker logs -t # 显示守护式容器日志的时间戳

docker top	# 查看容器内部运行的进程

Dockerfile 中的注释行都是以 # 开始的，除注释之外，每一行都是一条指令（使用基本的基于 DSL 语法的指令），指令及其使用的参数格式如下。指令是不区分大小写的，但是通常都采用大写的方式（可读性会更高）。

INSTRCUTION arguments

# 构建出一个叫 web:latest 的镜像，.（点）表示将当前目录作为构建上下文并且当前目录需要包含 Dockerfile
# 如果没有指定标签的话，那么会默认设置一个 latest 标签
docker image build -t web:latest .
# 可以通过 docker image build 的输出内容了解镜像的构建过程，而构建过程的最终结果是返回了新镜像的 ID。其实，构建的每一步都会返回一个镜像的 ID。

构建镜像的过程中会利用缓存

Docker 构建镜像的过程中会利用缓存机制。对于每一条指令，Docker 都会检查缓存中是否检查已经有与该指令对应的镜像层。如果有，即为缓存命中，并且使用这个镜像层；如果没有，则是缓存未命中，Docker 会基于该指令构建新的镜像层。缓存命中能显著加快构建过程。

比如，示例中使用的 Dockerfile。第一条指令告诉 Docker 使用 apline:latest 作为基础镜像。如果主机中已经存在这个镜像，那么构建时就会直接跳转到下一条指令；如果镜像不存在，则会从 Docker Hub 中拉取。



















