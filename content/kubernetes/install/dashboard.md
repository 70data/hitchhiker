dashboard 配置文件
http://70data.net/upload/manifest/dashboard/dashboard-1.10.1.yaml

发布

```shell script
kubectl apply -f dashboard-1.10.1.yaml
```

查看

```shell script
kubectl -n kube-system get pods -l k8s-app=kubernetes-dashboard
```

生成密钥

```shell script
kubectl -n kube-system get secret `kubectl -n kube-system get secret | grep admin-token | awk '{print $1}'` -o jsonpath={.data.token} | base64 -d
```

通过 `node:8443` 访问。

