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

`docker images` 等同于 `docker image ls`。
`docker image ls -a` 显示所有镜像。
`docker image ls --digests` 查看镜像的 `SHA256` 签名。

可以使用 `--filter` 参数来过滤 `docker image ls` 命令返回的镜像列表内容。

dangling，悬虚镜像，name 为 none , tag 为 none。
通常出现这种情况是因为构建了一个新的镜像，并且为这个镜像打上了已经存在的标签。旧镜像就变成了悬虚镜像了。

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

## docker ID 登录

```shell script
docker login <Registry>
```

## 搭建本地私有镜像仓库

```shell script
# 检查端口5000是否被占用
netstat -tunlp | grep 5000

# pull registry
mkdir -p /data/registry

docker pull registry:2.7.1

docker run -d -p 5000:5000 --name registry --restart=always -v /data/registry:/var/lib/registry registry:2.7.1
```

```shell script
curl http://172.17.0.1:5000/v2/

# modify https to http
vim /etc/docker/daemon.json
"insecure-registries": ["172.26.196.109:5000"]
```

```shell script
# 拉取 busybox 镜像做测试
docker pull busybox 

# tag 镜像
docker tag busybox 172.26.196.109:5000/busybox

# 删除 tag 为 latest 的镜像
docker rmi busybox

# push 镜像到本地仓库
docker push 172.26.196.109:5000/busybox

# check
tree -l 4 /data/registry

# 删除下载的 busybox 镜像
docker rmi 172.26.196.109:5000/busybox

# 从本地镜像仓库下载
docker pull 172.26.196.109:5000/busybox
```

