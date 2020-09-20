#! /bin/bash
kubectl delete -f cilium-1.7.0.yaml

rm -f cilium-1.7.0.yaml

wget http://70data.net/upload/manifest/cilium-1.7.0.yaml

kubectl apply -f cilium-1.7.0.yaml

kubectl -n kube-system  get all

kubectl -n kube-system  get pods

kubectl -n kube-system  get pods --selector=k8s-app=cilium
