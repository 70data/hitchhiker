CoreDNS 的优缺点：
- 非常灵活的配置，可以根据不同的需求给不同的域名配置不同的插件
- 缓存的效率不如 dnsmasq，对于内部域名解析 kube-dns 要优于 CoreDNS 大约 10%
- 对于外部域名 CoreDNS 要比 kube-dns 好 3 倍，kube-dns 不会缓存 negative cache

kubelet 将带有 `--cluster-dns=<dns-service-ip>` 标志的 DNS 信息传递给每个容器。

DNS name 也需要域。
kubelet 中配置本地域 `--cluster-domain=<default-local-domain>`。

## 安装

https://github.com/coredns/deployment/tree/master/kubernetes

## 配置

```yaml
ZONE:[PORT] {
	[PLUGIN] 0.0.10.in-addr.arpa {
        whoami
    }
}
```

ZONE：
定义 server 负责的 zone。
`.` 就是根域。

PORT：
可选项，默认为 53。

PLUGIN：
定义 server 所要加载的 plugin。
每个 plugin 可以有多个参数。

`0.0.10.in-addr.arpa` 为 Reverse Zone。

## 性能

https://github.com/coredns/deployment/blob/master/kubernetes/Scaling_CoreDNS.md

## CoreDNS 如何处理 DNS 请求

```yaml
# Corefile
coredns.io:5300 {
    file /etc/coredns/zones/coredns.io.db
}

example.io:53 {
    errors
    log
    file /etc/coredns/zones/example.io.db
}

example.net:53 {
    file /etc/coredns/zones/example.net.db
}

.:53 {
    errors
    log
    health
    rewrite name foo.example.com foo.default.svc.cluster.local
}
```

定义了两个 server，分别监听在 5300 和 53 端口。

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201205225755.png)

尽管在 .:53 配置了 health 插件，但是它并为在上面的逻辑图中出现。
原因是该插件并未参与请求相关的逻辑，只是修改了 server 配置。

## 插件系统

可以将插件分为两种：
- Normal 插件：参与请求相关的逻辑，且插入到插件链中
- 其他插件：不参与请求相关的逻辑，也不出现在插件链中，只是用于修改 server 的配置

##### 初始化注册插件

当执行 `go generate coredns.go` 这句命令的时候，将触发以 `go:generate` 为标记的命令。
即：`go run directives_generate.go`。

该命令执行完之后将生成两个文件：`coredns/core/zplugin.go` 和 `coredns/core/dnsserver/zdirectives.go`。

`coredns/core/zplugin.go` 执行每个 package 的 init 方法。

自动代码的生成依赖于 plugin.cfg 配置文件，所以当配置文件更新时，对应的目标也需要被重新创建。

```
metadata:metadata
tls:tls
reload:reload
nsid:nsid
root:root
```

每一行由冒号分割，第一部分是插件名，第二部分是插件的包名。
包名可以是一个完整的外部地址，如 `log:github.com/coredns/coredns/plugin/log`。

插件在 plugin.cfg 中的顺序就是最终生成文件中对应的顺序。

虽然 plugin.cfg 中定义了大量的默认插件，且编译的时候将其全部编译成一个二进制文件。
但实际运行过程中并不会全部执行，CoreDNS 在处理请求过程中只会运行配置文件中所需要的插件。

##### 入口逻辑

```go
package coremain

import (
	"github.com/coredns/coredns/core/dnsserver"
)

func Run() {
	caddy.TrapSignals()
	// 获取 Caddy 的配置，生成对应的配置文件结构 corefile
	corefile, err := caddy.LoadCaddyfile(serverType)
	// 以 corefile 为配置启动 Caddy
	instance, err := caddy.Start(corefile)
	// Execute instantiation events
	caddy.EmitEvent(caddy.InstanceStartupEvent, instance)
	// Twiddle your thumbs
	instance.Wait()
}
```

##### Plugin 的设计

```go
for _, plugin := range plugins {
	plugin()
}
```

一个请求在被插件处理时，大概有以下几种情况：
1. 请求被当前插件处理，处理完返回对应的响应，至此插件的执行逻辑结束，不会运行插件链的下一个插件
2. 请求被当前插件处理之后跳至下一个插件，即每个插件将维护一个 next 指针，指向下一个插件，转至下一个插件通过 NextOrFailure() 实现
3. 请求被当前插件处理之后增加了新的信息，携带这些信息将请求交由下一个插件处理

写一个插件必须符合一定的接口要求，CoreDNS 在 `coredns/plugin/plugin.go` 中定义了。

```go
type (
	Handler interface {
		// 每个插件处理请求的逻辑
		ServeDNS(context.Context, dns.ResponseWriter, *dns.Msg) (int, error)
		// 返回插件名
		Name() string
	}
)
```

每一个插件都会定义一个结构体，如果不需要对应数据结构就设置一个空的结构体，并为这个对象实现对应的接口。

```go
// 定义一个空的 struct
type Whoami struct{}
// 给 Whoami 对象实现 ServeDNS 方法，w 是用来写入响应，r 是接收到的 DNS 请求
func (wh Whoami) ServeDNS(ctx context.Context, w dns.ResponseWriter, r *dns.Msg) (int, error) {}
// 给 Whoami 对象实现 Name 方法，只需要简单返回插件名字的字符串即可
func (wh Whoami) Name() string { return "whoami" }
```

