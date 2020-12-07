Dockerfile 分为四部分：
- 基础镜像信息(FROM)
- 维护者信息(LABEL)，不推荐使用(MAINTAINER)
- 镜像操作指令(RUN)
- 数据复制(COPY)
- 容器启动时执行指令(CMD)

### FROM

基于哪个 base 镜像。

格式为 `FROM` <image> 或 `FROM` <image>:<tag>

第一条指令必须为 `FROM` 指令。
并且，如果在同一个 Dockerfile 中创建多个阶段时，可以使用多个 `FROM` 指令，每个阶段一次。

### MAINTAINER

镜像创建者。

格式为 `MAINTAINER` <name>，指定维护者信息。

已弃用，推荐使用 LABEL

### LABEL

给构建的镜像打标签。

格式：`LABEL` <key>=<value> <key>=<value> <key>=<value>。

```dockerfile
LABEL authors="js"
```

### WORKDIR

切换目录用，可以多次切换。
相当于 cd 命令，对 `RUN`、`CMD`、`ENTRYPOINT` 生效。

可以使用多个 `WORKDIR` 指令，后续命令如果参数是相对路径，则会基于之前命令指定的路径。

```dockerfile
WORKDIR /a
WORKDIR b
WORKDIR c
RUN pwd
```

最后输出路径为 `/a/b/c`。

为了清晰性和可靠性，应该总是在 `WORKDIR` 中使用绝对路径。
另外，应该使用 `WORKDIR` 来替代类似于 `RUN cd ... && do-something` 的指令，后者难以阅读、排错和维护。

### USER

使用哪个用户跑容器。

格式为 `USER` daemon

指定运行容器时的用户名或 UID，后续的 `RUN` 也会使用指定用户

容器不推荐使用 `root` 权限。
如果某个服务不需要特权执行，建议使用 USER 指令切换到非 root 用户。
先在 Dockerfile 中使用类似 `RUN groupadd -r nginx && useradd -r -g nginx nginx` 的指令创建用户和用户组。

```dockerfile
RUN groupadd -r redis && useradd -r -g redis redis
USER redis
RUN [ "redis-server" ]
```

应该避免使用 `sudo`，因为它不可预期的 `TTY` 和信号转发行为可能造成的问题比它能解决的问题还多。

如果真的需要和 `sudo` 类似的功能，你可以使用 `gosu`。

```dockerfile
# 建立 redis 用户，并使用 gosu 换另一个用户执行命令
RUN groupadd -r redis && useradd -r -g redis redis
# 下载 gosu
RUN wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/1.12/gosu-amd64" \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true
# 设置 CMD，并以另外的用户执行
CMD [ "exec", "gosu", "redis", "redis-server" ]
```

为了减少层数和复杂度，避免频繁地使用 `USER` 来回切换用户。

注意：
在镜像中，用户和用户组每次被分配的 UID/GID 都是不确定的，下次重新构建镜像时被分配到的 UID/GID 可能会不一样。
如果要依赖确定的 UID/GID，应该显式的指定一个 UID/GID。

### ENV

- `ENV` <key> <value>
- `ENV` <key1>=<value1> <key2>=<value2>

用来设置环境变量，比如：`ENV ROOT_PASS tenxcloud`

指定一个环境变量，会被后续 `RUN` 指令使用，并在容器运行时保持。

### ARG

格式 `ARG` <参数名>[=<默认值>]

构建参数和 `ENV` 的效果一样，都是设置环境变量。
所不同的是，`ARG` 所设置的构建环境的环境变量，在将来容器运行时是不会存在这些环境变量的。
但是不要因此就使用 `ARG` 保存密码之类的信息，因为 docker history 还是可以看到所有值的。

Dockerfile 中的 `ARG` 指令是定义参数名称，以及定义其默认值。
该默认值可以在构建命令 docker build 中用 `--build-arg <参数名>=<值>` 来覆盖。

在 1.13 之前的版本，要求 `--build-arg` 中的参数名，必须在 Dockerfile 中用 `ARG` 定义过了。
`--build-arg` 指定的参数，必须在 Dockerfile 中使用了，如果对应参数没有被使用，则会报错退出构建。

从 1.13 开始，这种严格的限制被放开，不再报错退出，而是显示警告信息，并继续构建。
对于使用 CI 系统，用同样的构建流程构建不同的 Dockerfile 的时候比较有帮助，避免构建命令必须根据每个 Dockerfile 的内容修改。

