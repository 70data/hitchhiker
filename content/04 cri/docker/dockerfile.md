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
