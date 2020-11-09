## 拉取镜像

```shell script
docker image pull <Registry>/<Repository>:<Tag>
```

在 `pull` 镜像的时候，需要给出镜像仓库服务的网络地址、镜像名以及标签即可定位到某个镜像。

- <Registry> 镜像仓库服务
- <Repository> 镜像仓库
- <Tag> 这个仓库中镜像的版本

由于 Docker 客户端的镜像仓库服务默认使用官方 Docker hub(默认镜像仓库服务是可配置的)，所以默认情况下在 `pull` 镜像时可以省略 <Registry>，只需要给出镜像的名字和标签，就能在官方 Docker Hub 中定位到一个镜像。
当然 Tag 也可以不填，默认情况下使用的是 latest。

```shell script
# 默认从 Docker Hub 上拉取镜像
docker image pull <Repository>:<Tag>
```

### 从第三方仓库服务中拉取镜像

除了官方仓库(Docker Hub)之外，还有非官方仓库。

```shell script
docker image pull gcr.io/demp/tu-demp:v2
```

总的来说 `pull` 镜像的定位方式是，先根据给定的第一个斜杠前的内容定位到基本镜像仓库服务，这个可以不填，默认情况下不填写是官方 Docker Hub。
之后再根据第一个斜杠后面和冒号前面的内容定位到位于该镜像仓库服务中的仓库。
最后根据标签找到所需镜像，这个也可以不填，默认是 latest。

## 删除镜像

从 Docker 主机删除镜像，删除操作会在当前主机上删除该镜像以及相关的镜像层。
如果某个镜像层被多个镜像共享，那么只有当全部依赖该镜像层的镜像全都删除之后，该镜像层才会删除。
另外，被删除的镜像上存在运行状态的容器，删除不会被允许，所以需要停止并删除该镜像相关的全部容器之后才能删除镜像。

```shell script
docker image rm test-ubuntu
Error response from daemon: conflict: unable to remove repository reference "test-ubuntu" (must force) - container de3a25e74907 is using its referenced image 9d045ed6f9c3

docker rmi -f test-ubuntu
Untagged: test-ubuntu:latest
Deleted: sha256:9d045ed6f9c318551349a8136480389a67f9752fa0f8d714e78dd68efd03d008
```

输出内容中每一个 Deleted 行都表示一个镜像层被删除。

`docker rmi` 等价于 `docker image rm`。

## 查看镜像

##### dangling

悬虚镜像，name 为 none , tag 为 none。

通常出现这种情况是因为构建了一个新的镜像，并且为这个镜像打上了已经存在的标签。旧镜像就变成了悬虚镜像了。

##### 中间层镜像

为了加速镜像构建、重复利用资源，Docker 会利用中间层镜像。

所以在使用一段时间后，可能会看到一些依赖的中间层镜像。

默认的 docker image ls 列表中只会显示顶层镜像，如果希望显示包括中间层镜像在内的所有镜像的话，需要加 -a 参数。

```shell script
docker image ls -a
```

这样会看到很多无标签的镜像，与之前的虚悬镜像不同，这些无标签的镜像很多都是中间层镜像，是其它镜像所依赖的镜像。

这些无标签镜像不应该删除，否则会导致上层镜像因为依赖丢失而出错。
实际上，这些镜像也没必要删除，因为之前说过，相同的层只会存一遍，而这些镜像是别的镜像的依赖，因此并不会因为它们被列出来而多存了一份，无论如何也会需要它们。
只要删除那些依赖它们的镜像后，这些依赖的中间层镜像也会被连带删除。

`docker images` 等同于 `docker image ls`。
`docker image ls -a` 显示所有镜像。
`docker image ls --digests` 查看镜像的 `SHA256` 签名。

可以使用 `--filter` 参数来过滤 `docker image ls` 命令返回的镜像列表内容。

支持四种过滤器：
- dangling，可以指定为 true 或者 false，指定 true 仅返回悬虚镜像，指定 false 仅返回非悬虚镜像。
- before，需要镜像名称或者 ID 作为参数，返回在指定镜像之前被创建的全部镜像。
- since 与 before 类似，不过返回的是指定镜像之后创建的全部镜像。
- label，根据 label 的名称或者值，对镜像进行过滤。`docker image ls` 命令输出中将不显示标注内容。

使用 `--format` 来通过 Go 模板对输出内容进行格式化

`docker image ls --format "{{.Size}}"`，只返回 Docker 主机上的镜像的大小属性。
`docker image ls --format "{{.Reposity}}:{{.Tag}}:{{.Size}}"`，只显示仓库、标签和大小。

`docker search`，查找镜像。

`docker search` 命令允许通过 CLI 的方式搜索 Docker Hub。
可通过 "Repository" 字段的内容进行匹配，并且对返回内容中任意列的值进行过滤。
返回的镜像中既有官方的也有非官方的，并且默认情况下只显示 25 行。

`docker search alpine`，查找 Repository 字段中带有 alpine 的。

`docker search apline --filter "is-official=true"`，`docker search apline --filter "is-automated=true"`。