`ARG` 指令有生效范围，如果在 `FROM` 指令之前指定，那么只能用于 `FROM` 指令中。

```dockerfile
ARG DOCKER_USERNAME=library
FROM ${DOCKER_USERNAME}/alpine
RUN set -x ; echo ${DOCKER_USERNAME}
```

使用上述 Dockerfile 会发现无法输出 `${DOCKER_USERNAME}` 变量的值，要想正常输出，你必须在 `FROM` 之后再次指定 `ARG`。

```dockerfile
# 只在 FROM 中生效
ARG DOCKER_USERNAME=library
FROM ${DOCKER_USERNAME}/alpine
# 要想在 FROM 之后使用，必须再次指定
ARG DOCKER_USERNAME=library
RUN set -x ; echo ${DOCKER_USERNAME}
```

对于多阶段构建，尤其要注意这个问题

```dockerfile
# 这个变量在每个 FROM 中都生效
ARG DOCKER_USERNAME=library
FROM ${DOCKER_USERNAME}/alpine
RUN set -x ; echo 1
FROM ${DOCKER_USERNAME}/alpine
RUN set -x ; echo 2
```

对于上述 Dockerfile 两个 `FROM` 指令都可以使用 `${DOCKER_USERNAME}`，对于在各个阶段中使用的变量都必须在每个阶段分别指定。

```dockerfile
ARG DOCKER_USERNAME=library
FROM ${DOCKER_USERNAME}/alpine
# 在FROM 之后使用变量，必须在每个阶段分别指定
ARG DOCKER_USERNAME=library
RUN set -x ; echo ${DOCKER_USERNAME}
FROM ${DOCKER_USERNAME}/alpine
# 在FROM 之后使用变量，必须在每个阶段分别指定
ARG DOCKER_USERNAME=library
RUN set -x ; echo ${DOCKER_USERNAME}
```

### COPY

`COPY` 指令将从构建上下文目录中 `源路径` 的文件/目录复制到新的一层的镜像内的 `目标路径` 位置。

