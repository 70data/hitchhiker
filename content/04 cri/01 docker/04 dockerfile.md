三、Dockerfile
Comment

INSTRUCTION arguments
1. FROM
基于哪个base镜像

2. RUN
执行命令并创建新的镜像层,run经常用于安装软件包

3. MAINTAINER
镜像创建者

4. copy
将文件从build context复制到镜像

#1
COPY ["src","dest"]
COPY src dest
#注意：src只能指定build context中的文件
5. CMD
container启动时执行的命令，但是一个Dockerfile中只能有一条CMD命令，多条则只执行最后一条CMD。CMD主要用于container启动时指定的服务

当docker run command的命令匹配到CMD command时，会替换CMD执行的命令。

存在三种使用格式

Exec: CMD [“Command”,”param1”,”param2”]

CMD [“param1”,”param2”] 为ENTRYPOINT提供额外的参数,此时ENTRYPOINT必须使用exec格式

CMD command param1 param2

6. ENTRYPOINT
container启动时执行的命令，但是一个Dockerfile中只能有一条ENTRYPOINT命令，如果多条，则只执行最后一条。ENTRYPOINT没有CMD的可替换特性

ENTRYPOINT的exec格式用于设置执行的命令及其参数，同时可通过CMD提供额外的参数

ENTRYPOINT的shell格式会忽略任何CMD或docker run提供的参数

7. USER
使用哪个用户跑container

8. EXPOSE
container内部服务开启的端口。主机上要用还得在启动container时，做host-container的端口映射：
docker run -d -p 127.0.0.1:3000:22 ubuntu-ssh
container ssh服务的22端口被映射到主机的33301端口

9. ENV
用来设置环境变量，比如：ENV ROOT_PASS tenxcloud

10. ADD
将文件拷贝到container的文件系统对应的路径。ADD只有在build镜像的时候运行一次，后面运行container的时候不会再重新加载了。如果src是一个tar,zip,tgz,xz文件,文件会被自动的解压到dest

11. VOLUME
可以将本地文件夹或者其他container的文件夹挂载到container中。

12. WORKDIR
切换目录用，可以多次切换(相当于cd命令)，对RUN、CMD、ENTRYPOINT生效

13. ONBUILD
ONBUILD 指定的命令在构建镜像时并不执行，而是在它的子镜像中执行

14. 两种方式shell,EXEC指定run,cmd和entrypoint要运行的命令
CMD和ENTRYPOINT建议使用Exec格式

RUN则两种都是可以的







RUN
为了保持 Dockerfile 文件的可读性，以及可维护性，建议将长的或复杂的 RUN指令用反斜杠 \分割成多行。

RUN 指令最常见的用法是安装包用的 apt-get。因为 RUN apt-get指令会安装包，所以有几个问题需要注意。

不要使用 RUN apt-get upgrade 或 dist-upgrade，如果基础镜像中的某个包过时了，你应该联系它的维护者。如果你确定某个特定的包，比如 foo，需要升级，使用 apt-get install -y foo 就行，该指令会自动升级 foo 包。



CMD
CMD指令用于执行目标镜像中包含的软件和任何参数。CMD 几乎都是以 CMD["executable","param1","param2"...]的形式使用。因此，如果创建镜像的目的是为了部署某个服务(比如 Apache)，你可能会执行类似于 CMD["apache2","-DFOREGROUND"]形式的命令。

多数情况下，CMD 都需要一个交互式的 shell (bash, Python, perl 等)，例如 CMD ["perl", "-de0"]，或者 CMD ["PHP", "-a"]。使用这种形式意味着，当你执行类似 docker run-it python时，你会进入一个准备好的 shell 中。

CMD 在极少的情况下才会以 CMD ["param", "param"] 的形式与 ENTRYPOINT协同使用，除非你和你的镜像使用者都对 ENTRYPOINT 的工作方式十分熟悉。

EXPOSE
EXPOSE指令用于指定容器将要监听的端口。因此，你应该为你的应用程序使用常见的端口。

例如，提供 Apache web 服务的镜像应该使用 EXPOSE 80，而提供 MongoDB 服务的镜像使用 EXPOSE 27017。

