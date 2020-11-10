## 目录结构

```shell script
cd /var/lib/docker

ll
total 48
drwx------  2 root root 4096 Nov  5 19:40 builder
drwx--x--x  4 root root 4096 Nov  5 19:40 buildkit
drwx------  8 root root 4096 Nov  8 14:13 containers
drwx------  3 root root 4096 Nov  5 19:40 image
drwxr-x---  3 root root 4096 Nov  5 19:40 network
drwx------ 20 root root 4096 Nov  8 14:13 overlay2
drwx------  4 root root 4096 Nov  5 19:40 plugins
drwx------  2 root root 4096 Nov  7 15:16 runtimes
drwx------  2 root root 4096 Nov  5 19:40 swarm
drwx------  2 root root 4096 Nov  8 12:22 tmp
drwx------  2 root root 4096 Nov  5 19:40 trust
drwx------  2 root root 4096 Nov  5 19:40 volumes
```

- `/var/lib/docker/containers/` 容器信息。
- `/var/lib/docker/tmp` docker 临时目录。
- `/var/lib/docker/trust` docker 信任目录。
- `/var/lib/docker/volumes` docker 卷目录。

## 存储流程

![images](https://70data.oss-cn-beijing.aliyuncs.com/note/20201109225048.png)

![images](http://70data.net/upload/kubernetes/640-3.png)

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201106122832.png)

### rootfs

rootfs 只是一个操作系统所包含的文件、配置和目录，并不包括操作系统内核。

在 Linux 操作系统中，这两部分是分开存放的，操作系统只有在开机启动时才会加载指定版本的内核镜像。

rootfs 里打包的不只是应用，而是整个操作系统的文件和目录，也就意味着，应用以及它运行所需要的所有依赖，都被封装在了一起。

Docker 容器内的进程只对可读写层拥有写权限，其他层对进程而言都是只读的(Read-Only)。

比如想修改一个文件，这个文件会从该读写层下面的只读层复制到该读写层，该文件的只读版本仍然存在，但是已经被读写层中的该文件副本所隐藏了。
这种机制被称为写时复制(copy on write)。

另外，关于 VOLUME 以及容器的 hosts、hostname、resolv.conf 文件等都会挂载到这里。

需要额外注意的是，虽然 Docker 容器有能力在可读写层看到 VOLUME 以及 hosts 文件等内容，但那都仅仅是挂载点，真实内容位于宿主机上。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201106210637.png)

- 最下层是 lower 层，也是只读/镜像层
- upper 是容器的读写层，采用了写时复制机制，只有对文件进行修改才会将文件拷贝到 upper 层，之后所有的修改操作都会对 upper 层的副本进行修改
- upper 并列还有 work 层，它的作用是充当一个中间层的作用，每当对 upper 层里面的副本进行修改时，会先当到 work，然后再从 work 移动 upper 层
- 最上层是 merged，是一个统一图层，从 merged 可以看到 lower、upper、work 中所有数据的整合，整个容器展现出来的就是 merged 层。

### Overlay2