`源路径` 可以是多个，甚至可以是通配符，其通配符规则要满足 Go 的 [filepath.Match](https://golang.org/pkg/path/filepath/#Match) 规则。

```dockerfile
COPY package.json /usr/src/app/
COPY hom* /mydir/
COPY hom?.txt /mydir/
```

`目标路径` 可以是容器内的绝对路径，也可以是相对于工作目录的相对路径。

目标路径不需要事先创建，如果目录不存在会在复制文件前先行创建缺失目录。

此外，还需要注意一点，使用 `COPY` 指令，源文件的各种元数据都会保留。
比如读、写、执行权限、文件变更时间等。
这个特性对于镜像定制很有用，特别是构建相关文件都在使用 Git 进行管理的时候。

如果 Dockerfile 有多个步骤需要使用上下文中不同的文件。
单独 COPY 每个文件，而不是一次性的 COPY 所有文件，这将保证每个步骤的构建缓存只在特定的文件变化时失效。

在使用该指令的时候还可以加上 `--chown=<user>:<group>` 选项来改变文件的所属用户及所属组。

```dockerfile
COPY --chown=myuser:mygroup files* /mydir/
COPY --chown=10:11 files* /mydir/
```

如果源路径为文件夹，复制的时候不是直接复制该文件夹，而是将文件夹中的内容复制到目标路径

### ADD

ADD 指令和 COPY 的格式和性质基本一致。
但在 COPY 基础上增加了一些功能。

`ADD` 只有在 build 镜像的时候运行一次，后面运行容器的时候不会再重新加载了。

`源路径` 可以是一个 URL，这种情况下，Docker 引擎会试图去下载这个链接的文件放到 `目标路径` 去。
下载后的文件权限自动设置为 600，如果这并不是想要的权限，那么还需要增加额外的一层 `RUN` 进行权限调整。
另外，如果下载的是个压缩包，需要解压缩，也一样还需要额外的一层 `RUN` 指令进行解压缩。

`源路径` 为一个 tar 压缩文件的话，压缩格式为 如果src是一个tar、tgz、zip、gzip、bzip2、xz 的情况下，`ADD` 指令将会自动解压缩这个压缩文件到 `目标路径` 去。

```dockerfile
FROM scratch
ADD ubuntu-xenial-core-cloudimg-amd64-root.tar.gz
```

在使用该指令的时候还可以加上 `--chown=<user>:<group>` 选项来改变文件的所属用户及所属组。

```dockerfile
ADD --chown=myuser:mygroup files* /mydir/
ADD --chown=10:11 files* /mydir/
```

尽可能的使用 `COPY`。
因为 `COPY` 的语义很明确，就是复制文件而已，而 `ADD` 则包含了更复杂的功能，其行为也不一定很清晰。

最适合使用 `ADD` 的场合，就是所提及的需要自动解压缩的场合。

另外需要注意的是，`ADD` 指令会令镜像构建缓存失效，从而可能会令镜像构建变得比较缓慢。

### RUN

执行命令并创建新的镜像层，经常用于安装软件包。

为了保持 Dockerfile 文件的可读性，以及可维护性，建议将长的或复杂的 `RUN`指令用反斜杠 `\` 分割成多行。

格式为 `RUN` <command> 或 `RUN` ["executable", "param1", "param2"]。

推荐 `RUN` 把所有需要执行的 shell 命令写一行。

```dockerfile
RUN mkdir /app && \
    echo "Hello World!" && \
    touch /tmp/testfile
```

不推荐

```dockerfile
RUN mkdir /app
RUN echo "Hello World!"
RUN touch /tmp/testfile
```

如果 `RUN` 写多行会增加 docker image 体积。

### VOLUME

可以将本地文件夹或者其他容器的文件夹挂载到容器中。

- `VOLUME` <路径>
- `VOLUME` ["<路径1>", "<路径2>"...]

有数据的应用，其数据文件应该保存于卷(volume)中。

为了防止运行时忘记将动态文件所保存目录挂载为卷，在 Dockerfile 中，可以事先指定某些目录挂载为匿名卷，这样在运行时如果用户不指定挂载，其应用也可以正常运行，不会向容器存储层写入大量数据。

```dockerfile
VOLUME /data
```

运行时可以覆盖这个挂载设置。

```shell script
docker run -d -v mydata:/data xxxx
```

在这行命令中，就使用了 mydata 这个命名卷挂载到了 `/data` 这个位置，替代了 Dockerfile 中定义的匿名卷的挂载配置。

创建一个容器挂载的挂载点，用来保持数据不被销毁。
强烈建议使用 `VOLUME` 来管理镜像中的可变部分和用户可以改变的部分。

### EXPOSE

指定容器将要监听的端口。

格式为 `EXPOSE` <port> [<port>...]

对于外部访问，用户可以在执行 `docker run` 时使用一个标志来指示如何将指定的端口映射到所选择的端口。

```shell script
docker run -d -p 127.0.0.1:3000:22 ubuntu-ssh
```

容器 ssh 服务的 22 端口被映射到主机的 33301 端口。

EXPOSE 指令是声明运行时容器提供服务端口。
这只是一个声明，在运行时并不会因为这个声明应用就会开启这个端口的服务。

在 Dockerfile 中写入这样的声明有两个好处：
- 帮助镜像使用者理解这个镜像服务的守护端口，以方便配置映射。
- 在运行时使用随机端口映射时，也就是 `docker run -P` 时，会自动随机映射 EXPOSE 的端口。

要将 `EXPOSE` 和在运行时使用 `-p` 区分开来。
`-p`，是映射宿主端口和容器端口，就是将容器的对应端口服务公开给外界访问。
`EXPOSE` 仅仅是声明容器打算使用什么端口而已，并不会自动在宿主进行端口映射。

### CMD

- shell 格式，`CMD` <命令>
- exec 格式，`CMD` ["可执行文件", "参数1", "参数2"...]。
- 参数列表格式，`CMD` ["参数1", "参数2"...]，在指定了 `ENTRYPOINT` 指令后，用 `CMD` 指定具体的参数。

`CMD` 就是用于指定默认的容器主进程的启动命令的。

在运行时可以指定新的命令来替代镜像设置中的这个默认命令。
比如，ubuntu 镜像默认的 `CMD` 是 `/bin/bash`，如果直接 `docker run -it ubuntu` 的话，会直接进入 `bash`。
可以在运行时指定运行别的命令，如 `docker run -it ubuntu cat /etc/os-release`。这就是用 `cat /etc/os-release` 命令替换了默认的 `/bin/bash` 命令了，输出了系统版本信息。

推荐使用 exec 格式，这类格式在解析时会被解析为 JSON 数组，因此一定要使用双引号 "，而不要使用单引号。

如果使用 shell 格式的话，实际的命令会被包装为 `sh -c` 的参数的形式进行执行。

`CMD echo $HOME` 在执行的时候，会被变更为 `CMD [ "sh", "-c", "echo $HOME" ]`。

##### 前台执行

Docker 不是虚拟机，容器中的应用都应该以前台执行。
而不是像虚拟机、物理机里面那样，用 systemd 去启动后台服务，容器内没有后台服务的概念。

`CMD service nginx start` 命令会让容器执行后就立即退出了。

对于容器而言，其启动程序就是容器应用进程，容器就是为了主进程而存在的，主进程退出，容器就失去了存在的意义，从而退出，其它辅助进程不是它需要关心的东西。

`CMD service nginx start` 会被理解为 `CMD [ "sh", "-c", "service nginx start"]`，因此主进程实际上是 sh。
那么当 `CMD service nginx start` 命令结束后，sh 也就结束了，sh 作为主进程退出了，自然就会令容器退出。

正确的做法是直接执行 nginx 可执行文件，并且要求以前台形式运行。

```dockerfile
CMD ["nginx", "-g", "daemon off;"]
```

1 个 Dockerfile 中只能有一条 `CMD` 命令，多条则只执行最后一条 `CMD`。

当 `docker run command` 的命令匹配到 `CMD command` 时，会替换 `CMD` 执行的命令。

### ENTRYPOINT

支持两种格式：
- shell 格式，`ENTRYPOINT` <命令>
- exec 格式，`ENTRYPOINT` ["可执行文件", "参数1", "参数2"...]

容器启动时执行的命令，但是一个 Dockerfile 中只能有一条 `ENTRYPOINT` 命令。
如果多条，则只执行最后一条。

`ENTRYPOINT` 的 shell 格式会忽略任何 `CMD` 或 `docker run` 提供的参数。

`ENTRYPOINT` 的 exec 格式用于设置执行的命令及其参数，同时可通过 `CMD` 提供额外的参数。

`ENTRYPOINT` 没有 `CMD` 的可替换特性。
`ENTRYPOINT` 单独使用时，可以完全取代 `CMD`。

`ENTRYPOINT` 和 `CMD` 一起使用时，`CMD` 变成 `ENTRYPOINT` 的默认参数。

推荐使用 `ENTRYPOINT`/`CMD` 的 exec 书写形式，即 `ENTRYPOINT` ["entry.app", "arg"]。
因为 shell 书写形式会额外启动 shell 进程。

`ENTRYPOINT` 的最佳用处是设置镜像的主命令，允许将镜像当成命令本身来运行，用 `CMD` 提供默认选项。

- `ENTRYPOINT` 存在时，入口为 `ENTRYPOINT` + `CMD`
- `ENTRYPOINT` 不存在时，`CMD` 的第一个参数必须可执行

### ONBUILD

`ONBUILD` 指定的命令在构建镜像时并不执行，而是在它的子镜像中执行。

格式为 `ONBUILD` [INSTRUCTION]。

`ONBUILD` 是一个特殊的指令，它后面跟的是其它指令，比如 `RUN`、`COPY` 等，而这些指令，在当前镜像构建时并不会被执行。
只有当以当前镜像为基础镜像，去构建下一级镜像的时候才会被执行。

Dockerfile 中的其它指令都是为了定制当前镜像而准备的，唯有 `ONBUILD` 是为了构建下一级镜像而准备的。

假设要制作 Node.js 所写的应用的镜像。
Node.js 使用 npm 进行包管理，所有依赖、配置、启动信息等会放到 `package.json` 文件里。
在拿到程序代码后，需要先进行 `npm install` 才可以获得所有需要的依赖。
然后就可以通过 `npm start` 来启动应用。

```dockerfile
FROM node:slim
RUN mkdir /app
WORKDIR /app
COPY ./package.json /app
RUN [ "npm", "install" ]
COPY . /app/
CMD [ "npm", "start" ]
```

构建好镜像后，就可以直接拿来启动容器运行。

如果还有第二个 Node.js 项目也差不多呢？
好吧，那就再把这个 Dockerfile 复制到第二个项目里。
那如果有第三个项目呢？再复制么？文件的副本越多，版本控制就越困难。

```dockerfile
FROM node:slim
RUN mkdir /app
WORKDIR /app
ONBUILD COPY ./package.json /app
ONBUILD RUN [ "npm", "install" ]
ONBUILD COPY . /app/
CMD [ "npm", "start" ]
```

各个项目的 Dockerfile 就变成了简单的引用。

```dockerfile
FROM my-node
```

## Dockerfile 最佳实践

```dockerfile
# 引用基础镜像
FROM base_image:tag
# 声明变量
ARG arg_key=default_value1
# 声明环境变量
ENV env_key=value2
# 构建几乎不变的部分 build 时依赖的文件和工具包
COPY src dst
RUN command1 && command2
# 设置工作目录
WORKDIR /path/to/work/dir
# 构建较少变动的部分 应用的依赖的文件、依赖的包
COPY src dst
RUN command3 && command4
# 构建经常变动的部分 应用的编译生成
COPY src dst
RUN command5 && command6
# 容器入口 指定容器启动时默认执行的命令
ENTRYPOINT ["/entry.app"]
# 指定容器启动时默认命令的默认参数
CMD ["--options"]
```

## Build

可以通过 docker image build 的输出内容了解镜像的构建过程，而构建过程的最终结果是返回了新镜像的 ID，构建的每一步都会返回一个镜像的 ID。

- `-t` 指定 tag
- `-f` 指定 dockerfile

`docker build –t <Repository>:<Tag>`，尽量不使用 `latest`。

容器字符集

```shell script
localedef -i zh_CN -f UTF-8 zh_CN.UTF-8
localedef -i zh_CN -f GBK zh_CN.GBK
```

##### 构建缓存

在镜像的构建过程中，Docker 根据 Dockerfile 指定的顺序执行每个指令。
在执行每条指令之前，Docker 都会在缓存中查找是否已经存在可重用的镜像，如果有就使用现存的镜像，不再重复创建。

如果不想在构建过程中使用缓存，可以在 `docker build` 命令中使用 `--no-cache=true` 选项。

Docker 中缓存遵循的基本规则如下：
1. 从一个基础镜像开始，`FROM` 指令指定，下一条指令将和该基础镜像的所有子镜像进行匹配，检查这些子镜像被创建时使用的指令是否和被检查的指令完全一样。
如果不是，则缓存失效。
2. 在大多数情况下，只需要简单地对比 Dockerfile 中的指令和子镜像。
然而，有些指令需要更多的检查和解释。
3. 对于 `ADD` 和 `COPY` 指令，镜像中对应文件的内容也会被检查，每个文件都会计算出一个校验值。
这些文件的修改时间和最后访问时间不会被纳入校验的范围。
在缓存的查找过程中，会将这些校验和和已存在镜像中的文件校验值进行对比。
如果文件有任何改变，比如内容和元数据，则缓存失效。
4. 除了 `ADD` 和 `COPY` 指令，缓存匹配过程不会查看临时容器中的文件来决定缓存是否匹配。
例如，当执行完 `RUN apt-get -y update` 指令后，容器中一些文件被更新，但 Docker 不会检查这些文件。这种情况下，只有指令字符串本身被用来匹配缓存。
5. 一旦缓存失效，所有后续的 Dockerfile 指令都将产生新的镜像，缓存不会被使用。

##### .dockerignore

使用 Dockerfile 构建镜像时最好是将 Dockerfile 放置在一个新建的空目录下。
然后将构建镜像所需要的文件添加到该目录中。
为了提高构建镜像的效率，可以在目录下新建一个 .dockerignore 文件来指定要忽略的文件和目录。

.dockerignore 文件的排除模式语法和 Git 的 .gitignore 文件相似。

## 多阶段构建

```go
package main

import (
	"github.com/gin-gonic/gin"
	"net/http"
)

func main() {
	router := gin.Default()
	router.GET("/ping", func(c *gin.Context) {
		c.String(http.StatusOK, "PONG")
	})
	router.Run(":8080")
}
```

最终的目的都是将最终的可执行文件放到一个最小的镜像中去执行。

怎样得到最终的编译好的文件呢？
基于 Docker 的指导思想，需要在一个标准的容器中编译，比如在一个 Ubuntu 镜像中先安装编译的环境。
然后编译，最后也在该容器中执行即可。

如果想把编译后的文件放置到 alpine 镜像中执行呢？
得通过上面的 Ubuntu 镜像将编译完成的文件通过 volume 挂载到主机上。
然后再将这个文件挂载到 alpine 镜像中去。

这种解决方案理论上肯定是可行的，但是这样的话在构建镜像的时候就得定义两步了。
第一步是先用一个通用的镜像编译镜像。
第二步是将编译后的文件复制到 alpine 镜像中执行，而且通用镜像编译后的文件在 alpine 镜像中不一定能执行。

定义编译阶段的镜像，保存为 Dockerfile.build。

```dockerfile
FROM golang:1.14-alpine
WORKDIR $GOPATH/src/$CODEPATH
COPY . .
RUN go mod init gin
RUN go mod edit -require github.com/gin-gonic/gin@latest
RUN GO111MODULE=on CGO_ENABLED=0 GOOS=linux GOPROXY=https://mirrors.aliyun.com/goproxy/ go build -o /opt/app app.go
```

定义 alpine 镜像，保存为 Dockerfile.run。

```dockerfile
FROM centos:7.6.1810
WORKDIR /opt
COPY app .
RUN chmod +x /opt/app
CMD [ "app" ]
```

据执行步骤，可以简单定义成一个脚本。

```shell script
#!/bin/sh
docker build -t js/docker-multi-stage-demo:build . -f Dockerfile.build

docker create --name extract js/docker-multi-stage-demo:build
docker cp extract:/opt/app ./app
docker rm -f extract

docker build --no-cache -t js/docker-multi-stage-demo:run . -f Dockerfile.run
rm ./app
```

有没有一种更加简单的方式来实现上面的镜像构建过程呢？
Docker 17.05 版本以后，官方就提供了一个新的特性 Multi-stage builds(多阶段构建)。

使用多阶段构建，可以在一个 Dockerfile 中使用多个 `FROM` 语句。
每个 `FROM` 指令都可以使用不同的基础镜像，并表示开始一个新的构建阶段。

```dockerfile
# build
FROM golang:1.14-alpine as builder
WORKDIR $GOPATH/src/$CODEPATH
COPY . .
RUN go mod init gin
RUN go mod edit -require github.com/gin-gonic/gin@latest
RUN GO111MODULE=on CGO_ENABLED=0 GOOS=linux GOPROXY=https://mirrors.aliyun.com/goproxy/ go build -o /opt/app app.go

# build server
FROM centos:7.6.1810
WORKDIR /opt
COPY --from=builder /opt/app .
RUN chmod +x /opt/app
CMD [ "app" ]
```

```shell script
docker build -t js/docker-multi-stage-demo:latest .
```

## Dockerfile 应用

```dockerfile
FROM ubuntu:18.04
RUN apt-get update \
    && apt-get install -y curl \
    && rm -rf /var/lib/apt/lists/*
CMD [ "curl", "-s", "http://myip.ipip.net" ]
```

构建 `docker build -t myip .`。

需要查询当前公网 IP。

```shell script
docker run myip
当前 IP 61.148.226.66 来自 北京市 联通
```

可以直接把镜像当做命令使用了。
不过命令总有参数，如果希望加参数呢？比如从上面的 `CMD` 中可以看到实质的命令是 `curl`，那么如果我们希望显示 `HTTP` 头信息，就需要加上 `-i` 参数。

可以直接加 -i 参数给 docker run myip 么？

```shell script
docker run myip -i
docker: Error response from daemon: invalid header field value "oci runtime error: container_linux.go:247: starting container process caused \"exec: \\\"-i\\\": executable file not found in $PATH\"\n".
```

执行文件找不到的报错，`executable file not found`。
跟在镜像名后面的是 `command`，运行时会替换 `CMD` 的默认值。
因此这里的 `-i` 替换了原来的 `CMD`，而不是添加在原来的 `curl -s http://myip.ipip.net` 后面。
而 `-i` 根本不是命令，所以自然找不到。

```dockerfile
FROM ubuntu:18.04
RUN apt-get update \
    && apt-get install -y curl \
    && rm -rf /var/lib/apt/lists/*
ENTRYPOINT [ "curl", "-s", "http://myip.ipip.net" ]
```

```shell script
docker run myip -i
HTTP/1.1 200 OK
Server: nginx/1.8.0
Date: Tue, 22 Nov 2016 05:12:40 GMT
Content-Type: text/html; charset=UTF-8
Vary: Accept-Encoding
X-Powered-By: PHP/5.6.24-1~dotdeb+7.1
X-Cache: MISS from cache-2
X-Cache-Lookup: MISS from cache-2:80
X-Cache: MISS from proxy-2_6
Transfer-Encoding: chunked
Via: 1.1 cache-2:80, 1.1 proxy-2_6:8006
Connection: keep-alive
当前 IP 61.148.226.66 来自 北京市 联通
```

因为当存在 `ENTRYPOINT` 后，`CMD` 的内容将会作为参数传给 `ENTRYPOINT`。
而这里 `-i` 就是新的 `CMD`，因此会作为参数传给 `curl`。