对于外部访问，用户可以在执行 docker run 时使用一个标志来指示如何将指定的端口映射到所选择的端口。

ENV
为了方便新程序运行，你可以使用 ENV来为容器中安装的程序更新 PATH 环境变量。例如使用ENV PATH /usr/local/nginx/bin:$PATH来确保 CMD["nginx"]能正确运行。

ENV 指令也可用于为你想要容器化的服务提供必要的环境变量，比如 Postgres 需要的 PGDATA。
最后，ENV 也能用于设置常见的版本号，比如下面的示例：

ADD 和 COPY
虽然 ADD和 COPY功能类似，但一般优先使用 COPY。因为它比 ADD 更透明。COPY 只支持简单将本地文件拷贝到容器中，而 ADD 有一些并不明显的功能（比如本地 tar 提取和远程 URL 支持）。因此，ADD的最佳用例是将本地 tar 文件自动提取到镜像中，例如ADD rootfs.tar.xz。

如果你的 Dockerfile 有多个步骤需要使用上下文中不同的文件。单独 COPY 每个文件，而不是一次性的 COPY 所有文件，这将保证每个步骤的构建缓存只在特定的文件变化时失效。例如：

如果将 COPY./tmp/放置在 RUN 指令之前，只要 . 目录中任何一个文件变化，都会导致后续指令的缓存失效。

为了让镜像尽量小，最好不要使用 ADD 指令从远程 URL 获取包，而是使用 curl 和 wget。这样你可以在文件提取完之后删掉不再需要的文件来避免在镜像中额外添加一层。比如尽量避免下面的用法：

上面使用的管道操作，所以没有中间文件需要删除。
对于其他不需要 ADD 的自动提取功能的文件或目录，你应该使用 COPY。

ENTRYPOINT
ENTRYPOINT的最佳用处是设置镜像的主命令，允许将镜像当成命令本身来运行（用 CMD 提供默认选项）。

VOLUME
VOLUME指令用于暴露任何数据库存储文件，配置文件，或容器创建的文件和目录。强烈建议使用 VOLUME来管理镜像中的可变部分和用户可以改变的部分。

USER
如果某个服务不需要特权执行，建议使用 USER 指令切换到非 root 用户。先在 Dockerfile 中使用类似 RUN groupadd -r postgres && useradd -r -g postgres postgres 的指令创建用户和用户组。

注意：在镜像中，用户和用户组每次被分配的 UID/GID 都是不确定的，下次重新构建镜像时被分配到的 UID/GID 可能会不一样。如果要依赖确定的 UID/GID，你应该显示的指定一个 UID/GID。

你应该避免使用 sudo，因为它不可预期的 TTY 和信号转发行为可能造成的问题比它能解决的问题还多。如果你真的需要和 sudo 类似的功能（例如，以 root 权限初始化某个守护进程，以非 root 权限执行它），你可以使用 gosu。

最后，为了减少层数和复杂度，避免频繁地使用 USER 来回切换用户。

WORKDIR
为了清晰性和可靠性，你应该总是在 WORKDIR中使用绝对路径。另外，你应该使用 WORKDIR 来替代类似于 RUN cd ... && do-something 的指令，后者难以阅读、排错和维护。

ONBUILD
格式：ONBUILD <其它指令>。 ONBUILD是一个特殊的指令，它后面跟的是其它指令，比如 RUN, COPY 等，而这些指令，在当前镜像构建时并不会被执行。只有当以当前镜像为基础镜像，去构建下一级镜像的时候才会被执行。Dockerfile 中的其它指令都是为了定制当前镜像而准备的，唯有 ONBUILD 是为了帮助别人定制自己而准备的。

假设我们要制作 Node.js 所写的应用的镜像。我们都知道 Node.js 使用 npm 进行包管理，所有依赖、配置、启动信息等会放到 package.json 文件里。在拿到程序代码后，需要先进行 npm install 才可以获得所有需要的依赖。然后就可以通过 npm start 来启动应用。因此，一般来说会这样写 Dockerfile：