![images](http://70data.net/upload/kubernetes/igF3VQg2c-4ckZgi-K2WwQ.webp)

OverlayFS 将单个 Linux 主机上的两个目录合并成一个目录。
这些目录被称为层，统一过程被称为联合挂载。

OverlayFS 底层目录称为 lower，高层目录称为 upper，合并统一视图称为 merged。

```
                   ├───────────────────────────────────│
  Container Mount  │ FILE 1 │ FILE 2 │ FILE 3 │ FILE 4 │       "merged"
                   ├────↑────────↑────────↑───────↑────│
  Container layer  │    ↑   │ FILE 2 │    ↑   │ FILE 4 │       "upper"
                   ├────↑─────────────────↑────────────│
     Image layer   │ FILE 1 | FILE 2 | FILE 3 |        │       "lower"
                   ├───────────────────────────────────│
```

#### image layer 和 OverlayFS

每一个 Docker image 都是由一系列 read-only layer 组成的。

Image layer 的内容都存储在 Docker hosts filesystem 的 /var/lib/docker/overlay2 下面。

如果在没有拉取任何镜像的前提下,可以发现没有存储任何内容的

```shell script
ll /var/lib/docker/overlay2
total 4
drwx------ 2 root root 4096 Nov  5 19:40 l # 这里面都是软连接文件目录的简写标识，这个主要是为了避免 mount 时候页大小的限制
```

接下来拉取 `ubuntu:18.04` 镜像

```shell script
docker pull ubuntu:18.04
18.04: Pulling from library/ubuntu
171857c49d0f: Pull complete
419640447d26: Pull complete
61e52f862619: Pull complete
Digest: sha256:646942475da61b4ce9cc5b3fadb42642ea90e5d0de46111458e100ff2c7031e6
Status: Downloaded newer image for ubuntu:18.04
docker.io/library/ubuntu:18.04

cd /var/lib/docker/overlay2

tree . -L 3
.
├── 4e4a9d3a47560ea8d028d6f3407e9e4d8fa2ebbaa3ef3ae565c1f07a3241542b
│ ├── committed
│ ├── diff
│ │ ├── bin
│ │ ├── boot
│ │ ├── dev
│ │ ├── etc
│ │ ├── home
│ │ ├── lib
│ │ ├── lib64
│ │ ├── media
│ │ ├── mnt
│ │ ├── opt
│ │ ├── proc
│ │ ├── root
│ │ ├── run
│ │ ├── sbin
│ │ ├── srv
│ │ ├── sys
│ │ ├── tmp
│ │ ├── usr
│ │ └── var
│ └── link
├── 522d0e9650e08fc19e76dce7d45efe73e071be925868c8374e3e971d3b6948ce
│ ├── committed
│ ├── diff
│ │ ├── etc
│ │ ├── sbin
│ │ ├── usr
│ │ └── var
│ ├── link
│ ├── lower
│ └── work
├── 9a72fd9eb1565b6cb6112fbf8ed1bacdb818d871650d6f37baf4ecf1eaf889e9
│ ├── diff
│ │ └── run
│ ├── link
│ ├── lower
│ └── work
└── l
    ├── 3P7AELS3DXCFMIG2XCMOC7G53A -> ../9a72fd9eb1565b6cb6112fbf8ed1bacdb818d871650d6f37baf4ecf1eaf889e9/diff
    ├── RLZN5GOVMEKZ73WRHXXQGLOC5F -> ../522d0e9650e08fc19e76dce7d45efe73e071be925868c8374e3e971d3b6948ce/diff
    └── SGY3PJZFGC6CM32Q347WLAZCET -> ../4e4a9d3a47560ea8d028d6f3407e9e4d8fa2ebbaa3ef3ae565c1f07a3241542b/diff
36 directories, 7 files
```

1. 可以看到 `ubuntu:18.04` 镜像一共有 3 个 layer，每层的 diff 即是文件系统在统一挂载时的挂载点
2. l 文件夹下都是链接各个 layer 的软连接
3. 查看 `4e4a9d3a47560ea8d028d6f3407e9e4d8fa2ebbaa3ef3ae565c1f07a3241542b` 这个目录，可以看到已经基本系统的雏形了
4. lower 文件描述了层序的组织关系，前一个 layer 依靠后一个 layer

```shell script
cat 9a72fd9eb1565b6cb6112fbf8ed1bacdb818d871650d6f37baf4ecf1eaf889e9/lower
l/RLZN5GOVMEKZ73WRHXXQGLOC5F:l/SGY3PJZFGC6CM32Q347WLAZCET
```

### 查看容器运行起来后的变化

以 `ubuntu:18.04` 为基础镜像，创建一个名为 `test-ubuntu` 的镜像。
这个镜像只是在 `/tmp` 文件夹中添加了 `Hello World` 文件。
可以用 Dockerfile 来实现。

```Dockerfile
FROM ubuntu:18.04
RUN echo "Hello World" > /tmp/newfile
```

执行构建镜像

```shell script
docker build -t test-ubuntu .
Sending build context to Docker daemon  2.048kB
Step 1/2 : FROM ubuntu:18.04
 ---> 56def654ec22
Step 2/2 : RUN echo "Hello World" > /tmp/newfile
 ---> Running in a44c1b5a2970
Removing intermediate container a44c1b5a2970
 ---> 9d045ed6f9c3
Successfully built 9d045ed6f9c3
Successfully tagged test-ubuntu:latest
```

然后执行 `docker history test-ubuntu` 可以清楚查看到 `test-ubuntu` 的构建过程。

```shell script
docker history test-ubuntu
IMAGE               CREATED             CREATED BY                                      SIZE                COMMENT
9d045ed6f9c3        40 seconds ago      /bin/sh -c echo "Hello World" > /tmp/newfile    12B
56def654ec22        6 weeks ago         /bin/sh -c #(nop)  CMD ["/bin/bash"]            0B
<missing>           6 weeks ago         /bin/sh -c mkdir -p /run/systemd && echo 'do…   7B
<missing>           6 weeks ago         /bin/sh -c [ -z "$(apt-get indextargets)" ]     0B
<missing>           6 weeks ago         /bin/sh -c set -xe   && echo '#!/bin/sh' > /…   745B
<missing>           6 weeks ago         /bin/sh -c #(nop) ADD file:4974bb5483c392fb5…   63.2MB
```

从输出中可以看到 `9d045ed6f9c3 image layer` 位于最上层，只有 `12B` 大小。

```shell script
/bin/sh -c echo "Hello World" > /tmp/newfile
```

最下面的四层 image layer 则是构成 `ubuntu:18.04` 镜像的 4 个 image layer。

标记为 `<missing>` 的 layer，是因为在 Docker v1.10 版本之前，每次都会创建一个新的图层作为 commit 操作的结果，Docker 也会创建一个相应的镜像，但很多图层其实是缓存的中间层，并不算是最终的镜像。
所以从 Docker v1.10 开始，一个镜像可以包含多个图层，并且显示父级镜像的 sha256 值，其他图层则用 `<missing>` 代替。

查看 `test-ubuntu` 的存储信息。

```shell script
docker inspect test-ubuntu
[
    {
        "Id": "sha256:9d045ed6f9c318551349a8136480389a67f9752fa0f8d714e78dd68efd03d008",
        "RepoTags": [
            "test-ubuntu:latest"
        ],
        "RepoDigests": [],
        "Parent": "sha256:56def654ec22f857f480cdcc640c474e2f84d4be2e549a9d16eaba3f397596e9",
        "Comment": "",
        "Created": "2020-11-07T08:26:48.431629907Z",
        "Container": "a44c1b5a2970db288542f5c3d03216e22b4633f145e2188e1c21a285e07d9911",
        "ContainerConfig": {
            "Hostname": "",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "Tty": false,
            "OpenStdin": false,
            "StdinOnce": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            ],
            "Cmd": [
                "/bin/sh",
                "-c",
                "echo \"Hello World\" > /tmp/newfile"
            ],
            "Image": "sha256:56def654ec22f857f480cdcc640c474e2f84d4be2e549a9d16eaba3f397596e9",
            "Volumes": null,
            "WorkingDir": "",
            "Entrypoint": null,
            "OnBuild": null,
            "Labels": null
        },
        "DockerVersion": "19.03.4",
        "Author": "",
        "Config": {
            "Hostname": "",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "Tty": false,
            "OpenStdin": false,
            "StdinOnce": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            ],
            "Cmd": [
                "/bin/bash"
            ],
            "ArgsEscaped": true,
            "Image": "sha256:56def654ec22f857f480cdcc640c474e2f84d4be2e549a9d16eaba3f397596e9",
            "Volumes": null,
            "WorkingDir": "",
            "Entrypoint": null,
            "OnBuild": null,
            "Labels": null
        },
        "Architecture": "amd64",
        "Os": "linux",
        "Size": 63245650,
        "VirtualSize": 63245650,
        "GraphDriver": {
            "Data": {
                "LowerDir": "/var/lib/docker/overlay2/9a72fd9eb1565b6cb6112fbf8ed1bacdb818d871650d6f37baf4ecf1eaf889e9/diff:/var/lib/docker/overlay2/522d0e9650e08fc19e76dce7d45efe73e071be925868c8374e3e971d3b6948ce/diff:/var/lib/docker/overlay2/4e4a9d3a47560ea8d028d6f3407e9e4d8fa2ebbaa3ef3ae565c1f07a3241542b/diff",
                "MergedDir": "/var/lib/docker/overlay2/a479c799173cbea6c798d834658db0f44ac34c10fc809153a27aa70ce37825a9/merged",
                "UpperDir": "/var/lib/docker/overlay2/a479c799173cbea6c798d834658db0f44ac34c10fc809153a27aa70ce37825a9/diff",
                "WorkDir": "/var/lib/docker/overlay2/a479c799173cbea6c798d834658db0f44ac34c10fc809153a27aa70ce37825a9/work"
            },
            "Name": "overlay2"
        },
        "RootFS": {
            "Type": "layers",
            "Layers": [
                "sha256:80580270666742c625aecc56607a806ba343a66a8f5a7fd708e6c4e4c07a3e9b",
                "sha256:3fd9df55318470e88a15f423a7d2b532856eb2b481236504bf08669013875de1",
                "sha256:7a694df0ad6cc5789a937ccd727ac1cda528a1993387bf7cd4f3c375994c54b6",
                "sha256:1ff920b422f3cdc30802e217fa71fd93a9e331bf257ee2041a27a779a012ed26"
            ]
        },
        "Metadata": {
            "LastTagTime": "2020-11-07T16:26:48.448884582+08:00"
        }
    }
]
```

从 `GraphDriver.Data` 可以看出新创建的图层在 `/var/lib/docker/overlay2/a479c799173cbea6c798d834658db0f44ac34c10fc809153a27aa70ce37825a9`

```shell script
# 进入目录
cd /var/lib/docker/overlay2/a479c799173cbea6c798d834658db0f44ac34c10fc809153a27aa70ce37825a9

# 查看目录
tree .
.
├── diff
│ └── tmp
│     └── newfile
├── link
├── lower
└── work
3 directories, 3 files
```

在 `diff/` 层下面多了一个 `tmp/newfile` 文件。
在创建容器的时候，会根据 LowerDir -> UpperDir/WorkDir -> MergedDir 层最终在 MergedDir 层展示出来。

### lxcfs

top 是从 `/prof/stats` 目录下获取数据，所以容器不挂载宿主机的该目录就可以直接使用 top 命令查看容器内部信息。

lxcfs 是把宿主机的 `/var/lib/lxcfs/proc/memoinfo` 文件挂载到 Docker 容器的 `/proc/meminfo` 位置。
容器中进程读取相应文件内容时，lxcfs 的 FUSE 实现会从容器对应的 Cgroup 中读取正确的内存限制。从而使得应用获得正确的资源约束设定。

