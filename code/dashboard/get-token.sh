#! /bin/bash
kubectl -n kube-system get secret `kubectl -n kube-system get secret | grep admin-token | awk '{print $1}'` -o jsonpath={.data.token} | base64 -d