```
# 引用基础镜像
FROM base_image:tag
# 声明变量
ARG arg_key[=default_value1]
# 声明环境变量
ENV env_key=value2
# 构建几乎不变的部分 目录结构\build时依赖的文件和工具包
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
# 容器入口
# 指定容器启动时默认执行的命令
ENTRYPOINT ["/entry.app"]
# 指定容器启动时默认命令的默认参数  
CMD ["--options"]
```

FROM 前的 ARG 只能在 FROM 中使用，如果在 FROM 后也要使用，需要重新声明。ARG 变量的作用范围是 build 阶段 ARG 之后的指令，不会带入镜像。
ENV 环境变量作用范围是 build 阶段 ENV 声明的指令，并且会编入镜像，容器运行时也会这些环境变量也生效。ENV 会产生中间层（layer），被编入镜像，即使使用 unset 也无法去掉。
当 ARG 和 ENV 变量同名时，ENV 环境变量的值会覆盖 ARG 变量。
CMD 和 ENTRYPOINT 中不能使用 ARG 和 ENV 定义的变量。

以 `COPY <src>/ <dest>/` 为例。
`<src>` 是目录时，是否带反斜线都只会复制目录下的所有文件，不会复制目录本身，如果要复制目录本身，需要使用 `<src>` 父目录。
`<src>` 必须在 context 下，不能使用 `../` 跳出 context。
`<dest>` 是目录时，必须带反斜线才会把文件复制到 `<dest>` 下。

优先使用 COPY。

ADD 额外支持：

- `<src>` 是本地 tar 文件等常见的压缩格式时，会自动解包。
- `<src>` 可以是 url，支持从远程拉取。

CMD 单独使用时，用来指定容器启动时默认执行的命令。
ENTRYPOINT 单独使用时，可以完全取代 CMD。ENTRYPOINT 和 CMD 一起使用时，CMD 变成 ENTRYPOINT 的默认参数。
推荐使用 ENTRYPOINT/CMD 的 exec 书写形式，即 `ENTRYPOINT ["entry.app", "arg"]`，因为 shell 书写形式 `ENTRYPOINT entry.app arg` 会额外启动 shell 进程。







FROM

格式为 FROM <image> 或 FROM <image>:<tag>

第一条指令必须为 FROM 指令。并且，如果在同一个 Dockerfile 中创建多个阶段时，可以使用多个 FROM 指令（每个阶段一次）

MAINTAINER

格式为 MAINTAINER <name>，指定维护者信息。已弃用，推荐使用 LABEL

LABEL

给构建的镜像打标签。格式：LABEL <key>=<value> <key>=<value> <key>=<value> ...

RUN

格式为 RUN <command> 或 RUN ["executable", "param1", "param2"]

推荐 RUN 把所有需要执行的 shell 命令写一行

例如：

RUN mkdir /app && \
    echo "Hello World!" && \
    touch /tmp/testfile
不推荐，例如：

RUN mkdir /app
RUN echo "Hello World!"
RUN touch /tmp/testfile
如果 RUN 写多行会增加 docker image 体积

CMD

支持三种格式

CMD ["executable","param1","param2"] 使用 exec 执行，推荐方式；

CMD command param1 param2 在 /bin/sh 中执行，提供给需要交互的应用；

CMD ["param1","param2"] 提供给 ENTRYPOINT 的默认参数；

指定启动容器时执行的命令，每个 Dockerfile 只能有一条 CMD 命令。如果指定了多条命令，只有最后一条会被执行。

EXPOSE

格式为 EXPOSE <port> [<port>...]

声明 Docker 服务端容器暴露的端口号，供外部系统使用。在启动容器时需要通过 -p指定端口号

ENV

格式为 ENV <key> <value>。指定一个环境变量，会被后续 RUN 指令使用，并在容器运行时保持

ADD

格式为 格式为 ADD <src> <dest> ，在 docker ce 17.09以上版本支持 格式为 ADD --chown=<user>:<group> <src> <dest>

COPY

格式为 COPY <src> <dest>，在 docker ce 17.09以上版本支持 格式为 COPY --chown=<user>:<group> <src> <dest>

ENTRYPOINT

