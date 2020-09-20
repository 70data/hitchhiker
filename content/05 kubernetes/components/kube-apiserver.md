- 提供集群管理的 REST API 接口，包括认证授权、数据校验以及集群状态变更等。
- 提供其他模块之间的数据交互和通信的枢纽，其他模块通过 kube-apiserver 查询或修改数据，只有 kube-apiserver 才直接操作 etcd。

## REST API

![images](http://70data.net/upload/kubernetes/709700eea03075bed35c25b5b6cdefda.png)

## OpenAPI & Swagger

通过 `/swaggerapi` 可以查看 Swagger API，开启 `--enable-swagger-ui=true` 后还可以通过 `/swagger-ui` 访问 Swagger UI。

通过 `/openapi/v2` 查看 OpenAPI。

## 访问控制

![images](http://70data.net/upload/kubernetes/assets_-LDAOok5ngY4pc1lEDes_-LpOIkR-zouVcB8QsFj__-LpOIpdEZgWQrGyDjwu1_access_control.png)