对于每一个插件，`setup.go` 中都有 `setup()` 函数。

```go
func setup(c *caddy.Controller) error {
	// 通常前面是做一些参数解析的逻辑，dnsserver 层添加插件，next 表示的是下一个插件
	dnsserver.GetConfig(c).AddPlugin(func(next plugin.Handler) plugin.Handler {
		l.Next = next
		return l
	})
}
```

在 `setup()` 中 `AddPlugin()` 将一个函数对象添加到一个插件列表中。

```go
func (c *Config) AddPlugin(m plugin.Plugin) {
	c.Plugin = append(c.Plugin, m)
}
```

##### 处理请求

`coredns/core/dnsserver/register.go`

```go
func (h *dnsContext) MakeServers() ([]caddy.Server, error) {
	var servers []caddy.Server
	// 可以定义多个 group 来对不同的域名做解析，每个 group 都将创建一个不同的 DNS server 的实例
	for addr, group := range groups {
		// switch on addr
		switch tr, _ := parse.Transport(addr); tr {
		case transport.DNS:
			s, err := NewServer(addr, group)
			if err != nil {
				return nil, err
			}
			servers = append(servers, s)
		case transport.TLS:
			s, err := NewServerTLS(addr, group)
			if err != nil {
				return nil, err
			}
			servers = append(servers, s)
		case transport.GRPC:
			s, err := NewServergRPC(addr, group)
			if err != nil {
				return nil, err
			}
			servers = append(servers, s)
		case transport.HTTPS:
			s, err := NewServerHTTPS(addr, group)
			if err != nil {
				return nil, err
			}
			servers = append(servers, s)
		}
	}
	return servers, nil
}
```

```go
func NewServer(addr string, group []*Config) (*Server, error) {
	var stack plugin.Handler
	// 从插件列表的最后一个元素开始
	for i := len(site.Plugin) - 1; i >= 0; i-- {
		// stack 作为此时插件的 next 参数
		// 如果配置文件中的插件顺序是 A,B,C,D，首次初始化时添加到列表就会变成 D,C,B,A
		// 从最后一个元素 A，开始依次调用对应的 plugin.Handler，将有：
		// A: next=nil，B: next=A，C: next=B，D: next=C
		// 最终插件从 D 开始，即原来配置顺序的最后一个
		// 最终的执行顺序为配置文件插件顺序的逆序
		stack = site.Plugin[i](stack)
		// register the *handler* also
		site.registerHandler(stack)
	}
	// 这时的插件是配置文件顺序中的最后一个
	site.pluginChain = stack
}
```

插件链中的插件顺序与配置文件中的插件顺序是相反的。
插件的执行顺序是按照插件链的顺序进行，即是插件配置顺序的逆序。

`coredns/core/dnsserver/server.go`

```go
func (s *Server) ServeDNS(ctx context.Context, w dns.ResponseWriter, r *dns.Msg) {
	// 如果请求落在对应的 zone，执行 zone 内的插件
	if h, ok := s.zones[string(b[:l])]; ok {
		if r.Question[0].Qtype != dns.TypeDS {
			// 如果没有过滤函数
			if h.FilterFunc == nil {
			// 执行插件链上上的插件，如果插件中有 NextOrFailure() 则将跳至下一个插件，否则则直接返回
				rcode, _ := h.pluginChain.ServeDNS(ctx, w, r)
				if !plugin.ClientWrite(rcode) {
					DefaultErrorFunc(ctx, w, r, rcode)
				}
				return
			}
			// FilterFunc is set, call it to see if we should use this handler.
			// This is given to full query name.
			if h.FilterFunc(q) {
				rcode, _ := h.pluginChain.ServeDNS(ctx, w, r)
				if !plugin.ClientWrite(rcode) {
					DefaultErrorFunc(ctx, w, r, rcode)
				}
				return
			}
		}
	}
}
```

## Pod 内配置

![image](https://70data.oss-cn-beijing.aliyuncs.com/note/20201206183153.png)

`/etc/resolv.conf`

```
search hello.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.152.183.10
options ndots:5
```

nameserver：
DNS 查询转发到的服务地址，实际上就是 CoreDNS 服务的地址。

search：
特定域的搜索路径。
大多数 DNS 解析器遵循的标准约定是，如果域名以 . 结尾，代表根区域，该域就会被认为是 FQDN。
有一些 DNS 解析器会尝试用一些自动的方式将 . 附加上。

ndots：
ndots 代表查询名称中的点数阈值。
Kubernetes 中默认为5。
如果查询的域名包含的 . 不到 5 个，那么进行 DNS 查找，将使用非完全限定名称。
如果查询的域名包含的 . 大于等于5，那么 DNS 查询默认会使用绝对域名进行查询。

即：
a.b.c.d.e. 五级域名以下，先查找本地域，如果没有再查找上级 DNS。
a.b.c.d.e.f. 五级域名以上，先查找上级 DNS，如果没有再查找本地域。

## DNS 浪费

1. 使用全限定域名，携带最后的 `.`，并写全路径

即 `a.b.c.`。

2. 具体应用配置特定的 ndots

```yaml
apiVersion: v1
kind: Pod
metadata:
  namespace: default
  name: dns-example
spec:
  containers:
    - name: test
      image: nginx
  dnsConfig:
    options:
      - name: ndots
        value: "1"
```