支持两种格式：

ENTRYPOINT ["executable", "param1", "param2"]

ENTRYPOINT command param1 param2（shell中执行）

VOLUME

格式为 VOLUME ["/data"]

创建一个可以从本地主机或其它容器挂载的挂载点，用来保持数据不被销毁

USER

格式为 USER daemon

指定运行容器时的用户名或 UID，后续的 RUN 也会使用指定用户

容器不推荐使用 root 权限

WORKDIR

格式为 WORKDIR /path/to/workdir

为后续的 RUN、CMD、ENTRYPOINT 指令配置工作目录

可以使用多个 WORKDIR 指令，后续命令如果参数是相对路径，则会基于之前命令指定的路径。例如

WORKDIR /a
WORKDIR b
WORKDIR c
RUN pwd
则最后输出路径为 /a/b/c

ONBUILD

为他人做嫁衣，格式为 ONBUILD [INSTRUCTION]

配置当前所创建的镜像作为其它新创建镜像的基础镜像时，所执行的操作指令

HEALTHCHECK

健康检查，格式： HEALTHCHECK [选项] CMD <命令>：设置检查容器健康状况的命令 HEALTHCHECK NONE：如果基础镜像有健康检查指令，使用这行可以屏蔽掉其健康检查指令

HEALTHCHECK 支持下列选项：

--interval=<间隔>：两次健康检查的间隔，默认为30秒；

--timeout=<时长>：健康检查命令运行超时时间，如果超过这个时间，本次健康检查就被 视为失败，默认30 秒；

--retries=<次数>：当连续失败指定次数后，则将容器状态视为unhealthy，默认3 次

和CMD ,ENTRYPOINT一样， HEALTHCHECK 只可以出现一次，如果写了多个，只有最后一个生效

ARG

构建参数，格式：ARG<参数名>[=<默认值>]

构建参数 和 ENV的 效果一样，都是设置环境变量。所不同的是，ARG所设置的构建环境的环境变量，在将来容器运行时是不会存在这些环境变量的。但是不要因此就使用ARG保存密码之类的信息，因为docker history还是可以看到所有值的。


Dockerfile 中的注释行都是以 # 开始的，除注释之外，每一行都是一条指令（使用基本的基于 DSL 语法的指令），指令及其使用的参数格式如下。指令是不区分大小写的，但是通常都采用大写的方式（可读性会更高）。

INSTRCUTION arguments

# 构建出一个叫 web:latest 的镜像，.（点）表示将当前目录作为构建上下文并且当前目录需要包含 Dockerfile
# 如果没有指定标签的话，那么会默认设置一个 latest 标签
docker image build -t web:latest .
# 可以通过 docker image build 的输出内容了解镜像的构建过程，而构建过程的最终结果是返回了新镜像的 ID。其实，构建的每一步都会返回一个镜像的 ID。

构建镜像的过程中会利用缓存

Docker 构建镜像的过程中会利用缓存机制。对于每一条指令，Docker 都会检查缓存中是否检查已经有与该指令对应的镜像层。如果有，即为缓存命中，并且使用这个镜像层；如果没有，则是缓存未命中，Docker 会基于该指令构建新的镜像层。缓存命中能显著加快构建过程。

比如，示例中使用的 Dockerfile。第一条指令告诉 Docker 使用 apline:latest 作为基础镜像。如果主机中已经存在这个镜像，那么构建时就会直接跳转到下一条指令；如果镜像不存在，则会从 Docker Hub 中拉取。

RUN vs CMD vs ENTRYPOINT

RUN: 编译时
CMD: 默认参数
ENTRYPOINT: 可执行入口

ENTRYPOINT 存在时，入口为 ENTRYPOINT + CMD
ENTRYPOINT 不存在时，CMD 的第一个参数必须可执行
[“<可执行文件>”, “<参数2>”, “<参数3>”, …] 
<命令> = sh –c “<命令>”

RUN 与 docker build --no-cache
不滥用 ENTRYPOINT 与 CMD

docker build –t <repository>:<tag>
tag的最佳实践
不使用latest
规范的命名


## Build

容器字符集

