- Ingress Controller，和 Kubernetes API 通信，实时更新 Nginx 配置。
- Ingress Nginx，实际运行转发、规则的载体。

## 部署方式

##### Deployment + LB

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201127233146.png)

##### Deployment + LB 直通 Pod

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201127233403.png)

##### Daemonset + HostNetwork + LB

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201127233254.png)

## Ingress Nginx 如何工作

![image](http://70data.net/upload/ingress/WX20191222-162012.png)

Ingress 本身也是一个 Pod。
外部流量统一经过这个 Pod，然后通过该 Pod 内部的 Nginx 反向代理到各个服务的 Endpoint。

Ingress 的 Pod 也会发生漂移，为了不让它漂移，通过 DaemonSet、nodeAffinity、taint 来实现独享 + 可控。

转发的核心逻辑 `balancer_by_lua_block`
https://github.com/q8s-io/ingress-openresty/blob/q8s-0.26.2/rootfs/etc/nginx/template/nginx.tmpl#L413

具体逻辑实现
https://github.com/q8s-io/ingress-openresty/blob/q8s-0.26.2/rootfs/etc/nginx/lua/balancer.lua

如何加载
https://github.com/q8s-io/ingress-openresty/blob/q8s-0.26.2/rootfs/etc/nginx/template/nginx.tmpl#L109

`serviceName` + `servicePort` 确定转发。

```yaml
metadata:
  name: echoserver-demo
  labels:
    app: echoserver-demo
spec:
  selector:
    app: echoserver-demo
  ports:
    - name: echoserver-demo-80
      port: 80
      protocol: TCP
      targetPort: 8080
```

最终的配置会体现在 `nginx.conf` 中。
会影响 `nginx.conf` 的配置入口有三个，`ingress-configmap`、`nginx.tmpl`、Ingress。

Nginx reload 场景：
- Ingress 创建/删除
- Ingress 添加新的 TLS 引用
- Ingress annotations 配置变更
- Ingress `path` 配置变更
- Ingress、Service、Secret 删除
- Secret 配置变更
- Ingress 中的引用对象由缺失变成可用，比如 Service、Secret

> 注意：这里没说 `nginx.tmpl` 变更，会 reload。实际测试也不会！

刷新流程

![image](http://70data.net/upload/ingress/WX20191222-113014.png)

Kubernetes Controller 利用同步循环模式来检查控制器中所需的状态是否已更新或需要更改。

Ingress Controller 为了从集群中获取该对象，使用了 `Kubernetes Informers`，尤其是 `FilteredSharedInformer`。
可以对使用回调的更改做出反应添加，修改或删除新对象时的更改。
但是没有办法知道特定的更改是否会影响最终的配置文件。

### Nginx 模型

Ingress Controller 每次更改时，都必须根据集群的状态从头开始重建一个新模型，并将其与当前模型进行比较。
如果新模型等于当前模型，那么避免生成新的 Nginx 配置并触发重新加载。
否则，检查差异是否仅与 Endpoint 有关。
如果是，使用 HTTP POST 请求将新的 Endpoint 列表发送到在 Nginx 内运行的 Lua 处理程序，并再次避免生成新的 Nginx 配置并触发重新加载。
如果运行模型和新模型之间的差异不仅仅是 Endpoint，将基于新模型创建新的 Nginx 配置。
该模型的用途之一是避免状态没有变化时避免不必要的重载，并检测定义中的冲突。

使用同步循环，通过使用 `Queue`，可以不丢失更改并删除 `sync.Mutex` 来强制执行一次同步循环。

还可以在同步循环的开始和结束之间创建一个时间窗口，从而允许丢弃不必要的更新。

##### 模型的建立

- 按时间顺序加载规则。
- 如果多个 Ingress 使用了相同的 `host` 和 `path`，以最旧规则为准。
- 如果多个 Ingress 使用了相同的 `host`，但 TLS 不同，以最旧规则为准。
- 如果多个 Ingress 定义了一个影响 Server block 的 annotation，以最旧规则为准。
- 创建 Nginx Server。
- 如果多个 Ingress 为同一个 `host` 定义了不同的 `path`，则 Ingress 会合并。
- annotation 将应用于 Ingress 中的所有 `path`。
- 多个 Ingress 可以定义不同的 annotation。这些 annotation 在 Ingress 之间不共享。

## 调优

##### 调大连接队列的大小

进程监听的 socket 的连接队列最大的大小受限于内核参数 `net.core.somaxconn`。

在高并发环境下，如果队列过小，可能导致队列溢出，使得连接部分连接无法建立。

要调大 Nginx Ingress 的连接队列，只需要调整 `somaxconn` 内核参数的值即可。

进程调用 `listen()` 系统调用来监听端口的时候，还会传入一个 `backlog` 的参数，这个参数决定 socket 的连接队列大小，其值不得大于 `somaxconn` 的取值。

Go 程序标准库在 `listen` 时，默认直接读取 `somaxconn` 作为队列大小。

Nginx 监听 socket 时没有读取 `somaxconn`，而是有自己单独的参数配置。
在 nginx.conf 中 listen 端口的位置，还有个叫 `backlog` 参数可以设置，它会决定 nginx listen 的端口的连接队列大小。

```
server {
    listen  80  backlog=1024;
}
```

如果不设置，`backlog` 在 linux 上默认为 511。

```
backlog=number

sets the backlog parameter in the listen() call that limits the maximum length for the queue of pending connections.
By default, backlog is set to -1 on FreeBSD, DragonFly BSD, and macOS, and to 511 on other platforms.
```

Nginx Ingress Controller 会自动读取 `somaxconn` 的值作为 `backlog` 参数写到生成的 nginx.conf 中。
也就是说 Nginx Ingress 的连接队列大小只取决于 `somaxconn` 的大小。
https://github.com/q8s-io/ingress-openresty/blob/q8s-0.26.2/internal/ingress/controller/nginx.go#L591

##### 扩大源端口范围

高并发场景会导致 Nginx Ingress 使用大量源端口与 upstream 建立连接。

源端口范围从 `net.ipv4.ip_local_port_range` 这个内核参数中定义的区间随机选取。

在高并发环境下，端口范围小容易导致源端口耗尽，使得部分连接异常。

##### TIME_WAIT 复用

如果短连接并发量较高，它所在 netns 中 `TIME_WAIT` 状态的连接就比较多。

`TIME_WAIT` 连接默认要等 2MSL 时长才释放，长时间占用源端口。
当这种状态连接数量累积到超过一定量之后可能会导致无法新建连接。

TIME_WAIT 重用，即允许将 TIME_WAIT 连接重新用于新的 TCP 连接 `net.ipv4.tcp_tw_reuse=1`

##### 调大最大文件句柄数

Nginx 作为反向代理，对于每个请求，它会与 client 和 upstream server 分别建立一个连接，即占据两个文件句柄。

理论上来说 Nginx 能同时处理的连接数最多是系统最大文件句柄数限制的一半。

系统最大文件句柄数由 `fs.file-max` 这个内核参数来控制。

##### 调高 keepalive 连接最大请求数

Nginx 针对 client 和 upstream 的 keepalive 连接，均有 `keepalive_requests` 参数来控制单个 keepalive 连接的最大请求数，且默认值均为 100。
当一个 keepalive 连接中请求次数超过这个值时，就会断开并重新建立连接。

频繁断开跟 client 建立的 keepalive 连接，然后就会产生大量 `TIME_WAIT` 状态连接。
Nginx Ingress 的配置对应 keep-alive-requests。

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-ingress-controller
data:
  # https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#keep-alive-requests
  keep-alive-requests: "10000"
```

在高并发下场景下调大 `upstream-keepalive-requests`，避免频繁建联导致 `TIME_WAIT` 飙升。

https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#upstream-keepalive-requests

一般情况应该不必配此参数，如果将其调高，可能导致负载不均。
Nginx 与 upstream 保持的 keepalive 连接过久，导致连接发生调度的次数就少了，连接就过于固化，使得流量的负载不均衡。

##### 调高 keepalive 最大空闲连接数

Nginx 与 upstream 保持长连接的最大空闲连接数，默认 32。

空闲连接数多了之后关闭空闲连接，就可能导致 Nginx 与 upstream 频繁断开和建立链接，引发 `TIME_WAIT` 飙升。

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-ingress-controller
data:
  # https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#upstream-keepalive-connections
  upstream-keepalive-connections: "200"
```

##### 调高单个 worker 最大连接数

`max-worker-connections` 控制每个 worker 进程可以打开的最大连接数。

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-ingress-controller
data:
  # https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#max-worker-connections
  max-worker-connections: "65536"
```

## 监控

https://github.com/kubernetes/ingress-nginx/tree/master/deploy/grafana/dashboards

## 如何落地

想落地，还挺难的。

### 躲在 LVS 后面，如何平滑的上下线是个问题

正常上线流程：
- Controller、Nginx 正常运行。
- 加到 LVS 后面。
- 应用流量接进来。

正常下线流程：
- 从 LVS 摘掉。
- 应用请求结束。
- Controller、Nginx 退出。

官方默认的配置肯定做不到。

方案1:

利用 Kubernetes 生命周期钩子，平滑上下线。

- 启动 postStart，`touch status.html`
- 结束 preStop，`remove status.html`。

听起来可行，但是没有办法做到正常上线，因为不知道啥时候 Controller、Nginx 准备好。

Nginx 启动正常不代表 Controller 启动正常。

方案2:

在 `location` 里写 Lua。

结合生命周期钩子，通过判断传递的参数，来执行 check 逻辑，模拟默认健康检查流程。

听起来也可行，但需要复现 `Start()`、`Stop()` 逻辑，太 trick 了，不好维护。

check 逻辑

```go
// Check returns if the nginx healthz endpoint is returning ok (status code 200)
func (n *NGINXController) Check(_ *http.Request) error {
	if n.isShuttingDown {
		return fmt.Errorf("the ingress controller is shutting down")
	}
	// check the nginx master process is running
	fs, err := proc.NewFS("/proc", false)
	if err != nil {
		return errors.Wrap(err, "reading /proc directory")
	}
	f, err := ioutil.ReadFile(nginx.PID)
	if err != nil {
		return errors.Wrapf(err, "reading %v", nginx.PID)
	}
	pid, err := strconv.Atoi(strings.TrimRight(string(f), "\r\n"))
	if err != nil {
		return errors.Wrapf(err, "reading NGINX PID from file %v", nginx.PID)
	}
	_, err = fs.NewProc(pid)
	if err != nil {
		return errors.Wrapf(err, "checking for NGINX process with PID %v", pid)
	}
	statusCode, _, err := nginx.NewGetStatusRequest(nginx.HealthPath)
	if err != nil {
		return errors.Wrapf(err, "checking if NGINX is running")
	}
	if statusCode != 200 {
		return fmt.Errorf("ingress controller is not healthy (%v)", statusCode)
	}
	statusCode, _, err = nginx.NewGetStatusRequest("/is-dynamic-lb-initialized")
	if err != nil {
		return errors.Wrapf(err, "checking if the dynamic load balancer started")
	}
	if statusCode != 200 {
		return fmt.Errorf("dynamic load balancer not started")
	}
	return nil
}
```

最终方案：
添加 lvscheck server，严格匹配。

```
server {
    server_name lvscheck;
    listen 80;
    location ~* "^/status$" {
        rewrite ^/status$ /healthz break;
        proxy_pass  http://127.0.0.1:10254;
    }
}
```

`Start()` 的逻辑是满足需求的，因为会配置健康检测与存活检测以应对 LVS。

```go
// Start starts a new NGINX master process running in the foreground.
func (n *NGINXController) Start() {
	klog.Info("Starting NGINX Ingress controller")
	n.store.Run(n.stopCh)
	// we need to use the defined ingress class to allow multiple leaders in order to update information about ingress status
	electionID := fmt.Sprintf("%v-%v", n.cfg.ElectionID, class.DefaultClass)
	if class.IngressClass != "" {
		electionID = fmt.Sprintf("%v-%v", n.cfg.ElectionID, class.IngressClass)
	}
	setupLeaderElection(&leaderElectionConfig{
		Client:     n.cfg.Client,
		ElectionID: electionID,
		OnStartedLeading: func(stopCh chan struct{}) {
			if n.syncStatus != nil {
				go n.syncStatus.Run(stopCh)
			}
			n.metricCollector.OnStartedLeading(electionID)
			// manually update SSL expiration metrics (to not wait for a reload)
			n.metricCollector.SetSSLExpireTime(n.runningConfig.Servers)
		},
		OnStoppedLeading: func() {
			n.metricCollector.OnStoppedLeading(electionID)
		},
		PodName:      n.podInfo.Name,
		PodNamespace: n.podInfo.Namespace,
	})
	cmd := n.command.ExecCommand()
	// put NGINX in another process group to prevent it to receive signals meant for the controller
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Setpgid: true,
		Pgid:    0,
	}
	if n.cfg.EnableSSLPassthrough {
		n.setupSSLProxy()
	}
	klog.Info("Starting NGINX process")
	n.start(cmd)
	go n.syncQueue.Run(time.Second, n.stopCh)
	// force initial sync
	n.syncQueue.EnqueueTask(task.GetDummyObject("initial-sync"))
	// In case of error the temporal configuration file will be available up to five minutes after the error
	go func() {
		for {
			time.Sleep(5 * time.Minute)
			err := cleanTempNginxCfg()
			if err != nil {
				klog.Infof("Unexpected error removing temporal configuration files: %v", err)
			}
		}
	}()
	if n.validationWebhookServer != nil {
		klog.Infof("Starting validation webhook on %s with keys %s %s", n.validationWebhookServer.Addr, n.cfg.ValidationWebhookCertPath, n.cfg.ValidationWebhookKeyPath)
		go func() {
			klog.Error(n.validationWebhookServer.ListenAndServeTLS("", ""))
		}()
	}
	for {
		select {
		case err := <-n.ngxErrCh:
			if n.isShuttingDown {
				break
			}
			// if the nginx master process dies the workers continue to process requests, passing checks but in case of updates in ingress no updates will be reflected in the nginx configuration which can lead to confusion and report issues because of this behavior.
			// To avoid this issue we restart nginx in case of errors.
			if process.IsRespawnIfRequired(err) {
				process.WaitUntilPortIsAvailable(n.cfg.ListenPorts.HTTP)
				// release command resources
				cmd.Process.Release()
				// start a new nginx master process if the controller is not being stopped
				cmd = n.command.ExecCommand()
				cmd.SysProcAttr = &syscall.SysProcAttr{
					Setpgid: true,
					Pgid:    0,
				}
				n.start(cmd)
			}
		case event := <-n.updateCh.Out():
			if n.isShuttingDown {
				break
			}
			if evt, ok := event.(store.Event); ok {
				klog.V(3).Infof("Event %v received - object %v", evt.Type, evt.Obj)
				if evt.Type == store.ConfigurationEvent {
					// TODO: is this necessary? Consider removing this special case
					n.syncQueue.EnqueueTask(task.GetDummyObject("configmap-change"))
					continue
				}
				n.syncQueue.EnqueueSkippableTask(evt.Obj)
			} else {
				klog.Warningf("Unexpected event type received %T", event)
			}
		case <-n.stopCh:
			break
		}
	}
}
```

```yaml
livenessProbe:
  failureThreshold: 3
  httpGet:
    path: /healthz
    port: 10254
    scheme: HTTP
  initialDelaySeconds: 10
  periodSeconds: 10
  successThreshold: 1
  timeoutSeconds: 10
readinessProbe:
  failureThreshold: 3
  httpGet:
    path: /healthz
    port: 10254
    scheme: HTTP
  periodSeconds: 10
  successThreshold: 1
  timeoutSeconds: 10
```

但 `Stop()` 逻辑不满足需求，无法做到先从 LVS 摘掉，再停止服务。

这里有一个很关键的点是，健康检测为 false 不等于将其从 LVS 摘掉。

如果 LVS 的健康检测周期是 8s，累计 3 次失败再摘掉的话，需要 24s 才能停止服务，但 Controller + Nginx 停止服务的速度远比这快。

所以，需要延迟停止服务的策略。

```go
// Stop gracefully stops the NGINX master process.
func (n *NGINXController) Stop() error {
	n.isShuttingDown = true
	n.stopLock.Lock()
	defer n.stopLock.Unlock()
	if n.syncQueue.IsShuttingDown() {
		return fmt.Errorf("shutdown already in progress")
	}
	klog.Info("Shutting down controller queues")
	close(n.stopCh)
	go n.syncQueue.Shutdown()
	if n.syncStatus != nil {
		n.syncStatus.Shutdown()
	}
	if n.validationWebhookServer != nil {
		klog.Info("Stopping admission controller")
		err := n.validationWebhookServer.Close()
		if err != nil {
			return err
		}
	}
	var (
		period int
		perr   error
	)
	periodEnv := os.Getenv("GRACE_STOP_PERIOD")
	if period, perr = strconv.Atoi(periodEnv); perr != nil {
		period = 30
	}
	klog.Infof("Graceful waiting %d second to stop", period)
	time.Sleep(time.Second * time.Duration(period))
	// send stop signal to NGINX
	klog.Info("Stopping NGINX process")
	cmd := n.command.ExecCommand("-s", "quit")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err := cmd.Run()
	if err != nil {
		return err
	}
	// wait for the NGINX process to terminate
	timer := time.NewTicker(time.Second * 1)
	for range timer.C {
		if !nginx.IsRunning() {
			klog.Info("NGINX process has stopped")
			timer.Stop()
			break
		}
	}
	return nil
}
```

默认也有 preStop 逻辑，但没有什么帮助。

```yaml
lifecycle:
  preStop:
    exec:
      command:
        - /wait-shutdown
```

开始造轮子，做一个 low 版的延迟停止。

```go
// Stop gracefully stops the NGINX master process.
func (n *NGINXController) Stop() error {
	...
	periodEnv := os.Getenv("GRACE_STOP_PERIOD")
	if period, perr = strconv.Atoi(periodEnv); perr != nil {
		period = 30
	}
	klog.Infof("Graceful waiting %d second to stop", period)
	time.Sleep(time.Second * time.Duration(period))
	...
}
```

### Header 携带问题

PHP 需要解析 `x-real-ip` 字段中的特殊标识来获取到真实的 IP。

获取真实 IP 的途径有如下几种：
- `x-real-ip`
- `x-forwarded-for` 中的 `$remote_addr`
- Header 增加特殊字段

如果尽量兼容现有的方式，整体代价又最小，修改 `nginx.conf` 可能是最简单的方式。

`$remote_addr` 不能伪造，需要修改内核，又是 trick 的方式，快算了。

```
set $q8s_remote_addr $remote_addr;
if ( $http_x_real_ip != "" ) {
    set $q8s_remote_addr $http_x_real_ip;
}
{{ $proxySetHeader }} X-Real-IP    $q8s_remote_addr;
```

Nginx 里只有 if，没有 else。
`ngx.var` 搞定一切。`ngx.ctx` 相对昂贵。

> 请认真学习 `nginx.conf` 与 Lua，否则 OpenResty 分分钟告诉你 `who's your daddy`。

### 超时太长

s -> ms

```
proxy_connect_timeout    {{ $location.Proxy.ConnectTimeout }}ms;
```

原本也是想挂载 `nginx.tmpl` 的，但考虑到 `nginx.tmpl` 修改后需要测试，不能动态生效，所以放弃了挂载方式。

### 修改日志格式，改用 Lua 记录

plugin 需要有效利用。

```
init_by_lua_block {
    -- load all plugins that'll be used here
    plugins.init({"json_log"})
}
```

先读源码，不然分分钟告诉你 `who's your daddy`。

```
local string_format = string.format
local new_tab = require "table.new"
local ngx_log = ngx.log
local INFO = ngx.INFO
local ERR = ngx.ERR
local _M = {}
local MAX_NUMBER_OF_PLUGINS = 10000

-- TODO: is this good for a dictionary?
local plugins = new_tab(MAX_NUMBER_OF_PLUGINS, 0)

local function load_plugin(name)
  local path = string_format("plugins.%s.main", name)
  local ok, plugin = pcall(require, path)
  if not ok then
    ngx_log(ERR, string_format("error loading plugin \"%s\": %s", path, plugin))
    return
  end
  plugins[name] = plugin
end

function _M.init(names)
  for _, name in ipairs(names) do
    load_plugin(name)
  end
end

function _M.run()
  local phase = ngx.get_phase()
  for name, plugin in pairs(plugins) do
    if plugin[phase] then
      ngx_log(INFO, string_format("running plugin \"%s\" in phase \"%s\"", name, phase))
      -- TODO: consider sandboxing this, should we?
      -- probably yes, at least prohibit plugin from accessing env vars etc
      -- but since the plugins are going to be installed by ingress-nginx operator they can be assumed to be safe also
      local ok, err = pcall(plugin[phase])
      if not ok then
        ngx_log(ERR, string_format("error while running plugin \"%s\" in phase \"%s\": %s", name, phase, err))
      end
    end
  end
end

return _M
```

先了解啥是 `ngx.get_phase()`，来自温主席的书

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201127202916.png)

