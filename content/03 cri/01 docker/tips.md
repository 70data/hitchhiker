Docker 运行容器时，时区与期望不符合：
- 在 Dockerfile 中加入 `RUN echo "Asia/Shanghai" > /etc/timezone` 设置时区
- 启动的时候挂载宿主机的时间 `-v /etc/localtime:/etc/localtime`