```
localedef -i zh_CN -f UTF-8 zh_CN.UTF-8
localedef -i zh_CN -f GBK zh_CN.GBK
```

-t 指定 tag，-f 指定 dockerfile

```
docker build -t 360cloud/demo/https:0.1 -f docker/release/Dockerfile.node .
```

可以通过 `--no-cache` 参数设置编译缓存








使用 .dockerignore文件
使用 Dockerfile 构建镜像时最好是将 Dockerfile 放置在一个新建的空目录下。然后将构建镜像所需要的文件添加到该目录中。为了提高构建镜像的效率，你可以在目录下新建一个 .dockerignore文件来指定要忽略的文件和目录。.dockerignore 文件的排除模式语法和 Git 的 .gitignore 文件相似。

构建缓存
在镜像的构建过程中，Docker 根据 Dockerfile 指定的顺序执行每个指令。在执行每条指令之前，Docker 都会在缓存中查找是否已经存在可重用的镜像，如果有就使用现存的镜像，不再重复创建。当然如果你不想在构建过程中使用缓存，你可以在 docker build 命令中使用 --no-cache=true选项。

如果你想在构建的过程中使用了缓存，那么了解什么时候可以什么时候无法找到匹配的镜像就很重要了，Docker中缓存遵循的基本规则如下：

从一个基础镜像开始（FROM 指令指定），下一条指令将和该基础镜像的所有子镜像进行匹配，检查这些子镜像被创建时使用的指令是否和被检查的指令完全一样。如果不是，则缓存失效。

在大多数情况下，只需要简单地对比 Dockerfile 中的指令和子镜像。然而，有些指令需要更多的检查和解释。

对于 ADD 和 COPY 指令，镜像中对应文件的内容也会被检查，每个文件都会计算出一个校验值。这些文件的修改时间和最后访问时间不会被纳入校验的范围。在缓存的查找过程中，会将这些校验和和已存在镜像中的文件校验值进行对比。如果文件有任何改变，比如内容和元数据，则缓存失效。

除了 ADD 和 COPY 指令，缓存匹配过程不会查看临时容器中的文件来决定缓存是否匹配。例如，当执行完 RUN apt-get -y update 指令后，容器中一些文件被更新，但 Docker 不会检查这些文件。这种情况下，只有指令字符串本身被用来匹配缓存。

一旦缓存失效，所有后续的 Dockerfile 指令都将产生新的镜像，缓存不会被使用。









使用小基础镜像(例：alpine)
RUN指令中最好把所有shell命令都放在一起执行，减少Docker层
ADD 或者 COPY 指令时一定要使用--chown=node:node（node:node 分别为用户组和附属组）并且Dockerfile中一定要有node用户，Dockerfile切换用户时不需要使用chown命令修改权限而导致镜像变大
分阶段构建
最好声明Docker镜像签名
使用.dockerignore排除不需要加入Docker镜像目录或者文件
不介意使用root用户






# stage 1
FROM node:13.1.0-alpine as builder

LABEL "name"="YP小站"
LABEL version="node 13.1.0"

# 修改alpine源为阿里源，安装tzdata包并修改为北京时间
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
    && apk --update add --no-cache tzdata \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 声明环境变量
ENV NODE_ENV development

# 声明使用node用户
USER node

# 首次只加入package.json文件，package.json一般不变，这样就可以充分利用Docker Cache，节约安装node包时间
COPY --chown=node:node package.json /app && npm ci

# 声明镜像默认位置
WORKDIR /app

# 加入node代码
ADD --chown=node:node . /app

# build代码
RUN npm run build \
    && mv dist public

# stage 2
# 加入nginx镜像
FROM nginx:alpine

# 拷贝上阶段build静态文件
COPY --from=builder /app/public /app/public

# 拷贝nginx配置文件
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 声明容器端口
EXPOSE 8080

# 启动命令
CMD ["nginx","-g","daemon off;"]








Dockerfile 分为四部分：

基础镜像信息 (FROM)
维护者信息 (LABEL)，不推荐使用 (MAINTAINER)
镜像操作指令 (RUN)
容器启动时执行指令 (CMD)







