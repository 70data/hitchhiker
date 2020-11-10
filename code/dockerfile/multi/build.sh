#!/bin/sh
docker build -t js/docker-multi-stage-demo:build . -f Dockerfile.build

docker create --name extract js/docker-multi-stage-demo:build
docker cp extract:/opt/app ./app
docker rm -f extract

docker build --no-cache -t js/docker-multi-stage-demo:run . -f Dockerfile.run
rm ./app-server

