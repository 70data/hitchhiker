## IPVlan

https://docs.cilium.io/en/v1.7/gettingstarted/ipvlan/

## Host-Reachable Services

https://docs.cilium.io/en/v1.7/gettingstarted/host-services/

## Kubernetes without kube-proxy

如果使用 yaml 安装，需要声明环境变量 `KUBERNETES_SERVICE_HOST`、`KUBERNETES_SERVICE_PORT`。

如果使用 helm 安装，需要声明环境变量 `API_SERVER_IP`、`API_SERVER_PORT`。

查看 Cilium 加载模块

```
kubectl exec -it -n kube-system cilium-5ztht -- cilium status | grep KubeProxyReplacement
KubeProxyReplacement: Strict [NodePort (SNAT, 30000-32767), ExternalIPs, HostReachableServices (TCP, UDP)]
```

部署 Nginx 测试

http://70data.net/upload/manifest/nginx/nginx-deployment.yaml

http://70data.net/upload/manifest/nginx/nginx-service-nodeport.yaml

```
kubectl apply -f nginx-deployment.yaml

kubectl apply -f nginx-service-nodeport.yaml

kubectl get svc nginx
NAME    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
nginx   NodePort   10.107.137.30   <none>        80:30202/TCP   10s

kubectl exec -it -n kube-system cilium-5ztht -- cilium service list
ID   Frontend            Service Type   Backend
1    10.96.0.1:443       ClusterIP      1 => 10.16.29.16:6443
2    10.96.0.10:53       ClusterIP      1 => 10.217.0.171:53
                                        2 => 10.217.0.57:53
3    10.96.0.10:9153     ClusterIP      1 => 10.217.0.171:9153
                                        2 => 10.217.0.57:9153
4    10.107.137.30:80    ClusterIP      1 => 10.217.0.203:80
5    0.0.0.0:30202       NodePort       1 => 10.217.0.203:80
6    10.16.29.16:30202   NodePort       1 => 10.217.0.203:80
7    10.217.0.99:30202   NodePort       1 => 10.217.0.203:80

curl 10.217.0.203:80
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>
<p><em>Thank you for using nginx.</em></p>
</body>
</html>

curl 10.107.137.30:80
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>
<p><em>Thank you for using nginx.</em></p>
</body>
</html>

curl 127.0.0.1:30202
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>
<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

默认情况下，Cilium 的 BPF NodePort 实现是使用的 SNAT 模块。包括节点外的流量接入以及节点将流量转发到 NodePort 或者 ExternalIPs 后端。
不需要任何额外的 MTU 更改，代价是后端响应需要返回该节点，以便在将包直接返回到外部之前执行反向 SNAT 转换。

DSR 模式下，后端会直接返回流量，而不需要任何额外跳转。这意味着后端应用可以使用 service 的源 IP/port 作为应答。
DSR 模式的另一个优点是保留了客户机的源 IP（ SNAT 模式下不支持）。

DSR 模式需要依赖 直接路由/本地路由。

如果使用 helm 安装，可以通过设置 helm 中的 `global.nodePort.mode` 参数，启动 DSR 模式。

## Cluster Mesh

https://docs.cilium.io/en/v1.7/gettingstarted/clustermesh/
