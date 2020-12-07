Docker Compose 是 Docker 官方编排(Orchestration)项目之一，负责快速的部署分布式应用。

Compose 定位是 "定义和运行多个 Docker 容器的应用(Defining and running multi-container Docker applications)"，其前身是开源项目 Fig。
Fig 是老师容器编排的三驾马车之一。

Dockerfile 模板文件，可以让用户很方便的定义一个单独的应用容器。

然而，在日常工作中，经常会碰到需要多个容器相互配合来完成某项任务的情况。
例如要实现一个 Web 项目，除了 Web 服务容器本身，往往还需要再加上后端的数据库服务容器，甚至还包括负载均衡容器等。

Compose 恰好满足了这样的需求。
它允许用户通过一个单独的 docker-compose.yml 模板文件来定义一组相关联的应用容器为一个项目(project)。

Compose 中有两个重要的概念：
- 服务(service)，一个应用的容器，实际上可以包括若干运行相同镜像的容器实例。
- 项目(project)，由一组关联的应用容器组成的一个完整业务单元，在 docker-compose.yml 文件中定义。

Compose 的默认管理对象是项目，通过子命令对项目中的一组容器进行便捷地生命周期管理。

Compose 项目由 Python 编写，实现上调用了 Docker 服务提供的 API 来对容器进行管理。
因此，只要所操作的平台支持 Docker API，就可以在其上利用 Compose 来进行编排管理。

## 安装

在 Linux 上的也安装十分简单，从 官方 GitHub Release 处直接下载编译好的二进制文件即可。

```shell script
curl -L https://github.com/docker/compose/releases/download/1.27.4/docker-compose-`uname -s`-`uname -m` > docker-compose

chmod +x docker-compose
```

## 启动

写一个 Web 服务

```python
from flask import Flask
from redis import Redis

app = Flask(__name__)
redis = Redis(host='redis', port=6379)

@app.route('/')
def hello():
    count = redis.incr('hits')
    return 'Hello World! 该页面已被访问 {} 次。\n'.format(count)

if __name__ == "__main__":
    app.run(host="0.0.0.0", debug=True)
```

编写 Dockerfile 文件

```dockerfile
FROM python:3.6-alpine
ADD . /code
WORKDIR /code
RUN pip install redis flask
CMD [ "python", "app.py" ]
```

编写 docker-compose.yml 文件

```yaml
version: '3'
services:

  web:
    build: .
    ports:
     - "5000:5000"

  redis:
    image: "redis:alpine"
```

运行 compose 项目

```shell script
docker-compose up
```

## 命令选项

- `-f`，`--file` 指定使用的 Compose 模板文件，默认为 docker-compose.yml，可以多次指定。
- `-p`，`--project-name` 指定项目名称，默认将使用所在目录名称作为项目名。
- `--verbose` 输出更多调试信息。
- `-v`，`--version` 打印版本并退出。

##### config

验证 Compose 文件格式是否正确，若正确则显示配置，若格式错误显示错误原因。

##### up

格式为 `docker-compose up [options] [SERVICE...]`

该命令十分强大，它将尝试自动完成包括构建镜像，创建服务，启动服务，并关联服务相关容器的一系列操作。

链接的服务都将会被自动启动，除非已经处于运行状态。

可以说，大部分时候都可以直接通过该命令来启动一个项目。

默认情况，docker-compose up 启动的容器都在前台，控制台将会同时打印所有容器的输出信息，可以很方便进行调试。
当通过 Ctrl-C 停止命令时，所有容器将会停止。

如果使用 `docker-compose up -d`，将会在后台启动并运行所有的容器。一般推荐生产环境下使用该选项。

默认情况，如果服务容器已经存在，`docker-compose up` 将会尝试停止容器，然后重新创建，以保证新启动的服务匹配 docker-compose.yml 文件的最新内容。
如果用户不希望容器被停止并重新创建，可以使用 `docker-compose up --no-recreate`。这样将只会启动处于停止状态的容器，而忽略已经运行的服务。
如果用户只想重新部署某个服务，可以使用 `docker-compose up --no-deps -d <SERVICE_NAME>` 来重新创建服务并后台停止旧服务，启动新服务，并不会影响到其所依赖的服务。

选项：
- `-d` 在后台运行服务容器
- `--no-color` 不使用颜色来区分不同的服务的控制台输出
- `--no-deps` 不启动服务所链接的容器
- `--no-recreate` 如果容器已经存在了，则不重新创建，不能与 `--force-recreate` 同时使用
- `--force-recreate` 强制重新创建容器，不能与 `--no-recreate` 同时使用
- `--no-build` 不自动构建缺失的服务镜像
- `-t`，`--timeout` 停止容器时候的超时，默认为 10 秒

##### down

此命令将会停止 `up` 命令所启动的容器，并移除网络。

##### logs

格式为 `docker-compose logs [options] [SERVICE...]`

查看服务容器的输出。

默认情况下，docker-compose 将对不同的服务输出使用不同的颜色来区分。
可以通过 `--no-color` 来关闭颜色。

##### start

格式为 `docker-compose start [SERVICE...]`

启动已经存在的服务容器。

##### stop

格式为 `docker-compose stop [options] [SERVICE...]`

停止已经处于运行状态的容器，但不删除它。

通过 `docker-compose start` 可以再次启动这些容器。

## 实战 wordpress

```yaml
version: "3"

services:

   db:
     image: mysql:5.7
     volumes:
       - db_data:/var/lib/mysql
     restart: always
     environment:
       # 如果有表达布尔含义的词汇，最好放到引号里，避免 YAML 自动解析某些内容为对应的布尔语义
       MYSQL_ALLOW_EMPTY_PASSWORD: "yes"
       MYSQL_DATABASE: wordpress
       MYSQL_USER: wordpress
       MYSQL_PASSWORD: wordpress

   wordpress:
     depends_on:
       - db
     image: wordpress
     ports:
       - "18000:80"
     restart: always
     environment:
       WORDPRESS_DB_HOST: db
       WORDPRESS_DB_USER: wordpress
       WORDPRESS_DB_PASSWORD: wordpress

volumes:
  db_data:
```

