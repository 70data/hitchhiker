在容器中管理数据主要有两种方式：
- 数据卷(Volumes)
- 挂载主机目录(Bind mounts)

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20201109221857.png)

数据卷是一个可供一个或多个容器使用的特殊目录，它绕过 UFS，可以提供很多有用的特性：
- 数据卷可以在容器之间共享和重用
- 对数据卷的修改会立马生效
- 对数据卷的更新不会影响镜像
- 数据卷默认会一直存在，即使容器被删除

创建一个数据卷

```shell script
docker volume create my-vol
my-vol
```

查看所有的数据卷

```shell script
docker volume ls
DRIVER              VOLUME NAME
local               my-vol
```

在主机里使用以下命令可以查看指定数据卷的信息

```shell script
docker volume inspect my-vol
[
    {
        "CreatedAt": "2020-11-10T12:28:00+08:00",
        "Driver": "local",
        "Labels": {},
        "Mountpoint": "/var/lib/docker/volumes/my-vol/_data",
        "Name": "my-vol",
        "Options": {},
        "Scope": "local"
    }
]
```

启动一个挂载数据卷的容器。

在用 `docker run` 命令的时候，使用 `--mount` 标记来将数据卷挂载到容器里。
在一次 `docker run` 中可以挂载多个数据卷。

创建一个名为 web 的容器，并加载一个数据卷到容器的 `/usr/share/nginx/html` 目录。

```shell script
docker run -d -P --name web --mount source=my-vol,target=/usr/share/nginx/html nginx:alpine
```

查看卷挂载信息

```shell script
docker inspect web
...
        "Mounts": [
            {
                "Type": "volume",
                "Name": "my-vol",
                "Source": "/var/lib/docker/volumes/my-vol/_data",
                "Destination": "/usr/share/nginx/html",
                "Driver": "local",
                "Mode": "z",
                "RW": true,
                "Propagation": ""
            }
        ],
...
```

删除数据卷

```shell script
docker volume rm my-vol
Error response from daemon: remove my-vol: volume is in use - [c99fd72ae860790d53ba848ff5a916e968243aa6de10204eca6cdadc447bacae]

docker stop web
web

docker volume rm my-vol
Error response from daemon: remove my-vol: volume is in use - [c99fd72ae860790d53ba848ff5a916e968243aa6de10204eca6cdadc447bacae]

docker rm web
web

docker volume rm my-vol
my-vol
```

数据卷是被设计用来持久化数据的。

它的生命周期独立于容器。
Docker 不会在容器被删除后自动删除数据卷，并且也不存在垃圾回收这样的机制来处理没有任何容器引用的数据卷。
如果需要在删除容器的同时移除数据卷。可以在删除容器的时候使用 `docker rm -v` 这个命令。

无主的数据卷可能会占据很多空间，要清理请使用以下命令。

```shell script
docker volume prune
```

