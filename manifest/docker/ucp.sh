#! /bin/bash

CONTAINER_NAME=nginx
pause_image=$(docker container inspect ${CONTAINER_NAME} --format {{.Config.Image}})
docker container create --name nginx-pause ${pause_image}
docker container logs -f ${CONTAINER_NAME} > ${CONTAINER_NAME}-${HOSTNAME}-$(date -Is).log 2>&1 &
docker container kill -s SIGABRT ${CONTAINER_NAME}
test -n "$(docker ps -qaf is-task=true -f name=${CONTAINER_NAME})" || docker container start ${CONTAINER_NAME}
docker container rm nginx-pause
