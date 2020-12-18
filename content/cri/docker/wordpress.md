创建网络

```shell script
docker network create -d bridge wordpress
cdcf218f0168fdd1a3231cb9ad7ea62728462e563675aface72d6ca847744804

docker network ls
NETWORK ID          NAME                DRIVER              SCOPE
27ef241af0da        bridge              bridge              local
2b0bfe5bf708        host                host                local
cef1546fa081        my-net              bridge              local
ea93ada1070f        none                null                local
cdcf218f0168        wordpress           bridge              local
```

安装 mysql

```shell script
mkdir -p /data/docker/mysql
chmod -p 777 /data/docker/mysql

docker pull mysql:5.7
```

启动 mysql

```shell script
docker rm -f wordpress-mysql && docker run -d --name wordpress-mysql -v /data/docker/mysql:/var/lib/mysql -p 13306:3306 --network wordpress -e "MYSQL_DATABASE=wordpress" -e "MYSQL_USER=wordpress" -e "MYSQL_PASSWORD=wordpress" -e "MYSQL_ALLOW_EMPTY_PASSWORD=yes" mysql:5.7
```

进入 mysql 容器查看


```shell script
docker exec -it 517e2ef8e3f7 /bin/bash

mysql -u wordpress -p'wordpress'

mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| wordpress          |
+--------------------+
2 rows in set (0.00 sec)
```

下载 wordpress

```shell script
docker pull wordpress
```

启动 wordpress

```shell script
docker run -d --name wordpress -p 18080:80 --network wordpress -e "WORDPRESS_DB_HOST=39.99.234.40:13306" -e "WORDPRESS_DB_USER=wordpress" -e "WORDPRESS_DB_PASSWORD=wordpress" -e "WORDPRESS_DB_NAME=wordpress" wordpress
```

使用 docker 网络连接

```shell script
docker run -d --name wordpress-mysql -v /data/docker/mysql:/var/lib/mysql --network wordpress -e "MYSQL_DATABASE=wordpress" -e "MYSQL_USER=wordpress" -e "MYSQL_PASSWORD=wordpress" -e "MYSQL_ALLOW_EMPTY_PASSWORD=yes" mysql:5.7

docker run -d --name wordpress -p 18080:80 --network wordpress -e "WORDPRESS_DB_HOST=172.19.0.2:3306" -e "WORDPRESS_DB_USER=wordpress" -e "WORDPRESS_DB_PASSWORD=wordpress" -e "WORDPRESS_DB_NAME=wordpress" wordpress
```

删除所有停止的容器、dangling 镜像、未使用的网络，`--volumes` 删除所有未使用的卷。

```shell script
docker system prune --volumes
```