`docker search apline --limit 30`，增加返回内容的行数，最多 100 行。

## 使用 commit 制作镜像

镜像是容器的基础，每次执行 `docker run` 的时候都会指定哪个镜像作为容器运行的基础。

在之前所使用的都是来自于 Docker Hub 的镜像。
直接使用这些镜像是可以满足一定的需求，而当这些镜像无法直接满足需求时，就需要定制这些镜像。

```shell script
docker run -d --name nginx -p 8080:80 nginx
```

```shell script
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

修改首页

```shell script
docker exec -it nginx bash

echo '<h1>Hello, Docker!</h1>' > /usr/share/nginx/html/index.html

exit
exit
```

```shell script
curl 127.0.0.1:8080
<h1>Hello, Docker!</h1>
```

通过 commit 来制作镜像。

docker commit <Options> <ContainerName>||<ContainerID> <Repository>:<Tag>

```shell script
docker commit --author "jiangshui" --message "修改了默认网页" nginx js-nginx
sha256:47d2ea08d30eb570ddb31329d0c6ea0ef423bb6aa6d1b19f4f630d4c88bae6de

docker images
REPOSITORY                    TAG                 IMAGE ID            CREATED             SIZE
js-nginx                      latest              47d2ea08d30e        23 seconds ago      133MB
```

```shell script
docker history js-nginx
IMAGE               CREATED              CREATED BY                                      SIZE                COMMENT
47d2ea08d30e        About a minute ago   nginx -g daemon off;                            1.21kB              修改了默认网页
c39a868aad02        3 days ago           /bin/sh -c #(nop)  CMD ["nginx" "-g" "daemon…   0B
<missing>           3 days ago           /bin/sh -c #(nop)  STOPSIGNAL SIGTERM           0B
<missing>           3 days ago           /bin/sh -c #(nop)  EXPOSE 80                    0B
<missing>           3 days ago           /bin/sh -c #(nop)  ENTRYPOINT ["/docker-entr…   0B
<missing>           3 days ago           /bin/sh -c #(nop) COPY file:0fd5fca330dcd6a7…   1.04kB
<missing>           3 days ago           /bin/sh -c #(nop) COPY file:13577a83b18ff90a…   1.96kB
<missing>           3 days ago           /bin/sh -c #(nop) COPY file:e7e183879c35719c…   1.2kB
<missing>           3 days ago           /bin/sh -c set -x     && addgroup --system -…   63.6MB
<missing>           3 days ago           /bin/sh -c #(nop)  ENV PKG_RELEASE=1~buster     0B
<missing>           3 days ago           /bin/sh -c #(nop)  ENV NJS_VERSION=0.4.4        0B
<missing>           3 days ago           /bin/sh -c #(nop)  ENV NGINX_VERSION=1.19.4     0B
<missing>           3 weeks ago          /bin/sh -c #(nop)  LABEL maintainer=NGINX Do…   0B
<missing>           3 weeks ago          /bin/sh -c #(nop)  CMD ["bash"]                 0B
<missing>           3 weeks ago          /bin/sh -c #(nop) ADD file:0dc53e7886c35bc21…   69.2MB
```

```shell script
docker run -d --name nginx -p 8080:80 js-nginx
4b610f763a2159afbc0d7e6c7c9b8efd5938379375596f10b0bacfb6df09e7a3

docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                  NAMES
4b610f763a21        js-nginx            "/docker-entrypoint.…"   3 seconds ago       Up 2 seconds        0.0.0.0:8080->80/tcp   nginx

curl 127.0.0.1:8080
<h1>Hello, Docker!</h1>
```

### diff

```shell script
docker diff js-nginx
C /usr
C /usr/share
C /usr/share/nginx
C /usr/share/nginx/html
C /usr/share/nginx/html/index.html
C /etc
C /etc/nginx
C /etc/nginx/conf.d
C /etc/nginx/conf.d/default.conf
C /var
C /var/cache
C /var/cache/nginx
A /var/cache/nginx/client_temp
A /var/cache/nginx/fastcgi_temp
A /var/cache/nginx/proxy_temp
A /var/cache/nginx/scgi_temp
A /var/cache/nginx/uwsgi_temp
C /root
A /root/.bash_history
C /run
A /run/nginx.pid
```

- `A` Add
- `C` Change
- `D` Delete

真正想要修改的 `/usr/share/nginx/html/index.html` 文件外，由于命令的执行，还有很多文件被改动或添加了。

这还仅仅是最简单的操作，如果是安装软件包、编译构建，那会有大量的无关内容被添加进来，将会导致镜像极为臃肿。

此外，使用 docker commit 意味着所有对镜像的操作都是黑盒操作，生成的镜像也被称为黑盒镜像。
换句话说，就是除了制作镜像的人知道执行过什么命令、怎么生成的镜像，别人根本无从得知。
而且，即使是这个制作镜像的人，过一段时间后也无法记清具体的操作。这种黑盒镜像的维护工作是非常痛苦的。