- `set_by_lua` 流程分支处理判断变量初始化
- `rewrite_by_lua` 转发、重定向、缓存等功能(例如特定请求代理到外网)
- `access_by_lua` IP 准入、接口权限等情况集中处理(例如配合 iptable 完成简单防火墙)
- `content_by_lua` 内容生成
- `header_filter_by_lua` 响应头部过滤处理(例如添加头部信息)
- `body_filter_by_lua` 响应体过滤处理(例如完成应答内容统一成大写)
- `log_by_lua` 会话完成后本地异步完成日志记录(日志可以记录在本地，还可以同步到其他机器)

官方文档：
https://github.com/openresty/lua-nginx-module#ngxget_phase

在 Ingress 里的调用

```
init_worker_by_lua_block {
    plugins.run()
}

rewrite_by_lua_block {
    plugins.run()
}

header_filter_by_lua_block {
    plugins.run()
}

log_by_lua_block {
    plugins.run()
}
```

自定义 log 形态

```
local json = require("cjson")
local ngx_re = require("ngx.re")
local req = ngx.req
local var = ngx.var

local function gsub(subject, regex, replace)
  return ngx.re.gsub(subject, regex, replace, "jo")
end

local function get_upstream_addrs()
  local res = {}
  setmetatable(res, json.empty_array_mt)
  local cnt = 0
  for k, v in ipairs(ngx_re.split(var.upstream_addr, ","))
  do
    res[k] = gsub(v, [[^%s*(.-)%s*$]], "%1")
    cnt = k
  end
  return res, cnt
end

local _M = {}

function _M.log()
  local log = {
    hostname = var.hostname,
    request_method = var.request_method,
    request_uri = gsub(var.request_uri, [[\?.*]], ""),
    args = req.get_uri_args(),
    headers = req.get_headers(),
    remote_addr = var.remote_addr,
    uri = var.uri,
    upstream_bytes_sent = tonumber(var.upstream_bytes_sent),
    upstream_bytes_received = tonumber(var.upstream_bytes_received),
    upstream_status = tonumber(var.upstream_status),
    upstream_connect_time = tonumber(var.upstream_connect_time),
    upstream_header_time = tonumber(var.upstream_header_time),
    upstream_response_time = tonumber(var.upstream_response_time),
    body_bytes_sent = tonumber(var.body_bytes_sent),
    bytes_sent = tonumber(var.bytes_sent),
    status = tonumber(var.status),
    connection_requests = tonumber(var.connection_requests),
    request_time = tonumber(var.request_time),
    time_local = ngx.time()
  }

  log.upstream_addr, log.upstream_tries = get_upstream_addrs()

  var.json_log = gsub(json.encode(log), [[\\/]], "/")
end

return _M
```

