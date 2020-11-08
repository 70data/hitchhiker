 run wordpress on docker
Deploy MYSQL

docker pull mysql
挂载卷保存数据文件

mkdir -p /mysql/data
chmod -p 777 /mysql/data


MySQL使用过程中的环境变量
Num|Env Variable| Description
—-|—-|—-
1|MYSQL_ROOT_PASSWORD|root用户的密码
2|MYSQL_DATABASE|创建一个数据库
3|MYSQL_USER,MYSQL_PASSWORD|创建一个用户以及用户密码
4|MYSQL_ALLOW_EMPTY_PASSWORD|允许空密码

创建网络

docker network create --subnet 10.0.0.0/24 --gateway 10.0.0.1 marion
docker network ls
➜  ~ docker network ls | grep marion
6244609a83bb        marion              bridge              local


创建MYSQL container
```Shell
➜ ~ docker run -v /mysql/data:/var/lib/mysql —name mysqldb —restart=always -p 3306:3306 -e MYSQL_DATABASE=’wordpress’ -e MYSQL_USER=’marion’ -e MYSQL_PASSWORD=’marion’ -e MYSQL_ALLOW_EMPTY_PASSWORD=’yes’ -e MYSQL_ROOT_PASSWORD=’marion’ —network=marion —ip=10.0.0.2 -d mysql
➜ ~ docker ps -a
➜ marion docker ps -a
CONTAINER ID IMAGE COMMAND CREATED STATUS PORTS NAMES
3013c407c74b mysql “docker-entrypoint…” 4 minutes ago Up 4 minutes 0.0.0.0:3306->3306/tcp mysqldb
➜ marion docker exec -it 3013c407c74b /bin/bash
root@3013c407c74b:/# ip addr
1: lo:

mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
inet 127.0.0.1/8 scope host lo
 valid_lft forever preferred_lft forever
inet6 ::1/128 scope host
 valid_lft forever preferred_lft forever
9: eth0@if10:mtu 1500 qdisc noqueue state UP group default
link/ether 02:42:0a:00:00:02 brd ff:ff:ff:ff:ff:ff
inet 10.0.0.2/24 scope global eth0
 valid_lft forever preferred_lft forever
inet6 fe80::42:aff:fe00:2/64 scope link
 valid_lft forever preferred_lft forever
root@3013c407c74b:/# apt-get install net-tools -y
root@3013c407c74b:/# netstat -tunlp
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address Foreign Address State PID/Program name
tcp 0 0 127.0.0.11:45485 0.0.0.0: LISTEN -
tcp6 0 0 :::3306 ::: LISTEN -
udp 0 0 127.0.0.11:48475 0.0.0.0:* -
root@3013c407c74b:/# mysql -u marion -p
Enter password:
Welcome to the MySQL monitor. Commands end with ; or \g.
Your MySQL connection id is 3
Server version: 5.7.20 MySQL Community Server (GPL)
Copyright (c) 2000, 2017, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type ‘help;’ or ‘\h’ for help. Type ‘\c’ to clear the current input statement.

mysql> show databases;
+——————————+
| Database |
+——————————+
| information_schema |
| wordpress |
+——————————+
2 rows in set (0.01 sec)

mysql>

* 3、运行nginx-php
mkdir -p /var/www/html
docker run —name php7 -p 9000:9000 -p 80:80 -v /var/www/html:/usr/local/nginx/html —restart=always —network=marion —ip=10.0.0.3 -d skiychan/nginx-php7
docker ps
docker exec -it cfb9556b71b3 /bin/bash
cd /usr/local/php/etc
vim php.ini
date.timezone =Asia/Shanghai

*　编辑nginx配置文件/usr/local/nginx/conf/nginx.conf
```Shell
user www www;  #modify
worker_processes auto;  #modify

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;
error_log /var/log/nginx_error.log crit;  #add

#pid        logs/nginx.pid;
pid /var/run/nginx.pid;  #modify
worker_rlimit_nofile 51200;

events {
    use epoll;
    worker_connections 51200;
    multi_accept on;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    client_max_body_size 100m;  #add
    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  120; #65;

    #gzip  on;

    server {
        listen       80;
        server_name  localhost;

        #charset koi8-r;

        #access_log  logs/host.access.log  main;

        root   /usr/local/nginx/html;
        index  index.php index.html index.htm;

        location / {
            try_files $uri $uri/ /index.php?$args;
        }

        #error_page  404              /404.html;

        # redirect server error pages to the static page /50x.html
        #
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }

        location ~ \.php$ {
            root           /usr/local/nginx/html;
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  /$document_root$fastcgi_script_name;
            include        fastcgi_params;
        }
    }

    #add
    ##########################vhost#####################################
    include vhost/*.conf;

}

daemon off;
测试配置文件是否有问题

[root@cfb9556b71b3 sbin]# /usr/local/nginx/sbin/nginx -t
nginx: the configuration file /usr/local/nginx/conf/nginx.conf syntax is ok
nginx: configuration file /usr/local/nginx/conf/nginx.conf test is successful
重新加载配置文件

[root@cfb9556b71b3 sbin]# /usr/local/nginx/sbin/nginx -s reload 
[root@cfb9556b71b3 sbin]#


