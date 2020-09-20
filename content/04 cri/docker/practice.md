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

## 删除

删除所有容器

```
docker rm $(docker ps -aq)
docker system prune -f
```

删除历史容器

```
docker rm $(sudo docker ps -a | grep Exited | awk '{print $1}')
```

删除没有打标签的镜像

```
docker rmi `docker images | awk '/^<none>/ {print $3}'`
```

删除名称包含关键字的镜像
```
docker rmi --force `docker images | grep name | awk '{print $3}'`
```

## 进入容器

通过 nsenter

```
nsenter --target `docker inspect --format '{{.State.Pid}}' containerid` --mount --uts --ipc --net --pid
```
