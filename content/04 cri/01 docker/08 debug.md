## 暂停容器

会暂停容器中所有进程

```
docker pause
```

## Debug

在 `/etc/docker/daemon.json` 中开启 debug。

```
{
    "debug": true
}
```

### 重载配置

```
sudo kill -SIGHUP $(pidof dockerd)
```

### Dump Docker Engine

```
kill -SIGUSR1 $(pidof dockerd)
```

可以在 `/var/run/docker` 下看堆栈日志。

### Dump UCP Container

```
#! /bin/bash
CONTAINER_NAME=nginx
pause_image=$(docker container inspect ${CONTAINER_NAME} --format {{.Config.Image}})
docker container create --name nginx-pause ${pause_image}
docker container logs -f ${CONTAINER_NAME} > ${CONTAINER_NAME}-${HOSTNAME}-$(date -Is).log 2>&1 &
docker container kill -s SIGABRT ${CONTAINER_NAME}
test -n "$(docker ps -qaf is-task=true -f name=${CONTAINER_NAME})" || docker container start ${CONTAINER_NAME}
docker container rm nginx-pause
```

### Dump containerd

```
kill -s USR1 $(pidof containerd)
```