`escape=json` 是 OpenResty 1.11.8 以后的新特性。

```
log_format upstreaminfo escape=none '$json_log';
```

### 落地配置

```yaml
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: ingress-nginx-redefine
spec:
  template:
    metadata:
      annotations:
        prometheus.io/port: '10254'
        prometheus.io/scrape: 'true'
        nginx.ingress.kubernetes.io/force-ssl-redirect: 'false'
    spec:
      serviceAccountName: ingress-nginx-redefine-serviceaccount
      hostNetwork: true
      terminationGracePeriodSeconds: 300
      containers:
        - name: nginx-ingress-controller
          image: nginx-ingress-controller:0.26.1
          args:
            - /nginx-ingress-controller
            - '--configmap=default/ingress-nginx-redefine-configuration'
            - '--default-backend-service=default/ingress-default-http-backend'
            - '--annotations-prefix=nginx.ingress.kubernetes.io'
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: GRACE_STOP_PERIOD
              value: '30'
          ports:
            - name: http
              containerPort: 80
              hostPort: 80
            - name: https
              containerPort: 443
              hostPort: 443
          livenessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 10
          readinessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 10
          lifecycle:
            preStop:
              exec:
                command:
                  - /wait-shutdown
          resources:
            limits:
              cpu: 0
              memory: 0
            requests: {}
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: node-role.kubernetes.io/ingress
                    operator: Exists
      tolerations:
        - operator: Exists
```

## Tips

- 调试费劲，需要重新编译。编译需要翻墙，不然下不下来包。
- 由 `by_lua_block` 改成 `by_lua_file`。Lua 文件可以通过挂载实现热加载。如果是 `lua_code_cache off` 的方式，依然太 trick 了。
- 对全局 `ingress-configmap` 的修改，不会影响到单个 Ingress 对象。

##### Header 包涵下划线

```yaml
kind: ConfigMap
apiVersion: v1
data:
  enable-underscores-in-headers: "true"
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
```

